#!/bin/bash

set -u

# defaults
cn_ca_default="/CN=kube-ca"
cn_apiserver_default="/CN=kube-apiserver"
cn_admin_default="/CN=kube-admin"
domain_default="cloud.local"

# params
cn_ca="${cn_ca:-$cn_ca_default}"
cn_apiserver="${cn_apiserver:-$cn_apiserver_default}"
cn_admin="${cn_admin:-$cn_admin_default}"
domain="${domain:-$domain_default}"

cd $(dirname $0)

ca() {
   [ -f ca.key ] || openssl genrsa -out ca.key 2048
	[ -f ca.crt ] || openssl req -x509 -new -nodes -key ca.key -days 10000 -out ca.crt -subj "$cn_ca"
	ls -la ca.{key,crt}
}

apiserver() {
	local conf="$(mktemp)"; trap "rm -f $conf" EXIT
	cat > $conf \
<< EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = master.${domain}
EOF

	[ -f apiserver.key ] || openssl genrsa -out apiserver.key 2048
	[ -f apiserver.csr ] || openssl req -new -key apiserver.key -subj "$cn_apiserver" -config $conf -out apiserver.csr
	[ -f apiserver.crt ] || openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -extensions v3_req \
		-out apiserver.crt -extfile $conf
	ls -l apiserver.{key,csr,crt}
}

admin() {
	[ -f admin.key ] || openssl genrsa -out admin.key 2048
	[ -f admin.csr ] || openssl req -new -key admin.key -out admin.csr -subj "$cn_admin"
	[ -f admin.crt ] || openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -out admin.crt
	ls -l admin.{key,csr,crt}
}

node() {
   local conf="$(mktemp)"
   local name="$1"
   cat > $conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.${domain}
EOF

	[ -f ${name}.key ] || openssl genrsa -out ${name}.key 2048
	[ -f ${name}.csr ] || openssl req -new -key ${name}.key -subj "/CN=${name}" -config $conf \
		-out ${name}.csr
	[ -f ${name}.crt ] || openssl x509 -req -in ${name}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
		-days 365 -extensions v3_req -extfile $conf \
		-out ${name}.crt
	ls -l ${name}.{key,csr,crt}
}

pfx() {
	for name in $(ls -1 *.key | sed 's/.key$//'); do
		[ -f $name.pfx ] || openssl pkcs12 -export -out $name.pfx \
			-inkey $name.key -in $name.crt -certfile ca.crt \
			-passin pass: -passout pass:
		ls -l $name.pfx
	done
}

help() {
cat << EOF
ca
apiserver
admin
node <name>
EOF
}

"${@:-help}"
