# WARNING: Latest Docker for Mac 17.12.0-ce-mac46 seems to [break d4m-nfs](https://github.com/IFSight/d4m-nfs/issues/55).
# At this time, don't update if you rely on d4m-nfs.

Downgrade at https://docs.docker.com/docker-for-mac/release-notes/#docker-community-edition-17120-ce-mac46-2018-01-09-stable

## d4m-nfs

With the Docker for Mac's (D4M) current implementation of osxfs, depending on how read and write heavy containers are on mounted volumes, performance can be abismal.

d4m-nfs blantently steals from the way that DockerRoot/xhyve used NFS mounts to get around i/o performance issues. With this implementation D4M appears to even outperform DockerRoot/xhyve under a full Drupal stack (mariadb/redis/php-fpm/nginx/varnish/haproxy), including persistent MySQL databases.

The advantage of this over a file sync strategy is simpler, less overhead and not having to duplicate files.

In order to make use of NFS, you will want to run ./d4m-nfs.sh before bringing up your containers, **please note this must be run via the bash shell and not the sh shell**. You will either need to change your volume paths to use /mnt, or configure the mounts in etc/d4m-nfs-mounts.txt. Look at the example directory for docker or docker-compose simple examples and an example d4m-nfs-mounts.txt. Please keep in mind that since NFS is the underlying glue that is this project, that all rules of NFS must be followed. Unlike Docker which creates the directory for you, if it doesn't exist, NFS needs it to exist. Since NFS and Docker have no idea of the other, it is up to you to create the skeleton directory structure for bootstrap.  The way in which I often bootstrap is start up a stack normally without using NFS, use docker cp to get what the containers of docker had made, and then use that copied directory to map it via a Docker volume.

By default, if the script doesn't find any other volumes bound to /mnt in your etc/d4m-nfs-mounts.txt, it will mount your home directory (eg. /Users/username) on /mnt to be exposed for the container. If you'd like to disable this, you may set the environment variable AUTO_MOUNT_HOME to false.

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

# Opening Github Issues
**Please keep in mind that everyone's environment is quite unique and this make helping people much harder. In that spirit when opening an issue, please provide the following:**

1. Comment out mounts from compose file and add them one at a time. Due to NFS, d4m-nfs cannot make the empty directory structure and will error.  Read paragraphs above for more.
2. Please ensure you have looked at the "examples" directory in the root of this site.
3. include the text of the any approriate error message
4. screenshot of Docker for Mac's Preferences -> File Sharing
5. attachment of d4m-nfs/etc/d4m-nfs-mounts.txt
6. attachment of /tmp/d4m-mount-nfs.sh
7. attachment of /tmp/d4m-nfs-mounts.txt
8. attachment of /etc/exports

## Common Problem
It appears as though a number of people are blindly copying the mounts from the preference in Docker for Mac to d4m-nfs/etc/d4m-nfs-mounts.txt. In doing this they end up having a /Volumes, /private and /Users mounts. If you are getting an error similar to the following, you might of done this:

```
ERROR: for applications  Cannot start service applications: Mounts denied: r more info.
```

In all likelihood this is not what you want. The location /Volumes on a Mac is actually just a symlink to /, and it is never good to export a symlink. On top of that, with NFS, you can not export child directories which are on the same file system, and since both /Users and /private this could cause problems. You probably will need have to clean up your /etc/exports to remove all the lines from # d4m-nfs exports down.

Please keep in mind that since NFS is the underlying glue that is this project, that all rules of NFS must be followed. Unlike Docker which creates the directory for you, if it doesn't exist, NFS needs it to exist. Since NFS and Docker have no idea of the other, it is up to you to create the skeleton directory structure for bootstrap.  The way in which I often bootstrap is start up a stack normally without using NFS, use docker cp to get what the containers of docker had made, and then use that copied directory to map it via a Docker volume.

You may also want to check on the latest file system changes that the Docker team is working on: https://blog.docker.com/2017/05/user-guided-caching-in-docker-for-mac/


# Use Stable Docker for Mac channel
Currently d4m-nfs is known to work on the stable channel of 'Docker for Mac' both versions 1.12 and 1.13, we cannot guarantee how it will work on the beta channel of 'Docker for Mac'.  Please use the stable channel of Docker for Mac https://docs.docker.com/docker-for-mac/

# Integration with text editors

## Sublime Text

If you use Sublime, please checkout the plugin by Yves to help with auto reloads on file changes - https://github.com/yvess/sublime_d4m

## Atom

The easiest way to enable auto reloading is to install [on-save](https://atom.io/packages/on-save) package and set it up with this config:

```json
[
  {
    "srcDir": ".",
    "files": "**/**",
    "command": "screen -S d4m -p 0 -X stuff \"touch \\\"`pwd`/${srcFile}\\\"\"\r"
  }
]
```

