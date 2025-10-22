#!/bin/sh
set -eu

errf() { code=$?; printf "$@" 1>&2; exit $code; }
usage() {
  errf 'usage: %s -i input_dir output_dir\n' "$0"
  exit 1
}

# placeholder
[ -n "${HOST-}" ] || HOST='https://raw.githubusercontent.com/enriqueruiz1911/SAE1.03/refs/heads/main'

while getopts "i:" opt; do
  case "$opt" in
    i) in="$OPTARG";;
    *) usage;;
  esac
done

shift $(( OPTIND-1 ))
[ $# -lt 1 ] && usage
out="$1"

[ -d "$in" ] && [ -f "$in/bootlogo" ] && [ -n "$out" ] || usage
[ -d "$out" ] || mkdir -p "$out"

in="$(realpath -- "$in")"
(
  cd "$out"
  cpio -idm <"$in/bootlogo"
  rm -f "$out/bootlogo" || :
  # curl "$HOST/isolinux/back.jpg" -o "$out/back.jpg"
  # curl "$HOST/isolinux/back.png" -o "$out/back.png"
  curl "$HOST/isolinux/txt.cfg" -o "$out/txt.cfg"
  curl "$HOST/isolinux/rqtxt.cfg" -o "$out/rqtxt.cfg"
  find . | cpio -o >"$out/bootlogo"
)

