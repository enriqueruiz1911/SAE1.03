#!/bin/sh
set -eu

errf() { code=$?; printf "$@" 1>&2; exit $code; }
trap "errf 'backup failed, see output above\n'" INT TERM

export BORG_REPO=/root/backup
export BORG_PASSPHRASE='entreprise_s103'

[ -d "$BORG_REPO" ] || mkdir -p "$BORG_REPO"

echo 'creating backup'
echo "repository: '$BORG_REPO'"
echo

borg create \
  --verbose \
  --filter AME \
  --list \
  --stats \
  --show-rc \
  --compression lz4 \
  --exclude-caches \
  --exclude 'home/*/.cache/*' \
  --exclude 'var/tmp/*' \
  "::'{hostname}-{now:%Y-%m-%d_%H-%M-%S}'" \
  /etc \
  /home \
  /root \
  /var

echo
echo "pruning repository"
echo

borg prune \
  --list \
  --glob-archives '{hostname}-*' \
  --show-rc \
  --keep-daily=7 \
  --keep-weekly=4 \
  --keep-monthly=6

echo
echo 'compacting'
echo

borg compact $BORG_REPO

echo "all done."
trap - INT TERM

