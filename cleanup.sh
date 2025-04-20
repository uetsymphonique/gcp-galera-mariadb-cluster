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

