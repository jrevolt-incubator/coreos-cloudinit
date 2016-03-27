#!/bin/bash

fail() { echo "ERR@$@"; exit 1; }
log() { echo "cloudinit/bootstrap: $@"; }

domain="$(hostname -d)"
URL="http://cloudinit.${domain}"

ssh() {
log "Deploying root SSH key..."
local fname="/root/.ssh/authorized_keys"; mkdir -p $(dirname $fname); cat >> $fname << EOF
$(curl -s $URL/root/authorized_keys)
EOF
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
	local fname="/var/lib/cloudinit/.bootconfigured"; [ -f $fname ] || {
		log "rebooting to apply network changes..."
		mkdir -p $(dirname $fname) && date > $fname
		reboot
	}
}

pki() {
	log "PKI: Deploying domain CA..."
	fname="/etc/ssl/certs/ca.${domain}.pem"; [ -f $fname ] || (
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

node() {
	# strip numeric suffix from host name and use result as type.sh script name
	fname="$(hostname -s | sed 's/-[0-9]*$//')"
	curl -sf $URL/node/${fname}.sh | bash || log "${fname}.sh failed."
}

###

main() {
	ssh
	network
	reboot_if_needed
	pki
	binaries
	node
}

###

"${@:-main}"

