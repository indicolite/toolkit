kubectl create -f es-deployment.yaml
kubectl create -f es-service.yaml
kubectl create -f kibana-deployment.yaml
kubectl create -f kibana-service.yaml
kubectl create -f logstash-config.yaml
kubectl create -f logstash-deployment.yaml
kubectl create -f logstash-service.yaml
