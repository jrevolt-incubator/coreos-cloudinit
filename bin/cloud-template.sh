#!/bin/bash
set -u

basedir="$(realpath $(dirname $0)/..)"
ovfdir="$basedir/cloud-template"

log() { echo "$@" >&2; }
fail() { echo "${@:-FAIL}"; exit 1; }


build_archive() {
	log "Building and encoding archive..."
	tar cz -C $basedir bin cloud-config manifests pki router | base64 -w0
}

build_user_data() {
cat << EOF
$(cat $basedir/bin/cloud-template-openstack-user-data.sh | sed 's/##ARCHIVE.TGZ.BASE64##/'$(build_archive | sed 's/\//\\\//g')'/' )
EOF
}

build_iso() {
	echo "Building ISO..."
	local workdir=$(mktemp -d); trap "rm -rf $workdir" EXIT
	mkdir -p $workdir/openstack/latest
	build_user_data > $workdir/openstack/latest/user_data

	log "- validating encoded archive"
	bash $workdir/openstack/latest/user_data validate || fail "$LINENO Invalid archive"

   mkisofs -R -V config-2 --input-charset=utf-8 -joliet \
   	-o $basedir/cloud-template/cloud-template.iso $workdir \
   	>/dev/null 2>&1 || fail $LINENO
}

rebuild() {
	build_iso
	update_ovf
}

build_manifest() {
	(
	local fname="$1"
	log "$fname: building manifest"
	cd $ovfdir
	sha1sum --tag $fname *.vmdk *.iso > ${fname%.ovf}.mf || fail $LINENO
	)
}

update_ovf() {
	(
	cd $ovfdir
	for fname in *.ovf; do
		log "$fname: updating file sizes in OVF"
     	sed -i -r 's#<File ovf:href="([^"]*)".*#'$basedir/bin/cloud-template.sh' get_ovf_fileref \1#ge' $fname
     	build_manifest $fname
	done
	)
}

get_ovf_fileref() {
	(
	local fname="$1"
	cd $ovfdir || fail $LINENO
   echo "<File ovf:href=\"$fname\" ovf:id=\"$fname\" ovf:size=\""$(stat --printf="%s" $fname)"\"/>"
   )
}

help() {
	echo "todo: help()"
}

"${@:-help}"
