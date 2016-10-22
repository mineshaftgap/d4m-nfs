#!/bin/bash

echo "Run Docker for Mac"
open -a /Applications/Docker.app

echo "Making the NFS /etc/exports entry if it doesn't already exist"
echo -e "\n\"/Users/$USER\" -alldirs -mapall=$(id -u):$(id -g) localhost\n" | sudo tee -a /etc/exports

echo "Set the NFS nfs.server.mount.require_resv_port value"
echo -e "\nnfs.server.mount.require_resv_port = 0\n" | sudo tee -a /etc/nfs.conf

echo "Make sure NFS /etc/exports are ok"
sudo nfsd checkexports || (echo "Please check your /etc/exports." >&2 && exit 1)

echo "Start and restop nfsd, for some reason restart is not as kind"
sudo nfsd stop && sudo nfsd start

echo "Wait until NFS is setup"
while ! rpcinfo -u localhost nfs > /dev/null 2>&1; do sleep 0.5; done

echo "Wait until it looks like D4M is running"
$(ps auxwww|grep docker|grep vmstateevent |grep '"vmstate":"running"')
CHECK=$?
i=0
while [ $CHECK -eq 1 ]; do
  sleep 1
  echo -n "$i "
  i=$[$i+1]
  $(ps auxwww|grep docker|grep vmstateevent |grep '"vmstate":"running"')
  CHECK=$?
done

echo "Setup 'screen' to work properly with the Docker for Mac tty, while at it name it 'd4f'"
screen -AmdS d4m ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty

echo "Log into D4M as root so next commands can run"
screen -S d4m -p 0 -X stuff $(printf "root\\r\\n")

echo "Install nfs-utils, make the /mnt dir, start rpcbind, wait, then mount Mac NFS"
screen -S d4m -p 0 -X stuff "apk add --update nfs-utils && mkdir -p /mnt && rpcbind -s && sleep .5 && mount -o nolock,local_lock=all \$(route|awk '/default/ {print \$2}'):/Users/$USER /mnt
"

echo "Give instructions on detaching from D4M tty screen session"
screen -S d4m -p 0 -X stuff "# Use Ctrl-a d to disconnect from D4M tty screen session
"

echo "Entering D4M to see what has been done"
screen -r d4m
