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
