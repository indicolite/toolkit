[TOC]


## Oracle RAC 简介
Oracle RAC 是一个具有共享缓存体系结构的集群数据库，它克服了传统的不共享和共享磁盘方法的限制，为所有业务应用程序提供了一种具有可伸缩性和可用性的数据库解决方案，它一般与 Oracle Clusterware 或第三方集群软件共同组成 Oracle 集群系统。
![text](http://wiki.jikexueyuan.com/project/oraclecluster/images/1.png)
RAC 是一个全共享式的体系架构，它的所有数据文件、控制文件、联机日志文件、参数文件等都必须存放在共享磁盘中，因为只有这样，集群所有节点才能访问到，RAC 支持多种存储方式，可以使用下面几种方式的任意一种：
- 裸设备
  也就是不经过文件系统，将数据直接写入磁盘中，这种方式的好处是磁盘I/O性能很高，适合写操作频繁的业务系统，但缺点也很明显：数据维护和备份不方便，备份只能通过dd命令或者基于块级别的备份设备来完成，这无疑增加了维护成本。Oracle 11gR2 以后，该种方式将不再被支持。
- 集群文件系统
  为了支持共享存储，Oracle 开发出了集群文件系统 OCFS，这个文件系统可用于 Windows、Linux 和 Solaris，已经发展到了 OCFS2，通过 OCFS2 文件系统，多个集群节点可以同时读写一个磁盘而不破坏数据，但对于大量读写的业务系统，性能不是很高。另外，Oracle RAC 也支持第三方的集群文件系统，例如 Redhat 的 GFS 等。
- 网络文件系统
- ASM
  Automated Storage Management，简称 ASM，是 Oracle 推荐的共享数据存储方式，它是 Oracle 10g 包含的一个特性。ASM 其实就是 RAW 方式存储数据，但是加入了数据管理功能，它通过将数据直接写入磁盘，避免了经过文件系统而产生的 I/O 消耗。因而，使用 ASM 可以很方便地管理共享数据，并提供异步 I/O 的性能。ASM 还可以通过分配 I/O 负载来优化性能，免除了手动调整 I/O 的需要。
- ACFS
  在 Oracle 11gR2 中引入了 ASM Cluster FileSystem，即 ACFS。它 是一个通用的 POSIX 标准的Clusterfile System，是 Oracle ASM 的一种应用。因为遵守 POSIX 标准，所以使用 ext3 或者其他文件系统的系统应用都可以使用 Oracle ACFS来管理。Oracle ACFS 扩展了 Oracle ASM 的架构，ACFS 可以维护除 database 之外的多种类型的文件。 比如 ORACLE ACFS 可以用来存储 BFILES，database trace files，可执行文件，report file，文本文件，甚至图片、视频和音频文件等通用的文件。 

## Oracle RAC 的特点
通过 RAC 数据库，可以构建一个高性能、高可靠的数据库集群系统，RAC 的优势在于：
- 可以实现多个节点间的负载均衡
  RAC 数据库集群可以根据设定的调度策略，在集群节点间实现负载均衡，因此，RAC 数据库每个节点都是工作的，同时也处于互相监控状态，当某个节点出现故障时，RAC 集群自动将失败节点从集群隔离，并将失败节点的请求自动转移到其它健康节点上，从而实现服务透明切换。
- 可以提供高可用服务
  这个是 Oracle Clusterware 实现的功能，通过 CRS 可以实现节点状态监控，故障透明转移，这保证了 Oracle 数据库可以对外不间断的提供服务。
- 通过横向扩展提高了并发连接数
  RAC 这个优点非常适合大型的联机事务系统中。
- 通过并行执行技术提高了事务响应时间
  这个是 RAC 集群的一大优势，通常用于数据分享系统中。
- 具有很好的扩展性
  在集群系统不能满足繁忙的业务系统时，RAC 数据库可以很方便的添加集群节点，且可以在线完成节点的添加，并自动加入集群系统，不存在宕机时间；同时在不需要某个集群节点时，删除节点也非常简单。

RAC 数据库也有一定的缺点：
- 与单机数据库相比，管理维护更复杂，并对维护人员要求更高
- 底层规划设计不好时，系统整体性能会较差，甚至不如单机系统的性能。
- 由于 RAC 集群系统需要多个节点，那么需要购买多台服务器，同时需要 Oracle 企业级版本数据库，这无形中也增加了软硬件成本。

## RAC 进程管理
RAC 数据库是由多个节点构成的，每个节点就是一个数据库实例，而每个实例都有自己的后台进程和内存结构，并且在 RAC 集群中，每个实例的后台进程和内存结构都是相同的，从整体上看起来，就像是一个单一数据库的镜像，但是，RAC 数据库在结构上与单实例库也有不同之处：
- RAC 数据库的每个实例至少拥有一个额外的重做线程（redo thread）
- RAC 数据库的每个实例都拥有自己的撤消表空间（undo tablespace）

很显然，这种机制是每个实例独立的使用自己的重做线程和撤消表空间，各自锁定自己修改的数据。  RAC 的这种设计方式，把多个实例的操作相对独立的分开。那么RAC数据库如何实现节点数据的一致性呢，其实每个 RAC 实例的 SGA 内有一个 Buffer Cache，通过 Cache Fusion 技术，RAC 在各个节点之间同步 SGA 中的缓存信息，从而保证了节点数据的一致性，同时也提高了集群的访问速度。
RAC 数据库最大的特点是共享，那么如何实现多个节点有条不紊的数据共享呢，这就是要说的 RAC 的两个进程：即 Global Cache Service (GCS) 和 the Global Enqueue Service (GES)。
全局缓存服务（GCS）和全局队列服务（GES）是最基本的 RAC 进程，主要用于协调对共享数据库和数据库内的共享资源的同时访问。同时，GES 和 GCS 通过使用全局资源目录（Global Resource Directory，GRD）来记录和维护每个数据文件的状态信息，而 GRD 保存在内存中，内容分布存储在所有实例上。每个实例都管理部分内容。

RAC 中通过几个特别的进程与 GRD 相结合，使得 RAC 可以使用缓存融合技术，这几个特别进程是：
- Global Cache Service Processes(LMSn)
  LMS 进程主要用来管理集群内数据块的访问，并在不同实例的 BUFFER CACHE 中传输块镜像。 
- Global Enqueue Service Monitor(LMON)
  LMON 主要监视群集内的全局资源和集群间的资源交互，并管理实例和处理异常，以及集群队列的恢复操作。 
- Global Enqueue Service Daemon(LMD)
  LMD 进程主要管理对全局队列和全局资源的访问，并更新相应队列的状态，处理来自于其他实例的资源请求。 
- Lock Processes(LCK)
  LCK 进程主要用来管理实例间资源请求和跨实例调用操作，并管理除 Cache Fusion 以外的资源请求，比如 library 和 row cache 的请求等。 
- Diagnosability Daemon(DIAG)
  DIAG 进程主要用来捕获实例中失败进程的诊断信息，并生成相应的 TRACE文件。

## RAC 的安装
软件版本如下。
* Ceph 10.2.5
* Centos 7.4 1708
* Oracle 11.2.0.4

本篇在 Ceph 共享卷方式下采用rbd方式的搭建，用来验证 Ceph 共享卷对 RAC 的支持。
### 0. 网络规划
在 Oracle 11gR2 中，安装 RAC 发生了显著变化。在这之前，安装 RAC 的步骤是先安装 Crs，再安装 Database，而到了 11gR2 的时代，Crs 与 Asm 被集成在一起，合称为 Grid。因此必须先安装Grid 以后，才能继续安装 Database。从 Oracle 11.2 开始，对网络 IP 地址有特殊要求，增加 SCAN IP，所以从 11.2开始至少需要 4 种 IP 地址。
* 首先是公网地址。可以将 eth0 和 eth1 绑定成 bond0，作为 RAC 的公网地址，提供外部通信。
* 其次是私网地址。可以将 eth2 和 eth3 绑定为 bond1，作为 RAC 的私网地址，提供内部心跳通信。
* 接着是 RAC 中的 SCAN IP。在 Oracle 11gR2 中，SCAN  IP 是作为一个新增 IP 出现的，它其实是Oracle 在客户端与数据库之间新加的一个连接层。当有客户端访问时，连接到 SCAN IP Listener， 而 SCAN IP Llistener 接收到连接请求时，会根据一种叫 LBA 算法的将该客户端的连接请求转发给对应的 Instance 上的 VIP Listener，从而完成了整个客户端与服务器的连接过程。也可以把 SCAN 理解为一个虚拟主机名，它对应的是整个 RAC 集群。客户端主机只需通过这个 SCAN Name 即可访问集群中的任意节点。当然访问的节点是随机的，Oracle 强烈建议通过 DNS Server 的 RR 模式配置解析 SCAN，实现轮询的负载均衡。
* 还有一个 VIP 地址。它与公网地址在同一个网段，与公网地址最主要的不同之处在于，它是浮动的，而公网地址是固定的。在所有节点都正常运行时，每个节点的 VIP 会被分配到公网网卡上。在 Linux 下使用 ifconfig 查看，公网网卡上有 2 个地址；如果一个节点宕机，这个节点的 VIP 会被转移到还在运行的节点上。也就是幸存的节点的公网网卡上，会有 3 个 IP 地址。

| 节点名称    | 公网地址           | 私网地址            | VIP 地址         | SCAN 名称 | SCAN IP 地址      |
| ------- | -------------- | --------------- | -------------- | ------- | --------------- |
| server1 | 192.168.122.62 | 192.168.123.31  | 192.168.122.63 | racscan | 192.168.122.246 |
| server2 | 192.168.122.30 | 192.168.123.186 | 192.168.122.64 | racscan | 192.168.122.246 |
### 1. Ceph 搭建
Ceph 的搭建过程略过。
```
[root@ceph ~]# ceph -s
    cluster c7d48bc5-c8dd-4e24-af01-04c97f2d42f9
     health HEALTH_WARN
            mon.ceph low disk space
     monmap e1: 1 mons at {ceph=192.168.2.207:6789/0}
            election epoch 6, quorum 0 ceph
     osdmap e138: 3 osds: 2 up, 2 in
            flags sortbitwise,require_jewel_osds
      pgmap v253541: 128 pgs, 2 pools, 13040 MB data, 3394 objects
            29366 MB used, 1076 GB / 1105 GB avail
                 128 active+clean
  client io 125 kB/s rd, 26621 B/s wr, 11 op/s rd, 8 op/s wr
[root@ceph ~]# rbd ls volumes
volume01
volume02
volume03
volume04
[root@server1 bin]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sr0              11:0    1  8.1G  0 rom  /run/media/oracle/CentOS 7 x86_64
vda             252:0    0   40G  0 disk 
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   39G  0 part 
  ├─centos-root 253:0    0   35G  0 lvm  /
  └─centos-swap 253:1    0    4G  0 lvm  [SWAP]
vdb             252:16   0   20G  0 disk 
└─vdb1          252:17   0   20G  0 part 
vdc             252:32   0   20G  0 disk 
└─vdc1          252:33   0   20G  0 part 
vdd             252:48   0   20G  0 disk 
└─vdd1          252:49   0   20G  0 part 
[root@server1 bin]# ll /dev/oracleasm/disks/
Total 0
brwxrwxrwx 1 grid oinstall 252, 33 5月  14 16:31 DATA
brwxrwxrwx 1 grid oinstall 252, 49 5月  14 16:31 FRA
brwxrwxrwx 1 grid oinstall 252, 17 5月  14 16:31 OCRS
```
### 2. 虚拟机的准备
采用 kvm 方式创建两个虚拟机，xml 类似如下，确保每个虚拟机有两块网卡。
```
<domain type='kvm'>
<memory unit='GiB'>12</memory>
<vcpu>8</vcpu>
<os>
    <type arch='x86_64' machine='pc'>hvm</type>
    <boot dev='hd'/>
    <boot dev='cdrom'/>
</os>
<features>
    <acpi/>
</features>
<devices>
    <disk type='file' device='cdrom'>
        <driver name='qemu' type='raw'/>
        <source file='/home/image/CentOS-7-x86_64-Everything-1708.iso'/>
        <target dev='hda' bus='ide'/>
    </disk>
    <disk type='file' device='disk'>
        <driver name='qemu' type='raw'/>
        <source file='/home/image/server1.img'/>
        <target dev='vda' bus='virtio'/>
    </disk>
    <!--
    <disk type='network' device='disk'>
        <auth username='admin'>
            <secret type='ceph' uuid='0a7ed5ef-e060-491d-b9f6-d47237d34015'/>
        </auth>
        <source protocol='rbd' name='volumes/volume01'>
            <host name='192.168.2.207' port='6789'/>
        </source>
        <target dev='vdb' bus='virtio'/>
    </disk>
    -->
    <graphics type='vnc' port='5900' autoport='yes' listen='0.0.0.0' keymap='en-us'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
    <video>
      <model type='cirrus'/>
      <alias name='video0'/>
    </video>
    <interface type='network'>
      <mac address='fa:16:5f:a3:a5:ce'/>
      <source network='default'/>
      <model type='virtio'/>
      <alias name='net0'/>
    </interface>
    <interface type='network'>
      <mac address='fa:16:6d:a2:35:ce'/>
      <source network='default'/>
      <model type='virtio'/>
      <alias name='net1'/>
    </interface>
</devices>
<name>server1</name>
</domain>
```
挂载的ceph卷格式如下。
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
### 3. 环境的准备
执行如下操作，安装依赖包（所有节点操作）。
```
yum -y install binutils compat-libcap1 compat-libstdc++ compat-libstdc++-33 e2fsprogs e2fsprogs-libs glibc glibc glibc-devel glibc-devel ksh libgcc libgcc libstdc++ libstdc++ libstdc++-devel libstdc++-devel libaio libaio libaio-devel libaio-devel libXtst libXtst libX11 libX11 libXau libXau libxcb libxcb libXi libXi make net-tools nfs-utils sysstat smartmontools
```
配置内核参数 /etc/sysctl.conf（所有点操作）。
```
kernel.shmall = 2097152
kernel.shmmax = 4294967295
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
kernel.panic_on_oops=1
```
执行 sysctl -p 使其生效（所有点操作）。
创建所需的用户、组、文件夹。
```
groupadd -g 1010 oinstall
groupadd -g 1020 asmadmin
groupadd -g 1021 asmdba
groupadd -g 1022 asmoper
groupadd -g 1031 dba
groupadd -g 1032 oper
useradd -u 1100 -g oinstall -G asmadmin,asmdba,asmoper,oper,dba grid
useradd -u 1101 -g oinstall -G dba,asmdba,oper oracle
mkdir -p /u01/software
mkdir -p /u01/app/11.2.0/grid
mkdir -p /u01/app/grid
mkdir -p /u01/app/oracle
chown -R grid:oinstall /u01
chown oracle:oinstall /u01/app/oracle
chmod -R 775 /u01/
```
本地的网络规划如下 /etc/hosts（所有节点操作）。
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
#public
192.168.122.62	server1
192.168.122.30	server2
#private
192.168.123.31	server1-priv
192.168.123.186	server2-priv
#virtual
192.168.122.63	server1-vip
192.168.122.64	server2-vip
#racscan
192.168.122.246	racscan
```
### 4. Grid 的安装
需要修改的环境变量文件部分（所有节点都要操作，注意替换如 ORACLE_SID=+ASM2）。
```
export PATH
export ORACLE_SID=+ASM1
export TMP=/tmp
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/11.2.0/grid
export PATH=$ORACLE_HOME/bin:/usr/sbin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export LC_ALL=en_US.UTF-8
```
采用图形化的安装方式或者静默安装，过程省略。
推荐使用 asmca 辅助工具来创建 asm 磁盘组。
### 5. Database 的安装
需要修改的环境变量文件部分（所有节点都要操作，注意替换如 ORACLE_SID=orcl2）。
```
export PATH
export TMP=/tmp
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/dbhome_1
export ORACLE_SID=orcl1
export PATH=$ORACLE_HOME/bin:/usr/sbin:$ORACLE_HOME/OPatch:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export NLS_LANG=AMERICAN_AMERICA.UTF8
export LC_ALL=en_US.UTF-8
```
采用图形化的安装方式或者静默安装，过程省略。
### 6. Instance 的创建
推荐采用 dbca 辅助工具来安装，过程省略。
### 7. 简单验证
分别在 server1 和 server2 上执行 lsnrctl status 查看实例运行状态。
```
[oracle@server1 ~]$ lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 14-MAY-2018 14:39:19

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 11.2.0.4.0 - Production
Start Date                14-MAY-2018 13:42:05
Uptime                    0 days 0 hr. 57 min. 13 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/11.2.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/server1/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.122.62)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.122.63)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM1", status READY, has 1 handler(s) for this service...
Service "orcl" has 1 instance(s).
  Instance "orcl1", status READY, has 1 handler(s) for this service...
Service "orclXDB" has 1 instance(s).
  Instance "orcl1", status READY, has 1 handler(s) for this service...
The command completed successfully
```
```
[oracle@server2 ~]$ lsnrctl status

LSNRCTL for Linux: Version 11.2.0.4.0 - Production on 14-MAY-2018 14:39:22

Copyright (c) 1991, 2013, Oracle.  All rights reserved.

Connecting to (ADDRESS=(PROTOCOL=tcp)(HOST=)(PORT=1521))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 11.2.0.4.0 - Production
Start Date                14-MAY-2018 13:42:14
Uptime                    0 days 0 hr. 57 min. 7 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/11.2.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/server2/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=LISTENER)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.122.30)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.122.64)(PORT=1521)))
Services Summary...
Service "+ASM" has 1 instance(s).
  Instance "+ASM2", status READY, has 1 handler(s) for this service...
Service "orcl" has 1 instance(s).
  Instance "orcl2", status READY, has 1 handler(s) for this service...
Service "orclXDB" has 1 instance(s).
  Instance "orcl2", status READY, has 1 handler(s) for this service...
The command completed successfully
```
检查 RAC 状态。
```
[grid@server1 ~]$ srvctl config database -d orcl
Database unique name: orcl
Database name: orcl
Oracle home: /u01/app/oracle/product/11.2.0/dbhome_1
Oracle user: oracle
Spfile: +DATA/orcl/spfileorcl.ora
Domain: 
Start options: open
Stop options: immediate
Database role: PRIMARY
Management policy: AUTOMATIC
Server pools: orcl
Database instances: orcl1,orcl2
Disk Groups: DATA,FRA
Mount point paths: 
Services: 
Type: RAC
Database is administrator managed
[grid@server1 ~]$ srvctl status database -d orcl
Instance orcl1 is running on node server1
Instance orcl2 is running on node server2
```
执行 sqlplus / as sysdba 登录数据库。
```
15:04:27 SQL> select inst_id, instance_number, instance_name, parallel, status, database_status, active_state, host_name host FROM gv$instance ORDER BY inst_id;

   INST_ID INSTANCE_NUMBER INSTANCE_NAME    PAR STATUS	     DATABASE_STATUS   ACTIVE_ST HOST
---------- --------------- ---------------- --- ------------ ----------------- --------- ----------------------------------------------------------------
	 1		 1 +ASM1	    YES STARTED      ACTIVE	       NORMAL	 server1
	 2		 2 +ASM2	    YES STARTED      ACTIVE	       NORMAL	 server2

Elapsed: 00:00:00.01
```
通过企业管理器控制台 em 界面查看。
![text](/Users/urmcdull/Downloads/RAC安装/cluster_status.jpeg)
## 结论
通过上面的实验，Oracle 11gR2 的 RAC 集群成功地在作为共享存储的 Ceph 10.2.5 上跑了起来。这里甚至没有贴简单的性能测试数据，是因为从严格意义上来讲这些数据不具备参考性。接下来就可以愉快地体验 Oracle RAC 了。
