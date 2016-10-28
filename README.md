# d4m-nfs

With the Docker for Mac's (D4M) current implementation of osxfs, depending on how read and write heavy containers are on mounted volumes, performance can be abismal.

d4m-nfs blantently steals from the way that DockerRoot/xhyve used NFS mounts to get around i/o performance issues. With this implementation D4M appears to even outperform DockerRoot/xhyve under a full Drupal stack (mariadb/redis/php-fpm/nginx/varnish/haproxy), including persistent MySQL databases.

The advantage of this over a file sync strategy is simpler, less overhead and not having to duplicate files.

In order to make use of NFS, you will want to run d4m-nfs.sh before bringing up your containers. You will either need to change your volume paths to use /mnt, or configure the mounts in etc/d4m-nfs-mounts.txt. Look at the example directory for docker or docker-compose simple examples and an example d4m-nfs-mounts.txt.

Alpine Linux NFS packages are now cached so that d4m-nfs can be used when not online. In order for this to work, you must of run it once before while online.

You can now specify what mounts you want in the d4m-nfs-mounts.txt file. Note that if you do this, you need to make sure that it does not conflict with D4M settings, in other words if you want to have /Users be served by NFS instead of osxfs you will need to remove it from the D4M Preferences -> File Sharing. The /tmp share must stay since that is how d4m-nfs exchanges information with the D4M Moby VM. 

This is the default file sharing:
![D4M Default File Sharing](/examples/img/d4m-default-file-sharing.png?raw=true "D4M Default File Sharing")

Please make sure that /tmp is still shared:
![D4M Minimal File Sharing](/examples/img/d4m-min-file-sharing.png?raw=true "D4M Minimal File Sharing")

Please note:
* To connect to the D4M moby linux VM use: screen -r d4m
* To disconnect from the D4M moby linux VM tty screen session use Ctrl-a d.
* To run d4m-nfs faster and/or offline, leave the files in d4m-apk-cache and the hello-world image.
* If you switch between D4M stable and beta, you might need to remove files in d4m-apk-cache and the hello-world image.
