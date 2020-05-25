---
title: chronicle-map与apache ignite的使用场景及限制性
date: 2020-05-25 21:11:00
tags: ['Java', 'ChronicleMap', 'ApacheIgnite']
comments: true
categories: ['分布式系统']
---

本文浅谈HashMap从Java Heap中offload的方案考虑.

<!--more-->

现工作负责的一个datanode项目，其本质是一个巨大的分布式hashmap。其含有亿级别的key，value则是用户信息UserInfo。通过hash将该巨大的hashmap分成了多个partition，然后分布到50多台机器上，即每台机器有1至3个partition。partition的数据存放于机器上datanode进程的Java Heap中，这有几个好处：
- datanode进程中的业务逻辑代码直接访问Java Heap处理UserInfo，只有内存访问开销，无反序列化/网络开销；
- datanode进程可以将partition进一步分成多个slot，这样就可以多线程并行去读/写partition的UserInfo数据加速业务逻辑；
- partition数据存放于Java Heap中，datanode进程天生可以基于Heap中的UserInfo对象做各种锁操作保证并发安全。

但这也带来了一些坏处：
- datanode业务逻辑和Java Heap数据绑定在一起，无法在不重启JVM情况下热更新datanode业务逻辑。

上一篇文章[浅谈有状态Java服务热部署方案](https://github.com/zhangjunjia/zhangjunjia.github.io/issues/16)探讨了解决这个问题的一些方案，本文继续讨论此问题——将Java Heap做offload的方案。

## chronicle-map

[chronicle-map](https://github.com/OpenHFT/Chronicle-Map)是Chronicle Software公司开源的一款堆外hashmap，它支持两种内存模式：
- 与JVM进程绑定，数据存放于堆外内存（direct memory），JVM进程退出数据也就没了；
- 不与JVM进程绑定，**数据存放于共享内存**（使用[Ram Drive](https://en.wikipedia.org/wiki/RAM_drive)和MappedByteBuffer实现的共享内存，Linux系统自带的Ram Drive是`/dev/shm/`），JVM进程退出了数据还在；

第二种模式显然比较适合做Java Heap的offload。但对我们的datanode业务而言，Chronicle-Map存在着几个问题：
- Chronicle-Map建议的ValueType数据类型，只适合那种确定长度的业务数据，如每个Value对象由2个int和1个长度在10以内的string组成这样确定性的数据视图。而我们的业务数据，有大量的`int[]`、`float[]`、`String[]`对象，长度有非常大的不确定性，因此无法使用其建议的ValueType数据类型。因此我方业务只能使用实现其建议的ByteReader/ByteWriter接口写自定义数据序列化/反序列化操作，序列化开销对于我方业务频繁需要遍历几百万个Key的场景是无法接受的。
- Chronicle-Map的entrySet全量遍历会产生大量新生代对象，这个GC开销也是不能忽略的。

其实第一个问题也不是不能规避。我们可以自行维护一套内存地址到Java数据结构（UserInfo）的映射关系，在访问第N个属性时再去按需反序列化该属性。但这样又带了新问题，按下葫芦浮起瓢：
- 每个Value数据是不定长的，因此它们的映射关系也是不一样的，这一套映射关系需要能按照一定规则生成，维护好这样一套映射关系有一定的复杂度，而且对于新增/删除数据结构成员并不友好；
- 读直接操作内存地址，在没有锁保护的情况下很容易和写操作冲突，产生难以预期的后果。

综上，chronicle-map虽然好但不适合我们。

## apache ignite

> Apache Ignite® is a horizontally scalable, fault-tolerant distributed in-memory computing platform for building real-time applications that can process terabytes of data with in-memory speed.

[ignite](https://ignite.apache.org/)是apache顶级项目之一，上文是其官方定义，它可以和以下应用扮演同样角色：
- Memcache；
- Redis；
- MySQL；
- ...

ignite支持以下几种模式：
- in-memory：这种情况下，数据是全部in-memory的，这和我们的datanode有点像，在内存不足时是否要触发swap则是optional的；
- in-memory+native persistence：这种情况下，和Redis的AOF模式有点像，write操作更新内存后做append-only操作后立即返回，由后台线程定期去compact这些append-only的log。不同于Redis的是：ignite在这种模式下是支持SQL查询的，且可以根据B+树索引直接定位到DISK的数据记录，且in-memory的数据量是多少也是可配置的。
- in-memory+3rd database：这种情况下，ignite作为一个cache store，接管了对database的read/write操作，即cache模式中的[read-through和write-through](https://docs.oracle.com/cd/E15357_01/coh.360/e15723/cache_rtwtwbra.htm#COHDG5180)。ignite在这种模式下的SQL查询是受限的，它必须先把database的数据全部load到内存。

ignite还有其他强大的特性：
- Queue、Set等数据结构支持（类比Redis）；
- 客户端支持near cache（在业务进程的cache）；
- 支持将计算闭包逻辑从业务端传输到ignite的node结点中运行（把计算搬到了存储结点中）；
- 支持分布式join；
- 支持分布式transaction（2PC，两阶段提交）；
- 支持异步cache接口；
- 支持集群化，非常方便scale，且有高可用方案支持；
- 集群拓扑变化时自动进行数据rebalance；
- 支持对cache对象加锁；
- 对Hadoop、Spark等计算引擎有良好支持；
- 对machine learning有很好的支持；
- 支持多种语言客户端；
- 支持作为微服务通信框架；
- 支持Streaming；
- 支持Kubernetes部署；
- ...

总的来讲，ignite非常强悍而且功能特性非常的多，且有很多production上应用的[示例](https://ignite.apache.org/use-cases/provenusecases.html)。但ignite的以下几点不符合我方的业务需求：
- ignite最小级别的高可用要求每个node的data有一份backup，这相当于总数据量乘以2，我们没有这么多的机器quota，要知道我们现在的数据量已经有几亿个KV了；
- ignite作为server端，客户端与其通信难免会有网络通信、序列化开销，对于我们动辄扫描几百万个key的应用场景，这些开销带来的时延是无法容忍的。
