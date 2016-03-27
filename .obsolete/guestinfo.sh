#!/bin/bash

set -u

encode() {
	echo "$(gzip <&0 | base64 -w0)"
}

decode() {
	base64 -d <&0 | gunzip
}

fencode() {
	cat "$1" | encode
}

fdecode() {
	cat "$1" | decode
}

properties0() {
cat << EOF
guestinfo.coreos.config.data="$(bootstrap0 | encode)"
guestinfo.coreos.config.data.encoding="gzip+base64"
EOF
}

properties() {
cat << EOF
guestinfo.coreos.config.data="$("$@")"
guestinfo.coreos.config.data.encoding="gzip+base64"
EOF
}

properties2() {
local name="$1"
cat << EOF
guestinfo.coreos.config.data="$(bootstrap2 | encode)"
guestinfo.coreos.config.data.script="$(fencode cloud-config/$name.sh)"
guestinfo.coreos.config.data.yaml="$(fencode cloud-config/$name.yaml)"
guestinfo.coreos.config.data.encoding="gzip+base64"
EOF
}

bootstrap0() {
cat << EOF
#!/bin/bash
passwd -d root
EOF
}

bootstrap1() {
cat << EOF
#!/bin/bash
(passwd -d root; curl -sf http://cloudinit/bootstrap.sh | bash) 2>&1
EOF
}

bootstrap2() {
cat << EOF
#!/bin/bash
infoget() { /usr/share/oem/bin/vmtoolsd --cmd="info-get $1"; }
mkdir /etc/cloud-config && cd /etc/cloud-config && (
infoget guestinfo.coreos.config.data.tgz    | base64 -d | tar xzv
infoget guestinfo.coreos.config.data.script | base64 -d | gunzip > /etc/cloud-config.sh
/bin/bash /etc/cloud-config.sh
)
EOF
}

vmxupdate() {
local esxhost="$1"
local datastore="$2"
local vmname="$3"
local hostname="$4"
local fname="/vmfs/volumes/${datastore}/${vmname}/${vmname}.vmx"
local tmp="$(mktemp)"; trap "rm -f $tmp" EXIT
cat > $tmp << EOF
$(ssh root@${esxhost} cat $fname | grep -vE "^guestinfo.coreos.config.data.*")
$(properties2 $hostname)
EOF
}

help() {
cat << EOF
encode
decode
fencode <file>
fdecode <file>
properties <command-encoding-data>
vmxupdate <esxhost> <datastore> <vmname> <hostname>
EOF
}

"${@:-help}"
