#!/bin/bash

fail() { echo "ERR@$@"; exit 1; }
log() { echo "cloudinit/bootstrap: $@"; }

domain="$(hostname -d)"
URL="http://cloudinit.${domain}"

log "kubernetes: Updating certificates..."
mkdir -p /etc/kubernetes/ssl; cd /etc/kubernetes/ssl && (
	wget -qN $URL/pki/apiserver.{key,crt}
	[ -L ca.crt ] || ln -s /etc/ssl/certs/ca.${domain}.pem ca.crt
	ls -la
)

log "kubernetes: Updating manifests..."
mkdir -p /etc/kubernetes/manifests; cd /etc/kubernetes/manifests && (
	wget -qN $URL/manifests/master/kube-{apiserver,controller-manager,podmaster,proxy,scheduler,dns}.yaml
	ls -la
)

log "cloudinit: Updating and running config..."
mkdir -p /etc/cloudinit; cd /etc/cloudinit && (
	fname="master.yaml"
	wget -qN "$URL/config/$fname" || log "cloudinit: No such file: $fname"
	[ -f $fname ] && coreos-cloudinit --from-file="$fname"
)

