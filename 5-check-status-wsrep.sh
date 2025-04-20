sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_local_state_comment';"
