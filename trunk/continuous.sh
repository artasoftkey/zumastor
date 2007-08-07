#!/bin/sh -x
#
# $Id$
#

# Continuously svn update, run the encapsulated build, and the test
# suite.  Copy this and the build-dapper.sh and runtests.sh scripts to
# the parent directory to avoid running unsafe code on your host
# machine.  Code direct from the repository is only run on virtual instances.

sendmail=/usr/sbin/sendmail
email_failure="zumastor-buildd@google.com"
email_success="zumastor-buildd@google.com"

if [ ! -f zumastor/Changelog ] ; then
  echo "cp $0 to the parent directory of the zumastor repository and "
  echo "run from that location.  Periodically inspect the three "
  echo "host scripts for changes and redeploy them."
  exit 1
fi

cd zumastor

oldrevision=""

while true
do
  svn update
  revision=`svn info | awk '/Revision:/ { print $2; }'`
  if [ "x$revision" = "x$oldrevision" ]
  then
    sleep 300
  else
    # TODO(dld): timeouts and report failure if these take "forever"
    buildlog=`mktemp`
      testlog=`mktemp`
    if ../dapper-build.sh >${buildlog} 2>&1 ; then
      if ../runtests.sh >${testlog} 2>&1 ; then
        ( echo "Subject: zumastor r$revision build and test success" ;\
          echo ; cat ${buildlog} ${testlog} ) | \
        ${sendmail} ${email_success}
      else
        ( echo "Subject: zumastor r$revision test failure" ;\
          echo ; cat ${buildlog} ${testlog} ) | \
        ${sendmail} ${email_success}
      fi
    else
      ( echo "Subject: zumastor r$revision build failure" ;\
        echo ; cat ${buildlog} ) | \
      ${sendmail} ${email_failure}
    fi
      
  fi
  oldrevision=$revision
done