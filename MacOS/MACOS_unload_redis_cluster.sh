#!/bin/bash

REDIS_INSTANCES=($(<ports.conf))  # List all ports of Redis instances

# Function to stop Redis instances
stop_redis_instances() {
    for port in "${REDIS_INSTANCES[@]}"; do
        plist_filename="com.redis.cluster.${port}.plist"
        plist_path="$HOME/Library/LaunchAgents/${plist_filename}"

        # Unload the plist file from launchd
        launchctl unload "${plist_path}"
        
        # Optionally, you can remove the plist file after unloading
        # sudo rm "${plist_path}"
        
        echo "Stopped Redis instance on port ${port}"
    done
}

# Call the function to stop Redis instances
stop_redis_instances
