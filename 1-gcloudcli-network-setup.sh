# Create VPC Network
gcloud compute networks create $NETWORK_NAME \
    --subnet-mode=custom \
    --mtu=1460 \
    --bgp-routing-mode=regional

# Create Subnet
gcloud compute networks subnets create $SUBNET_NAME \
    --network=$NETWORK_NAME \
    --range=$SUBNET_CIDR \
    --region=$REGION

# Reserve Static External IP for Load Balancer
gcloud compute addresses create $LB_IP_NAME \
    --region=$REGION \
    --network-tier=STANDARD # Use PREMIUM for global LB if needed

# Get the reserved external IP address
export LB_EXTERNAL_IP=$(gcloud compute addresses describe $LB_IP_NAME --region=$REGION --format='value(address)')
echo "Load Balancer External IP: $LB_EXTERNAL_IP"

# Firewall Rules
echo "Creating Firewall Rules..."

# Allow internal communication between Galera nodes (MySQL, Galera Replication, IST, SST)
gcloud compute firewall-rules create galera-internal \
    --network=$NETWORK_NAME \
    --allow=tcp:3306,tcp:4444,tcp:4567,tcp:4568,udp:4567,icmp \
    --source-ranges=$SUBNET_CIDR \
    --target-tags=$GALERA_TAG \
    --description="Allow internal Galera cluster communication"

sleep 2

# Allow Load Balancer Health Checks (Adjust ports if your health check uses a different one)
gcloud compute firewall-rules create allow-lb-health-check \
    --network=$NETWORK_NAME \
    --allow=tcp:3306 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=$GALERA_TAG \
    --description="Allow GCP Load Balancer health checks"
sleep 2

# Allow External Access to Load Balancer (Port 3306)
# This rule targets the *nodes* because TCP Proxy LB sends traffic directly
gcloud compute firewall-rules create allow-lb-external-access \
    --network=$NETWORK_NAME \
    --allow=tcp:3306 \
    --source-ranges=0.0.0.0/0 `# WARNING: Allows access from ANY IP. Restrict if possible.` \
    --target-tags=$GALERA_TAG \
    --description="Allow external traffic to MariaDB via LB"
sleep 2
# Allow SSH access (Optional but recommended for setup)
# Consider restricting source-ranges to your specific IP CIDR
gcloud compute firewall-rules create allow-ssh \
    --network=$NETWORK_NAME \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=$SSH_TAG,$GALERA_TAG,$PMM_TAG \
    --description="Allow SSH access"

# Allow PMM Server Web UI Access (Restrict source-ranges to your IP)
gcloud compute firewall-rules create allow-pmm-ui \
    --network=$NETWORK_NAME \
    --allow=tcp:80,tcp:443 \
    --source-ranges=0.0.0.0/0 `# Restrict this to your IP address/range for security` \
    --target-tags=$PMM_TAG \
    --description="Allow access to PMM Web UI"

# Allow PMM Agents (Galera Nodes) to connect to PMM Server
gcloud compute firewall-rules create allow-pmm-agents \
    --network=$NETWORK_NAME \
    --allow=tcp:42000-42005 `# Default ports used by pmm-agent` \
    --source-tags=$GALERA_TAG \
    --target-tags=$PMM_TAG \
    --description="Allow PMM agents to connect to PMM server"

echo "Networking setup complete."

