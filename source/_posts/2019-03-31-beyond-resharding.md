---
title: Redis Cluster & HDFS & ClustrixDB Reshard/Rebalance
date: 2019-03-31 22:12:14
tags: ['数据库', 'MySQL', 'Redis', 'HDFS']
comments: true
categories: ['系统设计', '中间件']
---

对于分布式存储，在新增或删除节点时，必将存在某些节点的数据“过多”，某些节点的数据“过少”。对节点上的数据进行重新整理使各节点的数据趋于相近的过程，就叫rebalance或reshard。本文简单介绍Redis Cluster、HDFS和ClustrixDB是如何对数据进行重分片的。

<!--more-->

## Redis Cluster Reshard

细节参考自[Redis Cluster Spec](https://redis.io/topics/cluster-spec)的**Redirection and resharding**章节。下图表示数据slot原先在Original节点，被迁移到New节点需要经历的过程。
（注：slot的介绍见[Redis Cluster Spec](https://redis.io/topics/cluster-spec)）

![redis cluster reshard](https://user-images.githubusercontent.com/4915189/71431424-c23ba100-270c-11ea-91b1-1cafb8aeaef5.png)

- 新增了New节点——Redis Instance（也可能是本来就存在的一个redis实例）；
- Original上待迁移slot被设置为importing状态，New上欲接受slot被设置为migrating状态。对该slot的读写请求仍然从original节点进来，但是当original不存在请求中包含的key时，请求将被转发给new节点，original已存在该key则请求仍由original受理；
- 将original节点已有的key逐个迁移到new节点，每个key在迁移过程是原子性的（会对该key进行加锁）；
- key全部迁移完成后，通过gossip协议通知集群中的其他节点更新metadata，以后该slot节点的请求将由new节点负责。

Redis Cluster可以做到online resharding，代价是迁移旧key的过程会对每个key进行加锁，加锁时间与key的值正相关。另外，其resharding是需要手动触发的。

## HDFS rebalance

细节参考自[hdfs rebalance JIRA需求](https://issues.apache.org/jira/browse/HADOOP-1652)的**RebalanceDesign6.pdf**，大概过程如下图所示。

![hdfs rebalance](https://user-images.githubusercontent.com/4915189/71431431-c9fb4580-270c-11ea-90b9-d851304c514a.png)

- 先向namenode取得各datanode的数据报告，根据规则确定source节点和destination节点；
- 获取source节点的部分block的metadata（元数据）；
- 对于每个要迁移的block，找到离destination节点最近的含有该block replica的proxy节点（不一定是source节点），向其发送copy到destination的指令；
- proxy节点把block数据传到destination；
- destination接受完block数据后，通知namenode更新block的metadata，并原路返回block已迁移完成的信号；
- 重复执行上述步骤，将每一个block迁移到destination。

hdfs rebalance同样需要手动触发，相比redis cluster，其整个迁移的过程是offline的——必须在safe mode模式下进行。

## ClustrixDB rebalance

ClustrixDB是一个闭源的数据库——目的是解决MySQL难以scale的问题，其中一篇[Rebalancer设计文档](http://docs.clustrix.com/display/CLXDOC/Rebalancer)详细的阐述了数据迁移的过程。这里的迁移场景指的是类似于上文Redis Cluster的slot迁移，是将某个replica从一个结点迁移到另外一个结点，下图描述了replica从Node 4迁移到Node 1的过程。

注：
- ClustrixDB sharding后的数据分片，由一个slice和多个replica组成（类比一主多备）；
- 下文的queue可以类比MySQL的binlog，不同的是它除了存储binlog到queue还提供转发binlog和重放的功能；

![ClustrixDB rebalance](https://user-images.githubusercontent.com/4915189/71431435-d1225380-270c-11ea-8a89-657b928f8ded.png)

- Initial State阶段：Node 3和Node 4为含有同一个分片数据的replica；
- Data Copy阶段：在epoch B开始时间，新增了Node 1作为replica（Building状态）和Node 2作为Queue（Store状态）；epoch A之后对于Node 4的新增修改将以类似于binlog的方式同步到Node 2的queue；Node 4的旧有数据将以一致性视图冻结在该时刻，并逐条传输到Node 1的Building replica；
- Queue Replay阶段：旧有数据已经同步完毕，此时将Node 2的queue数据进行重放到Node 1，此时queue仍然接受写入；
- End of Queue阶段：queue的数据重放执行完后，立马转为synchronize queue，即转为store & Forward状态，数据进到queue后同步给Node 1执行，执行完成才返回；
- Queue Flipped阶段：将旧节点Node 4标记为Retired，新节点Node 1标记为Online，epoch B开始的未提交的事务还是提交到Node 4，由queue直接forward到Node 1；
- Final state状态：待epoch B时间开始的transaction都提交后，可以将旧节点和queue都下线。

ClustrixDB的metadata也是[Multi-Version Concurrency Control (MVCC)](http://docs.clustrix.com/display/CLXDOC/Concurrency+Control)的，从epoch B开始意味着metadata发生了变化。为了防止数据不一致，需要在epoch A开始的事务全部提交后再开始epoch B。另外，如果磁盘和网络容量富余，其实上文的queue可以考虑与Node 1放在一起。最后，上文说到的synchronize queue是一个漂亮的设计，这不就是Java的synchronize queue吗？

