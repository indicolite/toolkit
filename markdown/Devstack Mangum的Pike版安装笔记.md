[TOC]

# magnum安装

安装条件：

- 尽量干净的操作系统环境。
- 至少要10G以上内存的机器。
- 硬盘至少50G。
- 良好的上网环境（挂代理）。

操作步骤参见[快速入门](http://docs.openstack.org/developer/magnum/dev/dev-quickstart.html)

以下是操作的步骤记录。

```
sudo mkdir -p /opt/stack
sudo chown $USER /opt/stack

git clone https://git.openstack.org/openstack-dev/devstack /opt/stack/devstack

```

我的 local.conf 样例。

```
[[local|localrc]]
# Modify the  enviroment info
HOST_IP=10.127.3.6

# Define images to be automatically downloaded during the DevStack built process, especially used by Manila.
DOWNLOAD_DEFAULT_IMAGES=False
IMAGE_URLS="http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img"


# Work offline
# OFFLINE=True
#
# Reclone each time
RECLONE=False

#change github to trystack
GIT_BASE=http://git.trystack.cn
NOVNC_REPO=http://git.trystack.cn/kanaka/noVNC.git
SPICE_REPO=http://git.trystack.cn/git/spice/spice-html5.git

HORIZON_BRANCH=stable/pike
KEYSTONE_BRANCH=stable/pike
NOVA_BRANCH=stable/pike
NEUTRON_BRANCH=stable/pike
GLANCE_BRANCH=stable/pike
CINDER_BRANCH=stable/pike

# Credentials
DATABASE_PASSWORD=pass
ADMIN_PASSWORD=pass
SERVICE_PASSWORD=pass
SERVICE_TOKEN=pass
RABBIT_PASSWORD=pass

# Pre-requisite
enable_service rabbit
enable_service mysql
enable_service key

# Heat
enable_plugin heat http://git.trystack.cn/openstack/heat stable/pike
enable_service h-api h-api-cfn h-eng h-api-cw


## Swift
# SWIFT_BRANCH=stable/mitaka
#ENABLED_SERVICES+=,s-proxy,s-object,s-container,s-account
#SWIFT_REPLICAS=1
#SWIFT_HASH=011688b44136573e209e

#Ensure we are using neutorn netowrk rather than nova network 
disable_service n-net
enable_service neutron q-svc q-agt q-dhcp q-l3 q-meta

## Neutron options
PUBLIC_INTERFACE=eth2
PUBLIC_NETWORK_GATEWAY=192.168.17.6
FLOATING_RANGE=192.168.17.0/24
#FIXED_RANGE=172.18.1.0/24
Q_FLOATING_ALLOCATION_POOL=start=192.168.17.230,end=192.168.17.250
Q_USE_SECGROUP=True
Q_USE_PROVIDERNET_FOR_PUBLIC=True
PHYSICAL_NETWORK=br-ex
OVS_PHYSICAL_BRIDGE=br-ex
OVS_BRIDGE_MAPPINGS=public:br-ex


# VLAN configuration.
Q_PLUGIN=ml2
ENABLE_TENANT_VLANS=True

enable_plugin neutron-lbaas http://git.trystack.cn/openstack/neutron-lbaas stable/pike
enable_plugin neutron-lbaas-dashboard http://git.trystack.cn/openstack/neutron-lbaas-dashboard  stable/pike 
NEUTRON_LBAAS_SERVICE_PROVIDERV2="LOADBALANCERV2:Haproxy:neutron_lbaas.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default"
enable_service q-lbaasv2


# Ceph
#ENABLED_SERVICES+=,ceph
#enable_plugin ceph https://github.com/openstack/devstack-plugin-ceph
#CEPH_LOOPBACK_DISK_SIZE=10G
#CEPH_CONF=/etc/ceph/ceph.conf
#CEPH_REPLICAS=1

# Glance - Image Service
#GLANCE_CEPH_USER=glance
#GLANCE_CEPH_POOL=glance-pool
#
# Cinder - Block Device Service
#CINDER_DRIVER=ceph
#CINDER_CEPH_USER=cinder
#CINDER_CEPH_POOL=cinder-pool
#CINDER_CEPH_UUID=1b1519e4-5ecd-11e5-8559-080027f18a73
#CINDER_BAK_CEPH_POOL=cinder-backups
#CINDER_BAK_CEPH_USER=cinder-backups
#CINDER_ENABLED_BACKENDS=ceph
#CINDER_ENABLED_BACKENDS=ceph
#
# Nova - Compute Service
#NOVA_CEPH_POOL=nova-pool


# Enable barbican service
# enable_plugin barbican https://git.openstack.org/openstack/barbican

# Logging
# -------
# By default ``stack.sh`` output only goes to the terminal where it runs. It can
# be configured to additionally log to a file by setting ``LOGFILE`` to the full
# path of the destination log file. A timestamp will be appended to the given name.
LOGFILE=${DEST}/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
LOGDAYS=1
#SCREEN_LOGDIR=/opt/stack/logs
LOGDIR=${DEST}/logs
use_syslog=True

#enable_plugin manila https://github.com/openstack/manila
#LIBS_FROM_GIT="python-manilaclient"

#enable_plugin manila https://github.com/openstack/manila
#enable_plugin manila-ui https://github.com/openstack/manila-ui

#enable_plugin mistral https://github.com/openstack/mistral
enable_plugin barbican http://git.trystack.cn/openstack/barbican stable/pike 
enable_plugin python-barbicanclient http://git.trystack.cn/openstack/python-barbicanclient stable/pike

enable_plugin magnum http://git.trystack.cn/openstack/magnum  stable/pike
enable_plugin python-magnumclient http://git.trystack.cn/openstack/python-magnumclient stable/pike
enable_plugin magnum-ui http://git.trystack.cn/openstack/magnum-ui stable/pike
enable_service magnum-api
enable_service magnum-cond

VOLUME_BACKING_FILE_SIZE=5G

disable_service tempest

```

或许能够参考的操作记录。

```
  375  cd magnum/magnum/drivers/common/templates/kubernetes/fragments/
  376  ll
  377  vim configure-kubernetes-master.sh 
  378  sed -i "s/10.127.2.8/10.121.5.59" configure-kubernetes-master.sh
  379  sed -i "s/10.127.2.8/10.121.5.59/g" configure-kubernetes-master.sh
  380  sed -i "s/10.127.2.8/10.121.5.59/g" configure-kubernetes-minion.sh
  381  cd ~
  382  cd magnum
  383  cd magnum/drivers/k8s_fedora_atomic_v1/templates/kubecluster.yaml
  384  vim  magnum/drivers/k8s_fedora_atomic_v1/templates/kubecluster.yaml
  385  cd magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-master.sh
  386  vim  magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-master.sh
  387  sed -i "s/10.121.2.8/10.121.5.59/g" configure-kubernetes-master.sh
  388  cd magnum/drivers/common/templates/kubernetes/fragments/
  389  sed -i "s/10.121.2.8/10.121.5.59/g" configure-kubernetes-master.sh
  390  sed -i "s/10.121.2.8/10.121.5.59/g" configure-kubernetes-minion.sh

```

执行安装。由于网络问题，经常下包失败，所以失败时候手动安装部分包或者重新执行 stack.sh。

```
cd /opt/stack/devstack
./stack.sh

```

配置执行 magnum。

```
[stack@3-6-master magnum]$ git branch -a
* stable/pike
  remotes/origin/HEAD -> origin/master
  remotes/origin/master
  remotes/origin/stable/ocata
  remotes/origin/stable/pike
[stack@3-6-master magnum]$ git diff >01.patch
[stack@3-6-master magnum]$ cat 01.patch 
diff --git a/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-master.sh b/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-master.sh
index bc7d077..287f744 100644
--- a/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-master.sh
+++ b/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-master.sh
@@ -4,11 +4,11 @@
 
 echo "configuring kubernetes (master)"
 
-atomic install --storage ostree --system --system-package=no --name=kubelet docker.io/openstackmagnum/kubernetes-kubelet:${KUBE_TAG}
-atomic install --storage ostree --system --system-package=no --name=kube-proxy docker.io/openstackmagnum/kubernetes-proxy:${KUBE_TAG}
-atomic install --storage ostree --system --system-package=no --name=kube-apiserver docker.io/openstackmagnum/kubernetes-apiserver:${KUBE_TAG}
-atomic install --storage ostree --system --system-package=no --name=kube-controller-manager docker.io/openstackmagnum/kubernetes-controller-manager:${KUBE_TAG}
-atomic install --storage ostree --system --system-package=no --name=kube-scheduler docker.io/openstackmagnum/kubernetes-scheduler:${KUBE_TAG}
+atomic install --storage ostree --system --system-package=no --name=kubelet 10.121.5.59:5000/openstackmagnum/kubernetes-kubelet:${KUBE_TAG}-mod
+atomic install --storage ostree --system --system-package=no --name=kube-proxy 10.121.5.59:5000/openstackmagnum/kubernetes-proxy:${KUBE_TAG}
+atomic install --storage ostree --system --system-package=no --name=kube-apiserver 10.121.5.59:5000/openstackmagnum/kubernetes-apiserver:${KUBE_TAG}
+atomic install --storage ostree --system --system-package=no --name=kube-controller-manager 10.121.5.59:5000/openstackmagnum/kubernetes-controller-manager:${KUBE_TAG}-mod
+atomic install --storage ostree --system --system-package=no --name=kube-scheduler 10.121.5.59:5000/openstackmagnum/kubernetes-scheduler:${KUBE_TAG}
 
 sed -i '
     /^KUBE_ALLOW_PRIV=/ s/=.*/="--allow-privileged='"$KUBE_ALLOW_PRIV"'"/
diff --git a/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-minion.sh b/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-minion.sh
index 861cdec..1c15992 100644
--- a/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-minion.sh
+++ b/magnum/drivers/common/templates/kubernetes/fragments/configure-kubernetes-minion.sh
@@ -4,8 +4,8 @@
 
 echo "configuring kubernetes (minion)"
 
-atomic install --storage ostree --system --system-package=no --name=kubelet docker.io/openstackmagnum/kubernetes-kubelet:${KUBE_TAG}
-atomic install --storage ostree --system --system-package=no --name=kube-proxy docker.io/openstackmagnum/kubernetes-proxy:${KUBE_TAG}
+atomic install --storage ostree --system --system-package=no --name=kubelet 10.121.5.59:5000/openstackmagnum/kubernetes-kubelet:${KUBE_TAG}-mod
+atomic install --storage ostree --system --system-package=no --name=kube-proxy 10.121.5.59:5000/openstackmagnum/kubernetes-proxy:${KUBE_TAG}
 
 CERT_DIR=/etc/kubernetes/certs
 PROTOCOL=https
diff --git a/magnum/drivers/k8s_fedora_atomic_v1/templates/kubecluster.yaml b/magnum/drivers/k8s_fedora_atomic_v1/templates/kubecluster.yaml
index 4c47ab4..73ba376 100644
--- a/magnum/drivers/k8s_fedora_atomic_v1/templates/kubecluster.yaml
+++ b/magnum/drivers/k8s_fedora_atomic_v1/templates/kubecluster.yaml
@@ -326,7 +326,7 @@ parameters:
   insecure_registry_url:
     type: string
     description: insecure registry url
-    default: ""
+    default: 10.121.5.59:5000
 
   dns_service_ip:
     type: string

```

修改过的 magnum.conf。

```
[stack@3-6-master magnum]$ cat /etc/magnum/magnum.conf 

[DEFAULT]
logging_exception_prefix = %(color)s%(asctime)s.%(msecs)03d TRACE %(name)s %(instance)s
logging_debug_format_suffix = from (pid=%(process)d) %(funcName)s %(pathname)s:%(lineno)d
logging_default_format_string = %(asctime)s.%(msecs)03d %(color)s%(levelname)s %(name)s [-%(color)s] %(instance)s%(color)s%(message)s
logging_context_format_string = %(asctime)s.%(msecs)03d %(color)s%(levelname)s %(name)s [%(request_id)s %(project_name)s %(user_name)s%(color)s] %(instance)s%(color)s%(message)s
state_path = /home/stack/data/magnum
bindir = /usr/bin
host = 3-6-master
transport_url = rabbit://stackrabbit:pass@10.127.3.6
debug = True

[database]
connection = mysql+pymysql://root:pass@127.0.0.1/magnum?charset=utf8

[cluster]
etcd_discovery_service_endpoint_format=http://10.121.5.59:8087/new?size=%(size)d


[api]
port = 9511
host = 10.127.3.6

[oslo_policy]
policy_file = /etc/magnum/policy.json

[keystone_auth]
auth_url = http://10.127.3.6/identity/v3
user_domain_id = default
project_domain_id = default
project_name = service
password = pass
username = magnum
auth_type = password

[keystone_authtoken]
auth_version = v3
auth_uri = http://10.127.3.6/identity/v3
memcached_servers = 10.127.3.6:11211
signing_dir = /var/cache/magnum
cafile = /home/stack/data/ca-bundle.pem
project_domain_name = Default
project_name = service
user_domain_name = Default
password = pass
username = magnum
auth_url = http://10.127.3.6/identity/v3
auth_type = password
admin_tenant_name = service
admin_password = pass
admin_user = magnum

[oslo_concurrency]
lock_path = /home/stack/data/magnum

[certificates]
cert_manager_type = barbican

[trust]
trustee_keystone_interface = public
trustee_domain_admin_password = secret
trustee_domain_admin_name = trustee_domain_admin
trustee_domain_name = magnum
cluster_user_trust = True

[cinder_client]
region_name = RegionOne

[cinder]
default_docker_volume_type = lvmdriver-1
```

所有都正常的话，你可以看到运行结果打印日志如下。

```
2017-11-16 02:56:22.013 |     ' /home/stack/devstack/local.conf

=========================
DevStack Component Timing
=========================
Total runtime    1120

run_process       22
test_with_retry    3
pip_install      262
osc              279
wait_for_service  25
yum_install       78
dbsync            15
=========================



This is your host IP address: 10.127.3.6
This is your host IPv6 address: ::1
Horizon is now available at http://10.127.3.6/dashboard
Keystone is serving at http://10.127.3.6/identity/
The default users are: admin and demo
The password: pass

WARNING: 
Using lib/neutron-legacy is deprecated, and it will be removed in the future


Services are running under systemd unit files.
For more information see: 
https://docs.openstack.org/devstack/latest/systemd.html

DevStack Version: pike
Change: a5c77a91b9bf0e2408aff58c0de9eab9a94ba391 Calculate package directory correctly in pip_install 2017-10-31 15:03:48 +0000
OS Version: CentOS 7.2.1511 Core
```

# 运行magnum


## 创建秘钥

```
stack@magnum:~/devstack$ nova keypair-add magnum

```

## 创建 cluster-model

```
magnum cluster-template-create k8s-cluster-template-4 \
    --public \
    --image Fedora-Atomic-26-20170723.0.x86_64 \
	--keypair testkey \
	--external-network public \
	--dns-nameserver 10.19.8.10 \
	--flavor ds1G \
	--master-flavor ds1G \
	--coe kubernetes \
	--volume-driver cinder

```

## 创建 cluster

```
magnum cluster-create k8s-cluster-2 \
    --cluster-template k8s-cluster-template \
    --node-count 1 \
    --keypair bingo \
    --master-count 1

```

## 查看 cluster

```
[stack@3-6-master ~]$ magnum cluster-list
+--------------------------------------+-------------+---------+------------+--------------+-----------------+
| uuid                                 | name        | keypair | node_count | master_count | status          |
+--------------------------------------+-------------+---------+------------+--------------+-----------------+
| b39a5b50-8402-4c92-abdd-1074a98377a9 | k8s-cluster | magnum  | 2          | 1            | CREATE_COMPLETE |
+--------------------------------------+-------------+---------+------------+--------------+-----------------+
[stack@3-6-master ~]$ openstack server list
+--------------------------------------+-----------------------------------+--------+------------------------------------------------------------------------+------------------------------------+--------+
| ID                                   | Name                              | Status | Networks                                                               | Image                              | Flavor |
+--------------------------------------+-----------------------------------+--------+------------------------------------------------------------------------+------------------------------------+--------+
| 23480dd9-adad-4ab8-88dd-f3d2a5d75db1 | k8s-cluster-2ahzncrpv3mw-minion-1 | ACTIVE | private=10.0.0.6, 192.168.17.231                                       | Fedora-Atomic-26-20170723.0.x86_64 | ds1G   |
| ea7d4a19-c023-44cf-a73e-0fa43be83c54 | k8s-cluster-2ahzncrpv3mw-minion-0 | ACTIVE | private=10.0.0.13, 192.168.17.241                                      | Fedora-Atomic-26-20170723.0.x86_64 | ds1G   |
| bae838f9-2e39-4eb6-8b38-1d3f54647602 | k8s-cluster-2ahzncrpv3mw-master-0 | ACTIVE | private=10.0.0.7, 192.168.17.230                                       | Fedora-Atomic-26-20170723.0.x86_64 | ds1G   |
| c0ca256c-9a00-47b1-ba65-7ac53239ab28 | localserver                       | ACTIVE | private=10.0.0.5, fd75:a0b0:e969:0:f816:3eff:fe81:91a2, 192.168.17.240 | Fedora-Atomic-26-20170723.0.x86_64 | ds1G   |
+--------------------------------------+-----------------------------------+--------+------------------------------------------------------------------------+------------------------------------+--------+


```


# Troubleshooting

## 涉及到的服务

如果做了某些更改，可能需要单独重启服务。比如 **systemctl restart devstack@magnum-api.service**。

```
devstack@c-api.service
devstack@c-sch.service
devstack@c-vol.service
devstack@dstat.service
devstack@g-api.service
devstack@g-reg.service
devstack@keystone.service
devstack@magnum-api.service
devstack@magnum-cond.service
devstack@n-api-meta.service
devstack@n-api.service
devstack@n-cauth.service
devstack@n-cond-cell1.service
devstack@n-cpu.service
devstack@n-novnc.service
devstack@n-sch.service
devstack@n-super-cond.service
devstack@o-api.service
devstack@o-cw.service
devstack@o-hk.service
devstack@o-hm.service
devstack@placement-api.service
devstack@q-agt.service
devstack@q-dhcp.service
devstack@q-l3.service
devstack@q-lbaasv2.service
devstack@q-meta.service
devstack@q-svc.service
```

## 遇到的奇奇怪怪的报错

```
BadRequest: resources[0].resources.kube-master: User data too large. User data must be no larger than 65535 bytes once base64 encoded. Your data is 66416 bytes (HTTP 400) (Request-ID: req-6695732d-be28-4ed3-9305-3f2b78662f72)', 'kube_masters': 'BadRequest: resources.kube_masters.resources[0].resources.kube-master: User data too large. User data must be no larger than 65535 bytes once base64 encoded. Your data is 66416 bytes (HTTP 400) (Request-ID: req-6695732d-be28-4ed3-9305-3f2b78662f72)', 'kube-master': 'BadRequest: resources.kube-master: User data too large. User data must be no larger than 65535 bytes once base64 encoded. Your data is 66416 bytes (HTTP 400) (Request-ID: req-6695732d-be28-4ed3-9305-3f2b78662f72)
```
遇到这种，改了默认的包大小 **MAX_USERDATA_SIZE**，然后重启了 n-api.service。
```
LOG = logging.getLogger(__name__)

get_notifier = functools.partial(rpc.get_notifier, service='compute')
# NOTE(gibi): legacy notification used compute as a service but these
# calls still run on the client side of the compute service which is
# nova-api. By setting the binary to nova-api below, we can make sure
# that the new versioned notifications has the right publisher_id but the
# legacy notifications does not change.
wrap_exception = functools.partial(exception_wrapper.wrap_exception,
                                   get_notifier=get_notifier,
                                   binary='nova-api')
CONF = nova.conf.CONF

MAX_USERDATA_SIZE = 165535
RO_SECURITY_GROUPS = ['default']

AGGREGATE_ACTION_UPDATE = 'Update'
AGGREGATE_ACTION_UPDATE_META = 'UpdateMeta'
AGGREGATE_ACTION_DELETE = 'Delete'
AGGREGATE_ACTION_ADD = 'Add'
BFV_RESERVE_MIN_COMPUTE_VERSION = 17

# FIXME(danms): Keep a global cache of the cells we find the
# first time we look. This needs to be refreshed on a timer or
# trigger.
CELLS = []

"~/nova/nova/compute/api.py" 5308L, 243143C   
```

## 剩下的一堆报错

```
2017-11-08 07:28:16.594 | +functions-common:restart_service:2393     '[' -x /bin/systemctl ']'
2017-11-08 07:28:16.597 | +functions-common:restart_service:2394     sudo /bin/systemctl restart rabbitmq-server
2017-11-08 07:28:20.472 | Job for rabbitmq-server.service failed because the control process exited with error code. See "systemctl status rabbitmq-server.service" and "journalctl -xe" for details.
2017-11-08 07:28:20.478 | +functions-common:restart_service:1        exit_trap


rabbitmq-server
[root@ccicd1 yum.repos.d]# lsof -i:4369
COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
systemd     1 root   56u  IPv4  33091      0t0  TCP *:epmd (LISTEN)
epmd    25095 epmd    3u  IPv4  33091      0t0  TCP *:epmd (LISTEN)
[root@ccicd1 yum.repos.d]# ps aux|grep epmd
epmd     25095  0.0  0.0  33060   972 ?        Ss   14:18   0:00 /usr/bin/epmd -systemd
root     32084  0.0  0.0 112668   976 pts/1    S+   15:29   0:00 grep --color=auto epmd
[root@ccicd1 yum.repos.d]# kill -9 25095
[root@ccicd1 yum.repos.d]# ps aux|grep epmd
epmd     32090  0.0  0.0  33060   976 ?        Ss   15:29   0:00 /usr/bin/epmd -systemd
root     32092  0.0  0.0 112668   976 pts/1    S+   15:29   0:00 grep --color=auto epmd
[root@ccicd1 yum.repos.d]# systemctl stop epmd
[root@ccicd1 yum.repos.d]# ps aux|grep epmd
epmd     32090  0.0  0.0  33060   976 ?        Ss   15:29   0:00 /usr/bin/epmd -systemd
root     32100  0.0  0.0 112668   972 pts/1    S+   15:29   0:00 grep --color=auto epmd
[root@ccicd1 yum.repos.d]# systemctl stop epmd@0.0.0.0.service 
Warning: Stopping epmd@0.0.0.0.service, but it can still be activated by:
  epmd@0.0.0.0.socket
[root@ccicd1 yum.repos.d]# systemctl stop epmd@0.0.0.0.socket 
[root@ccicd1 yum.repos.d]# ps aux|grep epmd
root     32174  0.0  0.0 112668   972 pts/1    S+   15:29   0:00 grep --color=auto epmd
[root@ccicd1 yum.repos.d]# 


rm  /var/lib/rabbitmq/*


2017-11-08 07:53:45.580 | --> Finished Dependency Resolution
2017-11-08 07:53:45.580 | Error: qemu-kvm-common conflicts with 10:qemu-kvm-common-ev-2.9.0-16.el7_4.5.1.x86_64
2017-11-08 07:53:45.580 | Error: qemu-kvm-common-ev conflicts with 10:qemu-kvm-common-1.5.3-141.el7_4.2.x86_64
2017-11-08 07:53:45.580 | Error: Package: 10:qemu-kvm-1.5.3-141.el7_4.2.x86_64 (updates)
2017-11-08 07:53:45.580 |            Requires: qemu-kvm-common = 10:1.5.3-141.el7_4.2
2017-11-08 07:53:45.580 |            Installed: 10:qemu-kvm-common-ev-2.9.0-16.el7_4.5.1.x86_64 (@rdo-qemu-ev)
2017-11-08 07:53:45.580 |                qemu-kvm-common = 10:2.9.0-16.el7_4.5.1
2017-11-08 07:53:45.580 |            Available: 10:qemu-kvm-common-1.5.3-141.el7.x86_64 (base)
2017-11-08 07:53:45.580 |                qemu-kvm-common = 10:1.5.3-141.el7
2017-11-08 07:53:45.580 |            Available: 10:qemu-kvm-common-1.5.3-141.el7_4.1.x86_64 (updates)
2017-11-08 07:53:45.580 |                qemu-kvm-common = 10:1.5.3-141.el7_4.1
2017-11-08 07:53:45.580 |  You could try using --skip-broken to work around the problem
2017-11-08 07:53:45.580 |  You could try running: rpm -Va --nofiles --nodigest






2017-11-08 08:00:57.835 | WARNING py.warnings [None req-59e0917c-7014-4f69-b9aa-f4ab60c465aa None None] /usr/lib/python2.7/site-packages/pycadf/identifier.py:80: UserWarning: Invalid uuid: RegionOne. To ensure interoperability, identifiers should be a valid uuid.
2017-11-08 08:00:57.835 |   'identifiers should be a valid uuid.' % (value)))
2017-11-08 08:00:57.835 | 
2017-11-08 08:00:57.838 | INFO keystone.cmd.cli [None req-59e0917c-7014-4f69-b9aa-f4ab60c465aa None None] Created region RegionOne
2017-11-08 08:00:57.859 | INFO keystone.cmd.cli [None req-59e0917c-7014-4f69-b9aa-f4ab60c465aa None None] Created admin endpoint https://10.127.2.8/identity
2017-11-08 08:00:57.865 | INFO keystone.cmd.cli [None req-59e0917c-7014-4f69-b9aa-f4ab60c465aa None None] Created public endpoint https://10.127.2.8/identity
2017-11-08 08:00:57.868 | INFO keystone.assignment.core [None req-59e0917c-7014-4f69-b9aa-f4ab60c465aa None None] Creating the default role 9fe2ff9ee4384b1894a90878d3e92bab because it does not exist.
2017-11-08 08:00:57.985 | +./stack.sh:main:1126                      create_keystone_accounts
2017-11-08 08:00:57.989 | +lib/keystone:create_keystone_accounts:331  local admin_project
2017-11-08 08:00:57.994 | ++lib/keystone:create_keystone_accounts:332  oscwrap project show admin -f value -c id
2017-11-08 08:00:57.999 | ++functions-common:oscwrap:2530             local out
2017-11-08 08:00:58.003 | ++functions-common:oscwrap:2531             local rc
2017-11-08 08:00:58.008 | ++functions-common:oscwrap:2532             local start
2017-11-08 08:00:58.012 | ++functions-common:oscwrap:2533             local end
2017-11-08 08:00:58.017 | +++functions-common:oscwrap:2537             date +%s%3N
2017-11-08 08:00:58.023 | ++functions-common:oscwrap:2537             start=1510128058018
2017-11-08 08:00:58.028 | +++functions-common:oscwrap:2538             command openstack project show admin -f value -c id
2017-11-08 08:00:58.033 | +++functions-common:oscwrap:2538             openstack project show admin -f value -c id
2017-11-08 08:01:00.308 | Failed to discover available identity versions when contacting https://10.127.2.8/identity. Attempting to parse version from URL.
2017-11-08 08:01:00.308 | Could not determine a suitable URL for the plugin
2017-11-08 08:01:00.369 | ++functions-common:oscwrap:2538             out=
2017-11-08 08:01:00.373 | ++functions-common:oscwrap:2539             rc=1
2017-11-08 08:01:00.379 | +++functions-common:oscwrap:2540             date +%s%3N
2017-11-08 08:01:00.385 | ++functions-common:oscwrap:2540             end=1510128060380
2017-11-08 08:01:00.390 | ++functions-common:oscwrap:2541             echo 2362
2017-11-08 08:01:00.394 | ++functions-common:oscwrap:2543             echo ''
2017-11-08 08:01:00.399 | ++functions-common:oscwrap:2544             return 1
2017-11-08 08:01:00.403 | +lib/keystone:create_keystone_accounts:332  admin_project=
2017-11-08 08:01:00.408 | +lib/keystone:create_keystone_accounts:1   exit_trap


2017-11-08 08:23:46.234 | +functions-common:is_fedora:445            '[' CentOS = CentOS ']'
2017-11-08 08:23:46.238 | +lib/apache:install_apache_uwsgi:112       echo 'LoadModule proxy_uwsgi_module modules/mod_proxy_uwsgi.so'
2017-11-08 08:23:46.239 | +lib/apache:install_apache_uwsgi:113       sudo tee /etc/httpd/conf.modules.d/02-proxy-uwsgi.conf
2017-11-08 08:23:46.245 | tee: /etc/httpd/conf.modules.d/02-proxy-uwsgi.conf: No such file or directory
2017-11-08 08:23:46.245 | LoadModule proxy_uwsgi_module modules/mod_proxy_uwsgi.so
2017-11-08 08:23:46.251 | +lib/apache:install_apache_uwsgi:1         exit_trap
2017-11-08 08:23:46.256 | +./stack.sh:exit_trap:521                  local r=1
2017-11-08 08:23:46.261 | ++./stack.sh:exit_trap:522                  jobs -p
2017-11-08 08:23:46.266 | +./stack.sh:exit_trap:522                  jobs=


2017-11-08 08:41:34.869 | WARNING py.warnings [None req-8d6931fb-3546-4f2c-b4b4-fb940bf774d7 None None] /usr/lib/python2.7/site-packages/pycadf/identifier.py:80: UserWarning: Invalid uuid: RegionOne. To ensure interoperability, identifiers should be a valid uuid.
2017-11-08 08:41:34.869 |   'identifiers should be a valid uuid.' % (value)))
2017-11-08 08:41:34.869 | 
2017-11-08 08:41:34.872 | INFO keystone.cmd.cli [None req-8d6931fb-3546-4f2c-b4b4-fb940bf774d7 None None] Created region RegionOne
2017-11-08 08:41:34.891 | INFO keystone.cmd.cli [None req-8d6931fb-3546-4f2c-b4b4-fb940bf774d7 None None] Created admin endpoint https://10.127.2.8/identity
2017-11-08 08:41:34.896 | INFO keystone.cmd.cli [None req-8d6931fb-3546-4f2c-b4b4-fb940bf774d7 None None] Created public endpoint https://10.127.2.8/identity
2017-11-08 08:41:34.900 | INFO keystone.assignment.core [None req-8d6931fb-3546-4f2c-b4b4-fb940bf774d7 None None] Creating the default role 9fe2ff9ee4384b1894a90878d3e92bab because it does not exist.
2017-11-08 08:41:35.016 | +./stack.sh:main:1126                      create_keystone_accounts
2017-11-08 08:41:35.020 | +lib/keystone:create_keystone_accounts:331  local admin_project
2017-11-08 08:41:35.025 | ++lib/keystone:create_keystone_accounts:332  oscwrap project show admin -f value -c id
2017-11-08 08:41:35.030 | ++functions-common:oscwrap:2530             local out
2017-11-08 08:41:35.035 | ++functions-common:oscwrap:2531             local rc
2017-11-08 08:41:35.039 | ++functions-common:oscwrap:2532             local start
2017-11-08 08:41:35.044 | ++functions-common:oscwrap:2533             local end
2017-11-08 08:41:35.049 | +++functions-common:oscwrap:2537             date +%s%3N
2017-11-08 08:41:35.055 | ++functions-common:oscwrap:2537             start=1510130495050
2017-11-08 08:41:35.061 | +++functions-common:oscwrap:2538             command openstack project show admin -f value -c id
2017-11-08 08:41:35.065 | +++functions-common:oscwrap:2538             openstack project show admin -f value -c id
2017-11-08 08:41:36.997 | Failed to discover available identity versions when contacting https://10.127.2.8/identity. Attempting to parse version from URL.


[root@ccicd1 etc]# netstat -anp|grep httpd
tcp6       0      0 :::80                   :::*                    LISTEN      17605/httpd         
tcp6       0      0 :::443                  :::*                    LISTEN      17605/httpd         
tcp6       0      0 :::35357                :::*                    LISTEN      17605/httpd         
tcp6       0      0 :::5000                 :::*                    LISTEN      17605/httpd         
unix  2      [ ACC ]     STREAM     LISTENING     676520   17606/httpd          /run/httpd/cgisock.17605
unix  3      [ ]         STREAM     CONNECTED     676518   17605/httpd          
[root@ccicd1 etc]# service httpd stop
Redirecting to /bin/systemctl stop  httpd.service
[root@ccicd1 etc]# netstat -anp|grep httpd


2017-11-08 09:36:25.536 | +functions-common:die:186                  local exitcode=0
2017-11-08 09:36:25.540 | [Call Trace]
2017-11-08 09:36:25.540 | ./stack.sh:1122:start_keystone
2017-11-08 09:36:25.540 | /opt/stack/devstack/lib/keystone:567:die
2017-11-08 09:36:25.542 | [ERROR] /opt/stack/devstack/lib/keystone:567 keystone did not start
2017-11-08 09:36:26.545 | Error on exit

export no_proxy=127.0.0.1,10.127.2.8


2017-11-08 13:01:09.401 | * Closing connection 0
2017-11-08 13:01:09.401 | curl: (18) transfer closed with 572673 bytes remaining to read
2017-11-08 13:01:10.978 | 2017-11-08 21:01:10.977 INFO diskimage_builder.block_device.blockdevice [-] State already cleaned - no way to do anything here
2017-11-08 13:01:11.030 | Unmount /tmp/dib_build.6VlLcqE7/mnt/var/cache/apt/archives
2017-11-08 13:01:11.043 | Unmount /tmp/dib_build.6VlLcqE7/mnt/tmp/pip
2017-11-08 13:01:11.051 | Unmount /tmp/dib_build.6VlLcqE7/mnt/sys
2017-11-08 13:01:11.058 | Unmount /tmp/dib_build.6VlLcqE7/mnt/proc
2017-11-08 13:01:11.066 | Unmount /tmp/dib_build.6VlLcqE7/mnt/dev/pts
2017-11-08 13:01:11.073 | Unmount /tmp/dib_build.6VlLcqE7/mnt/dev
2017-11-08 13:01:11.398 | +/opt/stack/octavia/devstack/plugin.sh:build_octavia_worker_image:1  exit_trap


2017-11-08 13:27:34.269 | ++::                                        openstack --os-cloud devstack-admin --os-region RegionOne compute service list --host ccicd1 --service nova-compute -c ID -f value
2017-11-08 13:27:36.528 | +::                                        ID=
2017-11-08 13:27:36.531 | +::                                        [[ '' == '' ]]
2017-11-08 13:27:36.534 | +::                                        sleep 1
2017-11-08 13:27:37.260 | +functions:wait_for_compute:414            rval=124
2017-11-08 13:27:37.264 | +functions:wait_for_compute:421            time_stop wait_for_service
2017-11-08 13:27:37.268 | +functions-common:time_stop:2509           local name
2017-11-08 13:27:37.272 | +functions-common:time_stop:2510           local end_time
2017-11-08 13:27:37.277 | +functions-common:time_stop:2511           local elapsed_time
2017-11-08 13:27:37.281 | +functions-common:time_stop:2512           local total
2017-11-08 13:27:37.285 | +functions-common:time_stop:2513           local start_time
2017-11-08 13:27:37.290 | +functions-common:time_stop:2515           name=wait_for_service
2017-11-08 13:27:37.294 | +functions-common:time_stop:2516           start_time=1510147597239
2017-11-08 13:27:37.298 | +functions-common:time_stop:2518           [[ -z 1510147597239 ]]
2017-11-08 13:27:37.304 | ++functions-common:time_stop:2521           date +%s%3N
2017-11-08 13:27:37.309 | +functions-common:time_stop:2521           end_time=1510147657304
2017-11-08 13:27:37.313 | +functions-common:time_stop:2522           elapsed_time=60065
2017-11-08 13:27:37.317 | +functions-common:time_stop:2523           total=24258
2017-11-08 13:27:37.322 | +functions-common:time_stop:2525           _TIME_START[$name]=
2017-11-08 13:27:37.326 | +functions-common:time_stop:2526           _TIME_TOTAL[$name]=84323
2017-11-08 13:27:37.330 | +functions:wait_for_compute:423            [[ 124 != 0 ]]
2017-11-08 13:27:37.334 | +functions:wait_for_compute:424            echo 'Didn'\''t find service registered by hostname after 60 seconds'
2017-11-08 13:27:37.334 | Didn't find service registered by hostname after 60 seconds
2017-11-08 13:27:37.338 | +functions:wait_for_compute:425            openstack --os-cloud devstack-admin --os-region RegionOne compute service list
2017-11-08 13:27:39.548 | +----+------------------+--------+----------+---------+-------+----------------------------+
2017-11-08 13:27:39.548 | | ID | Binary           | Host   | Zone     | Status  | State | Updated At                 |
2017-11-08 13:27:39.548 | +----+------------------+--------+----------+---------+-------+----------------------------+
2017-11-08 13:27:39.548 | |  9 | nova-scheduler   | ccicd1 | internal | enabled | up    | 2017-11-08T13:27:31.000000 |
2017-11-08 13:27:39.548 | | 18 | nova-consoleauth | ccicd1 | internal | enabled | up    | 2017-11-08T13:27:34.000000 |
2017-11-08 13:27:39.548 | | 19 | nova-conductor   | ccicd1 | internal | enabled | up    | 2017-11-08T13:27:34.000000 |
2017-11-08 13:27:39.548 | |  1 | nova-conductor   | ccicd1 | internal | enabled | up    | 2017-11-08T13:27:35.000000 |
2017-11-08 13:27:39.548 | +----+------------------+--------+----------+---------+-------+----------------------------+
2017-11-08 13:27:39.610 | +functions:wait_for_compute:427            return 124
2017-11-08 13:27:39.616 | +lib/nova:is_nova_ready:1                  exit_trap
2017-11-08 13:27:39.621 | +./stack.sh:exit_trap:521                  local r=124
2017-11-08 13:27:39.626 | ++./stack.sh:exit_trap:522                  jobs -p


https://bugs.launchpad.net/devstack/+bug/1726260


2017-11-09 00:43:37.674 | ++functions-common:oscwrap:2544             return 1
2017-11-09 00:43:37.679 | +lib/neutron_plugins/services/l3:create_neutron_initial_network:210  NET_ID=
2017-11-09 00:43:37.682 | +lib/neutron_plugins/services/l3:create_neutron_initial_network:211  die_if_not_set 211 NET_ID 'Failure creating NET_ID for private a18b62c28b574825b1792aa89b06689c'
2017-11-09 00:43:37.686 | +functions-common:die_if_not_set:204       local exitcode=0
2017-11-09 00:43:37.708 | [Call Trace]
2017-11-09 00:43:37.708 | ./stack.sh:1352:create_neutron_initial_network
2017-11-09 00:43:37.708 | /opt/stack/devstack/lib/neutron_plugins/services/l3:211:die_if_not_set
2017-11-09 00:43:37.708 | /opt/stack/devstack/functions-common:211:die
2017-11-09 00:43:37.710 | [ERROR] /opt/stack/devstack/functions-common:211 Failure creating NET_ID for private a18b62c28b574825b1792aa89b06689c
2017-11-09 00:43:38.714 | Error on exit


2017-11-09 01:03:31.765 | +functions:upload_image:349                openstack --os-cloud=devstack-admin --os-region-name=RegionOne image create cirros-0.3.5-x86_64-disk --public --container-format=bare --disk-format qcow2
2017-11-09 01:03:34.595 | Error finding address for https://10.127.2.8/image/v2/images/fef36f6b-8bf5-4f69-aec6-554be578de01/file: [SSL: UNKNOWN_PROTOCOL] unknown protocol (_ssl.c:579)
2017-11-09 01:03:34.683 | +functions:upload_image:1                  exit_trap
2017-11-09 01:03:34.688 | +./stack.sh:exit_trap:521                  local r=1
2017-11-09 01:03:34.693 | ++./stack.sh:exit_trap:522                  jobs -p
2017-11-09 01:03:34.698 | +./stack.sh:exit_trap:522                  jobs=
2017-11-09 01:03:34.702 | +./stack.sh:exit_trap:525                  [[ -n '' ]]
2017-11-09 01:03:34.706 | +./stack.sh:exit_trap:531                  '[' -f /tmp/tmp.FWvr4M0OSa ']'
2017-11-09 01:03:34.710 | +./stack.sh:exit_trap:532                  rm /tmp/tmp.FWvr4M0OSa
2017-11-09 01:03:34.716 | +./stack.sh:exit_trap:536                  kill_spinner
2017-11-09 01:03:34.720 | +./stack.sh:kill_spinner:417               '[' '!' -z '' ']'
2017-11-09 01:03:34.725 | +./stack.sh:exit_trap:538                  [[ 1 -ne 0 ]]
2017-11-09 01:03:34.729 | +./stack.sh:exit_trap:539                  echo 'Error on exit'
2017-11-09 01:03:34.729 | Error on exit
2017-11-09 01:03:34.733 | +./stack.sh:exit_trap:540                  generate-subunit 1510188585 829 fail
2017-11-09 01:03:35.177 | +./stack.sh:exit_trap:541                  [[ -z /opt/stack/logs ]]
2017-11-09 01:03:35.181 | +./stack.sh:exit_trap:544                  /opt/stack/devstack/tools/worlddump.py -d /opt/stack/logs
2017-11-09 01:03:35.727 | +./stack.sh:exit_trap:550                  exit 1


File "/usr/lib/python2.7/site-packages/urllib3/util/__init__.py", line 4, in <module>
    from .request import make_headers
  File "/usr/lib/python2.7/site-packages/urllib3/util/request.py", line 5, in <module>
    from ..exceptions import UnrewindableBodyError
ImportError: cannot import name UnrewindableBodyError

pip uninstall urllib3
pip install urllib3
http://www.cnblogs.com/xueweihan/p/7185133.html
```

# 参考链接

https://bugzilla.redhat.com/show_bug.cgi?id=1306485
https://wenqingfu.me/2016/12/09/config-two-network-interfaces/
http://www.tk4479.net/Gane_Cheng/article/details/53538203
http://docs.openstack.org/developer/devstack/configuration.html
http://www.bkjia.com/yjs/974868.html
https://www.52os.net/articles/linux-kvm-install-virtual-machines.html
https://docs.openstack.org/magnum/ocata/troubleshooting-guide.html#heat-stacks
https://docs.hpcloud.com/hos-5.x/helion/operations/troubleshooting/ts_magnum.html
https://bugs.launchpad.net/magnum/+bug/1720816
http://blog.csdn.net/minxihou/article/details/51956460