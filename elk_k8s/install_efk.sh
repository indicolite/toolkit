#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 master-ip node-ip"
    exit 0
fi

echo "make sure you have java installed!!!"
echo $1" "" in master node to install elasticsearch and kibana: "
    wget https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/rpm/elasticsearch/2.3.5/elasticsearch-2.3.5.rpm
    yum localinstall elasticsearch-2.3.5.rpm
    #vim /etc/elasticsearch/elasticsearch.yml
    ELK1="network.host: "
    sed -i '/network.host/d' /etc/elasticsearch/elasticsearch.yml
    echo ${ELK1}${1} >> /etc/elasticsearch/elasticsearch.yml

    systemctl enable elasticsearch.service
    systemctl restart elasticsearch.service
    systemctl status elasticsearch.service

    wget https://download.elastic.co/kibana/kibana/kibana-4.5.4-1.x86_64.rpm
    yum localinstall kibana-4.5.4-1.x86_64.rpm
    wget https://download.elastic.co/beats/filebeat/filebeat-1.2.3-x86_64.rpm

    #vim /opt/kibana/config/kibana.yml
    #elasticsearch.url: "http://10.10.20.203:9200"
    ELK2="elasticsearch.url: \""
    ELK3="http://"
    ELK4=":9200\""
    sed -i '/elasticsearch.url/d' /opt/kibana/config/kibana.yml
    echo ${ELK2}${ELK3}${args}${ELK4} >> /opt/kibana/config/kibana.yml
    systemctl enable kibana.service
    systemctl restart kibana.service
    systemctl status kibana.service -l

echo $1" "" done."

for args in ${@:2}
do
    gzip -c filebeat-1.2.3-x86_64.rpm |ssh root@${args} "gunzip -c - > /tmp/filebeat-1.2.3-x86_64.rpm"
    #wget https://download.elastic.co/beats/filebeat/filebeat-1.2.3-x86_64.rpm
    ssh root@${args} "cd /tmp && yum localinstall filebeat-1.2.3-x86_64.rpm"
    #vim /etc/filebeat/filebeat.yml

cat > /etc/filebeat/filebeat.yml <<EOF
filebeat:
  prospectors:
    -
      paths:
        - /var/log/messages
      input_type: log
      document_type: syslog
    -
      paths:
        - /var/lib/docker/containers/*/*.json
      input_type: log
      document_type: containerlog
  registry_file: /var/lib/filebeat/registry

output:
  elasticsearch:
    hosts: ["0.0.0.0:9200"]
    index: "filebeat"
EOF
    sed -i "s/0.0.0.0/${1}/" /etc/filebeat/filebeat.yml
    gzip -c /etc/filebeat/filebeat.yml |ssh root@${args} "gunzip -c - > /etc/filebeat/filebeat.yml"
    ssh root@${args} "systemctl enable filebeat"
    ssh root@${args} "systemctl restart filebeat"
    ssh root@${args} "systemctl status filebeat -l"
done
