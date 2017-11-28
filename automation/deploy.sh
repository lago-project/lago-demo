#!/bin/bash -ex
yum install -y python2 libselinux-python
mkfs.xfs /dev/sdb
mkdir -p /var/lib/lago
mount /dev/sdb /var/lib/lago
