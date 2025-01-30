FROM openresty/openresty:alpine

RUN apk add --no-cache curl perl jq && \
    opm get openresty/lua-resty-redis && \
    opm get ledgetech/lua-resty-http

COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY run.sh /run.sh

RUN mkdir -p /var/log/nginx && \
    chmod +x /run.sh

EXPOSE 80

CMD ["/run.sh"]