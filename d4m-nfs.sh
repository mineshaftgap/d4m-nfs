#!/bin/bash

# we get sudo first so the focus for the password is kept in the term, instead of Docker.app
echo -e "You maybe be asked for your Mac admin password in order to setup NFS\n"
sudo cat /dev/null

echo -e "Opening Docker for Mac (D4M)\n"
open -a /Applications/Docker.app

echo -e "Making the NFS /etc/exports entry if it doesn't already exist"
echo -e "\n\"/Users/$USER\" -alldirs -mapall=$(id -u):$(id -g) localhost\n" | sudo tee -a /etc/exports

echo -e "Set the NFS nfs.server.mount.require_resv_port value"
echo -e "\nnfs.server.mount.require_resv_port = 0\n" | sudo tee -a /etc/nfs.conf

echo -e "Make sure NFS /etc/exports is ok\n"
sudo nfsd checkexports || (echo "Please check your /etc/exports." >&2 && exit 1)

echo -e "Start and restop nfsd, for some reason restart is not as kind"
sudo nfsd stop && sudo nfsd start

echo -e "Wait until NFS is setup\n"
while ! rpcinfo -u localhost nfs > /dev/null 2>&1; do sleep 0.5; done

echo "Wait until it looks like D4M is running"
ps auxwww|grep docker|grep vmstateevent |grep '"vmstate":"running"' 1>/dev/null 2>/dev/null
CHECK=$?
i=0
while [ $CHECK -eq 1 ]; do
  sleep 1
  echo -n "$i "
  i=$[$i+1]
  ps auxwww|grep docker|grep vmstateevent |grep '"vmstate":"running"' 1>/dev/null 2>/dev/null
  CHECK=$?
done

echo -e "Setup 'screen' to work properly with the D4M tty, while at it name it 'd4m'\n"
screen -AmdS d4m ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty

echo -e "Log into D4M as root so next commands can run\n"
screen -S d4m -p 0 -X stuff $(printf "root\\r\\n")

echo -e "Install nfs-utils, make the /mnt dir, start rpcbind, wait, then mount Mac NFS\n"
screen -S d4m -p 0 -X stuff "apk add --update nfs-utils && mkdir -p /mnt && rpcbind -s && sleep .5 && mount -o nolock,local_lock=all \$(route|awk '/default/ {print \$2}'):/Users/$USER /mnt
"

echo -e "\n\nPlease note:
------------
• Only /Users/$USER directory is mounted, this might change if there is a request to be all user directories, or other locations.
• The /Users mount under D4M still exists and will continute to be slow, the d4m-nfs mount is under /mnt.
• When mounting Docker volumes, you need to change paths like /Users/$USER mounts with /mnt.
• To connect to the D4M moby linux VM use: screen -r d4m
• To disconnect from the D4M moby linux VM tty screen session use Ctrl-a d
"
