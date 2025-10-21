#!/bin/sh
set -eu

errf() { code=$?; printf "$@" 1>&2; exit $code; }

echo 'enabling Apache modules'

phpver=$(find '/etc/apache2/mods-available' -iname 'php*' -printf '%f\n' | \
  sed -E 's/php([0-9]+(\.[0-9]+)).*/\1/' | \
  sort -V | tail -n 1) ||
{
  errf 'php module not found\n'
}
a2enmod "php$phpver" && echo "+ php$phpver"
a2enmod ssl && echo '+ ssl'

systemctl is-active --quiet apache2 && systemctl restart apache2

