---
title: Paper阅读:The Google File System
date: 2020-07-08 15:25:29
tags: ['Kafka', 'Paper阅读']
comments: true
categories: ['分布式系统']
---

记录阅读论文Google File System(GFS)的笔记。

<!--more-->

## 设计目标

GFS的设计目标是：
> scalable filesystem：大文件、append写居多
> running on commodity hardware：可容忍硬盘、机器、网络等故障
> data intensive：数据密集

GFS暴露的文件系统接口如下：
- 创建/删除：create/delete
- 读：read
- 写：write/append/snapshot

## 从接口实现看系统架构

### read

在GFS中，文件由1至多个chunk组成，每个chunk的大小是64MB，类似于下面的结构：
```
文件名称：/boo/far（逻辑概念）
文件内容：[chunk_0, chunk_1, chunk_2]（物理概念）
```

论文提到chunk是Linux文件系统的真实文件，GFS中所指的分布式文件是由多个chunk组成的逻辑文件。
>Each chunk replica is stored as a plain Linux file on a chunkserver and is extended only as needed.

![image](https://user-images.githubusercontent.com/4915189/86358259-c3dcb780-bca1-11ea-99d0-f56c957a0571.png)
（图1 GFS架构，摘自论文）

GFS Client读取分布式文件内容如图1所示，
- client向master询问特定分布式文件的特定下标的chunk的信息；
- master在内存中维护`文件名 <> chunk下标数组`的映射，chunk下标数组的元素，存放了该chunk所在chunkserver的机器信息以及该chunk的唯一标识（chunk location）；
  - master在创建chunk时，会为其生成一个64bit的唯一标识，称之为chunk location；
  - 出于高可用、负载均衡等考虑，chunk会被replicate到多个chunkserver；
  - master维护分布式文件目录信息、文件到chunk handle的映射、chunk handle到机器的映射，这些信息称为metadata；
- client将master返回的信息缓存起来，挑选一个“网络距离最近”的chunkserver请求数据；
  - 缓存chunk信息失效后，client会重新向master获取；
  - client会批量读多个chunk的metadata，以减少和master的通信；
- chunkserver接收到数据读取请求时，根据chunk handle定位到文件读取数据返回；
  - chunkserver发现chunk handle不存在时，client应失效对该chunk的metadata的缓存；
  - chunkserver需要维护chunk handle到chunk文件的索引；

读取过程中，client先向master获取metadata，然后再向chunkserver发起真实数据读取请求。master是如何维护metadata的呢？
- 文件名称到chunk信息的映射是维护在内存中的，在create/delete时更新此映射；
- chunk存放在哪些chunkserver是由chunkserver主动上报的，chunkserver天生知道它维护了哪些chunk文件，可以通过HeartBeat上报这类信息，当网络分区恢复或者chunkserver重启时它能让master第一时间感知chunk信息的变化。

### write

![image](https://user-images.githubusercontent.com/4915189/86428940-9aaf3c00-bd20-11ea-8b36-5296662f6c90.png)
（图2 client写数据的过程，摘自论文）

1. client询问要写的chunk的primary replica以及secondary replica所在的chunkserver信息
    - 持有lease的replica称为primary否则称为secondary，如果没有replica持有lease，master会挑选一个replica授予，chunkserver通过HeartBeat延长lease的失效时间；
2. client缓存master回复的信息直至expired或者chunkserver回复不持有lease；
3. client以pipeline的方式将数据推送至所有replica，比如client->C1->C2->C3->C4，pipeline中下一跳的选择是网络距离最近的目标replica，每个replica一收到数据会立即向下一跳转发，数据此时是缓存在内存buffer的还未落盘；
4. 所有replica收完数据后，client通知primary replica将buffer的数据修改按照提交顺序串行落盘。每个数据修改有一个serial number，这个number是单调递增的用于代表落盘的顺序；
5. primary落盘成功后，通知所有secondary以相同serial number的次序落盘；
6. secondary回复primary落盘是否成功；
7. primary回复client自身以及所有secondary是否落盘成功，任一replica的失败都会导致client重试步骤3到步骤7。

append操作和write是相似的，不同点在于：
- 步骤4，primary尝试append数据到末尾，假设append会导致chunk超过64Mb，primary会将当前chunk补齐到64Mb，同时告知所有secondary进行补齐，最后返回错误告知client应该在下一个chunk index去append数据。否则，primary写数据到chunk文件末尾，写成功后通知secondary在哪个chunk的哪个offset写数据，append操作在secondary变成了指定offset的write操作。
- 步骤7，任一replica的失败同样会导致重试，这可能导致部分replica有多份需要append的数据，client需要实现幂等读取来容忍这种情况。

### create

master通过新增chunk来扩充分布式文件，新增chunk的设计要点是：
- 新增的chunk应该放在哪几台chunkserver？其原则是磁盘利用率最大化、机架容灾、负载均衡。3个replica至少应该分布到2个不同的机架，磁盘空间富余的chunkserver会优先选择，近期创建chunk较少的会优先选择（大量chunk同时创建在同一chunkserver意味着会立即带来较大的写负载）。
- 新增的chunk文件可以认为是一个空文件，只有在真正写的时候才触发磁盘空间申请。

### delete

client发起delete，只是在master层面将分布式文件做重命名，例如将文件重命名增加一个`TRASH`的后缀。这些被标识TRASH的分布式文件有一个缓冲期，缓冲期仍可以像正常文件一样访问他们或者回滚，缓冲期后他们会被真正清除。chunkserver通过HeartBeat感知自身负责的chunk文件是否还有分布式文件与其关联，无关联的话chunkserver会将这些chunk文件真正清除。这种延迟删除的垃圾回收机制有以下好处：
- delete操作是可回滚的；
- 对于delete请求，master只需要修改分布式文件名称即可返回，这无疑大大减轻master的负载；
- master扫描metadata并清除TRASH，chunkserver感知并清除chunk文件，这些流程都成为了常规的后台线程，这样一旦有失联的chunkserver重新加入集群，它们也能正确清除文件。

### snapshot

本质上是一种copy-on-write，master通过失效已授予的lease使得client写失败触发重新获取lease，这给了master去通知待写chunk所在的chunkserver去做chunk文件copy的机会，然后用新的copy文件来提供写。

## CAP理论

下面尝试从CAP理论的视角来看GFS的设计。

### consistency

对于master，任意涉及到文件namespace、文件到chunk映射修改的client操作都会写operation log、更新master的metadata内存，且同步到远端机器的operation log才算写成功，论文没有提及具体如何实现，应该也是某种二阶段提交。client写操作对metadata的修改是强一致的，完成后所有client都可以看到最新修改。

master有一种shadow的角色，它的借助operation log重放metadata，会轻微落后于master。在master宕机时client可以从shadow读取metadata，它的metadata是弱一致的。

![image](https://user-images.githubusercontent.com/4915189/86441384-b3c6e580-bd3e-11ea-806b-c5ccf9c56723.png)
（图3 chunk的一致性模型，摘自论文）

GFS对于chunk的一致性有两种定义：
- consitent：客户端永远能看到一致的数据，无论他们从哪个replica读取数据；
- defined：当某个chunk发生修改后，client能看到刚刚修改的所有数据。

图3是GFS在几种写下的一致性保证：
- 串行写：defined
- 并发写：consistent + undefined（client端无法确认最终到底是哪个写导致的数据变化）
- 追加写：defined but interspersed with inconsistent（append写只保证at least one，可能append了多次数据，且有的replica会有padding数据）
- 写失败：inconsistent

每个chunk文件在被修改时其chunk version都会自增，写操作会识别出那些chunk version落后的chunk并跳过写，这些落后的chunk会在垃圾回收过程被回收。每个64Mb的chunk文件的每个64Kb数据block，都会记录一个checksum（持久化到专门的logging文件），读取数据时需校验checksum是否正确来判断数据是否损坏。

master对于分布式文件的新增、删除是强一致性的。GFS在master有一个文件锁的设计，对文件加写锁可以防止并发创建同名的分布式文件，对目录加写锁可以防止目录下的文件新增和删除。

### availability

GFS的设计中master是单点的，当监控系统监测到master故障，会从远端存放operation log的机器挑选一台快速启动顶替。故障转移的过程中，master是不可用的，任何依赖master的服务在故障转移过程也是不可用的。master和chunkserver都被设计成可以快速启动的。以master为例，它启动时读取最近一次checkpoint文件（B-Tree格式）和最近一次checkpoint时间点之后的增量operation log文件实现快速启动。

写chunkserver的过程中，如果secondary失败则触发重试，若primary失败则该写操作会被failed掉，由客户端决定是否要重试写。

### partition tolerance

GFS的chunk默认有3个replica，其replicate数量是可调整的。写操作需要所有replica写成功才返回，这对读是有好处的，只需要读任意一份replica即可获取最新数据。当某些replica所在chunkserver宕机、磁盘故障时，GFS会触发re-replication，使得replica数量重归3份。GFS还会进行rebalancing，将replica从磁盘紧张的chunkserver迁移到磁盘富余的chunkserver。

## 总结

GFS是单master多chunkserver的设计，master通过HeartBeat感知chunkserver的数据视图并缓存在内存中。读、写请求都需要先通过master的内存视图定位到具体chunkserver，在向具体chunkserver进行真实数据交换。写chunkserver时，其一chunk replica所在chunkserver会被选为lease，这在某种程度上也是master权限的下放。

## 问题讨论

读paper很重要的一点是要把有问题的地方搞懂，因此提问题无疑是非常重要的。以下是搬运自[Charles的技术博客：GFS](http://oserror.com/distributed/gfs/)关于论文的一些问题：
>7.1 为什么存储三个副本？而不是两个或者四个？
>7.2 chunk的大小为何选择64MB？这个选择主要基于哪些考虑？
>7.3 gfs主要支持追加，改写操作比较少，为什么这么设计？如何设计一个仅支持追加操作的文件系统来构建分布式表格系统bigtable？
>7.4 为什么要将数据流和控制流分开？如果不分开，如何实现追加流程？
>7.5 gfs有时会出现重复记录或者padding记录，为什么？
>7.6 lease是什么？在gfs中起到了什么作用？它与心跳有何区别？
>7.7 gfs追加过程中如果出现备副本故障，如何处理？如果出现主副本故障，应该如何处理？
>7.8 gfs master需要存储哪些信息？master的数据结构如何设计？
>7.9 假设服务一千万个文件，每个文件1GB，master中存储元数据大概占多少内存？
>7.10 master如何实现高可用性？
>7.11 负载的影响因素有哪些？如何计算一台机器的负载值？
>7.12 master新建chunk时如何选择chunkserver？如果新机器上线，负载值特别低，如何避免其他chunkserver同时往这台机器上迁移chunk？
>7.13 如果chunkserver下线后过一会重新上线，gfs如何处理？
>7.14 如何实现分布式文件系统的快照操作？
>7.15 chunkserver数据结构如何设计？
>7.16 磁盘可能出现位翻转错误，chunkserver如何应对？
>7.17 chunkserver重启后可能有一些过期的chunk，master如何能够发现？

以下是我个人补充的一些问题：
1. 为什么不用RAID？
    - RAID不是commodity hardware，无法做到机器级别、机架级别的容灾；
1. 写失败后chunk数据不一致GFS是如何处理的？
    - application-level会检测数据中的checkpoint，来判断写入数据是否一致；
    - 对于append新增的padding，application-level会识别并丢弃；
    - 对于append被多次触发，application-level通过unique record id来幂等消费；
1. data flow的pipeline的拓扑相较tree的拓扑有何好处？
    - pipeline下一跳结点选择的原则是“网络最近”，这种拓扑能使得out带宽利用到极致，得到比tree拓扑更大的网络吞吐；
1. 单master设计有什么好处？
    - 不用维护多master的共识，使得master编程简单化，Kafka中Controller、Coordinator也是单master的设计；
1. GFS为什么不对chunk文件做cache？
    - chunk文件普遍比较大，client基本是以streaming的方式去读，重复读一个文件的概率不大，热点文件交给page cache缓存就够了；
1. consistent but undefined是如何发生的？
    - 在并发append时：GFS may insert padding or record duplicates in between. They occupy regions considered to be inconsistent and are typically dwarfed by the amount of user data.
    - 在并发write时：If a write by the application is large or straddles a chunk boundary, GFS client code breaks it down into multiple write operations.
1. read、overwrite数据时检测出checksum错误会触发什么后续操作？
    - client接收到error，从其他replica读；master对该chunk replica重新replicate，完成后通知corrupt的replica删除；
1. master为什么不持久化chunk location？
    - chunkserver拥有final wordview，对于硬盘故障等导致的chunk丢失能主动感知；chunkserver级别的事件非常多（leave、dead、rename等），这类事件都会导致location变化，若都触发落盘master的I/O可能存在瓶颈；
1. master的operation log为什么需要checkpoint？
    - 类似于Redis的aof机制，定期checkpoint可以减少append-only文件的大小便于故障时快速启动master；
1. lease机制的作用是什么？
    - 将master的部分权限下放到chunkserver，指定的chunk从chunkserver中挑选一台primary出来做一些核心工作（写指令的排序）；
1. 创建chunk时，该chunk放置到哪台chunkserver有什么考虑因素？
    - 磁盘使用较少，最近创建chunk较少，散步到不同的机架；
1. chunkserver如何限制clone数据的带宽？
    - 限制从源replica读数据的带宽；
1. 为什么要使用垃圾回收清除文件？
    - 假设master主动delete时chunkserver宕机，这无疑增加master的设计复杂度，且这种同步删除的动作也加重了master负载，垃圾回收清除可以认为是异步的；
1. 如何识别stale的replica？
    - 每次获取lease时，所有alive的replica的chunk version都会被master增加，落后的chunk version认为是stale的；
1. data flow为什么不经过master结点？
    - master是单点设计，要尽可能减小其负载；
1. master为什么要定期扫描metadata？
    - re-replication的考虑，找出哪些replica需要重新replicate；
    - 垃圾回收的考虑，找出哪些file需要过期清除；

## 参考文献

[Google File System论文](https://research.google.com/archive/gfs-sosp2003.pdf)
[Charles的技术博客：GFS](http://oserror.com/distributed/gfs/)
[分布式系统笔记(3)-GFS](http://wulc.me/2019/01/20/%E5%88%86%E5%B8%83%E5%BC%8F%E7%B3%BB%E7%BB%9F%E7%AC%94%E8%AE%B0(3)-GFS/)
[从 GFS 失败的架构设计来看一致性的重要性](http://blog.itpub.net/31562044/viewspace-2646753/)
[GFS: Evolution on Fast-forward](https://queue.acm.org/detail.cfm?id=1594206)（强烈推荐阅读这一篇，GFS早期开发者关于其演讲的对话）
