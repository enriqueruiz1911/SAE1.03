#!/bin/sh
set -eu

[ -n "${HOST-}" ] || HOST='https://raw.githubusercontent.com/enriqueruiz1911/SAE1.03/refs/heads/main'

curl "$HOST/preseed/trisquel.seed" >./custom-disk/preseed/trisquel.seed

script="$(mktemp)" tmp="$(mktemp -d)"
trap "rm -rf '$script' '$tmp'; exit" INT TERM
curl "$HOST/sh/isolinux.sh" >"$script"
sh "$script" -i ./custom-disk/isolinux "$tmp"
cp -r "$tmp"/* ./custom-disk/isolinux/

