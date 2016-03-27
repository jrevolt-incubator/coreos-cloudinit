#!/bin/bash
set -u

fail() { echo "ERR@$@"; exit 1; }
log() { echo "cloudconfig: $@"; }
silent() { "$@" >/dev/null 2>&1; }

URL="http://cloudinit/"
basedir="/etc/cloudconfig"

main() {
	echo "#### $(dirname $0)"
	passwd -d root
	fail $LINENO "STOP"


	if is_online; then
   	[ -d $basedir/.git ] && (cd $basedir && git pull) || git clone $URL $basedir
	else
      [ -d $basedir ] || extract
	fi
	$basedir/bin/cloud-config.sh
}

is_online() {
	silent curl -sf --head http://cloudinit/
}

extract() {
	silent rm -rf $basedir
	mkdir -p $basedir
	dump_archive | base64 -d | tar xz -C $basedir
}

validate() {
	(dump_archive | base64 -d | tar tz) >/dev/null || exit 1
}

dump_archive() {
cat << EOF
##ARCHIVE.TGZ.BASE64##
EOF
}

"${@:-main}"
