---
title: 谈谈MQ | 读取数据
date: 2020-11-03 14:06:16
tags: ['Kafka', 'Paper阅读']
comments: true
categories: ['分布式系统']
---

本文谈谈Kafka和RocketMQ读取数据的差别。

<!--more-->

## Kafka读取数据

![image](https://user-images.githubusercontent.com/4915189/97523900-50904b80-19de-11eb-9cd8-397b8e2f6126.png)
（图1 Kafka读取数据流程）

Kafka读取数据如图1所示。
- 只有leader副本提供数据读取（写也是leader副本提供，读写不分离）
- consumer和replica需要告诉leader副本从哪个offset开始读、读多少内容返回
- leader副本从索引文件中定位符合offset要求的最小offset，但由于Kafka是稀疏索引，所以还需要从前一步确定的offset向后扫描log文件找到符合要求的真实offset，然后从该offset开始读取数据返回

Kafka从log读记录的效率受Page Cache的影响，这个在[上一篇](https://github.com/zhangjunjia/zhangjunjia.github.io/issues/23)已经提到了。Kafka从索引文件确定offset，是一个二分查找的过程，在旧版本的Kafka，这个过程是这样的：
```java

  private def indexSlotRangeFor(idx: ByteBuffer, target: Long, searchEntity: IndexSearchEntity): (Int, Int) = {
        // 第1步：如果当前索引为空，直接返回<-1,-1>对
        if(_entries == 0)
          return (-1, -1)
    
    
        // 第2步：要查找的位移值不能小于当前最小位移值
        if(compareIndexEntry(parseEntry(idx, 0), target, searchEntity) > 0)
          return (-1, 0)
    
    
        // binary search for the entry
        // 第3步：执行二分查找算法
        var lo = 0
        var hi = _entries - 1
        while(lo < hi) {
          val mid = ceil(hi/2.0 + lo/2.0).toInt
          val found = parseEntry(idx, mid)
          val compareResult = compareIndexEntry(found, target, searchEntity)
          if(compareResult > 0)
            hi = mid - 1
          else if(compareResult < 0)
            lo = mid
          else
            return (mid, mid)
        }
    
    
        (lo, if (lo == _entries - 1) -1 else lo + 1)
}
```

Kafka的index文件是通过mmap映射到Page Cache的，上述二分查找代码，对Page Cache是不友好的。

```
page number: |0|1|2|3|4|5|6|7|8|9|10|11|12 |
steps:       |1| | | | | |3| | |4|  |5 |2/6|
```

假设index文件的大小是13个Page，in-sync replica和consumer大概率都是读取最后的一个Page。如上所示，这时二分查找Page的序号是：#0,6,9,11,12。之所以先从#0开始读，是要确保读取offset不能小于index文件的最小位移。

```
page number: |0|1|2|3|4|5|6|7|8|9|10|11|12|13 |
steps:       |1| | | | | | |3| | | 4|5 | 6|2/7|
```

最后一个Page随着时间的推移总会被写满，这时会新增#13这个Page。如上所示，此时二分查找page的顺序就变成了#0,7,10,12,13。问题在于，Page Cache是遵循LRU淘汰策略的，Page 7大概率会因为长时间没使用而被淘汰了，此时的二分查找就会产生Page Fault。单个index文件page fault还能接受，Broker上有N个index文件page fault这个代价就高了。有没有一种策略，使得对于较新的消息的二分查找过程，尽可能不产生page fault呢？

Kafka官方给出的解决方案是：冷热分离。

![image](https://user-images.githubusercontent.com/4915189/97548775-8519fc80-1a0a-11eb-9473-aabb698f8dee.png)
（图2 index索引项冷热分离）

假设index文件有10W个稀疏索引，Kafka将最末尾的2个Page大小（8192字节）的索引定义为热区（换算成offsetindex是1024个稀疏索引）。Kafka将待查找offset和热区的第一个索引项做offset比较，若判断到待查找offset在热区，则在热区内做二分查找，否则在冷区内做二分查找。这背后的思想很朴素，最近2个Page大小的热区，大概率还没有被LRU策略淘汰掉。其代码如下：

```java
protected def _warmEntries: Int = 8192 / entrySize

private def indexSlotRangeFor(idx: ByteBuffer, target: Long, searchEntity: IndexSearchEntity): (Int, Int) = {
  // ...

  def binarySearch(begin: Int, end: Int) : (Int, Int) = {
    // binary search for the entry
    var lo = begin
    var hi = end
    while(lo < hi) {
      val mid = (lo + hi + 1) >>> 1
      val found = parseEntry(idx, mid)
      val compareResult = compareIndexEntry(found, target, searchEntity)
      if(compareResult > 0)
        hi = mid - 1
      else if(compareResult < 0)
        lo = mid
      else
        return (mid, mid)
    }
    (lo, if (lo == _entries - 1) -1 else lo + 1)
  }

  val firstHotEntry = Math.max(0, _entries - 1 - _warmEntries)
  // 和热区的第一个索引比较，判断是否要在热区内二分查找
  if(compareIndexEntry(parseEntry(idx, firstHotEntry), target, searchEntity) < 0) {
    return binarySearch(firstHotEntry, _entries - 1)
  }

  // 如果小于index文件最小索引退出
  if(compareIndexEntry(parseEntry(idx, 0), target, searchEntity) > 0)
    return (-1, 0)

  // 在冷区二分查找
  binarySearch(0, firstHotEntry)
}
```

热区定义为8192字节是一个经验数值，它对应1024个offsetindex索引项，可索引大概4MB大小的消息。最大情况下，这8192字节会包括3个Page，例如`[Page1:2048字节][Page2:4096字节][Page3:2048字节]`。这个数值太大，Page可能已经被LRU策略淘汰，仍会产生page fault那就没价值了；这个数值太小，那就降级为冷区二分查找，仍会出现所提的page新增时page fault的问题。

## RocketMQ读取数据

![image](https://user-images.githubusercontent.com/4915189/97953016-2b367f80-1dda-11eb-88c2-2b906b095ca5.png)

（图3 RocketMQ读取数据）

有别于Kafka的partition级别的leader/follower，RocketMQ是Broker级别的master/slave，slave全量冗余master的数据。读取数据时，如果满足一定条件（数据太旧）会从slave读取，实现了某种程度上的「读写分离」。

```java
// org.apache.rocketmq.store.DefaultMessageStore#getMessage
long diff = maxOffsetPy - maxPhyOffsetPulling;
long memory = (long) (StoreUtil.TOTAL_PHYSICAL_MEMORY_SIZE
    * (this.messageStoreConfig.getAccessMessageInMemoryMaxRatio() / 100.0));
getResult.setSuggestPullingFromSlave(diff > memory);
```

什么情况下从slave读取数据？如上所示，

> maxOffsetPy 为当前最大物理偏移量，maxPhyOffsetPulling 为本次消息拉取最大物理偏移量，他们的差即可表示消息堆积量，TOTAL_PHYSICAL_MEMORY_SIZE 表示当前系统物理内存，accessMessageInMemoryMaxRatio 的默认值为 40，以上逻辑即可算出当前消息堆积量是否大于物理内存的 40 %，如果大于则将 suggestPullingFromSlave 设置为 true。
> 引用自：http://objcoding.com/2019/09/22/rocketmq-read-write-separation/

`setSuggestPullingFromSlave`为true后还会结合其他开关配置项决定是否从slave读取数据，具体可以参考上面引用的链接，但核心逻辑就是上面的代码。consumer无论是从master还是slave读取数据，都需要经历：
- 从consumerqueue读取位移数据（consumerqueue是mmap在内存中的）
- 根据位移数据回源到MappedFile读取数据，该MappedFile大概率还在page cache中未被LRU淘汰（如果已经LRU淘汰掉了，能切到slave读冷数据可以避免page fault，这就是核心思思）

从slave读取数据的价值是可以最大化利用master的page cache，使得冷数据的读取不影响到master的性能。slave同步master的数据则与上述过程不同，由于是Broker级别的replicate，因此不需要区分consumerqueue，所有master的数据都需要同步到slave。这个过程中，slave上报的offset作为游标，master根据该游标不断往slave推送新数据，slave接受数据后更新游标重复此过程。

## 参考文献

- RocketMQ主从同步源码分析：http://objcoding.com/2019/09/21/rocketmq-Master-slave-ha/#top
- RocketMQ主从读写分离机制：http://objcoding.com/2019/09/22/rocketmq-read-write-separation/

