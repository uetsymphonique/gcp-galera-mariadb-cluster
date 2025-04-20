#!/bin/bash

# Configuration
LB_HOST="$LB_EXTERNAL_IP"               # or hardcode the IP
MYSQL_USER="dbateam"
MYSQL_PASS="$EXTERNAL_DB_PASSWORD"
DB_NAME="demo_db"
TABLE_NAME="demo_table"
ITERATIONS=1000
DELAY=0.1                               # seconds

echo "Starting fake MySQL load..."

for i in $(seq 1 $ITERATIONS); do
    mysql -h "$LB_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -sN -e \
      "INSERT INTO ${DB_NAME}.${TABLE_NAME} (name) VALUES ('Fake load $i');" 2>/dev/null

    sleep $DELAY
done

echo "Fake load completed!"

