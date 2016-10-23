#!/bin/bash

docker run                                        \
  --name d4m-with-nfs                             \
  --detach=true                                   \
  --volume=/mnt/www:/usr/share/nginx/html         \
  nginx:mainline-alpine
