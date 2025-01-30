# Service Mesh Rate Limiting and Throttling System

## Architecture Overview
The system implements two levels of traffic control: rate limiting and throttling. These mechanisms work together to ensure service stability and fair resource utilization.

## Rate Limiting System
### Purpose
Protects backend services from excessive requests by limiting request counts within time windows.

### Implementation Flow
1. Each endpoint has specific limits for 30-second and 2-minute windows
2. Redis tracks request counts per endpoint, version, and user
3. System increments counters and checks against defined thresholds
4. Exceeding limits triggers 429 responses with retry information

### Time Windows
- Short window (30s): Handles sudden traffic spikes
- Long window (2m): Controls sustained load

## Throttling System
### Purpose
Manages concurrent requests and prevents system overload through dynamic request pacing.

### Key Components
1. Semaphore Counter
    - Tracks active concurrent requests
    - Provides real-time utilization metrics

2. Dynamic Throttling
    - Activates at configurable threshold (default 50%)
    - Applies graduated delays based on:
        * Current system utilization
        * User request frequency
        * Priority calculations

3. User Priority System
    - Higher priority for low-frequency users
    - Reduced throttling for well-behaved clients

## Monitoring and Metrics
### Available Metrics
- Current utilization
- Semaphore size and threshold
- Request rates per endpoint
- Throttling delays applied

### Testing Methodology
1. Baseline Performance Testing
    - Purpose: Establish normal operation metrics
    - Method: Low concurrency, sustained requests
    - Expected: Minimal throttling, no rate limiting

2. Load Testing
    - Purpose: Verify throttling behavior
    - Method: Increasing concurrent requests
    - Expected: Gradual response time increase, controlled degradation

3. Rate Limit Testing
    - Purpose: Verify rate limiting thresholds
    - Method: Rapid request sequences
    - Expected: 429 responses at limit boundaries

## System Behavior Examples
### Normal Operation
- Low utilization: Direct request processing
- No delays or rate limiting
- Fast response times

### Peak Load
1. High Concurrency
    - Throttling activates
    - Priority users experience shorter delays
    - System maintains stability

2. Rate Limit Approach
    - Warning headers indicate approaching limits
    - Gradual throughput reduction
    - Predictable failure modes

### Overload Protection
- Combined rate limiting and throttling
- Graceful service degradation
- Protected backend services

## Best Practices and Tuning
### Configuration Guidelines
- Set rate limits based on backend capacity
- Adjust throttling threshold to service characteristics
- Balance delay parameters for user experience

### Monitoring Focus
- Utilization patterns
- Error rates and types
- Response time distribution
- User request patterns

### Optimization Targets
- Minimize unnecessary throttling
- Maintain fair resource allocation
- Protect system stability
- Optimize user experience

Here's a tutorial on the rate limiting and throttling implementation:

# Configuration Overview
```bash
export SEMAPHORE_SIZE=100        # Max concurrent requests
export SEMAPHORE_THRESHOLD=50    # Throttling starts at 50%
export BASE_DELAY_MS=100        # Base delay for throttling
```

# Rate Limiting Logic
1. Time Windows:
- 30s window with limits: 100 requests for service_bindings
- 2m window with higher limits: 200 requests for service_bindings

2. Implementation:
```lua
local minute_key = math.floor(ngx.now() / time_window)
local rate_key = version .. ":" .. endpoint
local minute_count = red:incr(rate_key .. ":30s:" .. minute_key)
```

# Throttling Logic
1. Concurrent Request Tracking:
```lua
local success = semaphore:incr("current_utilization", 1, 0)
```

2. Throttling Calculation:
```lua
if current_utilization >= (semaphore_size * semaphore_threshold / 100) then
    throttle_time = calculate_throttling_time(utilization, freq)
end
```

# Testing Steps

1. Basic Health:
```bash
curl http://localhost:8081/health
curl http://localhost:8081/redis-test

docker-compose exec redis redis-cli monitor
```

2. Monitor Metrics:
```bash
watch -n 1 'curl -s https://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/metrics | jq'
tail -f /var/log/nginx/error.log | grep "utilization"
```

3. Load Testing:
```bash
# Baseline
wrk -t5 -c25 -d10s http://localhost:8081/v1/service_bindings

# Test Throttling
wrk -t5 -c100 -d30s http://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/v1/service_bindings

# Test Rate Limits
wrk -t2 -c10 -d60s http://localhost:8081/v1/service_bindings


for i in {1..5}; do
    wrk -t2 -c50 -d30s -H "X-Test-Client: client$i" http://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/v1/service_bindings &
done


ab -c 10 -n 1000 -r http://sm-nginx.cert.cfapps.stagingazure.hanavlab.ondemand.com/v1/service_bindings

```



4. Expected Results:
- Utilization increases with concurrent requests
- Throttling adds delay above 50% utilization
- Rate limits return 429 status when exceeded
- Higher request frequency users get more throttling

# Common Issues
1. High 429s: Increase rate limits
2. High latency: Decrease BASE_DELAY_MS
3. Zero utilization: Check semaphore initialization


The throttling flow works like this:

Every request increments a shared counter ("current_utilization") in Redis
When utilization exceeds threshold (SEMAPHORE_THRESHOLD% of SEMAPHORE_SIZE):

Calculate user's frequency/priority based on their recent requests
Determine delay time based on: current utilization, user frequency, and BASE_DELAY_MS
Apply delay to slow down request


After request completes, decrement the utilization counter
Key calculations:

Throttle time = BASE_DELAY_MS * (utilization/size)² * log(frequency) * (1 + random jitter)
Priority = 10 - floor(frequency/5)
Final delay = throttle_time * (1 - priority/10)