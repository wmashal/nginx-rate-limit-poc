#!/bin/bash

# Configuration
ENVOY_HOST="localhost"
ENVOY_PORT="80"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results storage
declare -A TEST_RESULTS 2>/dev/null || declare TEST_RESULTS
declare -A TEST_SUCCESSES 2>/dev/null || declare TEST_SUCCESSES
declare -A TEST_FAILURES 2>/dev/null || declare TEST_FAILURES
declare -A TEST_LIMITS 2>/dev/null || declare TEST_LIMITS
declare -A TEST_UNEXPECTED 2>/dev/null || declare TEST_UNEXPECTED

# Endpoint rate limits
ENDPOINTS=(
    "/v1/service_bindings:6"
    "/v1/service_offerings:1"
    "/v1/service_plans:1"
    "/v1/service_instances:6"
    "/v2/service_bindings:6"
    "/v2/service_offerings:1"
    "/v2/service_plans:1"
    "/v2/service_instances:6"
)

# Special case for POST service instances
POST_LIMIT=5

# Function to encode endpoint name for array key
encode_endpoint() {
    echo "$1" | tr '/' '_' | tr ':' '_' | sed 's/-//g'
}

# Function to store test results
store_result() {
    local endpoint="$1"
    local limit=$2
    local successes=$3
    local failures=$4
    local unexpected=$5
    local result=$6

    # Create a unique key that won't cause issues with special characters
    local key=$(echo "$endpoint" | tr -c '[:alnum:]' '_')

    TEST_RESULTS["$key"]="$result"
    TEST_LIMITS["$key"]=$limit
    TEST_SUCCESSES["$key"]=$successes
    TEST_FAILURES["$key"]=$failures
    TEST_UNEXPECTED["$key"]=$unexpected
}

# Function to generate payload
generate_payload() {
    local endpoint=$1
    case $endpoint in
        "/v1/service_bindings"|"/v2/service_bindings")
            echo '{"name":"test-binding","service_id":"test-service-id"}'
            ;;
        "/v1/service_offerings"|"/v2/service_offerings")
            echo '{"name":"test-offering","description":"Test offering"}'
            ;;
        "/v1/service_plans"|"/v2/service_plans")
            echo '{"name":"test-plan","description":"Test plan"}'
            ;;
        "/v1/service_instances"|"/v2/service_instances")
            echo '{"name":"test-instance","service_id":"test-service","plan_id":"test-plan"}'
            ;;
        *)
            echo '{}'
            ;;
    esac
}

# Function to send HTTP request
send_request() {
    local endpoint=$1
    local method=${2:-GET}
    local payload

    payload=$(generate_payload "$endpoint")

    response=$(curl -v -s \
        -X "$method" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "http://${ENVOY_HOST}:${ENVOY_PORT}${endpoint}" 2>&1)

    echo "$response"
}

# Function to extract HTTP status code
get_status_code() {
    echo "$1" | grep "^< HTTP/1.1" | cut -d' ' -f3
}

# Function to print summary
print_summary() {
    echo -e "\n${YELLOW}=== Rate Limit Test Summary ===${NC}"
    echo -e "${YELLOW}================================${NC}"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Print regular endpoints
    echo -e "\nEndpoint Rate Limits:"
    printf "%-30s %-15s %-15s %-15s %-15s %s\n" "ENDPOINT" "LIMIT" "SUCCESSFUL" "RATE LIMITED" "UNEXPECTED" "STATUS"
    echo "-----------------------------------------------------------------------------------------------------"

    for endpoint_with_limit in "${ENDPOINTS[@]}"; do
        IFS=':' read -r endpoint limit <<< "$endpoint_with_limit"
        local key=$(echo "$endpoint" | tr -c '[:alnum:]' '_')
        local result="${TEST_RESULTS[$key]}"
        local successes="${TEST_SUCCESSES[$key]}"
        local failures="${TEST_FAILURES[$key]}"
        local unexpected="${TEST_UNEXPECTED[$key]}"
        local status

        ((total_tests++))
        if [[ $result == "PASS" ]]; then
            ((passed_tests++))
            status="${GREEN}PASS${NC}"
        else
            ((failed_tests++))
            status="${RED}FAIL${NC}"
        fi

        printf "%-30s %-15s %-15s %-15s %-15s %b\n" \
            "$endpoint" \
            "$limit" \
            "$successes" \
            "$failures" \
            "$unexpected" \
            "$status"
    done

    # Print POST method tests
    echo -e "\nPOST Method Tests:"
    printf "%-30s %-15s %-15s %-15s %-15s %s\n" "ENDPOINT" "LIMIT" "SUCCESSFUL" "RATE LIMITED" "UNEXPECTED" "STATUS"
    echo "-----------------------------------------------------------------------------------------------------"

    for endpoint in "/v1/service_instances" "/v2/service_instances"; do
        local key=$(echo "${endpoint}_POST" | tr -c '[:alnum:]' '_')
        local result="${TEST_RESULTS[$key]}"
        local successes="${TEST_SUCCESSES[$key]}"
        local failures="${TEST_FAILURES[$key]}"
        local unexpected="${TEST_UNEXPECTED[$key]}"
        local status

        ((total_tests++))
        if [[ $result == "PASS" ]]; then
            ((passed_tests++))
            status="${GREEN}PASS${NC}"
        else
            ((failed_tests++))
            status="${RED}FAIL${NC}"
        fi

        printf "%-30s %-15s %-15s %-15s %-15s %b\n" \
            "${endpoint} (POST)" \
            "$POST_LIMIT" \
            "$successes" \
            "$failures" \
            "$unexpected" \
            "$status"
    done

    echo -e "\n${YELLOW}Overall Results:${NC}"
    echo "Total Tests Run: $total_tests"
    echo -e "Tests Passed:    ${GREEN}${passed_tests}${NC}"
    echo -e "Tests Failed:    ${RED}${failed_tests}${NC}"

    if [ $failed_tests -eq 0 ]; then
        echo -e "\n${GREEN}All rate limit tests passed successfully!${NC}"
    else
        echo -e "\n${RED}Some rate limit tests failed. Please check the detailed logs above.${NC}"
    fi
}

# Function to perform rate limit test
perform_rate_limit_test() {
    local endpoint=$1
    local limit=$2
    local method=${3:-GET}
    local test_key="$endpoint"

    if [ "$method" = "POST" ]; then
        test_key="${endpoint}_POST"
    fi

    echo -e "${YELLOW}Testing Rate Limit for ${endpoint} (${method} method)${NC}"

    local successful_requests=0
    local rate_limited_requests=0
    local unexpected_responses=0

    for ((i=1; i<=limit+5; i++)); do
        full_response=$(send_request "$endpoint" "$method")
        status_code=$(get_status_code "$full_response")

        case $status_code in
            200|201)
                ((successful_requests++))
                echo -n "."
                ;;
            429)
                ((rate_limited_requests++))
                echo -n "R"
                ;;
            *)
                ((unexpected_responses++))
                echo -n "X"
                echo "Unexpected response for request $i:"
                echo "$full_response"
                ;;
        esac

        sleep 0.1
    done

    echo -e "\n${GREEN}Successful Requests: $successful_requests${NC}"
    echo -e "${RED}Rate Limited Requests: $rate_limited_requests${NC}"
    echo -e "${YELLOW}Unexpected Responses: $unexpected_responses${NC}"

    # Determine test result
    local result
    if [[ $successful_requests -gt 0 && $successful_requests -le $((limit + 1)) && $rate_limited_requests -gt 0 ]]; then
        result="PASS"
        echo -e "${GREEN}PASS: Rate limit working as expected ($successful_requests successful, $rate_limited_requests rate limited)${NC}"
    else
        result="FAIL"
        echo -e "${RED}FAIL: Rate limit not working as expected ($successful_requests successful, $rate_limited_requests rate limited)${NC}"
    fi

    store_result "$test_key" "$limit" "$successful_requests" "$rate_limited_requests" "$unexpected_responses" "$result"
}

# Main test function
run_rate_limit_tests() {
    echo -e "${YELLOW}Starting Rate Limit Configuration Tests${NC}"

    # Test connectivity
    echo -e "${YELLOW}Checking Basic Connectivity${NC}"
    connectivity_response=$(send_request "/v1/service_bindings")
    echo "Connectivity Test Response:"
    echo "$connectivity_response"

    # Test endpoints
    for endpoint_limit in "${ENDPOINTS[@]}"; do
        IFS=':' read -r endpoint limit <<< "$endpoint_limit"
        perform_rate_limit_test "$endpoint" "$limit"
    done

    # Test POST endpoints
    perform_rate_limit_test "/v1/service_instances" "$POST_LIMIT" "POST"
    perform_rate_limit_test "/v2/service_instances" "$POST_LIMIT" "POST"

    # Print summary
    #print_summary
}

# Run the tests
run_rate_limit_tests

echo -e "${YELLOW}Rate Limit Tests Completed${NC}"