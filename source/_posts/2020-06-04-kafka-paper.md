---
title: 'Paper阅读：Kafka: a Distributed Messaging System for Log Processing'
date: 2020-06-04 22:02:22
tags: ['Kafka', 'Paper阅读']
comments: true
categories: ['分布式系统']
---

这篇论文是LinkedIn与2011年发表的关于Kafka的论文，从中可以窥探Kafka最源头的设计理念。

<!--more-->

## 总览

论文开篇就介绍到Kafka是：
> a distributed messaging system that we developed for **collecting** and **delivering high volumes of log data** with **low latency**.

Kafka一开始的设计目标就是聚集于收集数据、分发数据、大容量、日志数据、低延迟（高吞吐）。基于此目标，它做出了一些取舍：
- 不保证数据的强一致。`losing a few pageview events occasionally is certainly not the end of the world`，Producer生产时可能丢失数据，Kafka最新版本可通过设置ACK以及callback逻辑做生产失败的容错。`when a consumer process crashes without a clean shutdown, the consumer process that takes over those partitions owned by the failed consumer may get some duplicate messages that are after the last offset successfully committed to zookeeper`，Consumer消费数据时若没有正常提交offset，遇到crash会导致消息的重复投递。
- 为了高吞吐和低延迟做了一些针对性优化。Producer端会batch提交消息，Broker端依赖操作系统的page cache实现`write-through caching and read- ahead`，Consumer端会batch拉取消息。
- Broker端采用多分片设计，使得生产、消费的负载均衡的打到多台机。
- Consumer使用pull模型，由Consumer的消费能力决定拉取消息速率防止压垮进程，便于Consumer进行rewind消费旧的消息。

![image](https://user-images.githubusercontent.com/4915189/83505149-f86d2000-a4f7-11ea-9955-be8e4104cb55.png)
（图1 Kafka设计总览）

如图1，Kafka的三个核心是Producer、Broker和Consumer。论文对其逐一进行介绍。

## Broker

Kafka的Topic的数据，会被划分为多个Partition，这些Partiton会被打散到多台Broker进行存储。这样设计是为了负载均衡，生产、消费的流量均分到了多台Broker机器防止压垮某一台机器。

![image](https://user-images.githubusercontent.com/4915189/83505122-f0ad7b80-a4f7-11ea-967a-2c2b4717e9e9.png)
（图2 Partition的物理表示）

Partition是一个逻辑概念，在物理上它由多个segment文件组成，如图2所示。从图片可以看出每个segment文件存储一定offset范围的消息，segment文件在内存中建立索引。offset是递增的，每条消息都有唯一的offset标识其在segment文件中的偏移位置。Kafka的消息是没有唯一ID的，论文认为唯一ID会增加设计的复杂度，而offset设计既可以满足消息索引需求又足够简单。

Broker收到Producer的消息后，将其append到最新segment文件的末尾。这个append动作不是立即刷盘的，Broker会攒一定数量的消息或者等达到一定时间后才刷盘，刷盘后Consumer才能读取到消息。这个设计虽然能提高吞吐，但如果Broker突然崩溃将导致数据的一致性问题，在最新版本的Kafka通过ISR机制最大程度的减少这种问题的发生。

Broker并不会缓存消息到Java Heap中，它利用操作系统的`sendFile`调用减少内存的拷贝。不使用`sendFile`调用时，Broker提供消费消息的流程如下：
> (1) read data from the storage media to the page cache in an OS
> (2) copy data in the page cache to an application buffer
> (3) copy application buffer to another kernel buffer
> (4) send the kernel buffer to the socket

使用`sendFile`调用可以避免(2)和(3)的两次内存拷贝，假设生产、消费的速率相同第(1)步可能也是不需要的，即数据刷盘后其对应的page cache还未失效可被重用。当然这种极度依赖page cache的设计，在消费进度落后太多的情况下会有问题，部分Consumer拉取冷数据大量占用了操作系统的page cache，使得那些生产、消费相近的Consumer也受到牵连（即步骤(1)必不可少）。

Broker的这种读、写设计，在Partition比较少的情况下，几乎都是顺序IO，这也是它高吞吐的原因之一。但如果Broker上面的Partition急剧增加，维护多个文件的顺序读、写时随机IO将无法避免。另外需要注意的是，消息在单个Partition内是有序的，但Partition之间的消息是没有顺序保证的。

Broker在设计上是无状态的，这使得它可以保持简单。Consumer端需要自己负责消费进度offset的保存，这在Broker滚动清除数据时会有问题，因此它只能做time-based的数据滚动清除，即假定在一定时间内消息一定会被Consumer消费。

## Producer和Consumer

Producer生成消息时，按照随机、指定或者函数计算的策略，将消息投递到Broker。Consumer在消费消息时会有一个消费者组(Consumer Group)的概念，比如2个消费者消费2个Topic的数据。消费的粒度是Partition级别，即一个Topic的其中一个Partition只会分配给一个Consumer，一个Consumer可能会被分配到多个Partition。

Consumer Group内各Consumer分配消费任务的过程称为rebalance，这个过程是没有master参与的，论文认为引入master还需要考虑master崩溃的情况增加复杂度。论文阐述的reblance过程的大概思想如下：
- Consumer监听Zookeeper是否有Consumer/Broker的新增或删除，若有触发rebalance；
- 当前Consumer移除Zookeeper中分配给它消费的Partition占用数据；
- Consumer从Zookeeper获取待消费的Partition列表和待分配任务的Consumer列表，分别对他们进行排序；
- 假设Partition列表为N份，Consumer列表有M个，将N份顺序均分给M个消费者。如将`1,2,3,4,5,6`分成2份，即`1,2,3`和`4,5,6`。
- 当前消费者由上一步计算得知它分配到的Partition列表，再去Zookeeper中检测这些Partition是否被其他Consumer占据了消费权，若是则回到第一步重新开始，这种情况一般是Zookeeper消息延迟导致其他Consumer还未进入rebalance导致的。否则Consumer写Zookeeper，将分配到的Partition列表占用方更新为自身，然后启动pull数据线程开始拉Partition的数据消费。

投递Consumer的策略是at-least-once，Consumer消费完未提交offset后崩溃，会导致消息被重复消费，Consumer端需要自行容错这类问题。这个设计足够简单，避免引入2PC（两阶段提交）实现精准一次消费而使设计变得复杂。

## 总结

Kafka最初的设计理念，就是重吞吐量而牺牲一致性。它是一个优秀的中间件，但如果你需要在关键业务中使用，可以考虑下阿里系的RocketMQ，或者微信系的PhxQueue。

## 扩展阅读

[聊聊page cache与Kafka之间的事儿](https://cloud.tencent.com/developer/article/1488144)
[《Kafka核心技术与实战》专栏笔记](https://zhangjunjia.github.io/2020/01/03/kafka-geekbang-note/)
[Page Cache, the Affair Between Memory and Files](https://manybutfinite.com/post/page-cache-the-affair-between-memory-and-files/)
