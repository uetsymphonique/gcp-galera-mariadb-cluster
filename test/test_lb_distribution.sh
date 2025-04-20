#!/bin/bash

# Configuration
LB_HOST="$LB_EXTERNAL_IP"           # Or set directly like: LB_HOST="35.222.123.45"
MYSQL_USER="dbateam"
MYSQL_PASS="$EXTERNAL_DB_PASSWORD" # Or set directly like: MYSQL_PASS="yourpassword"
NUM_REQUESTS=20                     # Number of queries to test
DELAY=1                             # Delay between queries (seconds)

# Test loop
echo "Testing Load Balancer Distribution..."
for i in $(seq 1 $NUM_REQUESTS); do
    echo -n "[$i] "
    mysql -h "$LB_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -sN -e "SELECT @@hostname;" 2>/dev/null
    sleep $DELAY
done

