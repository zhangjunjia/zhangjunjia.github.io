---
title: 谈谈MQ | 与Page Cache的爱恨情仇
date: 2020-10-09 14:32:25
tags: ['Kafka', 'Paper阅读']
comments: true
categories: ['分布式系统']
---

Kafka和RocketMQ有很多围绕Page Cache的设计，本文带你一探究竟。

<!--more-->

论文[Paper阅读：Kafka: a Distributed Messaging System for Log Processing](https://zhangjunjia.github.io/2020/06/04/kafka-paper/)提到，Kafka Broker若通过`read`调用提供数据给Consumer需要经历以下4个步骤：
- (1) read data from the storage media to the page cache in an OS
- (2) copy data in the page cache to an application buffer
- (3) copy application buffer to another kernel buffer
- (4) send the kernel buffer to the socket

Kafka通过`sendfile`调用规避了步骤(2)和(3)，如果要读的数据也在Cache中，则步骤(1)也是不需要的，这就是Kafka高吞吐量的秘密之一。文章[Efficient data transfer through zero copy](https://developer.ibm.com/articles/j-zerocopy/)详细阐述了`read`和`tranferTo`的差别，概括来讲就是避免了user-space和kernel-space的内存拷贝以及减少user到kernel的来回切换。

![image](https://user-images.githubusercontent.com/4915189/93546442-5a617080-f995-11ea-8adc-80fa8e19e47d.png)

（图1 引用自[Efficient data transfer through zero copy](https://developer.ibm.com/articles/j-zerocopy/)）

在partition较少的情况下，这种模型性能非常优异。Producer写完Page Cache就返回了（底层是`pwrite`系统调用），由Kafka配置的刷盘间隔时间/条数调用`flush`刷盘，Consumer在和Producer的lag不大的前提下也是从Page Cache可以直接取到数据返回，图2虚线框表明了这种情况。

![image](https://user-images.githubusercontent.com/4915189/94356704-d78e9300-00c3-11eb-94bb-b22a14bc3174.png)

（图2 一个partition文件 vs N个partition文件）

但如果一个Broker上有1W甚至是10W级别的partition文件在同时写(producer)和读(consumer)呢？这会带来什么问题？
- 写时，N个文件各自虽然是在顺序写，但在`flush`刷盘时站在OS的视角变成了随机写（如图2）
- 进一步的，随着文件增多，`flush`的随机IO对写的吞吐量影响越来越大（寻址时间、磁头移动时间）

针对此问题，RocketMQ从存储模型上做了优化。单Broker支撑大量级的partition（在RocketMQ中称为Queue）时，写依然能做到顺序IO，如下图3所示。

![image](https://user-images.githubusercontent.com/4915189/94389931-c5742980-0183-11eb-9ce2-eef5fb355baa.png)
（图3 引用自[RocketMQ存储实现分析](http://www.daleizhou.tech/posts/rocketmq-store-commitlog.html)）

Kafka在单Broker上，会同时打开N个文件用于消息的生产，N的数量是该Broker上partition的数量。RocketMQ在单Broker上，只会打开一个MappedFile文件，所有queue（等同于Kafka的partition）的消息生产顺序追加到这个文件中，该文件的大小固定为1G。RocketMQ在新建MappedFile时，会做一个预热操作，其关键代码如下：
```java
public void warmMappedFile(FlushDiskType type, int pages) {
    // ...
    for (int i = 0, j = 0; i < this.fileSize; i += MappedFile.OS_PAGE_SIZE, j++) {
        byteBuffer.put(i, (byte) 0);
        // ...
    }
    // ...
    this.mlock();
}
```

预热过程做了以下事情：
- 将1G的MappedFile通过mmap映射到虚拟内存地址空间；
- 通过`byteBuffer.put(i, (byte) 0)`触发[Demand Paging](https://en.wikipedia.org/wiki/Demand_paging)，将文件的内容真实映射到Page Cache；
- 使用mlock锁定该文件的Page Cache，防止被OS置换到swap空间；

预热提前占用Page Cache，相比Kafka的`pwrite`按需占用Page Cache的好处是：
- 节省user和kernel来回切回的时间，mmap后读写只需要内存寻址；
- 节省disk映射到Page Cache的时间，预热后disk的block和page cache已经形成对应关系，消息生产时一定能命中，不需要有磁盘IO（mlock进一步保证了”一定能命中cache“）；

由于只有一个MappedFile文件提供写，因此Kafka单Broker在大量级partition写时随机IO的问题得到了解决。但这带来了另外一个问题，消费者消息时如何从MappedFile定位到其需要的消息，不可能去做全文件扫描吧？

MappedFile用于存储真实消息Record，RocketMQ维护了另外一个数据结构ConsumerQueue来索引真实的消息。单个ConsumerQueue文件存储30W条到MappedFile文件的消息Record的索引，便于消费者定位真实消息。但这不岂不是带来了新的问题，数据读取需要二次IO，最坏的情况下读MappedFile还会带来随机IO？
- 最近一个MappedFile和ConsumerQueue，都是mmap映射在Page Cache中的，只要消费者和生产者的lag不大，很大概率能从Page Cache读到需要的消息；
- 如果消费者的lag太大，RocketMQ建议从slave读取数据（具体细节待展开），有效规避了lag落后太大的消费者污染Page Cache的问题。

参考文献：https://www.jianshu.com/p/771cce379994
