#!/bin/sh
set -eu
/bin/sh -c 'set -o pipefail' >/dev/null 2>&1 && set -o pipefail || :

# placeholder
[ -n "${HOST-}" ] || HOST='http://192.168.1.14'

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
apt install -y lxqt flatpak gnome-software gnome-software-plugin-flatpak neovim webext-ublock-origin
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

curl "$HOST/s103.jpg" -o /usr/share/backgrounds/s103.jpg
curl "$HOST/s103_2.jpg" -o /usr/share/backgrounds/s103_2.jpg
curl "$HOST/s103.png" -o /usr/share/backgrounds/s103.png
curl "$HOST/s103_2.png" -o /usr/share/backgrounds/s103_2.png

sed -i 's/Wallpaper=.*/Wallpaper=\/usr\/share\/backgrounds\/s103.png/' \
  /etc/xdg/pcmanfm-qt/lxqt/settings.conf

# LAMP
apt install -y apache2 libapache2-mpm-itk \
  mariadb-server mariadb-client \
  libapache2-mod-php php-mysql phpmyadmin

# multimedia
apt install -y ffmpeg imagemagick kodi

# boot
command -v magick >/dev/null 2>&1 || magick() { convert "$@"; }
magick /usr/share/backgrounds/s103_2.png \
  -resize 640x480^ -gravity center -extent 640x480 /boot/background.png
curl "$HOST/boot.jpg" -o /boot/grub/back.jpg
grep -Fq 'GRUB_WALLPAPER="/boot/grub/back.jpg"' /etc/default/grub || {
  echo 'GRUB_WALLPAPER="/boot/grub/back.jpg"' >>/etc/default/grub
}

sed -i 's/^#background=.*/background=\/usr\/share\/backgrounds\/s103_2.png/' /etc/lightdm/lightdm-gtk-greeter.conf
cat >/etc/lightdm/lightdm.conf.d/00-live.conf <<__EOF__
[SeatDefaults]
autologin-user=trisquel
autologin-user-timeout=3
user-session=lxqt
greeter-session=lightdm-gtk-greeter

__EOF__

systemctl disable mariadb # spams logs during live install
set +x
echo 'all done.'
echo

