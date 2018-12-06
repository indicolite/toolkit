[TOC]

# 集群配置

## 设置每个节点的Cookie

Rabbitmq的集群是依赖于erlang的集群来工作的，所以必须先构建起erlang的集群环境。Erlang的集群中各节点是通过一个magic cookie来实现的，这个cookie存放在 /var/lib/rabbitmq/.erlang.cookie 中，文件是400的权限。所以必须保证各节点cookie保持一致，否则节点之间就无法通信。

```
# cat /var/lib/rabbitmq/.erlang.cookie 
EJARCZORCOTEQWFGPWXR
```

## 关于节点类型

ram节点的状态保存在内存中，disk节点保存在磁盘中被加入的节点为disk。可以通过```rabbitmqctl cluster```命令改变加入的集群以及节点类型。该命令后可以加多个节点名称，指定的节点就会变成disk节点

```
[root@rabbitmq-node3 ~]# rabbitmqctl cluster_status
[root@rabbitmq-node3 ~]# rabbitmq stop_app
[root@rabbitmq-node3 ~]# rabbitmqctl reset
[root@rabbitmq-node3 ~]# rabbitmqctl cluster
[root@rabbitmq-node3 ~]# rabbitmqctl start_app
 
#指定为ram
[root@rabbitmq-node2 ~]# rabbitmq stop_app
[root@rabbitmq-node2 ~]# rabbitmqctl reset
[root@rabbitmq-node2 ~]# rabbitmqctl cluster rabbit@rabbitmq-node3
[root@rabbitmq-node2 ~]# rabbitmqctl start_app
 
#指定为disc
[root@rabbitmq-node1 ~]# rabbitmq stop_app
[root@rabbitmq-node1 ~]# rabbitmqctl reset
[root@rabbitmq-node1 ~]# rabbitmqctl cluster rabbit@rabbitmq-node3 rabbit@rabbitmq-node1
[root@rabbitmq-node1 ~]# rabbitmqctl start_app
```

## 自动配置集群

默认文件是没有的，如果需要必须手动创建。

```
[root@rabbitmq-node1 ~]# cat /etc/rabbitmq/rabbitmq.conf 
[
...
{rabbit, [
...
{cluster_nodes, ['rabbit@rabbitmq-node1','rabbit@rabbitmq-node2', 'rabbit@rabbitmq-node3']},
...
]},
...
].
 
[root@rabbitmq-node1 ~]# cat /etc/rabbitmq/rabbitmq-env.conf 
RABBITMQ_MNESIA_BASE=/var/lib/rabbitmq/    //需要使用的MNESIA数据库的路径
RABBITMQ_LOG_BASE=/var/log/rabbitmq/       //log的路径
RABBITMQ_PLUGINS_DIR=/usr/lib/rabbitmq/lib/rabbitmq_server-2.8.6/plugins    //插件的路径
```


## 启动各个节点

分别在3个节点上启动Rabbit MQ：

```
rabbit1$ rabbitmq-server -detached
rabbit2$ rabbitmq-server -detached
rabbit3$ rabbitmq-server -detached
```

通过命令`rabbitmq-server -detached`就可以启动rabbit服务。

然后在每个节点上查看集群状态：

```
rabbit1$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit1 ...
[{nodes,[{disc,[rabbit@rabbit1]}]},{running_nodes,[rabbit@rabbit1]}]
...done.

rabbit2$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit2 ...
[{nodes,[{disc,[rabbit@rabbit2]}]},{running_nodes,[rabbit@rabbit2]}]
...done.

rabbit3$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit3 ...
[{nodes,[{disc,[rabbit@rabbit3]}]},{running_nodes,[rabbit@rabbit3]}]
...done.
```

RabbitMQ服务节点的名字是rabbit@shorthostname，所以上面3个节点分别是rabbit@rabbit1、rabbit@rabbit2、rabbit@rabbit3。需要注意的是使用`rabbitmq-server`基本执行的名字都是小写的。

## 创建集群

这里把rabbit@rabbit2和rabbit@rabbit3加入rabbit@rabbit1中，也就是说rabbit@rabbit1是磁盘节点，其他两个都是内存节点。

先把rabbit@rabbit2加入到rabbit@rabbit1中：

```
rabbit2$ rabbitmqctl stop_app
Stopping node rabbit@rabbit2 ...done.

rabbit2$ rabbitmqctl join_cluster rabbit@rabbit1
Clustering node rabbit@rabbit2 with [rabbit@rabbit1] ...done.

rabbit2$ rabbitmqctl start_app
Starting node rabbit@rabbit2 ...done.
```

如果没有报错，rabbit@rabbit2就已经加入到rabbit@rabbit1中了，可以使用命令`rabbitmqctl cluster_status`查看集群状态：

```
rabbit1$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit1 ...
[{nodes,[{disc,[rabbit@rabbit1,rabbit@rabbit2]}]},
 {running_nodes,[rabbit@rabbit2,rabbit@rabbit1]}]
...done.

rabbit2$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit2 ...
[{nodes,[{disc,[rabbit@rabbit1,rabbit@rabbit2]}]},
 {running_nodes,[rabbit@rabbit1,rabbit@rabbit2]}]
...done.
```

通过`join_cluster --ram`可以指定节点以内存节点的形式加入集群。然后在rabbit@rabbit3上执行相同的操作即可，这里不再赘述。

## 拆分集群

拆分集群实际上就是在想要从集群中删除的节点上执行`reset`即可，他会通知集群中所有的节点不要再理这个节点了。

```
rabbit3$ rabbitmqctl stop_app
Stopping node rabbit@rabbit3 ...done.

rabbit3$ rabbitmqctl reset
Resetting node rabbit@rabbit3 ...done.

rabbit3$ rabbitmqctl start_app
Starting node rabbit@rabbit3 ...done.
```

在各个节点上查看集群状态：

```
rabbit1$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit1 ...
[{nodes,[{disc,[rabbit@rabbit1,rabbit@rabbit2]}]},
 {running_nodes,[rabbit@rabbit2,rabbit@rabbit1]}]
...done.

rabbit2$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit2 ...
[{nodes,[{disc,[rabbit@rabbit1,rabbit@rabbit2]}]},
 {running_nodes,[rabbit@rabbit1,rabbit@rabbit2]}]
...done.

rabbit3$ rabbitmqctl cluster_status
Cluster status of node rabbit@rabbit3 ...
[{nodes,[{disc,[rabbit@rabbit3]}]},{running_nodes,[rabbit@rabbit3]}]
...done.
```

还可以在某节点上删除别的节点，可以使用`forget_cluster_node`来进行，这里不进行赘述，后面的一种异常中会用到这个命令。

在浏览器中可以看到所有节点的信息。比如访问```http://10.127.2.41:15672/```

# 几个异常

## 一台机器上启动多个实例

RabbitMQ允许在一台机器上启动多个实例，自己在这次运维中占用时间最长的就是不知道这3个节点上部署了两套集群，通过ps -ef|grep rabbit命令看到有两个实例，就天真的以为是有一个没有成功关闭，所以直接把两个都kill了。所以这里记录一下如果在一台机器上启动多个实例。

```
$ RABBITMQ_NODE_PORT=5673 RABBITMQ_SERVER_START_ARGS="-rabbitmq_management listener [{port,15673}]" RABBITMQ_NODENAME=hare rabbitmq-server -detached
$ rabbitmqctl -n hare stop_app
$ rabbitmqctl -n hare join_cluster rabbit@rabbit1
$ rabbitmqctl -n hare start_app
```

执行命令需要使用`-n`来指定执行命令的实例，这个是需要记住的。

## Bad cookie in table definition rabbit_durable_queue

这个已经找不到错误的具体描述了，就从Google上找了一条，基本类似。

```
rabbitmqctl cluster rabbit@vmrabbita
Clustering node rabbit@vmrabbitb with [rabbit@vmrabbita] ...
Error: {unable_to_join_cluster,
          [rabbit@vmrabbita],
          {merge_schema_failed,
              "Bad cookie in table definition rabbit_durable_queue: rabbit@vmrabbitb = {cstruct,rabbit_durable_queue,set,[],[rabbit@vmrabbitb],[],0,read_write,[],[],false,amqqueue,[name,durable,auto_delete,arguments,pid],[],[],{{1266,16863,365586},rabbit@vmrabbitb},{{2,0},[]}}, rabbit@vmrabbita = {cstruct,rabbit_durable_queue,set,[],[rabbit@vmrabbitc,rabbit@vmrabbita],[],0,read_write,[],[],false,amqqueue,[name,durable,auto_delete,arguments,pid],[],[],{{1266,14484,94839},rabbit@vmrabbita},{{4,0},{rabbit@vmrabbitc,{1266,16151,144423}}}}\n"}}
```

主要的就是Bad cookie in table definition rabbit_durable_queue这句，这是因为节点之间是通过“the Erlang Cookie”彼此识别的，存储在$HOME/.erlang.cookie中。如果因为某种原因，集群中几个节点服务器上的cookie不一致，就会不能够彼此识别，出现这样那样的错误。更多的是上面的这个”Bad cookie。。。”，还会有”Connection attempt from disallowed node”、 “Could not auto-cluster”。

## already_member

这个问题就是比较2的一个问题了，自己给自己挖的坑，只能自己填了。集群几个节点之间不能通信，然后我就把一个内存节点的`var/lib/rabbitmq/mnesia`中的文件夹删了，然后又执行了`reset`，当执行`join_cluster`命令的时候，就会报出错误：

```
Error: {ok,already_member}
```

分析一下可以明白，当前节点上没有待加入集群的信息，但是待加入集群中已经有了该节点的信息，但是发现两个信息不一致。所以当当前节点期望加入到集群的时候，出于安全考虑，集群就说你小子已经是集群里的一员了，不要再加了。扒出日志来看：

```
=INFO REPORT==== 25-Jul-2016::20:11:10 ===
Error description:
   {could_not_start,rabbitmq_management,
       {{shutdown,
            {failed_to_start_child,rabbit_mgmt_sup,
                {'EXIT',
                    {{shutdown,
                         [{{already_started,<23251.1658.0>},
                           {child,undefined,rabbit_mgmt_db,
                               {rabbit_mgmt_db,start_link,[]},
                               permanent,4294967295,worker,
                               [rabbit_mgmt_db]}}]},
                     {gen_server2,call,
                         [<0.618.0>,{init,<0.616.0>},infinity]}}}}},
        {rabbit_mgmt_app,start,[normal,[]]}}}

Log files (may contain more information):
   ./../var/log/rabbitmq/hare.log
   ./../var/log/rabbitmq/hare-sasl.log
```

既然集群中已经有个该节点信息，所以不要该节点重复加入。那就把集群里该节点信息删了，再加入集群，不就应该类似与一个全新的节点加入集群一样吗？

```
rabbitmqctl -n hare forget_cluster_node hare@rabbit1
```

这样，集群中就没有hare@rabbit1的信息了，之后就重新执行`join_cluster`命令即可。

## 千万不要在磁盘节点上删除var/lib/rabbitmq/mnesia中的文件

这个文件夹中的内容是磁盘节点用于记录集群信息的文件，一旦删除，会出现各种各样的异常。

# 参考链接

[RabbitMQ运维][https://blog.csdn.net/liuxinghao/article/details/52076436]

[RabbitMQ指南][https://dbaplus.cn/news-141-1464-1.html]

[https://messeiry.com/openstack-rabbitmq-deep-dive/][https://messeiry.com/openstack-rabbitmq-deep-dive/]