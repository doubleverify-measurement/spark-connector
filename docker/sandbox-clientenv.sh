function configure_kdc() {
  docker exec kdc /kdc/configure.sh
}

function configure_db() {
  docker exec -u 0 vertica /vertica-krb/kerberize.sh
}

function configure_hdfs() {
  docker exec hdfs service ssh start
  docker exec hdfs start-dfs.sh
  docker exec -u 0 hdfs /hdfs-krb/kerberize.sh
  docker exec hdfs stop-dfs.sh
  docker exec hdfs start-dfs.sh
}

function configure_client() {
  docker exec docker_krbclient_1 /client-krb/kerberize.sh
  docker exec docker_slave_1 bin/sh -c "chmod +x /client-krb/slave-kerberize.sh"
  docker exec docker_slave_1 /client-krb/slave-kerberize.sh
  docker exec docker_krbclient_1 bin/sh -c "echo SPARK_MASTER_HOST='$(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_krbclient_1)' | tee -a /opt/spark/conf/spark-env.sh"
  docker exec docker_krbclient_1 bin/sh -c "echo SPARK_DIST_CLASSPATH=\$(/hadoop-3.3.1/bin/hadoop classpath) | tee -a /opt/spark/conf/spark-env.sh"
  docker exec docker_slave_1 bin/sh -c "echo SPARK_DIST_CLASSPATH=\$(/hadoop-3.3.0/bin/hadoop classpath) | tee -a /opt/spark/conf/spark-env.sh"
  docker exec docker_krbclient_1 bin/sh -c "echo -e \"master\nslave01\" | tee -a opt/spark/conf/workers"
  docker exec vertica /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" hdfs) hdfs.example.com hdfs | sudo tee -a /etc/hosts"
  docker exec docker_krbclient_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" hdfs) hdfs.example.com hdfs | tee -a /etc/hosts"
  docker exec docker_krbclient_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_slave_1) slave01 | tee -a /etc/hosts"
  docker exec docker_krbclient_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_krbclient_1) master | tee -a /etc/hosts"
  docker exec docker_krbclient_1 /bin/sh -c "systemctl restart sshd"
  docker exec docker_slave_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_slave_1) slave01 | tee -a /etc/hosts"
  docker exec docker_slave_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_krbclient_1) master | tee -a /etc/hosts"
  docker exec docker_slave_1 /bin/sh -c "echo $(docker exec docker_krbclient_1 /bin/sh -c "cat /root/.ssh/id_rsa.pub") | tee -a /root/.ssh/authorized_keys"
  docker exec docker_slave_1 /bin/sh -c "systemctl restart sshd"
  docker exec docker_krbclient_1 /bin/sh -c "start-master.sh"
  docker exec docker_slave_1 /bin/sh -c "start-worker.sh spark://master:7077"
  docker exec docker_krbclient_1 /bin/sh -c "start-worker.sh spark://master:7077"
}

function configure_containers() {
  echo "configuring kdc"
  configure_kdc
  echo "configuring hdfs"
  configure_hdfs
  echo "configuring client"
  configure_client
  echo "configuring db"
  configure_db
}

if [ "$1" == "kerberos" ]
  then
    echo "running kerberos docker compose"
    docker compose -f docker-compose-kerberos.yml up -d
    configure_containers
    docker exec -it docker_krbclient_1 /bin/bash
  else
    echo "running non-kerberized docker compose"
    docker compose -f docker-compose.yml up -d
    docker exec docker_slave_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_slave_1) slave01 | tee -a /etc/hosts"
    docker exec docker_slave_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_client_1) master | tee -a /etc/hosts"
    docker exec docker_client_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_slave_1) slave01 | tee -a /etc/hosts"
    docker exec docker_client_1 /bin/sh -c "echo $(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_client_1) master | tee -a /etc/hosts"
    docker exec docker_client_1 bin/sh -c "echo SPARK_DIST_CLASSPATH=\$(/hadoop-3.3.0/bin/hadoop classpath) | tee -a /opt/spark/conf/spark-env.sh"
    docker exec docker_slave_1 bin/sh -c "echo SPARK_DIST_CLASSPATH=\$(/hadoop-3.3.0/bin/hadoop classpath) | tee -a /opt/spark/conf/spark-env.sh"
    docker exec docker_client_1 bin/sh -c "echo SPARK_MASTER_HOST='$(docker inspect -f "{{with index .NetworkSettings.Networks \"EXAMPLE.COM\"}}{{.IPAddress}}{{end}}" docker_client_1)' | tee -a /opt/spark/conf/spark-env.sh"
    docker exec docker_client_1 bin/sh -c "echo -e \"master\nslave01\" | tee -a opt/spark/conf/workers"
    docker exec docker_slave_1 /bin/sh -c "systemctl restart sshd"
    docker exec docker_client_1 /bin/sh -c "systemctl restart sshd"
    docker exec docker_client_1 /bin/sh -c "start-master.sh"
    docker exec docker_slave_1 /bin/sh -c "start-worker.sh spark://master:7077"
    docker exec docker_client_1 /bin/sh -c "start-worker.sh spark://master:7077"
    docker exec docker_hdfs_1 cp /hadoop/conf/core-site.xml /opt/hadoop/etc/hadoop/core-site.xml
    docker exec docker_hdfs_1 cp /hadoop/conf/hdfs-site.xml /opt/hadoop/etc/hadoop/hdfs-site.xml
    docker exec docker_hdfs_1 /opt/hadoop/sbin/stop-dfs.sh
    docker exec docker_hdfs_1 /opt/hadoop/sbin/start-dfs.sh
    docker cp ../functional-tests/src/main/resources/3.1.1 docker_hdfs_1:/partitioned
    docker exec docker_hdfs_1 hadoop fs -copyFromLocal /partitioned /3.1.1
    docker exec docker_vertica_1 vsql -c "ALTER DATABASE docker SET MaxClientSessions=100;"
    docker exec -it docker_client_1 /bin/bash
fi
