#!/bin/bash -ex
mkfs.xfs /dev/sdb
mkdir -p /var/lib/lago
mount /dev/sdb /var/lib/lago
