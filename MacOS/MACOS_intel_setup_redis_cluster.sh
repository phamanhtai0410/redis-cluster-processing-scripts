#!/bin/bash

# Redis Cluster Setup Script for macOS (with dynamic paths)

# Load the ports from an external file
PORTS=($(<ports.conf))

set -e  # Exit immediately if a command exits with a non-zero status.

# Check if Redis is installed
if ! command -v redis-server &> /dev/null; then
    echo "- Redis is not installed. Installing via Homebrew..."
    brew install redis
fi

# Dynamic path based on current user's home directory
REDIS_CLUSTER_PATH="$HOME/redis-cluster"
REDIS_DATA_PATH="$REDIS_CLUSTER_PATH/data"
REDIS_CONFIG_PATH="$REDIS_CLUSTER_PATH/config"

# Create directories
mkdir -p "$REDIS_CONFIG_PATH"
mkdir -p "$REDIS_DATA_PATH"

# Function to create Redis config file
create_redis_config() {
    cat << EOF > "$REDIS_CONFIG_PATH/redis-cluster-$1.conf"
port $1
cluster-enabled yes
cluster-config-file $REDIS_DATA_PATH/nodes-$1.conf
cluster-node-timeout 5000
appendonly yes
protected-mode no
bind 127.0.0.1
dir $REDIS_DATA_PATH
pidfile $REDIS_DATA_PATH/redis-$1.pid
EOF
    echo "Created configuration file for port $1"
}

# Function to create launchd plist file
create_launchd_plist() {
    touch "$REDIS_DATA_PATH/redis-cluster-$1.log"
    cat << EOF > "$HOME/Library/LaunchAgents/com.redis.cluster.$1.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.redis.cluster.$1</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/redis-server</string>
        <string>$REDIS_CONFIG_PATH/redis-cluster-$1.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$REDIS_DATA_PATH/redis-cluster-$1.log</string>
    <key>StandardOutPath</key>
    <string>$REDIS_DATA_PATH/redis-cluster-$1.log</string>
    <key>WorkingDirectory</key>
    <string>$REDIS_DATA_PATH</string>
</dict>
</plist>
EOF
    echo "Created launchd plist for port $1"
}

# Create configs and plists for each node
for port in "${PORTS[@]}"; do
    create_redis_config $port
    create_launchd_plist $port
    launchctl unload "$HOME/Library/LaunchAgents/com.redis.cluster.$port.plist" 2>/dev/null || true
    launchctl load "$HOME/Library/LaunchAgents/com.redis.cluster.$port.plist"
    echo "Loaded launchd job for port $port"
done

# Wait for Redis instances to start
echo "Waiting for Redis instances to start..."
sleep 5

# Check if Redis instances are running
for port in "${PORTS[@]}"; do
    if ! redis-cli -p $port ping > /dev/null 2>&1; then
        echo "Error: Redis instance on port $port is not responding."
        echo "Check the log file at $REDIS_DATA_PATH/redis-cluster-$port.log for more information."
        exit 1
    fi
    echo "Redis instance on port $port is running"
done

# Check cluster mode
for port in "${PORTS[@]}"; do
    if ! redis-cli -p $port INFO cluster | grep -q "cluster_enabled:1"; then
        echo "Error: Cluster mode is not enabled for Redis instance on port $port."
        echo "Check the configuration file at $REDIS_CONFIG_PATH/redis-cluster-$port.conf"
        exit 1
    fi
    echo "Cluster mode is enabled for Redis instance on port $port"
done

# Create the cluster
echo "Creating Redis cluster..."

# Generate the redis-cli --cluster create command
REDIS_CLI=$(which redis-cli)
CREATE_CMD="$REDIS_CLI --cluster create"
for port in "${PORTS[@]}"; do
  CREATE_CMD+=" 127.0.0.1:$port"
done
CREATE_CMD+=" --cluster-yes"

# Execute the redis-cli --cluster create command
eval $CREATE_CMD

echo "Redis cluster setup complete!"
