#!/bin/sh
set -eu
/bin/sh -c 'set -o pipefail' >/dev/null 2>&1 && set -o pipefail || :

# placeholder
[ -n "${HOST-}" ] || HOST='https://raw.githubusercontent.com/enriqueruiz1911/SAE1.03/refs/heads/main'

admin_pass='entreprise_s103'
app_pass='s103'

echo
echo 'S1.03 - Cubic environment setup'
echo 'press ^C to abort'
trap exit INT TERM
sleep 3
set -x

cleanup() { trap - INT TERM; apt autoremove; }
trap 'cleanup && exit' INT TERM

export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# remote
apt install -y curl openssh-server git xrdp rsync
# (the ports are already bound to on my vm interface)
sed -i 's/^port=.*/port=13389/' /etc/xrdp/xrdp.ini
sed -i 's/^#Port .*/Port 10022/' /etc/ssh/sshd_config
# hardening (each user will need to login with an openssh key and append
# their public key to $HOME/.ssh/authorized_keys)
sed -i 's/^#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

# i18n
apt install -y aspell-fr language-pack-fr language-pack-gnome-fr
locale-gen fr_FR && locale-gen fr_FR.UTF-8
update-locale LANG=fr_FR.UTF-8
# localectl set-locale LANG=fr_FR.UTF-8 || :

# desktop
apt purge -y lxde || :
apt purge -y lxsession || :
apt purge -y lxterminal || :
apt purge -y xfwm4 || :
apt install -y lxqt flatpak gnome-software gnome-software-plugin-flatpak webext-ublock-origin
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

curl "$HOST/bg/s103.png" -o /usr/share/backgrounds/s103.png
curl "$HOST/bg/s103.jpg" -o /usr/share/backgrounds/s103.jpg
curl "$HOST/bg/s103_darker.png" -o /usr/share/backgrounds/s103_darker.png
curl "$HOST/bg/s103_darker.jpg" -o /usr/share/backgrounds/s103_darker.jpg

sed -i 's/Wallpaper=.*/Wallpaper=\/usr\/share\/backgrounds\/s103.png/' \
  /etc/xdg/pcmanfm-qt/lxqt/settings.conf

# backup
apt install -y borgbackup

export BORG_PASSPHRASE="$admin_pass"
export BORG_REPO=/root/backup

mkdir -p "$BORG_REPO"
code=; borg init --encryption=repokey "$BORG_REPO" 2>/dev/null || code=$?
[ $code -ne 0 ] && [ ! -f "$BORG_REPO"/* ] && exit $code

curl "$HOST/sh/backup.sh" -o /usr/local/bin/backup.sh
chmod 755 /usr/local/bin/backup.sh

# development
apt install -y neovim nodejs python3

apt install -y apache2 libapache2-mpm-itk \
  mariadb-server mariadb-client \
  libapache2-mod-php php-mysql phpmyadmin

[ -d /etc/skel/www ] || mkdir /etc/skel/www
cat >/etc/skel/www/index.php <<__EOF__
<?php
\$serverName = \$_SERVER['SERVER_NAME'];
\$serverSoftware = \$_SERVER['SERVER_SOFTWARE'];
\$dir = __DIR__;
?>

<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Page par défaut</title>
</head>
<body>
  <header>
    <h1>Bienvenue</h1>
  </header>
  <section>
    <p>Vous êtes sur la page par défaut du serveur Web de l'ordinateur de votre entreprise.</p>
    <p>Votre site Web est dans <strong><a href="file://<?php echo \$dir; ?>"><?php echo \$dir; ?></a></strong>.</p>
  </section>
  <footer>
    <hr />
    <p>
      Hôte : <?php echo \$serverName; ?><br>
      Logiciel : <?php echo \$serverSoftware; ?>
    </p>
  </footer>
</body>
</html>
__EOF__

# multimedia
apt install -y ffmpeg imagemagick kodi

# boot
command -v magick >/dev/null 2>&1 || magick() { convert "$@"; }
magick /usr/share/backgrounds/s103_darker.png \
  -resize 640x480^ -gravity center -extent 640x480 /boot/background.png
magick /boot/background.png -resize 640x480! -colors 256 \
  -type Palette -dither FloydSteinberg /boot/grub/back.jpg
# curl "$HOST/isolinux/back.jpg" -o /boot/grub/back.jpg
grep -Fq 'GRUB_WALLPAPER="/boot/grub/back.png"' /etc/default/grub || {
  echo 'GRUB_WALLPAPER="/boot/grub/back.png"' >>/etc/default/grub
}

sed -i 's/^#background=.*/background=\/usr\/share\/backgrounds\/s103_darker.png/' /etc/lightdm/lightdm-gtk-greeter.conf
cat >/etc/lightdm/lightdm.conf.d/00-live.conf <<__EOF__
[SeatDefaults]
autologin-user=trisquel
autologin-user-timeout=3
user-session=lxqt
greeter-session=lightdm-gtk-greeter

__EOF__

systemctl disable mariadb # spams logs during live install

# post-installation
curl "$HOST/sh/post.sh" -o /usr/local/bin/post-setup.sh
chmod 744 /usr/local/bin/post-setup.sh

cat >/etc/systemd/system/post-setup.service <<__EOF__
# this systemd service runs once and deletes itself after the setup is
# done to configure everything that couldn't be done in the cubic chroot

[Unit]
Description=Run post-setup script on first boot
After=network.target

[Service]
ExecStart=/usr/local/bin/post-setup.sh
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
__EOF__

systemctl enable post-setup.service

set +x
echo 'all done.'
echo

