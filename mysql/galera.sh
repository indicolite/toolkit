#!/bin/sh
set -x
password_galera_root=Abc12345
STOP_NODES=();
UUID=$(uuidgen)
rm -rf /tmp/GTID_*

findBootstrapNode(){
  for host in $(cat /tmp/GTID_${UUID}|grep "\-1"|awk '{print $2}')
  do
    VIEW_ID=$(ssh ${host} cat /var/lib/mysql/gvwstate.dat|grep view_id|awk '{print $3}')
    MY_UUID=$(ssh ${host} cat /var/lib/mysql/gvwstate.dat|grep my_uuid|awk '{print $2}')
    if [ $VIEW_ID = $MY_UUID  ];then
       echo $host
       break
    fi
  done
}

### 1. Check mariadb service in every nodes
for i in $@;
do
  FLAG=$(ssh $i systemctl status mariadb |grep Active:|grep running|wc -l)
  if [ "${FLAG}" = "0" ];then
    echo "[INFO] $i is down!"
    let INDEX=${#STOP_NODES[@]}+1
    STOP_NODES[INDEX]=$i
    seqno=$(ssh $i cat /var/lib/mysql/grastate.dat|grep seqno:|awk '{print $2}')
    echo $seqno" "$i >> /tmp/GTID_$UUID
  elif [ "$FLAG" = "1" ];then
    echo "[INFO] $i is up!"
  else
    echo "[ERROR] Get the status of $i mariadb is error!"
    exit 127
  fi
done
### 2. Recover Galera Cluster
let CLUSTER_SIZE=3-${#STOP_NODES[@]}
if [ "${CLUSTER_SIZE}" = "3" ]; then
  echo "[INFO] Galera is OK!"
elif [ "$CLUSTER_SIZE" = "2" -o "$CLUSTER_SIZE" = "1" ];then
  echo "[INFO] One or Two MariaDB nodes is down!"
  ## 2.1 Only start the mariadb service in stopped nodes
  for node in ${STOP_NODES[@]};
  do
    ssh ${node} systemctl start mariadb
  done
elif [ "${CLUSTER_SIZE}" = "0" ]; then
  echo "[INFO] All MariaDB nodes is down!"
  ABNORMAL_SIZE=$(cat /tmp/GTID_$UUID |grep "\-1"|wc -l)
  ## 2.2 Find the latest state node to bootstrap and start others nodes
  ## 2.2.1 All three nodes are gracefully stopped
  if [ "$ABNORMAL_SIZE" = "0" ];then
    BOOTSTARP_NODE=$(cat /tmp/GTID_$UUID|sort -n -r|head -n 1|awk '{print $2}')
    echo "[INFO] All three nodes are gracefully stopped!"
  ## 2.2.2 All nodes went down without proper shutdown procedure
  elif [ "$ABNORMAL_SIZE" = "1" ];then
    BOOTSTARP_NODE=$(cat /tmp/GTID_$UUID|grep "\-1"|awk '{print $2}')
    echo "[INFO] One node disappear in Galera Cluster! Two nodes are gracefully stopped!"
  elif [ "$ABNORMAL_SIZE" = "2" ];then
    echo "[INFO] Two nodes disappear in Galera Cluster! One node is gracefully stopped!"
    BOOTSTARP_NODE=$(findBootstrapNode)
  elif [ "$ABNORMAL_SIZE" = "3" ];then
    echo "[INFO] All nodes went down without proper shutdown procedure!"
    BOOTSTARP_NODE=$(findBootstrapNode)
  else
   echo "[ERROR] No grastate.dat or gvwstate.dat file!"
   exit 127
  fi
  ### Recover Galera
  echo "[INFO] The bootstarp node is:"$BOOTSTARP_NODE
  MYSQL_PID=$(ssh $BOOTSTARP_NODE netstat -ntlp|grep 4567|awk '{print $7}'|awk -F "/" '{print $1}')
  ssh $BOOTSTARP_NODE /bin/bash << EOF
    kill -9 $MYSQL_PID
    mv /var/lib/mysql/gvwstate.dat /var/lib/mysql/gvwstate.dat.bak
    galera_new_cluster
EOF
  for i in $@;
  do
    if [ "$i" = $BOOTSTARP_NODE ];then
      echo "[INFO] $i's mariadb service status:"$(ssh $i systemctl status mariadb |grep Active:)
    else
      echo "[INFO] $i start service:"
      ssh "$i" systemctl start mariadb
    fi
  done
else
  echo "[ERROR] Recover Galera Cluster is error!"
  exit 127
fi
### 3. Check Galera Status
sleep 5
WSREP_CLUSTER_SIZE=$(mysql -uroot -p$password_galera_root -e "SHOW STATUS LIKE 'wsrep_cluster_size';"|grep wsrep_cluster_size|awk '{print $2}')
echo "[INFO] Galera cluster CLUSTER_SIZE:"$WSREP_CLUSTER_SIZE
if [ "${WSREP_CLUSTER_SIZE}" = "3" ]; then
  echo "[INFO] Galera Cluster is OK!"
  exit 0
elif [ "$WSREP_CLUSTER_SIZE" = "2"  ];then
  echo "[INFO] One MariaDB nodes is down!"
  exit 2
elif [ "$WSREP_CLUSTER_SIZE" = "1"  ];then
  echo "[INFO] Two MariaDB nodes is down!"
  exit 1
else
  echo "[INFO] All MariaDB nodes is down!"
  exit 3
fi
