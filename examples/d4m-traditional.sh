#!/bin/bash

docker run                                        \
  --name d4m-tradtional                           \
  --detach=true                                   \
  --volume=/Users/$USER/www:/usr/share/nginx/html \
  nginx:mainline-alpine
