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

