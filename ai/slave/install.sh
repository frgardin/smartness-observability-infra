#!/bin/bash

set -e

echo "=== Smartness Observability Slave Node Installation ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS $VER"

# Install Docker
install_docker() {
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
    echo "Docker installed successfully"
}

# Install Docker Compose
install_docker_compose() {
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installed successfully"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    install_docker
else
    echo "Docker is already installed"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    install_docker_compose
else
    echo "Docker Compose is already installed"
fi

# Create monitoring user
echo "Creating monitoring user..."
useradd -r -s /bin/false monitoring || true
usermod -aG docker monitoring

# Create directories
echo "Creating directories..."
mkdir -p /opt/observability/slave
mkdir -p /var/lib/node_exporter/textfile_collector

# Copy files
echo "Copying configuration files..."
cp -r . /opt/observability/slave/
chown -R monitoring:monitoring /opt/observability

# Create systemd service
cat > /etc/systemd/system/observability-slave.service << EOF
[Unit]
Description=Observability Slave Services
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/observability/slave
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable observability-slave.service
systemctl start observability-slave.service

# Configure firewall
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 9100/tcp
    ufw allow 8080/tcp
    ufw allow 9115/tcp
    echo "Firewall configured"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=9100/tcp
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=9115/tcp
    firewall-cmd --reload
    echo "Firewall configured"
fi

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Verify services
echo "Verifying services..."
if curl -s http://localhost:9100/metrics > /dev/null; then
    echo "✓ Node Exporter is running on port 9100"
else
    echo "✗ Node Exporter is not responding"
fi

if curl -s http://localhost:8080/metrics > /dev/null; then
    echo "✓ cAdvisor is running on port 8080"
else
    echo "✗ cAdvisor is not responding"
fi

if curl -s http://localhost:9115/metrics > /dev/null; then
    echo "✓ Blackbox Exporter is running on port 9115"
else
    echo "✗ Blackbox Exporter is not responding"
fi

echo ""
echo "=== Installation Complete ==="
echo "Node Exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "cAdvisor: http://$(hostname -I | awk '{print $1}'):8080/metrics"
echo "Blackbox Exporter: http://$(hostname -I | awk '{print $1}'):9115/metrics"
echo ""
echo "Add this node to the master using:"
echo "  ./scripts/add-target.sh $(hostname -I | awk '{print $1}') $(hostname)"