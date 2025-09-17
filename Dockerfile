FROM nginx:alpine

RUN apk add --no-cache gettext

COPY services/static/index.html.template /usr/share/nginx/html/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
