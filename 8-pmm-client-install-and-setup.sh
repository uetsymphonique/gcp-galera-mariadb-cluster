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

