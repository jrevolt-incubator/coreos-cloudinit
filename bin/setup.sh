#!/bin/bash

esxhost=
datastore=

get_ovftool() {
	docker pull jrevolt/ovftool
}

get_coreos() {
	curl -L -o coreos.ova http://alpha.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ova
}

deploy() {
	docker run -it --rm=true jrevolt/ovftool \
	--name=cloud-vm99-test -ds=SSD2 -dm=thin --net:"VM Network=greenhorn.sk" \
	--disableVerification --noSSLVerify \
	--X:injectOvfEnv --prop:"guestinfo.coreos.config.data=hey" --prop:"guestinfo.coreos.config.data.encoding=gzip+base64" \
	http://alpha.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ova \
	"vi://patrik%40vsphere.local:${mypass}@wserver.greenhorn.sk/Datacenter/host/esxi.greenhorn.sk/Resources/3-demo/3.2-cloud.local"


# --numberOfCpus
# --memorySize
docker run -it --rm jrevolt/ovftool --name=cloud-vm99-test -ds=SSD2 -dm=thin --net:"VM Network=greenhorn.sk" --disableVerification --noSSLVerify "https://root:${mypass}@esxi.greenhorn.sk/folder/cloud-template/cloud-template.ovf?dcPath=ha%252ddatacenter&dsName=HDD" "vi://patrik%40vsphere.local:${mypass}@wserver.greenhorn.sk/Datacenter/host/esxi.greenhorn.sk/Resources/3-demo/3.2-cloud.local"
}

vmxupdate_router() {
	local vmname="$1"
	local hostname="$2"
	$basedir/guestinfo.sh vmxupdate $esxhost $datastore $vmname $hostname
}

