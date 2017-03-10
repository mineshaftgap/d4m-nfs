#!/bin/bash

README=true

while getopts ":q" opt; do
  case $opt in
    q)
      README=false
      ;;
    \?)
      echo "[d4m-nfs] Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# check if this script is running under tmux, and if so, exit
# tmux sets $TERM=screen or user sets $TERM=screen-256color
# (under tmux, we are unable to attach to the d4m tty via screen)
if { [[ "$TERM" =~ screen* ]] && [ -n "$TMUX" ]; } then
  echo "[d4m-nfs] This script cannot be run under tmux. Exiting."
  exit 1
fi

# env var to specify whether we want our home bound to /host-home
AUTO_MOUNT_HOME=${AUTO_MOUNT_HOME:-true}

# see if sudo is needed
if ! $(sudo -n cat /dev/null > /dev/null 2>&1); then
  # get sudo first so the focus for the password is kept in the term, instead of Docker.app
  echo -e "[d4m-nfs] You will need to provide your Mac password in order to setup NFS."
  sudo cat /dev/null
fi

# check to see if Docker is already running
if ! $(docker info > /dev/null 2>&1); then
  echo "[d4m-nfs] Opening Docker for Mac (D4M)."
  open -a /Applications/Docker.app
fi

# check if nfs conf line needs to be added
NFSCNF="nfs.server.mount.require_resv_port = 0"
if ! $(grep "$NFSCNF" /etc/nfs.conf > /dev/null 2>&1); then
  echo "[d4m-nfs] Set the NFS nfs.server.mount.require_resv_port value."
  echo -e "\nnfs.server.mount.require_resv_port = 0\n" | sudo tee -a /etc/nfs.conf
fi

SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)"
EXPORTS="# d4m-nfs exports\n"
NFSUID=$(id -u)
NFSGID=$(id -g)

# iterate through the mounts in etc/d4m-nfs-mounts.txt to add exports
if [ -e "${SDIR}/etc/d4m-nfs-mounts.txt" ]; then
  while read MOUNT; do
    if ! [[ "$MOUNT" = "#"* ]]; then
      if [[ "$(echo "$MOUNT" | cut -d: -f3)" != "" ]]; then
        NFSUID=$(echo "$MOUNT" | cut -d: -f3)
      fi

      if [[ "$(echo "$MOUNT" | cut -d: -f4)" != "" ]]; then
        NFSGID=$(echo "$MOUNT" | cut -d: -f4)
      fi

      NFSEXP="\"$(echo "$MOUNT" | cut -d: -f1)\" -alldirs -mapall=${NFSUID}:${NFSGID} localhost"

      if ! $(grep "$NFSEXP" /etc/exports > /dev/null 2>&1); then
        EXPORTS="$EXPORTS\n$NFSEXP"
      fi
    fi
  done < "${SDIR}/etc/d4m-nfs-mounts.txt"

  egrep -v '^#' "${SDIR}/etc/d4m-nfs-mounts.txt" > /tmp/d4m-nfs-mounts.txt
fi

# if /Users is not in etc/d4m-nfs-mounts.txt then add /Users/$USER
if [[ ! "$EXPORTS" == *'"/Users"'* && ! "$EXPORTS" == *"\"/Users/$USER"* ]]; then
  # make sure /Users is not in /etc/exports
  if ! $(egrep '^"/Users"' /etc/exports > /dev/null 2>&1); then
    NFSEXP="\"/Users/$USER\" -alldirs -mapall=$(id -u):$(id -g) localhost"

    if ! $(grep "/Users/$USER" /etc/exports > /dev/null 2>&1); then
      EXPORTS="$EXPORTS\n$NFSEXP"
    fi
  fi
fi

# only add if we have something to do
if [ "$EXPORTS" != "# d4m-nfs exports\n" ]; then
  echo -e "$EXPORTS\n" | sudo tee -a /etc/exports
fi

# copy anything from the apk-cache into
echo "[d4m-nfs] Copy the Moby VM APK Cache back."
rm -rf /tmp/d4m-apk-cache
cp -fr ${SDIR}/d4m-apk-cache/ /tmp/d4m-apk-cache

# make sure /etc/exports is ok
if ! $(nfsd checkexports); then
  echo "[d4m-nfs] Something is wrong with your /etc/exports file, please check it." >&2
  exit 1
else
  echo "[d4m-nfs] Create the script for Moby VM."
  # make the script for the d4m side
  echo "ln -nsf /tmp/d4m-apk-cache /etc/apk/cache
apk update
apk add nfs-utils sntpc
rpcbind -s > /dev/null 2>&1

DEFGW=\$(ip route|awk '/default/{print \$3}')
FSTAB=\"\\n\\n# d4m-nfs mounts\n\"

if $AUTO_MOUNT_HOME && ! \$(grep ':/host-home' /tmp/d4m-nfs-mounts.txt > /dev/null 2>&1); then
  mkdir -p /host-home

  FSTAB=\"\${FSTAB}\${DEFGW}:/Users/${USER} /host-home nfs nolock,local_lock=all 0 0\"
fi

if [ -e /tmp/d4m-nfs-mounts.txt ]; then
  while read MOUNT; do
    DSTDIR=\$(echo \"\$MOUNT\" | cut -d: -f2)
    mkdir -p \${DSTDIR}
    FSTAB=\"\${FSTAB}\\n\${DEFGW}:\$(echo \"\$MOUNT\" | cut -d: -f1) \${DSTDIR} nfs nolock,local_lock=all 0 0\"
  done < /tmp/d4m-nfs-mounts.txt
fi

if ! \$(grep \"d4m-nfs mounts\" /etc/fstab > /dev/null 2>&1); then
    echo "adding d4m nfs config to /etc/fstab:"
    echo -e \$FSTAB | tee /etc/fstab
else
    echo "d4m nfs mounts already exist in /etc/fstab"
fi

sntpc -i 10 \${DEFGW} &

sleep .5
mount -a
touch /tmp/d4m-done
" > /tmp/d4m-mount-nfs.sh

  echo -e "[d4m-nfs] Start and restop nfsd, for some reason restart is not as kind."
  sudo nfsd stop && sudo nfsd start

  echo -n "[d4m-nfs] Wait until NFS is setup."
  while ! rpcinfo -u localhost nfs > /dev/null 2>&1; do
    echo -n "."
    sleep .25
  done

  echo -ne "\n[d4m-nfs] Wait until D4M is running."
  # while ! $(ps auxwww|grep docker|grep vmstateevent |grep '"vmstate":"running"' > /dev/null 2>&1); do
  while ! $(docker run --rm hello-world > /dev/null 2>&1); do
    echo -n "."
    sleep .25
  done
  echo ""

  # check that screen has not already been setup
  if ! $(screen -ls |grep d4m > /dev/null 2>&1); then
    echo "[d4m-nfs] Setup 'screen' to work properly with the D4M tty, while at it name it 'd4m'."
    screen -AmdS d4m ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty

    echo "[d4m-nfs] Run Moby VM d4m-nfs setup script."
    screen -S d4m -p 0 -X stuff "sh /tmp/d4m-mount-nfs.sh
"

    echo -n "[d4m-nfs] Waiting until d4m-nfs setup is done."
    while [ ! -e /tmp/d4m-done ]; do
      echo -n "."
      sleep .25
    done
    echo ""

    rm /tmp/d4m-done
  fi

  echo -e "[d4m-nfs] Copy back the APK cache.\n"
  cp -f /tmp/d4m-apk-cache/* ${SDIR}/d4m-apk-cache/

  echo ""

  if [ $README = true ]; then
    cat ${SDIR}/README.md
  fi
fi
