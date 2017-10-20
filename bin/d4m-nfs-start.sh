#!/bin/bash

LIBDIR=$(cd "$(dirname "$0")" ; pwd -P)

echo "[`date`][d4m-nfs] Waiting 30 seconds for the Docker VM to become ready"
sleep 25
echo "[`date`][d4m-nfs] Starting VM setup"

echo "[`date`][d4m-nfs] Setup for Moby VM APK Cache."
mkdir ${LIBDIR}/d4m-apk-cache

# check that screen has not already been setup
if ! $(screen -ls |grep d4m > /dev/null 2>&1); then

    until $(screen -ls |grep d4m > /dev/null 2>&1); do
        echo "[`date`][d4m-nfs] Setup 'screen' to work properly with the D4M tty, while at it name it 'd4m'."
        screen -AmdS d4m ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty
        sleep 5
    done

    rm -f ${LIBDIR}/d4m-done

    echo "[`date`][d4m-nfs] Runing Moby VM d4m-nfs setup script."
    screen -S d4m -p 0 -X stuff "sh ${LIBDIR}/d4m-mount-nfs.sh        
"
    echo -n "[`date`][d4m-nfs] Waiting until d4m-nfs setup is done."
    while [ ! -e ${LIBDIR}/d4m-done ]; do
      echo -n "."
      sleep .25
    done
    echo ""

    rm -f ${LIBDIR}/d4m-done
fi

echo "[`date`][d4m-nfs] Done."