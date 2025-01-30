#!/bin/bash

# Run 5 parallel loops simulating different clients
for client in {1..5}; do
    (
        for i in {1..30}; do
            curl -i -H "X-Client-ID: client$client" \
                "https://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/v1/service_bindings" &>/dev/null

            # Get metrics after each request
            echo "Client $client - Request $i"
            curl -s "https://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/metrics" | jq .

            sleep 0.5
        done
    ) &
done

wait