#!/bin/sh
# replace environment variables in template
envsubst '$HOSTNAME' < /usr/share/nginx/html/index.html.template > /usr/share/nginx/html/index.html
# start nginx
nginx -g 'daemon off;'
