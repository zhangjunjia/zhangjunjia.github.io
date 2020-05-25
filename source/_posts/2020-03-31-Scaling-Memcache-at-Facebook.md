---
title: Paper阅读：Scaling Memcache at Facebook
date: 2020-03-31 20:33:29
tags: ['Paper阅读', 'Memcached']
comments: true
categories: ['系统设计']
---

记录阅读论文[Scaling Memcache at Facebook](https://www.usenix.org/system/files/conference/nsdi13/nsdi13-final170_update.pdf)的笔记。

<!--more-->

## 背景介绍

[Scaling Memcache at Facebook](https://www.usenix.org/system/files/conference/nsdi13/nsdi13-final170_update.pdf)是Facebook团队2013年的一篇论文，讲述Facebook如何使用开源的memcached构建分布式内存KV集群，以响应billion级QPS。

Facebook作为社交网络服务基础设施，需要满足：
- 近似实时通信；
- 实时聚合多个来源的内容；
- 读取/更新热点的共享内容；
- 可伸缩以处理billion级用户并发。

为满足以上需求，Facebook从单机(memcached)、集群(cluster)、区域(region)、跨区域(cross-region)这4个方面以bottom up的方式讲述他们是如何scale的。memcache作为一个cache集群：用户大量读QPS，相比之下写QPS非常小；读的数据有多个后端源（MySQL/HDFS等），使用memcache集群做为query cache缓存可以极大的降低对后端存储系统的负载。Facebook使用一种cache aside的模式维护缓存，如图1：

![imagex](https://user-images.githubusercontent.com/4915189/78672026-a9997480-7912-11ea-9d8b-6837cd7f498e.png)
（图1 缓存更新模式）

[缓存更新的套路](https://coolshell.cn/articles/17416.html)提到这种模式在极端条件下会出错：A会话读完数据库网络阻塞，B会话删除并失效缓存，A会话将脏数据写到缓存。这种极端条件概率比较低，cache aside是在更复杂方案与简单但小概率出错之间的取舍。

在进入正文之前，需要厘清以下概念（见图2）：
- memcached：开源memcached技术，在文中指运行时的单台实例；
- cluster：指多台memcached组成的最小单位的集群，memcached之间相互不通信，由client端使用consistent hash将数据分布到多台memcached；
- region：多web server集群和多cluster集群组成frontend clusters，共享一个storage cluster组成一个region；
- cross-region：多个region，每个region分布在不同地理位置。只有一个region的storage cluster是master角色，其他的是slave角色，从master同步数据。

![image](https://user-images.githubusercontent.com/4915189/78672689-933fe880-7913-11ea-8557-74d5a3fac5bf.png)
（图2 以上概念的整体架构图示）

## memcached单机优化

对于开源的memcached，Facebook贡献给了社区的hashtable自动扩容、多线程加全局锁等优化。下面讲解一些未贡献给社区的。

其一是支持UDP通信，通过UDP实现的的multiget，要比TCP性能优异13%；

其二是动态的slab allocator。memcache预分配有多种size的slab桶，size从64 byte指数增长到1M不等，每个size的slab桶的个数是一定的。发起set调用时，根据value大小分配到满足条件的最小size的slab桶中。当负载增加时，某个size的slab桶可能会内存不足导致频繁该slab桶频繁的LRU，而其他slab桶因为命中率比较低其实是空闲的。Facebook做的优化是，检测slab桶中即将LRU的item，是否比其他slab桶的LRU item的使用次数要多20%，若是则保有该item从其他slab桶腾挪内存。

其三是，short-lived key的清理。memcached对于已经expired的short-lived key的清理，是在get调用或LRU时触发的，这样可能导致short-lived key的堆积，Facebook使用circular buffer来加速其清理。circular buffer有固定的桶数量（比方说10个桶），每个桶代表1秒，short-lived key根据其expired时间将key分配到某个桶中。每1秒清除circular buffer头结点上的所有key，同时向前进一格，如此循环反复。

其四，是使用shared memory解决memcached的热部署问题，这点在[Fast Database Restarts at Facebook](https://research.fb.com/wp-content/uploads/2016/11/fast-database-restarts-at-facebook.pdf)有详细的阐述。

## cluster最小单位集群

cluster的主要目标是get调用的低延迟，以及cache miss时不造成storage服务的load剧增。cluster主要围绕client端做优化，client是无状态的，表现为织入到web server的SDK，或独立运行的进程mcrouter（代理程序）。

![image](https://user-images.githubusercontent.com/4915189/78765359-79a5ac00-79ba-11ea-8e1e-fd8fa31c4ed9.png)
（图3 web server与memcached的通信示意图）

web server client如何减少延迟：
- web server client将所需key构造为DAG（有向无环图）描绘依赖关系，对于能并发请求的数据batch化获取减少fetch调用次数，经统计每次batch平均有24个key。
- web server client使用UDP（见图3）绕过mcrouter直接向memcached实例get数据，以实现低通信延迟。峰值负载下，0.25%的UDP的get请求失败，失败原因80%是因为丢包、超时。UDP的get请求错误会被当成cache miss，client从数据库load数据但不更新cache，因为get错误表明网络情况不佳，若还更新cache则加重网络负载。相比使用TCP执行get请求，有20%的通信延迟降低。
- mcrouter负责set和delete请求（见图3），和web server结对部署，使用TCP和需要通信的memcached建立长连接。这样设计是因为set和delete请求需要TCP的可靠重试，以及不需要每个web server thread都和memcached直接建立长连接，由mcrouter统一接管减少长连接数量可节省CPU、内存、带宽。
- all-to-all拥塞控制：UDP的get请求，是一种all-to-all通信模式，每个web server client都可直接与cluster内的N台memcached通信，这带来的潜在问题是网络拥塞。当每个client发送大量get请求，交换机、路由等网络设备将出现瓶颈。Facebook实现了一种划窗式(window)拥塞算法控制请求并发度，window大小表示request并发数，即每个request都要占据window的一个坑位并在request结束才释放坑位。window设置得太小，并发度低近似于串行，响应时间长；window设置得太大，并发请求多导致拥塞，响应时间也变长了。client与每个memcached的window是单独控制的，类似于TCP的拥塞控制算法。

web server如何减轻对存储的负载？
- stale sets问题，在并发写memcached被重排序时会发生。论文设计了一个lease机制，在get调用cache miss时会返回一个token（这个token可以设置成每N秒只生成一个），client端从存储系统load到数据后将token和数据一起set到memcached，若token校验通过则写成功，否则写失败，这样就避免了stale sets问题。
- thundering herds问题，是一个key被重度读写导致，写频繁失效缓存导致不断读存储。假设某个key刚被失效，此时有M个client读取发现cache miss，若M个client都去读存储系统那么将给其带来极大压力。首先，delete调用会使memcached为该key生成的token立即失效，相当于memcached又有配额为该key生成token；其次，get调用cache miss时，memcached可以只返回token给一个client，其他client返回一个短时间通知其休眠；最后，拿到token的client负责读盘set缓存，其他client短暂休眠后也就能读到数据了。
- lease机制使得高峰读数据库从17K/s降至1.3K/s。memcached的key被客户端失效时，可以打上一个stale标记延期清除，这样在get调用时可以顺带返回过期的数据由客户端决定是否需要重新更新cache。多数情况下，过期数据是无害的，这能在高峰时期降低系统负载。
- pool池化设计。将频繁访问且cache miss代价较小的key，与较少访问但cache miss代价昂贵的key，划分到不同的memcached pool，防止相互影响。key默认存放的pool叫wildcard pool，若在默认pool找不到key，则key可能存在于其他dedicated pool（专用pool）。论文没有阐述client是如何定位到不同pool查询key的。
- pool的replication设计。假设单机memcached需要处理1M request/sec，每个request返回100个key。为了降低负载，策略一是将一半的key分到另外一台机，但这样单机的请求还是1M request/sec，只是返回key数量变成了50个。单个request返回100还是50个key，没有实质性区别。策略二是将数据replicate到另外一台机，这样每台机只需承担500K request/sec，单机负载就大大降低了。

web server如何做错误处理？
- 小部分机器请求failed时，表现为get没有response，Facebook设计了Gutter来容错。当get调用failed时，请求会重试提交到Gutter pool。Gutter占cluster总机器1%，是一个stand by的pool，且为了减轻数据库负载是允许返回stale数据的。当出现hot key问题时，部分request将频繁失败，使用Gutter来有效分流，避免hot key压垮memcached（上文的pool replication也是这个目的）。如果没有Gutter容错，所有failed的get调用都会触发读盘，因为负责该key的memcached已经crash了。这是不同于rehash的设计，若使用consistent hash的方法，陡增的流量极可能把哈希环的下一个节点压垮。
- 如果整个cluster需要offline，则切流量到其他cluster。

## region区域单元化

当cluster不断扩容，网络拥塞、热key问题不断加剧，再扩容时问题已经得不到缓解，此时需要split成多个frontend cluster了。一个frontend cluster，由一个web server cluster和一个memcached cluster构成。多个frontend cluster，共享一个storge cluster(database)，组成一个region。

![image](https://user-images.githubusercontent.com/4915189/79035537-29b12a00-7bf2-11ea-82e9-def08fc08928.png)
（图4 mcsqueal失效缓存）

region内部如何失效缓存
- 提交SQL带有要失效的key，mcsqueal（database级别，见图4）监听数据库的commit log，解析出delete事件广播给region内所有mcrouter失效缓存。web server在delete后会直接失效其关联cluster的缓存，减少其关联cluster的stale data停留时间以提供read-after-write。mcsqueal方案设计缘由，在跨region设计章节有阐述。
- 减少失效package rate：mcsqueal将delete batch化提交到专用的mcrouter服务器，由其去分发到真实memcached。
- 为什么不由web server触发缓存失效，分散的web server比收敛到数据库commit log的mcsqueal做batch低效，会造成更多package。且web server对于配置错误导致的错误路由无法重试，commit log+mcsqueal则是可靠的可重放的。

regional pool：多个frontend cluster共享一个专用的pool称为regional pool，避免在每个cluster中replica低频访问的数据。
- 数据量大访问量很小的，适合共享到regional pool。访问量大的，适合每个cluster都存一份。若regional pool的机器failed了，Gutter又派上了用场，且regional pool占据每个cluster的wildcard的25%机器。
- 冷启动：前提是data replicate到多个cluster。从其他warm cluster获取数据加速冷启动，直至新cluster的hit rate达到预设的一个稳定值。这可能带来不一致性的问题。冷cluster先触发update，紧接着又一client从冷cluster取数据（冷启动未结束，实际是从warm cluster取），warm cluster此时还没收到mcsqueal失效缓存指令返回脏数据。delete操作可设置hold-off时间（2秒）拒绝掉add操作（可能是从warm cluster同步过来的脏数据），client发起add失败意味着要去数据库重新fetch以避免上述问题。delete操作如果被2秒后才同步到warm cluster执行，client还是有可能拿到脏数据，相比warm up这个代价可接受且概率低。

## cross-region跨区域

演变到multi region的原因是，用户可接入到更近的region降低latency、容灾考虑和电费考虑。多个region中，一个region的storage master负责读写，其他region的storage  cluster是read-only的（数据通过MySQL replication同步）。cross-region很容易带来一致性问题，这主要是主从数据库集群lag太大导致的。主要考虑两种情况的写操作对缓存一致性的影响。

write from master region：使用MySQL同步+mcsqueal触发失效cache是必要的，如果通过web server去触发其他region失效，数据有可能还没同步到其他region。

write from non-master region：web server发起写可能影响key k，如何避免该web server随后request的k的脏读？
1. 在regional pool设置marker rk；
2. 写操作路由到主库；
3. 删除local cluster的key k；
4. 从库mcsqueal消费写操作时，失效本地region的key k，更新最新数据到数据库；
5. 第4步为完成时，如果rk存在，get k被路由到master region。

（并发写key k仍然会导致脏读，但概率较小，相比带来的好处可容忍）

## 结语

这篇paper有许多值得学习借鉴的，很多关于trade off的推敲，能设身处地的看到他们是怎么想的。

另外值得一提的是，paper对于数据监控也是非常重视的，如请求百分比与server参与数、请求百分比与包大小，以及其p50、p75、p95等数据，做监控可以从这里学习和借鉴思想。

## 参考文献

[Scaling Memcache at Facebook](https://www.usenix.org/system/files/conference/nsdi13/nsdi13-final170_update.pdf)
[缓存更新的套路](https://coolshell.cn/articles/17416.html)
[How Facebook Scaled Memcache ?](https://efficientcodeblog.wordpress.com/2017/11/05/how-facebook-scale-memcache/)
[Scaling Memcache in Facebook 笔记（一）](https://zhuanlan.zhihu.com/p/20734038)
