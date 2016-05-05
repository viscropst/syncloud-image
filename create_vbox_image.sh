#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

apt-get install -y virtualbox

VBoxManage convertdd syncloud-vbox.img syncloud.vdi --format VDI

cp syncloud.vdi syncloud-test.vdi

VM='Syncloud-VM'

VBoxManage createvm --name $VM --ostype "Debian_64" --register

VBoxManage storagectl $VM --name "SATA Controller" --add sata --controller IntelAHCI

VBoxManage storageattach $VM --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium syncloud-test.vdi

VBoxManage modifyvm $VM --ioapic on

VBoxManage modifyvm $VM --boot1 dvd --boot2 disk --boot3 none --boot4 none

VBoxManage modifyvm $VM --memory 1024 --vram 128

VBoxManage modifyvm $VM --nic1 bridged --bridgeadapter1 e1000g0

VBoxHeadless -s $VM
