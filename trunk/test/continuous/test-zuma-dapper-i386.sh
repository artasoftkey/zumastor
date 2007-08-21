#!/bin/sh

# Run the zuma/dapper/i386 image using -snapshot to verify that it works.
# The template should be left unmodified.
# Any parameters are copied to the destination instance and executed as root

# $Id$
# Copyright 2007 Google Inc.
# Author: Drake Diedrich <dld@google.com>
# License: GPLv2

set -e

SSH='ssh -o StrictHostKeyChecking=no'
SCP='scp -o StrictHostKeyChecking=no'

# Die if more than four hours pass.  Hard upper limit on all test runs.
( sleep 14400 ; kill $$ ; exit 0 ) & tmoutpid=$!

execfiles="$*"

if [ "x$MACFILE" = "x" -o "x$MACADDR" = "x" -o "x$IFACE" = "x" \
     -o "x$IPADDR" = "x" ] ; then
  echo "Run this script under tunbr"
  exit 1
fi

# defaults, overridden by /etc/default/testenv if it exists
# diskimgdir should be local for reasonable performance
diskimgdir=${HOME}/testenv
tftpdir=/tftpboot
qemu_i386=qemu  # could be kvm, kqemu version, etc.  Must be 0.9.0 to net boot.

VIRTHOST=192.168.23.1
[ -x /etc/default/testenv ] && . /etc/default/testenv

IMAGE=zuma-dapper-i386
IMAGEDIR=${diskimgdir}/${IMAGE}
diskimg=${IMAGEDIR}/hda.img

tmpdir=`mktemp -d /tmp/${IMAGE}.XXXXXX`
SERIAL=${tmpdir}/serial
MONITOR=${tmpdir}/monitor
VNC=${tmpdir}/vnc


if [ ! -f ${diskimg} ] ; then

  echo "No template image ${diskimg} exists yet."
  echo "Run tunbr zuma-dapper-i386.sh first."
  exit 1
fi

echo IPADDR=${IPADDR}
echo control/tmp dir=${tmpdir}

${qemu_i386} -snapshot \
  -serial unix:${SERIAL},server,nowait \
  -monitor unix:${MONITOR},server,nowait \
  -vnc unix:${VNC} \
  -net nic,macaddr=${MACADDR},model=ne2k_pci \
  -net tap,ifname=${IFACE},script=no \
  -boot c -hda ${diskimg} -no-reboot & qemupid=$!

# kill the emulator if any abort-like signal is received
trap "kill ${qemu_pid} ; exit 1" 1 2 3 6 9  

while ! ${SSH} root@${IPADDR} hostname 2>/dev/null
do
  echo -n .
  sleep 10
done

echo IPADDR=${IPADDR}
echo control/tmp dir=${tmpdir}

# execute any parameters here
if [ "x${execfiles}" != "x" ]
then
  ${SCP} ${execfiles} root@${IPADDR}: </dev/null || true
  for f in ${execfiles}
  do
    if ${SSH} root@${IPADDR} ./${f}
    then
      echo ${f} ok
    else
      echo ${f} not ok
    fi
  done
fi


${SSH} root@${IPADDR} halt

wait

echo "Instance shut down, removing ssh hostkey"
sed -i /^${IPADDR}\ .*\$/d ~/.ssh/known_hosts

rm -rf %{tmpdir}
