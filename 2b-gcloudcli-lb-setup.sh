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
