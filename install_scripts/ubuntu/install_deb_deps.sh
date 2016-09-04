#!/bin/bash

# core components

sudo apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils

# python-magic version on PyPi is not suited for lago

sudo apt-get install python-magic

# deps for python cryptography

sudo apt-get install build-essential libssl-dev libffi-dev python-dev

# for guestfs

sudo apt-get install libguestfs-tools python-guestfs
