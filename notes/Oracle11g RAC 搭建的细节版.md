[TOC]
##前言
##虚拟机的准备
创建第一台虚拟机
安装操作系统
配置第一台虚拟机
配置子网
添加网卡
固定IP
克隆第二台虚拟机
配置第二台虚拟机
修改主机名
修改IP
添加共享磁盘
为第一台虚拟机添加磁盘
将磁盘设置为共享磁盘
将共享磁盘添加到第二台虚拟机

##环境的准备
配置操作系统
安装依赖包
配置内核参数
关闭NTP
配置PAM
关闭SELinux
创建用户、组、文件夹
配置环境变量
配置grid用户的环境变量
配置oracle的环境变量
配置网络
配置hosts解析
关闭虚拟网卡
禁用ZEROCONF
配置SSH互信
配置存储
安装ASMLIB
创建分区
创建磁盘组
##网格基础设施的安装
安装CVU
安装网格基础设施
创建其他磁盘组
##数据库软件的安装
##数据库实例的创建

##简介
Oracle Real Application Cluster (RAC) 数据库是一种集群数据库，它允许集群中的两台或多台节点同时访问一个共享数据库。其架构的最大特点是共享存储架构，整个 RAC 集群是建立在一个共享的存储设备之上的，节点之间采用高速网络互联。业务连续性、高可用性、可伸缩性、灵活性和敏捷性与轻松的管理相结合，是成功 IT 基础架构和云部署的支柱。

OracleRAC 提供了非常好的高可用特性，比如负载均衡和应用透明切块（TAF），其最大的优势在于对应用完全透明，应用无需修改便可切换到RAC 集群。因为整个集群都依赖于底层的共享存储，所以共享存储的 I/O 能力和可用性决定了整个集群的可以提供的能力，对于 I/O 密集型的应用，这样的机制决定后续扩容只能是 Scale Up类型，对于硬件成本、开发人员的要求、维护成本都相对比较高。新的架构中，采用 ASM 来整合多个存储设备的能力，使得 RAC 底层的共享存储设备具备线性扩展的能力，整个集群不再依赖于大型存储的处理能力和可用性。

RAC 的另外一个问题是，随着节点数的不断增加，节点间通信的成本也会随之增加，当到某个限度时，增加节点可能不会再带来性能上的提高，甚至可能造成性能下降。这个问题的主要原因是 Oracle RAC 对应用透明，应用可以连接集群中的任意节点进行处理，当不同节点上的应用争用资源时，RAC 节点间的通信开销会严重影响集群的处理能力。所以对于使用 ORACLE RAC 有以下两个建议：
* 节点间通信使用高速互联网络；
* 尽可能将不同的应用分布在不同的节点上。

##原理
Oracle RAC 数据库是一种集群数据库，它允许集群中的两台或多台节点同时访问一个共享数据库。这将有效地创建一个跨越多个硬件系统的数据库系统，同时对应用程序而言像是一个统一的数据库。在集群中，彼此独立的服务器组成一个服务器池，并作为一个系统协同工作。服务器池提供了比单对称多处理器 (SMP) 系统更好的容错方式和模块化系统扩展方式。在系统发生故障时，服务器池仍可为用户提供高可用性。对关键任务数据的访问不会丢失。冗余的硬件组件（如额外的服务器、网络连接和磁盘）为高可用性提供了保障。此类冗余硬件架构避免了单点故障并提供了卓越的故障恢复能力。

RAC 体系结构的一个主要优势是多个节点内建的容错性能。由于物理节点单独运行，因此其中一个或多个节点的故障将不会影响到集群内其它节点。故障切换可在网格内任一节点上进行。即使在最恶劣的情况下，包括只有一个节点没有停止工作，真正应用集群仍将能够提供数据库服务。这一体系结构允许将一组节点联网或与网络断开，以进行维护，而同时其它节点能够继续提供数据库服务。

![text](http://wiki.jikexueyuan.com/project/oraclecluster/images/1.png)
在 RAC 中，我们将 Oracle 实例（运行在服务器上的进程和内存结构，用于支持数据访问）与 Oracle 数据库（驻留在存储器上的实际用于保存数据的物理结构，通常称为数据文件）进行了分离。集群数据库是一个可由多个实例访问的数据库。各实例在服务器池中不同的服务器上运行。当需要更多的资源时，可以在不停机的情况下轻松地向服务器池中添加服务器和实例。在启动新实例后，使用服务的应用程序可立即利用该实例，无需对应用程序或应用程序服务器进行任何更改。

RAC 是一种全共享式架构，服务器池中的所有服务器共享用于 RAC 数据库的所有存储。所用存储池的类型可以是网络连接存储 (NAS)、存储区域网络 (SAN)、 SCSI 磁盘、甚至是流行的分布式的文件系统(Ceph、GlusterFS)。存储的选择取决于所选用的服务器硬件和硬件供应商支持的硬件类型。选择适当存储池的关键之处在于，选择一个可向应用程序提供可伸缩 I/O 的存储系统，一个在向池中添加服务器时可进行伸缩的 I/O 系统。

RAC 是一种全共享式架构，因此卷管理和文件系统必须支持集群识别。Oracle 建议使用 Oracle Database 11g 包含的特性 Oracle Automatic Storage Management (ASM)，为数据库实现各种存储池的自动化管理。ASM 提供了异步 I/O 存储子系统的性能，并可以简化文件系统的管理。它在所有可用资源中分配 I/O 负载，以便在消除手动 I/O 调优需求的同时优化性能。Oracle Database 11gR2 中的 ASM 还附带一个动态卷管理器和一个通用文件系统。此外，Oracle 也支持特定、经过认证的集群文件系统，如可在 Windows 和 Linux 上使用的
Oracle Cluster File System (OCFS)，即 OCFS2。以及更新的 Oracle ASM Cluster File System (ACFS)，即 ACFS。

##软件
###1. ceph 10.2.5
###2. centos 7.4 1708
###3. oracle 11.2.0.4
###3. rbd方式

##安装
本篇尝试验证在ceph卷方式下的搭建。
###0. ceph搭建
###1. 虚拟机的准备
kvm方式创建两个虚拟机，xml类似如下，确保每个虚拟机有两块网卡。
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
###2. 环境的准备
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
###3. grid的安装
需要修改的环境变量文件部分（所有节点都要操作，注意替换 ORACLE_SID）。
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
###4. database的安装
需要修改的环境变量文件部分（所有节点都要操作，注意替换 ORACLE_SID）。
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
###5. instance的创建
推荐采用 dbca 辅助工具来安装，过程省略。
###6. 简单验证
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

##问题
###1. 安装过程中弹出的对话框显示不完整
该问题在centos系列的虚拟机以及真实的物理环境中都会出现。
默认安装都是直接运行安装文件，这种默认安装就会出现上述问题。为了避免该情况可以通过指定参数安装：
```
./runInstaller -jreLoc /usr/lib/jvm/jre-1.8.0
```
###2. [INS-41112] Specified network interface doesnt maintain connectivity across cluster”错误
需要确认并**关闭**防火墙。
```
[root@server2 ~]# systemctl status firewalld.service 
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
     Docs: man:firewalld(1)
```
###3. installation error in invoking target 'agent nmhs'
```
##When you start to install with ./runInstaller, run in another terminal window (as root) 
ls $ORACLE_HOME/sysman/lib/ins_emagent.mk
##At first this will produce an error, as the installer wont have created this file yet.
##Once the file exists, do:
vim $ORACLE_HOME/sysman/lib/ins_emagent.mk
##Search for the line 
$(MK_EMAGENT_NMECTL)
##Change it to:
$(MK_EMAGENT_NMECTL) -lnnz11
##If you do it within 30-40 seconds of the file appearing, you should not get any errors and the build will go fine. If you get an error, finish your edit then click on retry.
```
vim /u01/app/oracle/product/11.2.0/dbhome_1/sysman/lib/ins_emagent.mk
```
171 #===========================
172 #  emdctl
173 #===========================
174 
175 $(SYSMANBIN)emdctl:
176         $(MK_EMAGENT_NMECTL) -lnnz11
```
###4. centos7 安装oracle rac 11.2.0.4执行root.sh报错ohasd failed to start
报错原因：centos7使用了systemd而不是init运行进程和重启进程，而root.sh通过init.d运行ohasd进程。
解决办法：在centos7中ohasd需要被设置为一个服务，在运行脚本root.sh之前。
```
touch /usr/lib/systemd/system/ohasd.service
chmod 777 /usr/lib/systemd/system/ohasd.service
```
```
cat /usr/lib/systemd/system/ohas.service
[Unit]
Description=Oracle High Availability Services
After=syslog.target

[Service]
ExecStart=/etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple
Restart=always

[Install]
WantedBy=multi-user.target
```
以root用户运行下面的命令
```
systemctl daemon-reload
systemctl enable ohasd.service
systemctl start ohasd.service
```
查看运行状态
```
[root@server1 lib]# systemctl status ohasd.service 
● ohasd.service - Oracle High Availability Services
   Loaded: loaded (/usr/lib/systemd/system/ohasd.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2018-05-09 15:15:44 CST; 1h 33min ago
 Main PID: 730 (init.ohasd)
   CGroup: /system.slice/ohasd.service
           └─730 /bin/sh /etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple

2018-05-09 15:15:44 server1 systemd[1]: Started Oracle High Availability Services.
2018-05-09 15:15:44 server1 systemd[1]: Starting Oracle High Availability Services...
```
###5. oracle asmlib 下载地址
http://www.oracle.com/technetwork/server-storage/linux/asmlib/ol7-2352094.html
http://www.oracle.com/technetwork/server-storage/linux/asmlib/rhel7-2773795.html
###6. PRVF-0002: Could not retrieve local nodename
依次检查几个节点里的三个文件，确保里面填写的 hostname 是一致的。修改完毕以后需要重启机器方可生效。 /etc/hosts，/etc/hostname，/etc/sysconfig/network
###7. Failed to register Grid Infrastructure type ora.mdns.type
https://blog.csdn.net/carry9148/article/details/52252755
##链接
http://www.oracle.com/technetwork/database/options/clustering/learnmore/index.html
http://www.oracle.com/technetwork/cn/products/clustering/rac-wp-12c-1896129-zhs.pdf
http://www.oracle.com/technetwork/database/options/clustering/overview/s298716-oow2008-perf-130776.pdf
https://docs.oracle.com/cd/E11882_01/server.112/e18951/asmfilesystem.htm#OSTMG30000
https://community.oracle.com/thread/1093616
https://blog.csdn.net/u010692693/article/details/48374557
http://www.pythonsite.com/?p=116
https://jaycelau.github.io/categories/Oracle/RAC/
http://www.oracle.com/technetwork/server-storage/linux/asmlib/ol7-2352094.html
http://www.oracle.com/technetwork/server-storage/linux/asmlib/rhel7-2773795.html
https://www.lijiawang.org/posts/intsall-ceph.html
http://www.talkwithtrend.com/Article/217185
https://en.wikipedia.org/wiki/Ceph_(software)