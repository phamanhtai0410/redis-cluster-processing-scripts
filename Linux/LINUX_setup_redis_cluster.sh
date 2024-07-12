#!/bin/bash

# Redis Cluster Setup Script for Linux

# Load the ports from an external file
PORTS=($(<ports.conf))

# Check if script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Check if Redis is installed
if ! command -v redis-server &> /dev/null
then
    echo "Redis is not installed. Please install Redis before running this script."
    exit 1
fi

# Create directories
mkdir -p /etc/redis
mkdir -p /var/lib/redis

# Function to create Redis config file
create_redis_config() {
    cat << EOF > /etc/redis/redis-cluster-$1.conf
port $1
cluster-enabled yes
cluster-config-file nodes-$1.conf
cluster-node-timeout 5000
appendonly yes
protected-mode no
bind 0.0.0.0
dir /var/lib/redis
pidfile /var/run/redis/redis-$1.pid
EOF
}

# Function to create systemd service file
create_systemd_service() {
    cat << EOF > /etc/systemd/system/redis-cluster@.service
[Unit]
Description=Redis cluster node on port %i
After=network.target

[Service]
ExecStart=/usr/local/bin/redis-server /etc/redis/redis-cluster-%i.conf
Restart=always
User=redis
Group=redis

[Install]
WantedBy=multi-user.target
EOF
}

# Create Redis user and group if they don't exist
id -u redis &>/dev/null || useradd -r -s /bin/false redis
groupadd -f redis

# Create configs for each node
for port in "${PORTS[@]}";
do
    create_redis_config $port
    chown redis:redis /etc/redis/redis-cluster-$port.conf
    chmod 640 /etc/redis/redis-cluster-$port.conf
done

# Create systemd service file
create_systemd_service

# Reload systemd to recognize new service file
systemctl daemon-reload

# Start and enable Redis instances
for port in ;
do
    systemctl start redis-cluster@$port
    systemctl enable redis-cluster@$port
done

# Wait for Redis instances to start
echo "Waiting for Redis instances to start..."
sleep 5

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