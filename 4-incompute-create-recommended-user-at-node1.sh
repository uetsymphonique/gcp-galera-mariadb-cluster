# (Optional but recommended) Create a user for PMM agent monitoring
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE USER 'pmm_agent'@'%' IDENTIFIED BY '${PMM_AGENT_PASSWORD}';"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD ON *.* TO 'pmm_agent'@'%';"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"

# (Optional but recommended) Create a user for remote login
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE USER 'dbateam'@'%' IDENTIFIED BY 'p@s5W0rd'";
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON *.* TO 'dbateam'@'%' WITH GRANT OPTION;"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"
