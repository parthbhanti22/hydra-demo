FROM nginx:alpine

# install envsubst
RUN apk add --no-cache gettext

# copy html template
COPY services/static/index.html /usr/share/nginx/html/index.html.template

# copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
