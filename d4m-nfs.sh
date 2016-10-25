#!/bin/bash

# see if sudo is needed
sudo -n cat /dev/null > /dev/null 2>&1
if [ $? -eq 1 ]; then
  # get sudo first so the focus for the password is kept in the term, instead of Docker.app
  echo -e "You will need to provide your Mac password in order to setup NFS."
  sudo cat /dev/null
fi

# check to see if Docker is already running
ps ax |grep 'Docker.app/Contents/MacOS/Docker' |grep -v grep > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo -e "Opening Docker for Mac (D4M).\n"
  open -a /Applications/Docker.app
fi

# check if export line needs to be added
NFSEXP="\"/Users/$USER\" -alldirs -mapall=$(id -u):$(id -g) localhost"
if ! $(grep "$NFSEXP" /etc/exports > /dev/null 2>&1); then
  echo -e "Making the NFS /etc/exports entry if it doesn't already exist."
  echo -e "\n$NFSEXP\n" | sudo tee -a /etc/exports
fi

# check if nfs conf line needs to be added
NFSCNF="nfs.server.mount.require_resv_port = 0"
if ! $(grep "$NFSCNF" /etc/nfs.conf > /dev/null 2>&1); then
  echo -e "Set the NFS nfs.server.mount.require_resv_port value."
  echo -e "\nnfs.server.mount.require_resv_port = 0\n" | sudo tee -a /etc/nfs.conf
fi

# make sure /etc/exports is ok
if ! $(nfsd checkexports); then
  echo "Something is wrong with your /etc/exports file, please check it." >&2
  exit 1
else
  echo -e "Start and restop nfsd, for some reason restart is not as kind."
  sudo nfsd stop && sudo nfsd start

  echo -n "Wait until NFS is setup."
  while ! rpcinfo -u localhost nfs > /dev/null 2>&1; do
    echo -n "."
    sleep 0.5
  done

  echo -ne "\nWait until D4M is running."
  while ! $(ps auxwww|grep docker|grep vmstateevent |grep '"vmstate":"running"' > /dev/null 2>&1); do
    echo -n "."
    sleep 1
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

    echo -e "Make symlink to apk cache dir on Mac.\n"
    screen -S d4m -p 0 -X stuff "ln -s /Users/$USER/d4m-apk-cache /etc/apk/cache
"

    if ! $(ls ~/d4m-apk-cache|grep APKINDEX > /dev/null 2>&1); then
      echo -e "Get an apk update.\n"
      screen -S d4m -p 0 -X stuff "apk update
"
    fi

    echo -e "Install nfs-utils, make the /mnt dir, start rpcbind, wait, then mount Mac NFS.\n"
    screen -S d4m -p 0 -X stuff "apk add nfs-utils && mkdir -p /mnt && rpcbind -s && sleep .5 && mount -o nolock,local_lock=all \$(route|awk '/default/ {print \$2}'):/Users/$USER /mnt
"

    echo "Pausing for NFS mount to be ready so this can be used in another script"
    sleep 1
  fi

  echo -e "\n\nPlease note:
------------
• Only /Users/$USER directory is mounted, this might change if there is a request to be all user directories, or other locations.
• The /Users mount under D4M still exists and will continute to be slow, the d4m-nfs mount is under /mnt.
• When mounting Docker volumes, you need to change paths like /Users/$USER mounts with /mnt.
• To connect to the D4M moby linux VM use: screen -r d4m
• To disconnect from the D4M moby linux VM tty screen session use Ctrl-a d
"
fi