## prerequisite
1. For **master**, make sure to deploy: docker|etcd|flannel|kube-apiserver|kube-controller-manager|kube-scheduler|elsticsearch|kibana
2. For **node**, make sure to deploy: docker|flannel|kubelet|kube-proxy|filebeat

## elsticsearch
1. wget [elasticsearch-2.3.5.rpm](https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/rpm/elasticsearch/2.3.5/elasticsearch-2.3.5.rpm)
2. yum localinstall elasticsearch-2.3.5.rpm
3. vim /etc/elasticsearch/elasticsearch.yml
```
    network.host: **master**
```
4. restart elasticsearch.service
```
    systemctl enable elasticsearch.service
    systemctl restart elasticsearch.service
    systemctl status elasticsearch.service
```

## kibana
1. wget [kibana-4.5.4-1.x86_64.rpm](https://download.elastic.co/kibana/kibana/kibana-4.5.4-1.x86_64.rpm)
2. yum localinstall kibana-4.5.4-1.x86_64.rpm
3. vim /opt/kibana/config/kibana.yml
```
    elasticsearch.url: "http://master:9200"
```
4. restart kibana.service
```
    systemctl enable kibana.service
    systemctl restart kibana.service
    systemctl status kibana.service -l
```

## filebeat
1. wget [filebeat-1.2.3-x86_64.rpm](https://download.elastic.co/beats/filebeat/filebeat-1.2.3-x86_64.rpm)
2. yum localinstall filebeat-1.2.3-x86_64.rpm
3. vim /etc/filebeat/filebeat.yml
```
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
    hosts: ["**master**:9200"]
    index: "filebeat"
```
4. restart filebeat
systemctl enable filebeat
systemctl restart filebeat
systemctl status filebeat -l
5. visit http://**master**:5601/, create new index: filebeat-*, and see results
