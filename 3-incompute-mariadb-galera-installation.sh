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

