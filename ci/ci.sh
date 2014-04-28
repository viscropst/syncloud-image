#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if ps -ef | grep -v grep | grep syncloud-job  ; then
  echo "syncloud job is already running"
  exit 0
fi

START_TIME=$(date +"%s")

CI_DIR=/data/syncloud/ci
ARTIFACT_DIR=/data/syncloud/files
BUILD_LOG=$ARTIFACT_DIR/syncloud-job-$(date +%F-%H-%M-%S).log.txt
BUILD_DIR=$CI_DIR/build

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

GIT_URL=https://github.com/syncloud/owncloud-setup
REV_FILE=$CI_DIR/.revision
LATEST_REV=$(git ls-remote $GIT_URL refs/heads/master | cut -f1)
if [ "$LATEST_REV" == "" ]; then
  echo "Unable to get latest version"
  exit 1
fi

if [ -f $REV_FILE ]; then
  CURRENT_REV=$(<$REV_FILE)
  if [ "$CURRENT_REV" == "$LATEST_REV" ]; then
    echo "No changes since last check"
    exit 1
  fi
fi



echo "$LATEST_REV" > $REV_FILE
echo "Build triggered for rev: $LATEST_REV" > $BUILD_LOG

SYNCLOUD_BOARD=$(uname -n)
wget -qO- https://raw.github.com/syncloud/owncloud-setup/master/ci/build-image.sh | exec -a syncloud-job bash >> $BUILD_LOG 2>&1

if [ $SYNCLOUD_BOARD == "arm" ]; then
  SYNCLOUD_BOARD="cubieboard"
  wget -qO- https://raw.github.com/syncloud/owncloud-setup/master/ci/build-image.sh | exec -a syncloud-job bash >> $BUILD_LOG 2>&1
fi

#if [ $? -nq 0 ]; then
#  echo "Build failed" >> $BUILD_LOG
#  exit 1
#fi

echo "Publishing artifacts ..." >> $BUILD_LOG  
mv $BUILD_DIR/*.img.xz $ARTIFACT_DIR
echo "removing old logs ..." >> $BUILD_LOG
ls -r1 $ARTIFACT_DIR/*.log* | tail -n+6 | xargs rm -f
echo "removing old images ..." >> $BUILD_LOG
ls -r1 $ARTIFACT_DIR/syncloud-*.img* | tail -n+6 | xargs rm -f

FINISH_TIME=$(date +"%s")
BUILD_TIME=$(($FINISH_TIME-$START_TIME))
echo "Build time: $(($BUILD_TIME / 60)) min" >> $BUILD_LOG 
