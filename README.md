## Build Openresty

cd manifest
docker build --platform linux/amd64 --no-cache -t <user>/custom-openresty:latest ./nginx
docker push <user>/custom-openresty:latest

## Deploy

cf push -f manifest.yml
cf push -f nginx-manifest.yml

cf add-network-policy nginx-instance-1 sm-mock-v2 --protocol tcp --port 443
cf add-network-policy nginx-instance-1 sm-mock --protocol tcp --port 443


## Test
### Test throtteling
./throtteling.sh
### Watch throtteling metrics
watch -n 1 'curl -s https://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/metrics | jq'

### Test with loadbalnce and ratelimit
./test_nginx_cf.sh --test-type loadbalance
./test_nginx_cf.sh --test-type ratelimit

### watch redis keys
curl -s https://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/redis-test




