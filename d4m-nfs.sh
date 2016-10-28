#!/bin/bash

# see if sudo is needed
if ! $(sudo -n cat /dev/null > /dev/null 2>&1); then
  # get sudo first so the focus for the password is kept in the term, instead of Docker.app
  echo -e "You will need to provide your Mac password in order to setup NFS."
  sudo cat /dev/null
fi

# check to see if Docker is already running
if ! $(docker info > /dev/null 2>&1); then
  echo -e "Opening Docker for Mac (D4M).\n"
  open -a /Applications/Docker.app
fi

# check if nfs conf line needs to be added
NFSCNF="nfs.server.mount.require_resv_port = 0"
if ! $(grep "$NFSCNF" /etc/nfs.conf > /dev/null 2>&1); then
  echo -e "Set the NFS nfs.server.mount.require_resv_port value."
  echo -e "\nnfs.server.mount.require_resv_port = 0\n" | sudo tee -a /etc/nfs.conf
fi

SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)"
EXPORTS="# d4m-nfs exports\n"
MYUID=$(id -u)
MYGID=$(id -g)

# iterate through the mounts in etc/d4m-nfs-mounts.txt to add exports
if [ -e "${SDIR}/etc/d4m-nfs-mounts.txt" ]; then
  while read MOUNT; do
    if ! [[ "$MOUNT" = "#"* ]]; then
      NFSEXP="\"$(echo "$MOUNT" | cut -d: -f1)\" -alldirs -mapall=${MYUID}:${MYGID} localhost"

      if ! $(grep "$NFSEXP" /etc/exports > /dev/null 2>&1); then
        EXPORTS="$EXPORTS\n$NFSEXP"
      fi
    fi
  done < "${SDIR}/etc/d4m-nfs-mounts.txt"

  egrep -v '^#' etc/d4m-nfs-mounts.txt > /tmp/d4m-nfs-mounts.txt
fi

# if /Users is not in etc/d4m-nfs-mounts.txt then add /Users/$USER
if [[ ! "$EXPORTS" == *'"/Users"'* ]]; then
  # make sure /Users is not in /etc/exports
  if ! $(egrep '^"/Users"' /etc/exports > /dev/null 2>&1); then
    NFSEXP="\"/Users/$USER\" -alldirs -mapall=$(id -u):$(id -g) localhost"

    if ! $(grep "$NFSEXP" /etc/exports > /dev/null 2>&1); then
      EXPORTS="$EXPORTS\n$NFSEXP"
    fi
  fi
fi

# only add if we have something to do
if [ "$EXPORTS" != "# d4m-nfs exports\n" ]; then
  echo -e "$EXPORTS\n" | sudo tee -a /etc/exports
fi

# copy anything from the apk-cache into 
echo "Copy the Moby VM APK Cache back"
rm -rf /tmp/d4m-apk-cache
cp -r ${SDIR}/d4m-apk-cache/ /tmp/d4m-apk-cache

# make sure /etc/exports is ok
if ! $(nfsd checkexports); then
  echo "Something is wrong with your /etc/exports file, please check it." >&2
  exit 1
else
  echo "Create the script for Moby VM"
  # make the script for the d4m side
  # updat
  echo "ln -s /tmp/d4m-apk-cache /etc/apk/cache
apk update
apk add nfs-utils
rpcbind -s
mkdir -p /mnt

DEFGW=\$(ip route|awk '/default/{print \$3}')
FSTAB=\"\\n\\n# d4m-nfs mounts\n\${DEFGW}:/Users/${USER} /mnt nfs nolock,local_lock=all 0 0\"

if [ -e /tmp/d4m-nfs-mounts.txt ]; then
  while read MOUNT; do
    DSTDIR=\$(echo \"\$MOUNT\" | cut -d: -f2)
    mkdir -p \${DSTDIR}
    FSTAB=\"\${FSTAB}\\n\${DEFGW}:\$(echo \"\$MOUNT\" | cut -d: -f1) \${DSTDIR} nfs nolock,local_lock=all 0 0\"
  done < /tmp/d4m-nfs-mounts.txt
fi

echo -e \$FSTAB >> /etc/fstab

sleep .5
mount -a
" > /tmp/d4m-mount-nfs.sh

  echo -e "Start and restop nfsd, for some reason restart is not as kind."
  sudo nfsd stop && sudo nfsd start

  echo -n "Wait until NFS is setup."
  while ! rpcinfo -u localhost nfs > /dev/null 2>&1; do
    echo -n "."
    sleep 0.5
  done

  echo -ne "\nWait until D4M is running."
  # while ! $(ps auxwww|grep docker|grep vmstateevent |grep '"vmstate":"running"' > /dev/null 2>&1); do
  while ! $(docker run --rm hello-world > /dev/null 2>&1); do
    echo -n "."
    sleep 0.5
  done

  # check that screen has not already been setup
  if ! $(screen -ls |grep d4m > /dev/null 2>&1); then
    echo -e "\nSetup 'screen' to work properly with the D4M tty, while at it name it 'd4m'.\n"
    screen -AmdS d4m ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty

    echo -e "Log into D4M as root so next commands can run.\n"
    screen -S d4m -p 0 -X stuff $(printf "root\\r\\n")

    if [ ! -e ~/d4m-apk-cache/ ]; then
      echo -e "Make sure persistent apk cache dir on Mac so NFS setup can happen offline"
      mkdir -p ~/d4m-apk-cache
    fi

    echo -e "Run Moby VM script: apk cache symlink,.\n"
    screen -S d4m -p 0 -X stuff "source /tmp/d4m-mount-nfs.sh
"

    echo "Pausing for NFS mount to be ready so this can be used in another script."
    sleep 1
  fi

  echo -e "\nCopy back the APK cache\n\n\n"
  cp /tmp/d4m-apk-cache/* ${SDIR}/d4m-apk-cache/

  cat README.md
fi