#!/bin/bash

REDIS_INSTANCES=($(<ports.conf)) # List all ports of Redis instances

# Function to start Redis instances
start_redis_instances() {
    for port in "${REDIS_INSTANCES[@]}"; do
        plist_filename="com.redis.cluster.${port}.plist"
        plist_path="$HOME/Library/LaunchAgents/${plist_filename}"

        # Load the plist file into launchd
        launchctl load "${plist_path}"
        
        echo "Started Redis instance on port ${port}"
    done
}

# Call the function to start Redis instances
start_redis_instances
