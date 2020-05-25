---
title: 浅谈MySQL/Redis/Kafka高可用
date: 2020-03-16 20:29:45
tags: ['系统设计', 'MySQL', 'Redis', 'Kafka']
comments: true
categories: ['系统设计']
---

浅谈MySQL/Redis/Kafka高可用设计。

<!--more-->

## 前言

工作中负责的一个有状态(stateful)服务需要实现高可用，借鉴MySQL/Kafka/Redis是如何实现故障转移(failover)的。主要从以下几个方面浅谈MySQL/Kafka/Redis高可用设计：
- 如何replicate数据？
- 如何发现master failed？
- 如何选举/提升(elect)新的master？

## Kafka

Kafka的故障转移，有两个场景：
- Broker出现故障，由于TopicPartition是单Master提供读写的设计，若该Broker上有Master级别的TopicPartition，需要触发该TopicPartition的重新选主；
- Controller负责监控Broker并对其进行故障转移，Controller在Kafka集群中也是单Master，出现故障时需要从剩余Broker中从新选举；

### Broker的故障转移

在Topic创建时，Kafka集群根据分区配置创建多个TopicPartition。每个TopicPartition有且仅有一个leader，有一或多个slave（数量由replicate因子而定）。Kafka使用以下方法将TopicPartition分散到多个Broker，使得TopicPartition尽可能的打散：

- 假设有n个broker；
- 第i个partition的leader副本将被分配到第(i mod n)个broker；
- 第i个partition的第j个follower副本将被分配到第((i+j) mod n)个broker。

往Kafka集群生产数据时，若将ack配置为all，Broker将确保在所有slave拉取到该消息时才返回给producer确认信号，如下图所示：

![image](https://user-images.githubusercontent.com/4915189/77650148-fd689d00-6fa5-11ea-94ba-e701f614c37c.png)
（图片源自[Kafka学习之路 （三）Kafka的高可用](https://www.cnblogs.com/qingyunzong/p/9004703.html)）

leader收到新消息会有落盘动作，slave的IO线程拉取到新消息后，在落盘之前会回复给leader以ACK信号，此时新消息只在slave的内存中。这样设计是在可靠性和性能之间做权衡，因为leader和所有slave全部挂掉的概率是极低的，只要有slave在内存中保有新消息，就会在未来被落盘。关于leader和slave之间的数据同步，笔者在[《Kafka核心技术与实战》专栏笔记](https://zhangjunjia.github.io/2020/01/03/kafka-geekbang-note/)有更详细的介绍。

Kafka集群使用Controller模块负责Broker的故障转移，如下图所示：

![image](https://user-images.githubusercontent.com/4915189/77652048-9f898480-6fa8-11ea-8a91-1f17a638f9ca.png)
（图片源自[Kafka学习之路 （三）Kafka的高可用](https://www.cnblogs.com/qingyunzong/p/9004703.html)）

- Controller在Zookeeper注册watcher，当Broker宕机时Zookeeper会fire事件；
- Controller从Zookeeper读取可用的Broker列表；
- Controller构造宕机Broker需要故障转移的TopicPartition，对于每个TopicPartition：
   - 从Zookeeper获取该TopicPartition的ISR集合；
   - 决定新的leader分配到ISR的某个Broker；
   - 将新leader所在Broker、ISR、leader_epoch等信息写回Zookeeper；
   - 通过RPC直接向新leader所在Broker发送leaderAndISRRequest命令；
   - 原slave与Controller心跳监听到leader变化，改为从leader拉取最新消息。

Kafka针对每个TopicPartition维护了ISR集合，只要slave存在于该集合中就意味着slave与leader的消息延迟在可接受范围内，这个可接受范围是通过消息落后条数、最近一次同步时间来配置的。极端情况下，ISR集合可能为空，这意味着已存活的但不在ISR集合中的slave落后于leader太多。此时若进行slave提升则有丢消息的风险，用户需要在可用性和一致性之间做出选择。

这里引申出另一个问题，Kafka集群为何不使用Zookeeper进行leader选举？
- Broker宕机时，其管理的N个leader角色的TopicPartition都要触发重新选举，如果N太大将给Zookeeper带来非常大的压力，即剩余的Broker同时进行N次leader选举；
- 引入Controller模块可以减轻Zookeeper压力，通过Controller可使得leader尽可能分散到各Broker中。

### Controller的故障转移

Controller模块，是所有Broker借助Zookeeper临时节点选举出来的领导者Broker。它是无状态的，不像Broker需要管理TopicPartition的数据。当Controller宕机时，通过Zookeeper触发重新选举即可。

## Redis

Redis主要谈论的是Redis Cluster的故障转移，关于非Cluster方案的故障转移可参考[【原创】那些年用过的Redis集群架构（含面试解析）](https://www.cnblogs.com/rjzheng/p/10360619.html)。

官方文档[Redis cluster tutorial](https://redis.io/topics/cluster-tutorial)提到：

> The first reason why Redis Cluster can lose writes is because it uses asynchronous replication. This means that during writes the following happens:
> - Your client writes to the master B.
> - The master B replies OK to your client.
> - The master B propagates the write to its slaves B1, B2 and B3.
> 
> As you can see, B does not wait for an acknowledgement from B1, B2, B3 before replying to the client, since this would be a prohibitive latency penalty for Redis, so if your client writes something, B acknowledges the write, but crashes before being able to send the write to its slaves, one of the slaves (that did not receive the write) can be promoted to master, losing the write forever.

从上面这段话我们可以得到Redis Cluster的一些信息，
- master/slave使用异步的方式同步消息；
- 消息写到master后立即返回给客户端，此时slave可能还未同步到新写入的消息；
- 如果master突然崩溃，slave被提升为master，master那部分未同步到slave的消息将永远丢失掉；

那么，Redis Cluster是如何探测master失效，然后提升slave为master的呢？书籍[Redis开发与运维](https://book.douban.com/subject/26971561/)
[Redis cluster tutorial](https://redis.io/topics/cluster-tutorial)的【10.6 故障转移】有关于这方面的详尽内容。

对于master失效检测，需要经历主观下线、客观下线的过程，**只有master角色的node才有参与主观下线、客观下线的权利**。主观下线的主要过程如下：

![image](https://user-images.githubusercontent.com/4915189/77818292-4470a280-710c-11ea-866a-71c4ea525a6d.png)
（PING/PING并标记主观下线）

- 集群中的单一node（假定为A），使用gossip协议遵循一定规则（最近最长未通信原则、通信超时原则），定期主动PING集群中的其他node，正常情况下其他node会立即回复PONG；
- A发出PING后，若未在cluster-node-timeout内收到来自其他node的PONG，则将timeout的node加入到A的pfail主观下线队列中，即A单方面认为其他node已经timeout；

客观下线的主要过程如下：
- PING/PONG会携带1/10其他node的pfail状态信息，通过gossip传播到其他node；
- 任一node收到来自其他node的PING信息时，提取其中的pfail信息，更新到其自身维护的pfail队列；
- 当pfail队列中，有半数以上的node认为某一node已经pfail，且这些主观pfail的消息还未过期(cluster-node-timeout x 2)，则标记失效的master node为主观下线；
- 通过gossip广播消息到集群其他master node，通知它们某个master node已被标记为客观下线。

之所以要半数以上的node投票(majority vote)，是为防止网络分区时，选举出多个master。极端情况下，master node A和集群其他master被划分到两个网络分区P1和P2，经历cluster-node-timeout时间后master node A也会自我标识为failed的状态：
> Similarly after node timeout has elapsed without a master node to be able to sense the majority of the other master nodes, it enters an error state and stops accepting writes.

标记为客观下线后，slave提升为master的过程是怎样的呢？失效master node的slave通过定时任务发现其master失效后，slave会触发以下流程：
- 资格检查：判断与master断线的时间是否长于配置值，若是则不具备提升为master的资格；
- 准备选举时间：获取其他slave的主从复制offset计算排名，offset最大者表示消息和master最接近，排名为第一。排名第一者，延迟1秒触发故障选举；排名第二，延迟2秒，以此类推，这样设计主要是考虑slave选举优先级；
![image](https://user-images.githubusercontent.com/4915189/77825513-c5e42700-7144-11ea-9ada-493814af1df5.png)
- 发起选举：在slave内存中自增集群的全局epoch（在PING/PONG的过程中可以得知集群当前全局epoch），向其他master node广播选举消息；
- 选举投票：其他master node判断该选举消息携带的epoch是否投票过，若是则忽略，否则投上一票，也即一个epoch只能投一票。若该次选举获得半数以上master node的投票，则slave可提升为master；
- 替换主节点：取消复制把自身改为主节点，将原先主节点复制的slot委派给自己，广播信息通知其他master和slave自身已提升为master。

## MySQL

MySQL高可用方案，有官方的Cluster方案，有已经不维护的master-master方案，有Group Replication方案（参见[MySQL · 引擎特性 · Group Replication内核解析](http://mysql.taobao.org/monthly/2017/08/01/)和
[MGR和HAProxy实现高可靠性MySQL集群](https://tmcdcgeek.club/2019/05/24/mgr_haproxy/)），本文主要讨论的是[MHA](https://github.com/yoshinorim/mha4mysql-manager)方案。

关于replicate，MHA支持binlog方案和GTID方案。关于如何监控master失效并提升slave为master，MHA官方文档[Sequences_of_MHA](https://github.com/yoshinorim/mha4mysql-manager/wiki/Sequences_of_MHA)有一份详尽的介绍（以binlog方案为例）：
- mha-manager验证MHA配置的MySQL实例能否正常连接，每个MySQL实例是否结对部署有mha-node，识别出实例中的master角色；
- mha-manager不断监测master是否failed，若是则触发failover流程；
- mha-manager检测其他slave是否更换了追随的master，以及最近是否发生过失败的failover，若是则中断；
- mha-manager识别出数据offset最大的slave A，若failed的master仍能通过SSH链接，将slave A的binlog补齐到和master一致的状态；
- mha-manager提升slave A为新master，为确保提升对业务无影响，需要触发脚本将master的虚拟IP指向到新的master，若不使用虚拟IP可参考[详解Mysql 高可用方案 之 Failover mha](https://juejin.im/post/5cc90ef26fb9a03232198ace)提到的proxy方案；
- 将其他slaves的binlog与新的master对齐，然后change master到新的master。

MHA的问题在于引入了mha-manager的高可用问题，按下葫芦浮起瓢。

## 总结

以上3个方案，极端情况下都可能在故障转移后丢失数据，而且故障转移过程master所负责的服务是不可用的。
- 一类方案是通过中介监控master失效并提升slave，但这引入了中介的高可用问题；
- 一类方案是去中介，所有节点互相连接通过gossip故障转移，其代价是gossip通信将耗费较大带宽。

## 参考文献

[Kafka学习之路 （三）Kafka的高可用](https://www.cnblogs.com/qingyunzong/p/9004703.html)
[Redis开发与运维](https://book.douban.com/subject/26971561/)
[Redis cluster tutorial](https://redis.io/topics/cluster-tutorial)
[详解Mysql 高可用方案 之 Failover mha](https://juejin.im/post/5cc90ef26fb9a03232198ace)
[Sequences_of_MHA](https://github.com/yoshinorim/mha4mysql-manager/wiki/Sequences_of_MHA)
