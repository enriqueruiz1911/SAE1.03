#!/bin/sh
set -eu

errf() { code=$?; printf "$@" 1>&2; exit $code; }

[ -z "${HOME+}" ] && [ ! -d "$HOME" ] && { errf 'HOME is unset or invalid'; }
[ -z "${XDG_CONFIG_HOME+}" ] && { XDG_CONFIG_HOME="$HOME/.config"; }

# overwrite pcmanfm-qt config for wallpaper on lxqt
#CONF_PATH="$XDG_CONFIG_HOME/pcmanfm-qt/lxqt/settings.conf"
#[ ! -d "$CONF_PATH" ] && mkdir -p "$CONF_PATH"
#cat /etc/xdg/pcmanfm-qt/lxqt/settings.conf | \
#  sed 's/Wallpaper=.*/Wallpaper=\/usr\/share\/backgrounds\/s103.jpg/' \
#  >"$CONF_PATH"

