#!/bin/bash

fail() { echo "ERR@$@"; exit 1; }
log() { echo "cloudinit/bootstrap: $@"; }
silent() { "$@" >/dev/null 2>&1; }

basedir="/etc/cloudconfig"

ssh() {
	log "Deploying root SSH key..."
	local fname="/root/.ssh/authorized_keys"
	mkdir -p $(dirname $fname)
	cp -uv $basedir/etc/ssh/authorized_keys $fname
}

network() {
	log "Network: using kernel naming policy..."
	local fname="/etc/systemd/network/00-dev.link"; [ -f $fname ] || cat > $fname \
<< EOF
[Link]
NamePolicy=kernel
EOF

	log "Network: disabling IPv6..."
	local fname="/etc/sysctl.d/10-disable-ipv6.conf"; [ -f $fname ] || cat > $fname \
<< EOF
net.ipv6.conf.all.disable_ipv6=1
EOF
}

reboot_if_needed() {
	local fname="/var/lib/cloudconfig/.bootconfigured"; [ -f $fname ] || {
		log "Rebooting to apply network changes..."
		mkdir -p $(dirname $fname) && date > $fname
		reboot
	}
}

pki() {
	log "PKI: Deploying domain CA..."
	fname="/etc/ssl/certs/ca.${domain}.pem"; [ -f $fname ] || (
		cp -uv $basedir/etc/ssl/pki/ca.crt
		curl -sf -o $fname http://init.cloud.local/pki/ca.crt && update-ca-certificates >/dev/null \
			&& log "CA updated" \
			|| log "CA update failed."
	)
}

binaries() {
	log "Updating Kubernetes binaries..."
	mkdir -p /opt/bin; cd /opt/bin && (
		wget -qN ${URL}/bin/{kubelet,kubectl}
		[ -L kctl ] || ln -s kubectl kctl
		chmod +x *;
		/opt/bin/kubelet --version
		/opt/bin/kubectl version --client
	)
}


customize() {
	case $(hostname -s) in
		router) ;;
		admin) ;;
		master) ;;
		node*) ;;
	esac
}

main() {
	ssh
	network
	reboot_if_needed
	pki
	binaries
	customize
}

###

"${@:-main}"

