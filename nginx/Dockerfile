FROM openresty/openresty:alpine

# Install required packages and Redis module
RUN apk add --no-cache curl perl && \
    opm get openresty/lua-resty-redis && \
    opm get ledgetech/lua-resty-http

# Copy nginx configuration
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Create log directory and set permissions
RUN mkdir -p /var/log/nginx && \
    chown -R nobody:nobody /var/log/nginx

# Expose HTTP port
EXPOSE 80

# Start OpenResty
CMD ["nginx", "-g", "daemon off;"]