# --- Configuration ---
export PROJECT_ID=$(gcloud config get-value project)
export REGION="asia-southeast1" # Choose your desired region
export ZONE_A="${REGION}-a"
export ZONE_B="${REGION}-b"
export ZONE_C="${REGION}-c" # Using 3 zones for better availability

export NETWORK_NAME="galera-vpc"
export SUBNET_NAME="galera-subnet"
export SUBNET_CIDR="10.10.0.0/24" # Choose a suitable CIDR range

export GALERA_NODE_PREFIX="galera-node"
export PMM_SERVER_NAME="pmm-server"
export MACHINE_TYPE="e2-medium" # Adjust as needed

# Fixed Internal IPs for Galera Nodes (Choose IPs within your SUBNET_CIDR)
export GALERA_IP_1="10.10.0.10"
export GALERA_IP_2="10.10.0.11"
export GALERA_IP_3="10.10.0.12"
export PMM_SERVER_IP="10.10.0.20"

# External Static IP for Load Balancer
export LB_IP_NAME="galera-lb-ip"

# Tags for Firewall Rules
export GALERA_TAG="galera-node"
export PMM_TAG="pmm-server"
export SSH_TAG="allow-ssh" # Optional: Tag for SSH access

# MariaDB/Galera Settings
export GALERA_CLUSTER_NAME="gcp_galera_cluster"
export DB_ROOT_PASSWORD="p@s5W0rd.t00r" # CHANGE THIS!
export PMM_AGENT_PASSWORD="p@s5W0rd.mmp" # CHANGE THIS!
export PMM_ADMIN_PASSWORD="p@s5W0rd.mmp_n1mda"
export EXTERNAL_DB_USER="dbateam"
export EXTERNAL_DB_PASSWORD="p@s5W0rd.ma3tabd"

# --- End Configuration ---

echo "Using Project: $PROJECT_ID"
echo "Using Region: $REGION"

