#!/bin/sh
set -eu

errf() { code=$?; printf "$@" 1>&2; exit $code; }
escape() { printf "%s" "$1" | sed 's/[\/&]/\\&/g' | sed ':a;N;$!ba;s/\n/\\n/g'; }
set -x

# placeholder
[ -n "${HOST-}" ] || HOST='https://raw.githubusercontent.com/enriqueruiz1911/SAE1.03/refs/heads/main'

admin_pass='entreprise_s103'
app_pass='s103'

[ -n "${HOSTNAME-}" ] || HOSTNAME="$(cat /etc/hostname)"

user="$(getent passwd 1000)" || \
user="$(getent passwd | grep /home | \
  grep -v "$(command -v nologin)")"
username="$(echo "$user" | cut -d':' -f1)"
home="$(echo "$user" | cut -d':' -f6)"
group="$(echo "$user" | cut -d':' -f4)"
user="$(echo "$user" | cut -d':' -f3)"

export DEBIAN_FRONTEND='noninteractive'

rm -f /etc/lightdm/lightdm.conf.d/00-live.conf
tmp="$(mktemp)"
cp /etc/default/grub "$tmp"
update-grub
cp "$tmp" /etc/default/grub

echo 'enabling Apache2/httpd modules'

phpver=$(find '/etc/apache2/mods-available' -iname 'php*' -printf '%f\n' | \
  sed -E 's/php([0-9]+(\.[0-9]+)).*/\1/' | \
  sort -V | tail -n 1) ||
{
  errf 'php module not found\n'
}
a2enmod "php$phpver" && echo "+ php$phpver"
a2enmod ssl && echo '+ ssl'
unset phpver

echo 'configuring httpd site'

conf="/etc/apache2/sites-available/$HOSTNAME.conf"
cp -a /etc/apache2/sites-available/default-ssl.conf "$conf"
sed -Ei "s/^(\s*)ServerAdmin .*/\1ServerAdmin $username@$HOSTNAME/" "$conf"
sed -Ei "s/^(\s*)DocumentRoot .*/\1DocumentRoot $(escape "$home/www")\n\1__XML__/" "$conf"

# we can use the hostname as the server name as it resolves to the loopback
# interface (127.0.1.1)
xml="$(cat <<__EOF__
ServerName $HOSTNAME
		AssignUserID #$user #$group

		<Directory $home/www>
			Require all granted
		</Directory>
__EOF__
)"
sed -i "s/__XML__/$(escape "$xml")/" "$conf"

rm -f /etc/apache2/sites-enabled/*.conf || :
ln -s "$conf" /etc/apache2/sites-enabled/"$(basename -- "$conf")"

echo 'configuring MariaDB'

echo "mariadb-server mysql-server/root_password password $admin_pass"
echo "mariadb-server mysql-server/root_password_again password $admin_pass"
dpkg-reconfigure -f noninteractive mariadb-server

db="$(echo "$HOSTNAME" | sed 's/-/_/g')"

systemctl is-active --quiet mariadb && systemctl stop mariadb
systemctl start mariadb
# mostly taken from mariadb-secure-installation
mariadb -u root -p"$admin_pass" <<__EOF__
DROP USER IF EXISTS '$username'@'localhost';

show create user root@localhost;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$admin_pass');
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';

CREATE DATABASE IF NOT EXISTS $db;
CREATE USER '$username'@'localhost' IDENTIFIED BY '$app_pass';
GRANT ALL PRIVILEGES ON $db.* TO '$username'@'localhost';

FLUSH PRIVILEGES;
__EOF__

cat >"$home/.my.cnf" <<__EOF__
[client]
database="$db"
user="$username"
password="$app_pass"
host="localhost"

__EOF__

chown $user:$group "$home/.my.cnf"
chmod 400 "$home/.my.cnf"

echo 'configuring phpMyAdmin'

conf="$(mktemp)" tmp="$(mktemp)"

env admin_pass="$admin_pass" app_pass="$app_pass" \
  user="$user" group="$user" username="$username" home="$home" \
  sh -eux <<__EOF__
trap "rm -f '$conf' || :; rm -f '$tmp' || :; exit" INT TERM
curl "$HOST/preseed/phpmyadmin.seed" -o "$tmp"
envsubst <"$tmp" >"$conf"
rm -f "$tmp"

debconf-set-selections "$conf"
dpkg-reconfigure -f noninteractive phpmyadmin

__EOF__

echo 'creating desktop icons'

cat >/usr/share/applications/s103-httpd.desktop <<__EOF__
[Desktop Entry]
Version=1.0
Name=S1.03 httpd
Comment=Site web Apache
Exec=xdg-open https://$HOSTNAME
Icon=web-browser
Terminal=false
Type=Application
Categories=Internet;WebBrowser;
__EOF__

cat >/usr/share/applications/s103-phpmyadmin.desktop <<__EOF__
[Desktop Entry]
Version=1.0
Name=S1.03 phpMyAdmin
Comment=Accéder à phpMyAdmin
Exec=xdg-open https://$HOSTNAME/phpmyadmin
Icon=phpmyadmin
Terminal=false
Type=Application
Categories=Internet;WebBrowser;
__EOF__

ln -fs /usr/share/applications/s103-httpd.desktop "$home/Desktop/s103-httpd.desktop"
ln -fs /usr/share/applications/s103-phpmyadmin.desktop "$home/Desktop/s103-phpmyadmin.desktop"

echo 'setting up daily backup'

# backup
cronjob='0 0 * * * /usr/local/bin/backup.sh >>/var/log/backup.log 2>&1'
( crontab -l 2>/dev/null | grep -Fv "$cronjob"; echo "$cronjob" ) | crontab -

# restart services after configuration
systemctl is-active --quiet apache2 && systemctl restart apache2
systemctl is-active --quiet mariadb && systemctl restart mariadb

# delete service so this only runs once
service=/etc/systemd/system/post-setup.service
[ -f "$service" ] && rm -f "$service"

echo 'all done.'

