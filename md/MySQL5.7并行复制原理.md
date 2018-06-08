[TOC]

## MySQL 5.7并行复制原理

MySQL 从 5.6 开始引入了多库并行主从复制，但是其并行只是基于 Schema 的，也就是基于库的。如果用户的 MySQL 数据库实例中存在多个 Schema，对于从机复制的速度的确可以有比较大的帮助。MySQL 5.6 并行复制的架构如下所示：
![](https://www.hi-linux.com/img/linux/mysql-mts-0.png)
在上图的红色框框部分就是实现并行复制的关键所在。在 MySQL 5.6 版本之前，Slave 服务器上有两个线程 I/O 线程和 SQL 线程。I/O 线程负责接收二进制日志(更准确的说是二进制日志的 event )，SQL 线程进行回放二进制日志。如果在 MySQL 5.6 版本开启并行复制功能，那么SQL线程就变为了 Coordinator 线程，Coordinator 线程主要负责以前两部分的内容：
- 若判断可以并行执行，那么选择 Worker 线程执行事务的二进制日志。
- 若判断不可以并行执行，如该操作是 DDL，亦或者是事务跨 Schema 操作，则等待所有的 Worker 线程执行完成之后，再执行当前的日志。

这意味着 Coordinator 线程并不是仅将日志发送给 Worker 线程，自己也可以回放日志，但是所有可以并行的操作交付由 Worker 线程完成。Coordinator 线程与 Worker 是典型的生产者与消费者模型。

上述机制实现的基于 Schema 的并行复制存在两个问题，首先是 Crash Safe 功能不好做，因为可能之后执行的事务由于并行复制的关系先完成执行，那么当发生 Crash 的时候，这部分的处理逻辑是比较复杂的。从代码上看，5.6 这里引入了 Low-Water-Mark 标记来解决该问题，从设计上看，其是希望借助于日志的幂等性来解决该问题，不过 5.6 的二进制日志回放还不能实现幂等性。另一个最为关键的问题是这样设计的并行复制效果并不高，如果用户实例仅有一个库，那么就无法实现并行回放，甚至性能会比原来的单线程更差。而单库多表是比多库多表更为常见的一种情形。

MySQL 5.7 才可称为真正的并行复制，这其中最为主要的原因就是 Slave 服务器的回放与主机是一致的即 Master 服务器上是怎么并行执行的 Slave 上就怎样进行并行回放。不再有库的并行复制限制，对于二进制日志格式也无特殊的要求（基于库的并行复制也没有要求）。

从 MySQL 官方来看，其并行复制的原本计划是支持表级的并行复制和行级的并行复制，行级的并行复制通过解析 ROW 格式的二进制日志的方式来完成。但是最终出现的是在开发计划中称为：MTS: Prepared transactions slave parallel applier。

该并行复制的思想最早是由 MariaDB 的 Kristain 提出，并已在 MariaDB 10 中出现，MySQL 5.7 并行复制的思想简单易懂，一言以蔽之：一个组提交的事务都是可以并行回放，因为这些事务都已进入到事务的 Prepare 阶段，则说明事务之间没有任何冲突（否则就不可能提交）。

为了兼容 MySQL 5.6 基于库的并行复制，5.7 引入了新的变量 slave-parallel-type，其可以配置的值有：
- DATABASE：默认值，基于库的并行复制方式。
- LOGICAL_CLOCK：基于组提交的并行复制方式。

如何知道事务是否在一组中，又是一个问题，因为原版的 MySQL 并没有提供这样的信息。在 MySQL 5.7版本中，其设计方式是将组提交的信息存放在 GTID 中。那么如果用户没有开启 GTID 功能，即将参数 gtid_mode 设置为 OFF 呢？故 MySQL 5.7 又引入了称之为 Anonymous_Gtid 的二进制日志 event 类型，如：
```
mysql> SHOW BINLOG EVENTS in 'mysql-bin.000011';

| mysql-bin.000011 | 123 | Previous_gtids | 88 | 194 | f11232f7-ff07-11e4-8fbb-00ff55e152c6:1-2 |
| mysql-bin.000011 | 194 | Anonymous_Gtid | 88 | 259 | SET @@SESSION.GTID_NEXT= 'ANONYMOUS' |
| mysql-bin.000011 | 259 | Query | 88 | 330 | BEGIN |
| mysql-bin.000011 | 330 | Table_map | 88 | 373 | table_id: 108 (aaa.t) |
| mysql-bin.000011 | 373 | Write_rows | 88 | 413 | table_id: 108 flags: STMT_END_F |
......
```
这意味着在 MySQL 5.7 版本中即使不开启 GTID ，每个事务开始前也是会存在一个 Anonymous_Gtid ，而这 GTID 中就存在着组提交的信息。

组提交是个比较好玩的方式，我们根据 MySQL 的 binlog 可以发现较之原来的二进制日志内容多了 last_committed 和 sequence_number 。
```
$ mysqlbinlog mysql-bin.000011 |grep last_committed
#170607 11:24:57 server id 353306 end_log_pos 876350 CRC32 0x92093332 GTID last_committed=654 sequence_number=655
#170607 11:24:58 server id 353306 end_log_pos 880406 CRC32 0x344fdf71 GTID last_committed=655 sequence_number=656
#170607 11:24:58 server id 353306 end_log_pos 888700 CRC32 0x4ba2b05b GTID last_committed=656 sequence_number=657
```
上面是没有开启组提交的一个日志，我们可以看得到 binlog 当中有两个参数 last_committed 和 sequence_number，我们可以看到，下一个事务在主库配置好组提交以后，last_committed 永远都和上一个事务的 sequence_number 是相等的。这也很容易理解，因为事务是顺序提交的。

下面看一下组提交模式的事务：
```
$ mysqlbinlog mysql-bin.000012|grep last_commit
#170609 10:11:07 server id 353306 end_log_pos 75629 CRC32 0xd54f2604 GTID last_committed=269 sequence_number=270
#170609 10:13:03 server id 353306 end_log_pos 75912 CRC32 0x43675b14 GTID last_committed=270 sequence_number=271
#170609 10:13:24 server id 353306 end_log_pos 76195 CRC32 0x4f843438 GTID last_committed=270 sequence_number=272
```
我们可以看到最后两个事务的 last_committed 是相同的，这意味着这两个事务是作为一个组提交的，两个事务在 Perpare 阶段获取相同的 last_committed 而且相互不影响，最终是会作为一个组进行提交。这就是所谓的组提交。组提交的事务是可以在从机进行并行回放的。

上述的 last_committed 和 sequence_number 代表的就是所谓的 LOGICAL_CLOCK 。

## 配置MySQL并行复制
### 环境准备
这里一共使用了二台机器，MySQL 版本都为 5.7.18。

|机器名	|IP地址	|MySQL角色|
|dev-master-01	|192.168.100.210	|MySQL 主库
|dev-node-02	|192.168.100.212	|MySQL 从库
### 安装MySQL
MySQL 安装比较简单，在 「MySQL 5.7多源复制实践」一文中我们也讲了，这里就不在重复讲了。如果你还不会安装，可以先参考此文安装好 MySQL 。
### 启用MySQL并行复制
MySQL 5.7的并行复制建立在组提交的基础上，所有在主库上能够完成 Prepared 的语句表示没有数据冲突，就可以在 Slave 节点并行复制。

关于 MySQL 5.7 的组提交，我们要看下以下的参数：
```
mysql> show global variables like '%group_commit%';
+-----------------------------------------+-------+
| Variable_name                           | Value |
+-----------------------------------------+-------+
| binlog_group_commit_sync_delay          | 0     |
| binlog_group_commit_sync_no_delay_count | 0     |
+-----------------------------------------+-------+
2 rows in set (0.00 sec)
```
要开启 MySQL 5.7 并行复制需要以下二步，首先在主库设置 binlog_group_commit_sync_delay 的值大于0 。
```
mysql> set global binlog_group_commit_sync_delay=10;
```
这里简要说明下 binlog_group_commit_sync_delay 和 binlog_group_commit_sync_no_delay_count 参数的作用。
- binlog_group_commit_sync_delay
  全局动态变量，单位微妙，默认0，范围：0～1000000（1秒）。
  表示 binlog 提交后等待延迟多少时间再同步到磁盘，默认0 ，不延迟。当设置为 0 以上的时候，就允许多个事务的日志同时一起提交，也就是我们说的组提交。组提交是并行复制的基础，我们设置这个值的大于 0 就代表打开了组提交的功能。
- binlog_group_commit_sync_no_delay_count
  全局动态变量，单位个数，默认0，范围：0～1000000。
  表示等待延迟提交的最大事务数，如果上面参数的时间没到，但事务数到了，则直接同步到磁盘。若 binlog_group_commit_sync_delay 没有开启，则该参数也不会开启。

其次要在 Slave 主机上设置如下几个参数：
```
# 过多的线程会增加线程间同步的开销，建议4-8个Slave线程。

slave-parallel-type=LOGICAL_CLOCK
slave-parallel-workers=4
```
或者直接在线启用也是可以的：
```
mysql> stop slave;
Query OK, 0 rows affected (0.07 sec)

mysql> set global slave_parallel_type='LOGICAL_CLOCK';
Query OK, 0 rows affected (0.00 sec)

mysql> set global slave_parallel_workers=4;
Query OK, 0 rows affected (0.00 sec)

mysql> start slave;
Query OK, 0 rows affected (0.06 sec)

mysql> show variables like 'slave_parallel_%';
+------------------------+---------------+
| Variable_name          | Value         |
+------------------------+---------------+
| slave_parallel_type    | LOGICAL_CLOCK |
| slave_parallel_workers | 4             |
+------------------------+---------------+
2 rows in set (0.00 sec)
```
### 检查Worker线程的状态
当前的 Slave 的 SQL 线程为 Coordinator（协调器），执行 Relay log 日志的线程为 Worker(当前的 SQL 线程不仅起到协调器的作用，同时也可以重放 Relay log 中主库提交的事务)。

我们上面设置的线程数是 4 ，从库就能看到 4 个 Coordinator（协调器）进程。
![](https://www.hi-linux.com/img/linux/mysql-mts-1.png)
### 并行复制配置与调优
开启 MTS 功能后，务必将参数 master-info-repository 设置为 TABLE ，这样性能可以有 50%~80% 的提升。这是因为并行复制开启后对于 master.info 这个文件的更新将会大幅提升，资源的竞争也会变大。

在 MySQL 5.7 中，推荐将 master-info-repository 和 relay-log-info-repository 设置为 TABLE ，来减小这部分的开销。
```
master-info-repository = table
relay-log-info-repository = table
relay-log-recovery = ON
```
### 并行复制监控
复制的监控依旧可以通过 SHOW SLAVE STATUS\G，但是 MySQL 5.7 在 performance_schema 架构下多了以下这些元数据表，用户可以更细力度的进行监控：
```
mysql> use performance_schema;
mysql> show tables like 'replication%';
+---------------------------------------------+
| Tables_in_performance_schema (replication%) |
+---------------------------------------------+
| replication_applier_configuration           |
| replication_applier_status                  |
| replication_applier_status_by_coordinator   |
| replication_applier_status_by_worker        |
| replication_connection_configuration        |
| replication_connection_status               |
| replication_group_member_stats              |
| replication_group_members                   |
+---------------------------------------------+
8 rows in set (0.00 sec)
```
### 参考文档
http://www.google.com
http://www.blogs8.cn/posts/2AR0c5
http://www.weidu8.net/wx/1000149002520518
https://www.kancloud.cn/thinkphp/mysql-parallel-applier
http://www.cnblogs.com/zhoujinyi/p/5614135.html
http://www.cnblogs.com/shengdimaya/p/6972278.html
http://blog.itpub.net/28218939/viewspace-1975822/
https://www.hi-linux.com/posts/9892.html
http://www.ttlsa.com/mysql/mysql-5-7-enhanced-multi-thread-salve/
http://www.innomysql.com/mysql-group-replication/
