## MariaDB Galera Cluster at GCP

Okay, let's set up a 3-node MariaDB Galera cluster on Google Cloud Platform using `gcloud`, place it within a VPC for fixed internal IPs, expose it via a TCP Load Balancer for external access, and add a PMM server for monitoring.

**Assumptions:**

- You have `gcloud` CLI installed and authenticated.
- You have a GCP project selected (`gcloud config set project YOUR_PROJECT_ID`).
- You have basic familiarity with Linux administration and MariaDB/MySQL.
- We'll use Ubuntu 22.04 LTS as the base OS.

**Steps:**

1. **Configuration Variables:** Define variables for easier command execution.
2. **Networking Setup:** Create VPC, Subnet, Firewall Rules, and Static IPs.
3. **Compute Instances:** Create VMs for Galera nodes and the PMM server.
4. **MariaDB Galera Installation & Configuration:** Set up MariaDB and Galera on the nodes.
5. **Load Balancer Setup:** Configure the TCP Load Balancer.
6. **PMM Server Setup:** Install and configure the PMM server.
7. **PMM Client Setup:** Install and configure PMM clients on Galera nodes.
8. **Verification:** Test the setup.

---

### **1. Configuration Variables**

This file will be run at all computes and your host by `source ./config.sh`

```bash
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
export PMM_AGENT_PASSWORD="p@s5W0rd.mmp_tn3ga" # CHANGE THIS!
export PMM_ADMIN_PASSWORD="p@s5W0rd.mmp_n1mda"
export EXTERNAL_DB_USER="dbateam"
export EXTERNAL_DB_PASSWORD="p@s5W0rd.ma3tabd"

# --- End Configuration ---

echo "Using Project: $PROJECT_ID"
echo "Using Region: $REGION"

```

**Make sure to change `YourSecureRootPassword` and `YourSecurePmmAgentPassword`!**

---

### **2. Networking Setup**

```bash
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

# Allow Load Balancer Health Checks (Adjust ports if your health check uses a different one)
gcloud compute firewall-rules create allow-lb-health-check \
    --network=$NETWORK_NAME \
    --allow=tcp:3306 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=$GALERA_TAG \
    --description="Allow GCP Load Balancer health checks"

# Allow External Access to Load Balancer (Port 3306)
# This rule targets the *nodes* because TCP Proxy LB sends traffic directly
gcloud compute firewall-rules create allow-lb-external-access \
    --network=$NETWORK_NAME \
    --allow=tcp:3306 \
    --source-ranges=0.0.0.0/0 `# WARNING: Allows access from ANY IP. Restrict if possible.` \
    --target-tags=$GALERA_TAG \
    --description="Allow external traffic to MariaDB via LB"

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

```

---

### **3. Compute Instances**

We'll create the instances one by one, assigning the fixed internal IPs.

```bash
echo "Creating Galera Node 1..."
gcloud compute instances create ${GALERA_NODE_PREFIX}-1 \
    --zone=$ZONE_A \
    --machine-type=$MACHINE_TYPE \
    --network-interface=subnet=${SUBNET_NAME},network-tier=PREMIUM,private-network-ip=${GALERA_IP_1} \
    --tags=$GALERA_TAG,$SSH_TAG \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-balanced \
    --scopes=cloud-platform # Needed for potential future GCP integrations

echo "Creating Galera Node 2..."
gcloud compute instances create ${GALERA_NODE_PREFIX}-2 \
    --zone=$ZONE_B \
    --machine-type=$MACHINE_TYPE \
    --network-interface=subnet=${SUBNET_NAME},network-tier=PREMIUM,private-network-ip=${GALERA_IP_2} \
    --tags=$GALERA_TAG,$SSH_TAG \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-balanced \
    --scopes=cloud-platform

echo "Creating Galera Node 3..."
gcloud compute instances create ${GALERA_NODE_PREFIX}-3 \
    --zone=$ZONE_C \
    --machine-type=$MACHINE_TYPE \
    --network-interface=subnet=${SUBNET_NAME},network-tier=PREMIUM,private-network-ip=${GALERA_IP_3} \
    --tags=$GALERA_TAG,$SSH_TAG \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-balanced \
    --scopes=cloud-platform

echo "Creating PMM Server Instance..."
gcloud compute instances create $PMM_SERVER_NAME \
    --zone=$ZONE_A \
    --machine-type=$MACHINE_TYPE `# PMM can be resource intensive, adjust if needed` \
    --network-interface=subnet=${SUBNET_NAME},network-tier=PREMIUM,private-network-ip=${PMM_SERVER_IP} \
    --tags=$PMM_TAG,$SSH_TAG \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB `# PMM needs more space for data` \
    --boot-disk-type=pd-balanced \
    --scopes=cloud-platform

echo "Instance creation complete. Waiting for SSH readiness..."
sleep 60 # Give instances time to boot

```

---

### **4. MariaDB Galera Installation & Configuration**

You'll need to SSH into each Galera node (`galera-node-1`, `galera-node-2`, `galera-node-3`) to perform these steps. Use `gcloud compute ssh <instance_name> --zone=<instance_zone>`.

**Perform these steps on ALL 3 Galera nodes:**

```bash
# SSH into the node first (e.g., gcloud compute ssh galera-node-1 --zone=$ZONE_A)

# Update package list and install MariaDB, Galera, rsync
sudo apt update
sudo apt install -y mariadb-server mariadb-client galera-4 rsync

# Stop MariaDB before configuration
sudo systemctl stop mariadb
sudo systemctl disable mariadb # Prevent auto-start before Galera is configured

# Create Galera configuration file
# IMPORTANT: Replace <NODE_IP> with the node's specific fixed internal IP
# (GALERA_IP_1 for node 1, GALERA_IP_2 for node 2, GALERA_IP_3 for node 3)
NODE_IP=$(hostname -I | awk '{print $1}') # This *should* get the primary private IP
CLUSTER_ADDRESS="gcomm://${GALERA_IP_1},${GALERA_IP_2},${GALERA_IP_3}"
NODE_NAME=$(hostname) # Use the instance hostname

sudo bash -c "cat > /etc/mysql/mariadb.conf.d/60-galera.cnf" << EOF
# Galera Cluster Configuration
[galera]
# Mandatory settings
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_address="${CLUSTER_ADDRESS}"
wsrep_cluster_name="${GALERA_CLUSTER_NAME}"
wsrep_node_address="${NODE_IP}"
wsrep_node_name="${NODE_NAME}"

# Optional but recommended settings
wsrep_sst_method=rsync # Or mariabackup if installed and configured
binlog_format=row
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0 # Listen on all interfaces within the VPC
performance_schema = ON

# Allow server to accept connections on all interfaces.
# Adjust bind-address for security if needed, but 0.0.0.0 is often
# necessary for health checks and intra-cluster communication depending on setup.
# Ensure firewall rules provide the actual security boundary.
EOF

echo "Galera config created for node ${NODE_NAME} with IP ${NODE_IP}"

# Exit SSH session if you were inside one for this node
# exit

```

**Now, Bootstrap the Cluster (ONLY on the FIRST node, e.g., `galera-node-1`):**

```bash
# SSH into galera-node-1
gcloud compute ssh ${GALERA_NODE_PREFIX}-1 --zone=$ZONE_A

# Start the cluster
sudo galera_new_cluster

# Check status (should show cluster size 1)
sudo mysql -u root -e "SHOW STATUS LIKE 'wsrep_cluster_size';"

# Secure the MariaDB installation (Set root password, remove test DBs, etc.)
# Use the DB_ROOT_PASSWORD you defined earlier
sudo mysql_secure_installation

# (Optional but recommended) Create a user for PMM agent monitoring
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE USER 'pmm_agent'@'%' IDENTIFIED BY '${PMM_AGENT_PASSWORD}';"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD ON *.* TO 'pmm_agent'@'%';"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"

# (Optional but recommended) Create a user for remote login
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE USER 'dbateam'@'%' IDENTIFIED BY 'p@s5W0rd'";
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON *.* TO 'dbateam'@'%' WITH GRANT OPTION;"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"

# Exit SSH session
exit
```

**Start MariaDB on the OTHER nodes (e.g., `galera-node-2`, `galera-node-3`):**

```bash
# SSH into galera-node-2
gcloud compute ssh ${GALERA_NODE_PREFIX}-2 --zone=$ZONE_B

# Start MariaDB normally, it will join the cluster
sudo systemctl start mariadb

# Check status (wait a minute or two)
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_cluster_size';" # Should show 2 after node 2 joins
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_local_state_comment';" # Should show 'Synced'

# Exit SSH session
exit

# --- Repeat for galera-node-3 ---
gcloud compute ssh ${GALERA_NODE_PREFIX}-3 --zone=$ZONE_C
sudo systemctl start mariadb
sleep 30 # Give it time to sync
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_cluster_size';" # Should show 3
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_local_state_comment';" # Should show 'Synced'
exit

```

Your Galera cluster should now be running.

---

### **5. Load Balancer Setup**

We'll use a Regional TCP Proxy Load Balancer.

```bash
echo "Setting up Load Balancer..."

# 1. Create a Health Check for MariaDB
gcloud compute health-checks create tcp galera-health-check \
    --region=$REGION \
    --port=3306 \
    --check-interval=10s \
    --timeout=5s \
    --unhealthy-threshold=3 \
    --healthy-threshold=2

# 2. Create an Unmanaged Instance Group (since we have fixed IPs)
# Add nodes one by one to their respective zonal groups
gcloud compute instance-groups unmanaged create galera-group-a --zone=$ZONE_A
gcloud compute instance-groups unmanaged add-instances galera-group-a --zone=$ZONE_A --instances=${GALERA_NODE_PREFIX}-1

gcloud compute instance-groups unmanaged create galera-group-b --zone=$ZONE_B
gcloud compute instance-groups unmanaged add-instances galera-group-b --zone=$ZONE_B --instances=${GALERA_NODE_PREFIX}-2

gcloud compute instance-groups unmanaged create galera-group-c --zone=$ZONE_C
gcloud compute instance-groups unmanaged add-instances galera-group-c --zone=$ZONE_C --instances=${GALERA_NODE_PREFIX}-3

# 3. Create Backend Service for Network LB (scheme EXTERNAL is suitable here)
#    Note: Health check remains the same regional TCP health check
gcloud compute backend-services create galera-backend-service \
    --region=$REGION \
    --protocol=TCP \
    --health-checks=galera-health-check \
    --health-checks-region=$REGION \
    --load-balancing-scheme=EXTERNAL `# Network LB uses EXTERNAL scheme`

# 4. Add Instance Groups to the Backend Service
gcloud compute backend-services add-backend galera-backend-service \
    --region=$REGION \
    --instance-group=galera-group-a \
    --instance-group-zone=$ZONE_A
gcloud compute backend-services add-backend galera-backend-service \
    --region=$REGION \
    --instance-group=galera-group-b \
    --instance-group-zone=$ZONE_B
gcloud compute backend-services add-backend galera-backend-service \
    --region=$REGION \
    --instance-group=galera-group-c \
    --instance-group-zone=$ZONE_C

# 5. Create Forwarding Rule targeting Backend Service directly
export LB_EXTERNAL_IP=$(gcloud compute addresses describe $LB_IP_NAME --region=$REGION --format='value(address)')
gcloud compute forwarding-rules create galera-forwarding-rule \
  --region=$REGION \
  --ports=3306 \
  --address=$LB_EXTERNAL_IP \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --backend-service=galera-backend-service \
  --backend-service-region=$REGION \
  --network-tier=STANDARD
echo "Load Balancer setup complete. Access it via: ${LB_EXTERNAL_IP}:3306"
```

---

### **6. PMM Server Setup**

We'll use Docker for the PMM Server as recommended by Percona.

```bash
# SSH into the PMM server instance
gcloud compute ssh $PMM_SERVER_NAME --zone=$ZONE_A

# Install Docker
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Add user to docker group (optional, avoids using sudo for docker commands)
sudo usermod -aG docker $USER
echo "You may need to log out and log back in for docker group changes to take effect."

# Create a persistent volume for PMM data
docker volume create pmm-data

# Run PMM Server container
# It will automatically restart if the VM reboots
docker run -d \
  -p 80:80 \
  -p 443:443 \
  -v pmm-data:/srv \
  --name pmm-server \
  --restart always \
  percona/pmm-server:2

echo "PMM Server container starting."
echo "Access the PMM UI via http://${PMM_SERVER_IP} or https://${PMM_SERVER_IP}"
echo "Note: Default login is admin/admin. CHANGE THE PASSWORD IMMEDIATELY upon first login."

# Exit SSH session
exit

```

Access the PMM Server UI using its *internal* IP (`http://${PMM_SERVER_IP}`) from a machine within the VPC or via SSH tunneling/IAP if you restricted the `allow-pmm-ui` firewall rule. Accessing via its *external* IP (if it has one, which we didn't assign by default) depends on the `allow-pmm-ui` rule source ranges. Change the default `admin` password.

---

### **7. PMM Client Setup**

Install the PMM agent on each Galera node and connect it to the server.

**Perform these steps on ALL 3 Galera nodes:**

```bash
# SSH into the node (e.g., galera-node-1)
# gcloud compute ssh ${GALERA_NODE_PREFIX}-1 --zone=$ZONE_A

# Download and install PMM2 client package
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
sudo apt update
sudo apt install -y pmm2-client

# Configure the client to connect to the PMM server
# Use --server-insecure-tls if PMM server is using self-signed certs (default)
sudo pmm-admin config --server-insecure-tls --server-url=https://admin:${PMM_ADMIN_PASSWORD}@${PMM_SERVER_IP}:443

# Add the MariaDB service for monitoring
# Use the pmm_agent user and password created earlier
NODE_NAME=$(hostname) # Get the instance name again
NODE_IP=$(hostname -I | awk '{print $1}')

sudo pmm-admin add mysql \
   --username=pmm_agent --password=${PMM_AGENT_PASSWORD} \
   --query-source=perfschema \
   --environment="galera-production" \
   --custom-labels="cluster=${GALERA_CLUSTER_NAME},region=${REGION}" \
   ${NODE_NAME}-mysql ${NODE_IP}:3306

# Check status
sudo pmm-admin list
sudo pmm-admin status

echo "PMM client setup complete for this node."

# Exit SSH session
# exit

# --- Repeat for other Galera nodes ---

```

Replace `YOUR_NEW_PMM_ADMIN_PASSWORD` with the password you set in the PMM UI.

---

### **8. Verification**

1. **Cluster Status:** SSH into any Galera node and run `sudo mysql -u root -p -e "SHOW STATUS LIKE 'wsrep_cluster_size';"`. It should show `3`. Also check `wsrep_local_state_comment` (should be `Synced`).
2. **Load Balancer:** Use a MySQL client from your local machine (or another VM) to connect to the `LB_EXTERNAL_IP` on port 3306 using a valid database user (e.g., the `root` user or another you created).
    
    ```bash
    mysql -h $LB_EXTERNAL_IP -u root -p
    
    ```
    
3. **PMM Monitoring:** Open the PMM UI (`http://${PMM_SERVER_IP}` or `https://${PMM_SERVER_IP}`). You should see the three Galera nodes appear and start reporting metrics within a few minutes. Explore the dashboards (e.g., MySQL Overview).

---

**Important Considerations:**

- **Security:** The firewall rules provided are basic. Restrict `source-ranges` (especially for SSH, PMM UI, and LB access) to only known IP addresses whenever possible. Use strong passwords. Consider tools like Cloud IAP for SSH access instead of opening port 22. Secure your MariaDB users properly.
- **StatefulSet Alternative:** For more complex or production environments, consider using Google Kubernetes Engine (GKE) with a StatefulSet and potentially an operator (like Percona Operator for MySQL) to manage the Galera cluster lifecycle.
- **Backups:** This setup does *not* include database backups. Implement a robust backup strategy (e.g., using `mariabackup`, snapshots, or Cloud SQL if you were using a managed service).
- **SST Method:** `rsync` is simple but locks the donor node. `mariabackup` is non-blocking but requires `mariadb-backup` package installation and potentially extra configuration/permissions.
- **Quorum:** Always maintain an odd number of nodes (>=3) to avoid split-brain scenarios. If a node goes down, the cluster needs a majority (more than half) to remain operational.
- **Resource Sizing:** Adjust `MACHINE_TYPE` and disk sizes based on your expected load.
- **Cost:** Be mindful of the costs associated with Compute Engine instances, Load Balancer, Static IPs, and network egress.
- **Maintenance:** Plan for OS patching and MariaDB upgrades.

---

### **Cleanup (If needed)**

```bash
echo "Cleaning up resources..."

# Delete Forwarding Rule
gcloud compute forwarding-rules delete galera-forwarding-rule --region=$REGION --quiet

# Delete Target Proxy
gcloud compute target-tcp-proxies delete galera-tcp-proxy --region=$REGION --quiet

# Delete Backend Service
gcloud compute backend-services delete galera-backend-service --region=$REGION --quiet

# Delete Instance Groups
gcloud compute instance-groups unmanaged delete galera-group-a --zone=$ZONE_A --quiet
gcloud compute instance-groups unmanaged delete galera-group-b --zone=$ZONE_B --quiet
gcloud compute instance-groups unmanaged delete galera-group-c --zone=$ZONE_C --quiet

# Delete Health Check
gcloud compute health-checks delete galera-health-check --region=$REGION --quiet

# Delete Instances
gcloud compute instances delete ${GALERA_NODE_PREFIX}-1 --zone=$ZONE_A --quiet
gcloud compute instances delete ${GALERA_NODE_PREFIX}-2 --zone=$ZONE_B --quiet
gcloud compute instances delete ${GALERA_NODE_PREFIX}-3 --zone=$ZONE_C --quiet
gcloud compute instances delete $PMM_SERVER_NAME --zone=$ZONE_A --quiet

# Delete Static External IP
gcloud compute addresses delete $LB_IP_NAME --region=$REGION --quiet

# Delete Firewall Rules
gcloud compute firewall-rules delete galera-internal --quiet
gcloud compute firewall-rules delete allow-lb-health-check --quiet
gcloud compute firewall-rules delete allow-lb-external-access --quiet
gcloud compute firewall-rules delete allow-ssh --quiet
gcloud compute firewall-rules delete allow-pmm-ui --quiet
gcloud compute firewall-rules delete allow-pmm-agents --quiet

# Delete Subnet
gcloud compute networks subnets delete $SUBNET_NAME --region=$REGION --quiet

# Delete VPC Network
gcloud compute networks delete $NETWORK_NAME --quiet

echo "Cleanup complete."

```

This comprehensive guide provides the `gcloud` commands and configuration steps to build your MariaDB Galera cluster with load balancing and PMM monitoring on GCP. Remember to adapt passwords, IP ranges, and resource sizes to your specific needs.
