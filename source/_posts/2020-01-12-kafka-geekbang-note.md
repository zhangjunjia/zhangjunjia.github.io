---
title: 《Kafka核心技术与实战》专栏笔记
date: 2020-01-03 22:00:32
tags: ['Kafka']
---

本文是极客时间专栏《Kafka核心技术与实战》的阅读笔记。

<!--more-->

## Kafka的三层模型

![image](https://user-images.githubusercontent.com/4915189/70886991-c6363780-2017-11ea-9b16-c455e0daf769.png)

- 第一层：主题Topic。主题是承载消息的逻辑容器，物理上通过多个分区来实现。
- 第二层：分区Partition。一个主题的消息按规则分散（比如轮询、哈希）存储在多个分区，单个分区内的消息是有序的，分区间的消息没有顺序关系。分区还分为leader和follower，leader才对外提供服务（producer写入、consumer消费）并记录消息位移offset，follower用于灾备。消费者以一个组（consumer group）的方式消费多个分区的数据，分配每个消费者消费哪些分区leader的过程称为rebalance，每个消费者自行记录单个分区的消费位移（consumer offset）。
- 第三层：消息record。存储在分区内的最小单元信息。

## Kafka的几个重要版本

- 0.9.0.0版本：增加基础安全认证，使用Java重写消费API，引入Kafka Connect
- 0.11.0.0版本：幂等性Producer API、事务API，对Kafka消息格式做了重构

## kafka的重要参数

![image](https://user-images.githubusercontent.com/4915189/70970163-9b5fe800-20d8-11ea-955d-1949f4889d4f.png)
![image](https://user-images.githubusercontent.com/4915189/70970212-bc283d80-20d8-11ea-9c1d-1e4bd5772adf.png)


## 分区策略

- 轮询策略：轮询写到每个分区
- 随机策略：随机写到每个分区
- Key-ordering策略：消息指定了key的，会被放到同一个分区，保障了单分区的有序性

## 压缩、解压策略

Producer压缩、Broker保持、Consumer解压

- 吞吐量：lz4 > snappy > zstd & gzip
- 压缩比：zstd > lz4 > gzip > snappy
- 带宽：snappy最多，zstd最少
- CPU：压缩时snappy多，解压时gzip多

## 丢消息问题

- producer应该使用带回调的producer.send(msg, callback)而不是producer.send(msg)，前者在丢消息可以在callback进行处理
- 消费者应该在消费消息后再提交位移，且不要开启自动提交，而应该用自动提交；
- broker端应该设置factor参数，将消息多存几份防止丢失；
- producer设置acks = all
- producer设置retries为一个比较大的值防止网络抖动导致的失败
- 禁用unclean的broker leader选举
- 关闭consumer的自动提交位移

## producer对TCP连接的管理
- 创建producer时，它会连接bootstrap.servers的所有Broker
- producer会定时请求更新元数据，判断到连接未建立则会触发创建
- 发送数据时，同上
- 关闭有两种，用户主动关闭，空链路被kafka释放

## 拦截器

- 可用于客户端监控、端到端监控、消息审计等；
- producer可在send之前、send完收到ack触发拦截方法；
- 消费者可在消费前、消费后commit触发拦截方法；

## __consumer_offsets
- 早期版本将消费者位移数据保存在zookeeper，但高频的读写zookeeper使得其成为瓶颈点
- 保存的记录为key/value，key为`<Group ID, 主题名, 分区号>`，消息体为位移数据
- 当kafka集群的第一个consumer启动时，kafka会自动创建位移主题
- kafka使用compact策略定期删除过期的位移数据，防止撑爆硬盘

## consumer group
- consumer提交位移时，其实是向coordinator所在broker提交位移
- 消费者组注册、成员管理也是由coordinator管理
- 如何确定消费者组的coordinator
  - partitionId=Math.abs(groupId.hashCode() % __consumer_offsets的总分区数)
  - 找出给分区leader副本所在的broker
- 大部分重平衡都是由于consumer被认为已经挂掉被kafka剔除组导致的，如何防止？
  - 延长会话
    - session.timeout.ms建议设为6秒，延长会话存活时间防止被误认为consumer死亡
    - heartbeat.interval.ms建议设为2秒，值越小能越快感知进入重平衡
    - **以上两值，consumer被认为死亡至少经历了3次心跳**
  - 延长消费时间
    - max.poll.interval.ms，两次poll的间隔如果大于这个值consumer会主动离开组，这可能是消费逻辑太重导致的，适当延长该值
  - 排查是否FULL GC

## 消费者端多线程设计（KafkaConsumer为单线程）
- 主线程负责消费数据提交位移，心跳线程负责探活
- KafkaConsumer不是线程安全的
- 方案1：消费者端多个线程，每个线程是一个KafkaConsumer（受限于topic_partition分区数）
- 方案2：消费者端一个KafkaConsumer线程，poll到的消息丢给线程池消费（可能导致消息重复消费、不利于提交位移）

## CommitFailedException
- poll之后的消费时间超过max.poll.interval.ms，consumer触发LeaveGroup，此时必然会提交位移失败（0.10.1.0版本之后），解决方案
    - 优化消费逻辑
    - 增加max.poll.interval.ms
    - 减少max.poll.records
    - 消费者端使用多线程消费（但引入多线程提交位移的负责度）
- 消费者组和standalone的消费者的groupid冲突，也会导致这个错误

## 消费者管理TCP连接
- 创建KafkaConsumer时不会创建TCP连接，以下3个时机才会发起TCP连接
    - 发起 FindCoordinator 请求时（发给负载最小的Broker，使用完后关闭）
    - 连接协调者时（连接coordinator）=> 心跳、Rebalance相关
    - 消费数据时（消费要消费的leader副本所在broker）=> 数据消费、元数据相关

## 消费者组位移
- 自动提交可能会导致重复消费，假设每5秒自动提交一次，在两次提交中间发生重平衡就会导致这个问题
- commitSync会阻塞消费者，失败时会自动重试
- commitAsync是异步操作，而且可以带回调，失败了不重试（因为此时位移值已经不是最新的了）
- 大部分情况用异步提交，在consumer要关闭前用同步提交
- kafka支持一次取多消息如5000条，每消费100条手动提交一次位移

## consumer group的消费监控

consumer lag指的是滞后未消费的消息数。假如生产了100W条消息，但当下只消费了80W条，那么lag为20W条。监控方法有三种：kafka的consumers-group脚本、comsumer的java api、自带的jmx监控指标（优选）。

## 副本机制

kafka的replica本质是一个只能追加写（append）的日志。kafka在创建分区时，会根据replica参数创建多个分区副本，分区副本分leader副本和follower副本两种，分布在不同的broker，他们的关系如下图：

![image](https://user-images.githubusercontent.com/4915189/70912772-a02c8980-204f-11ea-8643-b0d48cf9741f.png)

针对具体一分区的读/写，都会定位到leader副本。follower副本并不向外提供读取的功能，它们的作用只会在leader副本crash时进行重新选举用到。kafka的副本，没有类似于其他分布式系统的一些好处：
- 副本可提供读，读的能力得到扩充；
- 可根据客户端地理位置分配距离较近的副本提供读，加速读取。

但kafka的副本也规避了不能read-your-writes的问题。如果写到分区A，但读的是分区B，分区A、B是异步同步，此时读B可能读不到最新的数据，如果保证能读到即时更新则为read-your-writes。

kafka维护了一个ISR副本集合，领导副本重新选举时从这个集合中进行选择（normal情况），leader副本必会存在ISR集合中。follower副本与leader副本的时间差若小于replica.lag.time.max.ms则会被加到ISR集合，否则会被从ISR集合中踢出。极端情况下，ISR集合可能为空，这意味着leader副本crash了且所有follower副本都“落后”了replica.lag.time.max.ms时间，这种情况意味着丢失数据较严重。此时进行的领导者选举称作unclean选举，需要unclean.leader.election.enable为true时才开启。

## broker的请求处理模型

broker的socket模型为[reactor模型](http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf)，reactor负责accept请求，然后dispatch给不同的worker进行处理，大致如下：

![image](https://user-images.githubusercontent.com/4915189/70974586-0e6e5c00-20e3-11ea-8b6f-061ba7136691.png)

专栏提到更细致的线程模型如下：

![image](https://user-images.githubusercontent.com/4915189/70974621-234aef80-20e3-11ea-9465-ae83e6d74c63.png)

（专栏的这张图片有不严谨之处，最终的响应队列如何能直接返回结果给客户端呢？）

网络线程池read()完数据，生产给共享队列，IO线程池取数据消费。请求分两种：一种是数据类，一种是控制类。数据类比如PRODUCE、FETCH等请求，需要落盘或读盘，比较特殊的是当PRODUCE请求的ack设置为all时，在当前leader副本数据落盘后还需要等待其他follower副本落盘成功的消息才返回给客户端，此类PRODUCE请求会被放置到purgatory队列中（延迟队列）。控制类请求有诸如角色变更、停止replica。

![image](https://user-images.githubusercontent.com/4915189/72348031-69ac6200-3714-11ea-87c9-d445e7349d01.png)

（matt33博客的这张图比较靠谱）

数据类、控制类实质上是两套不同的处理流程（可简单理解为两个抽象队列），他们各自有acceptor、网络线程池、IO线程池，即他们的入端口都是不同的。

## kafka重平衡

什么情况下会触发消费者组(consumer group)的重平衡：
- 新的消费者通过指定group.id加入组
- 已有的消费退出组（主动退出、崩溃导致的心跳timeout）
- 消费者组关联的分区数、主题数发生变化

consumer group的重平衡，需要broker端的协调者组件协调，kafka内部实现了一个状态机协助状态转移：
![image](https://user-images.githubusercontent.com/4915189/71159642-fcc2bb00-2280-11ea-83c9-3674506d08aa.png)
- 进入PreparingRebalance，意味着触发了重平衡，所有消费者都需要重新参与一次重平衡
- Stable意味着重平衡完成
- Dead意味着这个组的一些元数据被清除了

kafka内部维护了一个_consumer_offsets的topic，一个consumer group消费的全部主题的offset数据，存在该topic的同一个partition，该partition的leader副本所在broker，即为该group的协调者。

从consumer的视角来看，它们参与重平衡的过程如下：
- 程序刚启动，或者收到了协调者组件含**REBALANCE_IN_PROGRESS**的心跳response（如果是这种情况需要先把当前未提交的位移数据提交）
- 向协调者组件发起加入组(JoinGroup)请求，协调者组件会回复ACK信号；特殊的是，一般第一个发起JoinGroup的consumer会被协调者组件选为leader consumer，协调者组件回复的ACK会携带上所有发起JoinGroup的consumer信息
- 向协调者组件发起SyncGroup请求，leader consumer的请求会带上分区分配方案，其余的consumer则是一个空消息
- 协调者组件将重平衡分配方案回复给每个consumer

对分区消费的并行度有疑问，查资料后整理如下：
![image](https://user-images.githubusercontent.com/4915189/71161512-727c5600-2284-11ea-816a-0488b3d93976.png)

一个topic下的一个分区只能由一个consumer消费，但反之并不成立，一个consumer可能分配到多个topic_partition。假设分组订阅的topic下的partition总数为N，消费者组的消费者数最好不要超过N，多出来的消费者不会分配topic_partition是一种浪费。

## kafka的控制器（controller）

在Zookeeper的协助下协调和管理整个Kafka集群。多个Broker竞争创建zookeeper的/controller，第一个创建成功的即为controller；当现有的controller宕机时，各broker监听到该事件触发重新选举（创建/controller）。它主要有以下职责：
- 主题管理（创建、删除、增加分区）
- 分区重分配
- preferred领导者选举（避免部分broker负载过重而提供的一种更换leader的方案）
- 集群成员管理（新增broker、broker主动关闭、broker宕机，/broker/ids/下的临时节点）
- 元数据服务（从zookeeper同步最新元数据，同步最新元数据给其他broker）

其内部线程设计如下：
![image](https://user-images.githubusercontent.com/4915189/71415497-f4122080-2696-11ea-92b9-4060d033b866.png)

- 多个zookeeper事件（异步处理）放到queue，由单线程顺序处理防止竞态；
- 控制类请求有另外一条通道，将比queue中的事件高优处理，如StopReplica请求；

## 高水位和Leader Epoch

![image](https://user-images.githubusercontent.com/4915189/71415605-769ae000-2697-11ea-92a9-faa2fc36bca0.png)

- 高水位（high water mask，简称HW）：表征已提交消息和未提交消息的分界，这里的未提交是指该message未被全部follower副本replicate——大于等于HW的均未被replicate
    - leader副本的HW即为分区的HW
    - follower副本的HW表征其与leader副本的同步情况，其值 = min(收到的leader的HW, follower的LEO)
- 日志末端位移（log end offset，简称LEO）：表征待写入消息的位置位移，新的消息来临时将写入LEO指向的位置，然后LEO自增1
    - leader副本同时保存有follower的LEO，用途：leader的HW = min(缓存的follower的LEO，leader的LEO)

![image](https://user-images.githubusercontent.com/4915189/71431213-50af2300-270b-11ea-8af6-8146d902e255.png)

- 当producer生产消息0时，leader的LEO被设为1
- 此时follower来fetch消息（offset为0），leader更新remote LEO为0（offset的值），leader的HW更新为min(remote LEO, leader LEO)即为0
- follower收到fetch的消息0，LEO自增1，更新HW为min(follower的LEO，leader的HW)，即为0
- follower继续fetch消息（offset为1），leader更新remote LEO为1（offset的值），leader的HW更新为min(remote LEO, leader LEO)即为1
- follower收到fetch的空消息（leader没有新消息了），更新HW为min(follower的LEO，leader的HW)，即为1

可以看到，leader的HW需要在第二次RPC时才更新，且在HW更新的response返回给follower前若follower宕机，则follower重启后LEO会被截断为HW导致未提交的消息丢失，此时若leader也正好宕机则会导致消息的彻底丢失，如下图：

![image](https://user-images.githubusercontent.com/4915189/71431323-0c705280-270c-11ea-92c0-de96d67b89ce.png)

[KIP-101](https://cwiki.apache.org/confluence/display/KAFKA/KIP-101+-+Alter+Replication+Protocol+to+use+Leader+Epoch+rather+than+High+Watermark+for+Truncation)提出了利用Epoch解决该问题，follower在重启后向leader获取最新的LEO防止错误截断，如下图：
![image](https://user-images.githubusercontent.com/4915189/71431336-25790380-270c-11ea-8301-3e582ff3c1cb.png)

## 常见问题
1. 为何使用MQ
    - 异步通信（调用解耦、故障隔离）
    - 流量的削峰（防止流量压垮）
    - 消息的持久化（可重试，可重复消费）
1. 与其他MQ的对比
    - RabbitMQ支持多协议，非常重量级，更适合于企业级开发
    - Redis的MQ支持，适合于存小消息，且可能丢消息
    - ZeroMQ是一个代码库，需要自己设计mq通信模式，可能丢消息
    - ActiveMQ支持多协议，类似于ZeroMQ，它能够以代理人和点对点的技术实现队列
    - kafka的显示特点：顺序写、push and pull、消息可重复消费、水平扩展、replica
1. Kafka delivery guarantee
    - At most once：设置producer为异步发送
    - At least once：可能会导致消息的重复投递
    - Exactly once：每个producer在创建时将会被分配一个PID，broker收到数据后将会检测<PID, TOPIC, PARTITION>对应的sequence是否增加，是则接受消息，否则丢弃消息。这种机制只能针对单个分区实现幂等，且要求producer不能宕机
1. 物理上如何存储
    - 每个topic-partition组合为一个文件夹，文件夹中存有多个segment，segment的命名为第一条消息的offset+kafka后缀，且伴随有segment的索引文件
1. push vs pull
    - 生产时push，由于kafka是顺序追加，因此可以做较高吞吐量的写入；消费时pull，由客户端自己去决定要pull多少，不至于压垮客户端
1. topic的partition是如何分配的
    - 假设有n个broker
    - 第i个partition的leader副本将被分配到第(i mod n)个broker
    - 第i个partition的第j个follower副本将被分配到第((i+j) mod n)个broker
1. produer的ACK机制是如何保证的
    - acks = all
    - producer将消息给到leader副本，leader副本将消息写到log
    - ISR副本中的所有follower副本PULL到新消息立即回复ACK给leader，此时消息还在内存中，这算是性能和持久化的一个折中平衡，所有follower同时挂掉的可能性很低
1. leader副本挂了是如何重新选举的
    - kafka并非借助zookeeper的临时节点进行重新选举的，因为如果挂掉的broker上面有多个partition将会导致zookeeper负载非常的大。其重选举是由controller角色的broker从ISR集合中挑选的broker作为新leader（具体实现待考究）
1. kafka是如何实现读写负载均衡的
    - partition均可能均匀的分发到各个broker
    - partition是最小并发粒度提供读写，不至于使流量集中压在一台broker上
1. kafka在网络传输层面的优化
    - producer并发每次send调用都将消息发送到broker，而是按时间或量积攒后批处理发到broker
    - broker也不是每收到一条消息就flush落盘，而是先写page cache，如果生产、消费速率相当此时消费者可能从cache直接取到消息绕开读盘，其缺点也由replica机制规避
    - kafka使用sendfile调用实现segment传输的zero copy
    - produce、consume传输的都是压缩的数据
    - kafka支持avro、protocol buffer等序列化方式对消息进行序列化，进一步减少传输的数据量大小
1. kafka的事务保障
    - 跨session的幂等写入，producer中间故障后恢复重写依然可以保证幂等
    - 跨session的事务恢复，producer中间故障后恢复的新实例可以保证旧事务的commit或abort
    - 跨多个topic-partition的写入，要么全部成功，要么全部失败，不会有中间状态
    - 注意事项
        - 需要在producer的配置文件配置唯一的transaction.id
        - consumer不保证一个已commit的事务的所有消息都会被消费，原因有：consumer不一定订阅全部topic，consumer可以使用seek从任意位置消费

## 最终总结

![image](https://user-images.githubusercontent.com/4915189/71614560-5a42fa00-2be7-11ea-9a9f-f30a025b6381.png)

