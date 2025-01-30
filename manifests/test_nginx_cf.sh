#!/bin/bash

# Configuration
ENVOY_HOST="sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com"
DEBUG=false
TEST_TYPE="all"

# Test statistics
total_lb_tests=0
load_balance_passed=0
total_rate_tests=0
rate_limit_passed=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Define endpoints and their limits
ENDPOINTS=(
   "/v1/service_bindings:5"
   "/v1/service_offerings:3"
   "/v1/service_plans:3"
   "/v1/service_instances:5"
   "/v2/service_bindings:5"
   "/v2/service_offerings:3"
   "/v2/service_plans:3"
   "/v2/service_instances:5"
)

curl_with_timeout() {
   curl -si --max-time 10 "$@" || echo "HTTP/1.1 000 Connection Failed"
}

debug_log() {
   if [ "$DEBUG" = true ]; then
       echo -e "${YELLOW}DEBUG: $1${NC}"
   fi
}

check_health() {
   echo -e "\n${YELLOW}Checking Health${NC}"
   local attempts=3
   local success=false

   for ((i=1; i<=attempts; i++)); do
       response=$(curl_with_timeout "https://${ENVOY_HOST}/health")
       status_code=$(echo "$response" | grep "HTTP" | awk '{print $2}')

       echo -e "Attempt $i - Status Code: ${status_code}"

       if [[ $status_code == "200" && $response == *"OK"* ]]; then
           success=true
           break
       fi
       sleep 1
   done

   if [ "$success" = true ]; then
       echo -e "${GREEN}✓ Service is healthy${NC}"
       return 0
   else
       echo -e "${RED}✗ Service is not healthy${NC}"
       return 1
   fi
}

check_load_balancing() {
   local endpoint=$1
   local requests=20
   local instance0_count=0
   local instance1_count=0

   ((total_lb_tests++))
   echo -e "\n${YELLOW}Testing Load Balancing for ${endpoint}${NC}"
   echo -e "Making ${requests} requests..."

   for ((i=1; i<=requests; i++)); do
       response=$(curl_with_timeout \
           --local-port $((10000 + i)) \
           -H "Accept: application/json" \
           "https://${ENVOY_HOST}${endpoint}")

       instance_index=$(echo "$response" | grep -i "x-backend-host" | awk '{print $2}' | grep -o '[0-1]')
       instance_id=$(echo "$response" | grep -i "x-backend-server" | awk '{print $2}')
       status_code=$(echo "$response" | grep "HTTP" | awk '{print $2}')

       if [[ "$instance_index" == "0" ]]; then
           ((instance0_count++))
           echo -n "0 "
       elif [[ "$instance_index" == "1" ]]; then
           ((instance1_count++))
           echo -n "1 "
       else
           echo -n "X "
       fi

       sleep 0.5
   done

   echo -e "\n\n${YELLOW}Load Balancing Results:${NC}"
   echo "Nginx Instance 0: $instance0_count requests"
   echo "Nginx Instance 1: $instance1_count requests"

   if [[ $instance0_count -gt 0 && $instance1_count -gt 0 ]]; then
       echo -e "${GREEN}✓ Load balancing working${NC}"
       ((load_balance_passed++))
   else
       echo -e "${RED}✗ Single instance handling all requests${NC}"
   fi
}

test_rate_limits() {
   local endpoint=$1
   local limit=$2

   ((total_rate_tests++))
   echo -e "\n${YELLOW}Testing Rate Limits for ${endpoint} (Limit: ${limit}/min)${NC}"

   local response=$(curl_with_timeout -H "Accept: application/json" "https://${ENVOY_HOST}${endpoint}")
   echo -e "\n${YELLOW}Rate Limit Headers:${NC}"
   echo "$response" | grep -i "x-ratelimit"

   local successful=0
   local limited=0
   local start_time=$(date +%s)

   echo -e "\n${YELLOW}Sending $((limit + 3)) requests...${NC}"
   for ((i=1; i<=limit+3; i++)); do
       response=$(curl_with_timeout \
           --local-port $((20000 + i)) \
           -H "Accept: application/json" \
           "https://${ENVOY_HOST}${endpoint}")

       status_code=$(echo "$response" | grep "HTTP" | awk '{print $2}')

       case $status_code in
           200|201)
               ((successful++))
               echo -n ". "
               ;;
           429)
               ((limited++))
               echo -n "R "
               ;;
           *)
               echo -n "X "
               debug_log "Unexpected status: ${status_code}"
               ;;
       esac
       sleep 0.2
   done

   local end_time=$(date +%s)
   local duration=$((end_time - start_time))

   echo -e "\n\n${YELLOW}Rate Limit Results:${NC}"
   echo "Test duration: ${duration}s"
   echo "Successful requests: ${successful}"
   echo "Rate limited requests: ${limited}"

   if [[ $successful -gt 0 && $limited -gt 0 && $successful -le $((limit + 1)) ]]; then
       echo -e "${GREEN}✓ Rate limiting working correctly${NC}"
       ((rate_limit_passed++))
   else
       echo -e "${RED}✗ Rate limiting not working as expected${NC}"
   fi
}

print_summary() {
   echo -e "\n${YELLOW}Test Summary${NC}"
   echo "=============================="

   if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "loadbalance" ]]; then
       echo "Load Balancing Tests: $load_balance_passed/$total_lb_tests passed"
   fi
   if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "ratelimit" ]]; then
       echo "Rate Limit Tests: $rate_limit_passed/$total_rate_tests passed"
   fi

   if [[ $load_balance_passed -eq $total_lb_tests && $rate_limit_passed -eq $total_rate_tests ]]; then
       echo -e "\n${GREEN}All tests passed successfully!${NC}"
   else
       echo -e "\n${RED}Some tests failed. Check the logs above for details.${NC}"
   fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
   case $1 in
       --test-type)
           TEST_TYPE="$2"
           shift 2
           ;;
       --debug)
           DEBUG=true
           shift
           ;;
       --endpoint)
           SINGLE_ENDPOINT="$2"
           shift 2
           ;;
       *)
           echo "Unknown option: $1"
           exit 1
           ;;
   esac
done

# Main execution
if [ "$DEBUG" = true ]; then
   set -x
fi

check_health || exit 1

case $TEST_TYPE in
   "loadbalance")
       for endpoint_info in "${ENDPOINTS[@]}"; do
           IFS=':' read -r endpoint limit <<< "$endpoint_info"
           check_load_balancing "$endpoint"
           sleep 3
       done
       ;;
   "ratelimit")
       for endpoint_info in "${ENDPOINTS[@]}"; do
           IFS=':' read -r endpoint limit <<< "$endpoint_info"
           test_rate_limits "$endpoint" "$limit"
           sleep 3
       done
       ;;
   "all")
       for endpoint_info in "${ENDPOINTS[@]}"; do
           IFS=':' read -r endpoint limit <<< "$endpoint_info"
           check_load_balancing "$endpoint"
           sleep 30
           test_rate_limits "$endpoint" "$limit"
           sleep 30
       done
       ;;
esac

print_summary

if [ "$DEBUG" = true ]; then
   set +x
fi