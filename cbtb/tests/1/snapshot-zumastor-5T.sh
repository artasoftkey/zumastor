#!/bin/sh -x
#
# $Id$
#
# Make use of large, extra devices on /dev/sd[bcd] to test
# multi-terabyte-sized zumastor filesystems.  RAID0 and LVM are used to
# create the large filesystems from 2047G disks provided by qemu (the
# largest supported by the qcow2 disk backing format).
# This is otherwise the same as the snapshot-zumastor-xfs.sh test
#
# Copyright 2007 Google Inc.  All rights reserved
# Author: Drake Diedrich (dld@google.com)


set -e

# Expect failure.  Delete this when the test is fully successful.
# Since xfs is used, xfs_freeze will certainly be required instead of sync.
# Read only by the test harness.
EXPECT_FAIL=1

# The required sizes of the sd[bcd] devices in G.
# Read only by the test harness.
HDBSIZE=2047
HDCSIZE=2047
HDDSIZE=2047

# Terminate test in 20 minutes.  Read by test harness.
TIMEOUT=1200

# necessary at the moment, looks like a zumastor bug
SLEEP=5

aptitude install xfsprogs
modprobe xfs

# create a MD RAID0 of hdb, hdc, and hdd
aptitude install mdadm
mdadm --create /dev/md0 --level=0 --raid-devices=3 /dev/sd[bcd]

# create LVM VG sysvg
pvcreate -ff /dev/md0
vgcreate sysvg /dev/md0

# create volumes 5T origin and .5T snapshot
lvcreate --size 5124G -n test sysvg
lvcreate --size 512G -n test_snap sysvg

echo "1..6"

zumastor define volume testvol /dev/sysvg/test /dev/sysvg/test_snap --initialize
mkfs.xfs /dev/mapper/testvol

  # TODO: make this part of the zumastor define master or define volume
  mkdir /var/lib/zumastor/volumes/testvol/filesystem
  echo nouuid >/var/lib/zumastor/volumes/testvol/filesystem/options

zumastor define master testvol -h 24 -d 7

echo ok 1 - testvol set up

sync
xfs_freeze -f /var/run/zumastor/mount/testvol
zumastor snapshot testvol hourly 
sleep $SLEEP
xfs_freeze -u /var/run/zumastor/mount/testvol

date >> /var/run/zumastor/mount/testvol/testfile
sleep $SLEEP

if [ -d /var/run/zumastor/mount/testvol\(0\)/ ] ; then
  echo "ok 2 - first snapshot mounted"
else
  ls -lR /var/run/zumastor/mount
  echo "not ok 2 - first snapshot mounted"
  exit 2
fi

if [ ! -f /var/run/zumastor/mount/testvol\(0\)/testfile ] ; then
  echo "ok 3 - testfile not present in first snapshot"
else
  ls -lR /var/run/zumastor/mount
  echo "not ok 3 - testfile not present in first snapshot"
  exit 3
fi

sync
xfs_freeze -f /var/run/zumastor/mount/testvol
zumastor snapshot testvol hourly 
sleep $SLEEP
xfs_freeze -u /var/run/zumastor/mount/testvol

if [ -d /var/run/zumastor/mount/testvol\(2\)/ ] ; then
  echo "ok 4 - second snapshot mounted"
else
  ls -lR /var/run/zumastor/mount
  echo "not ok 4 - second snapshot mounted"
  exit 4
fi

if diff -q /var/run/zumastor/mount/testvol/testfile \
    /var/run/zumastor/mount/testvol\(2\)/testfile 2>&1 >/dev/null ; then
  echo "ok 5 - identical testfile immediately after second snapshot"
else
  ls -lR /var/run/zumastor/mount
  echo "not ok 5 - identical testfile immediately after second snapshot"
  exit 5
fi

date >> /var/run/zumastor/mount/testvol/testfile

if ! diff -q /var/run/zumastor/mount/testvol/testfile \
    /var/run/zumastor/mount/testvol\(2\)/testfile 2>&1 >/dev/null ; then
  echo "ok 6 - testfile changed between origin and second snapshot"
else
  ls -lR /var/run/zumastor/mount
  echo "not ok 6 - testfile changed between origin and second snapshot"
  exit 6
fi

exit 0