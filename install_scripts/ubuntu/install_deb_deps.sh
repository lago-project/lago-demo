#!/bin/bash

# core components

sudo apt-get install -y qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils

# python-magic version on PyPi is not suited for lago

sudo apt-get install -y python-magic

# deps for python cryptography

sudo apt-get install -y build-essential libssl-dev libffi-dev python-dev

# for guestfs

sudo apt-get install -y libguestfs-tools python-guestfs
