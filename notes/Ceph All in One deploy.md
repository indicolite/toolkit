[TOC]

# [CentOS] Ceph All in One deploy:

## 准备工作
### 修改hostname
   修改/etc/hostname文件的信息为centos44
### 修改hosts文件
   修改/etc/hosts文件的信息为
   ```
   127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 centos44
   ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
   192.168.51.44 centos44
   ```
### reboot系统

## 安装ceph
### 建立一个目录，用于搭建ceph集群
$ mkdir my-cluster
$ cd my-cluster

### 如果之前有安装过ceph，需要做如下的清理操作：
```
$ ceph-deploy purge centos44
$ ceph-deploy purgedata centos44
$ ceph-deploy forgetkeys
$ rm ceph.*
```

### 初始化一个ceph集群，操作位置在my-cluster下面，操作完毕后会生成ceph.conf的配置文件
```
$ ceph-deploy new centos44
```

### 编辑ceph.conf文件，添加如下配置
```
public network = 192.168.51.0/24
osd max object name len = 256
osd max object namespace len = 64
osd_pool_default_size = 2
osd_pool_default_min_size = 1
osd crush chooseleaf type = 0
```

### 安装ceph相关的包
```
$ ceph-deploy install centos44 --no-adjust-repos
```

### 初始化ceph的monitor节点，操作完毕会出现如下的keyring文件
```
ceph-deploy mon create-initial
- ceph.client.admin.keyring
- ceph.bootstrap-mgr.keyring
- ceph.bootstrap-osd.keyring
- ceph.bootstrap-mds.keyring
- ceph.bootstrap-rgw.keyring
- ceph.bootstrap-rbd.keyring
```

### keyring和配置文件的拷贝
```
$ ceph-deploy admin centos44
```

### 初始化OSD
```
$ ceph-deploy osd prepare centos44:/dev/sdb
$ ceph-deploy osd prepare centos44:/dev/sdc
$ ceph-deploy osd prepare centos44:/dev/sdd
```

### 激活OSD
```
$ ceph-deploy osd activate centos44:/dev/sdb1
$ ceph-deploy osd activate centos44:/dev/sdc1
$ ceph-deploy osd activate centos44:/dev/sdd1
```

### Ceph环境就搭建完成了
### 验证：
```
$ ceph -s
    cluster efeb4e60-0bd6-4fb0-9dcf-9a217a5f3c4f
     health HEALTH_OK
     monmap e1: 1 mons at {centos44=192.168.51.44:6789/0}
            election epoch 3, quorum 0 centos44
     osdmap e17: 3 osds: 3 up, 3 in
            flags sortbitwise,require_jewel_osds
      pgmap v60: 192 pgs, 2 pools, 0 bytes data, 0 objects
            103 MB used, 45943 MB / 46046 MB avail
                 192 active+clean
```

## 创建挂载的卷
```
$ ceph osd pool create volumes 64 64 replicated
pool 'volumes' created

$ ceph osd lspools
0 rbd,1 libvirt-pool,2 volumes,

$ rbd create volumes/volume01 -s 1G

$ rbd ls volumes
volume01

$ rbd create volumes/volume02 -s 1G

$ rbd ls volumes
volume01， volume02

$ rbd create volumes/volume03 -s 1G

$ rbd ls volumes
volume01，volume02，volume03
```


## 获取认证并编辑xml
### touch secret.xml文件并编辑
```
<secret ephemeral='no' private='no'>
              <usage type='ceph'>
                    <name>client.cinder secret</name>
              </usage>
</secret>
```
```
$ sudo virsh secret-define --file secret.xml
<uuid of secret is output here>
```
```
$ ceph auth get-key client.cinder | sudo tee client.cinder.key
```
```
$ sudo virsh secret-set-value --secret {uuid of secret} --base64 $(cat client.cinder.key) && rm client.cinder.key secret.xml
```
生成的uuid，如0a7ed5ef-e060-491d-b9f6-d47237d34015， 将uuid添加到设备的xml文件上

如下volume1.xml中的uuid
```
<disk type='network' device='disk'>
       <auth username='admin'>
                        <secret type='ceph' uuid='0a7ed5ef-e060-491d-b9f6-d47237d34015'/>
            </auth>
            <source protocol='rbd' name='volumes/volume01'>
                        <host name='192.168.2.207' port='6789'/>
            </source>
            <target dev='vdb' bus='virtio'/>
            <shareable/>
</disk>
```

如下volume2.xml中的uuid
```
<disk type='network' device='disk'>
       <auth username='admin'>
                        <secret type='ceph' uuid='0a7ed5ef-e060-491d-b9f6-d47237d34015'/>
            </auth>
            <source protocol='rbd' name='volumes/volume02'>
                        <host name='192.168.2.207' port='6789'/>
            </source>
            <target dev='vdb' bus='virtio'/>
            <shareable/>
</disk>
```

如下volume3.xml中的uuid
```
<disk type='network' device='disk'>
       <auth username='admin'>
                        <secret type='ceph' uuid='0a7ed5ef-e060-491d-b9f6-d47237d34015'/>
            </auth>
            <source protocol='rbd' name='volumes/volume03'>
                        <host name='192.168.2.207' port='6789'/>
            </source>
            <target dev='vdb' bus='virtio'/>
            <shareable/>
</disk>
```
