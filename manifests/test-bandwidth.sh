#!/bin/bash

# test-bandwidth.sh
echo "Starting bandwidth tests..."

# Base URL - adjust this to your environment
BASE_URL="https://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com"

# Function to check bandwidth stats
check_stats() {
    curl -s "${BASE_URL}/bandwidth-stats" | jq '.'
}

# Test 1: Single request with 1MB payload
echo "Test 1: Single request with 1MB payload"
# Use dd to create a temporary 1MB file
dd if=/dev/zero bs=1M count=1 2>/dev/null | tr '\0' 'A' > temp_payload.txt
curl -X POST -d @temp_payload.txt "${BASE_URL}/test-bandwidth"
rm temp_payload.txt
echo "Stats after single request:"
check_stats
echo

# Test 2: Multiple concurrent requests
echo "Test 2: Multiple concurrent requests"
wrk -t2 -c10 -d30s -s test.lua "${BASE_URL}/test-bandwidth"
echo "Stats after concurrent test:"
check_stats
echo

# Test 3: Gradual ramp-up
echo "Test 3: Gradual ramp-up"
for i in {1..5}; do
    echo "Batch $i"
    wrk -t2 -c5 -d10s -s test.lua "${BASE_URL}/test-bandwidth"
    echo "Stats after batch $i:"
    check_stats
    echo
    sleep 2
done

# Test 4: Recovery test
echo "Test 4: Recovery test"
wrk -t2 -c10 -d15s -s test.lua "${BASE_URL}/test-bandwidth"
echo "Initial stats:"
check_stats
echo
echo "Waiting 30 seconds for recovery..."
sleep 30
echo "Stats after recovery:"
check_stats