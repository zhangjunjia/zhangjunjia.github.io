---
title: 《左耳听风》笔记：管理设计篇
date: 2020-01-15 11:03:25
tags: ['分布式系统设计']
comments: true
categories: ['系统设计']
---

极客时间《左耳听风》专栏读书笔记之管理设计篇。

<!--more-->

## 分布式锁 distributed lock

为什么需要分布式锁，分布式研究者Martin Kleppmann在[How to do distributed locking](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)提到有以下两点，
- Efficiency：防止只需要做一次的工作被重复执行，浪费资源
- Correctness：防止竞态修改资源导致不一致性

分布式锁需要具备以下几个特点，
- 安全性/排他性：任何时候只能有一个客户端获得锁
- 避免死锁：客户端最终一定能获得锁，即使获得锁后客户端崩溃也不会影响后来者获取锁
- 容错性：只要集群中半数以上结点存活，就可以正常加解锁

方案1：Redis分布式锁（RedLock算法，[Distributed locks with Redis](https://redis.io/topics/distlock)）
- 其算法共5个步骤，详见[redis的分布式锁算法redlock](https://zhangjunjia.github.io/2019/08/21/redlock-algorithm/)
- 其底层原理依赖于Redis的NX特性和TTL特性
    - `SET resource_name my_random_value NX PX 30000`
    - `NX`表示不存在才创建，因此只要有客户端在该Redis实例取锁后，其他客户端就会失败
    - `PX 30000`表示key的timeout时间，即使客户端取锁后崩溃，其锁也会在timeout后被释放
    - `my_random_value`必须是一个随机值，在释放锁时使用原子性的Check And Set进行释放，原子性可通过lua脚本实现
- Martin Kleppmann在[How to do distributed locking](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)认为此算法在某些情况不安全（下文详细展开），Redis作者antirez的回应[Is Redlock safe?](http://antirez.com/news/101)很有意思，
    - Martin Kleppmann的方案需要被修改的存储本身具备version自增和校验功能，如果存储本身具备这个功能真的还需要分布式锁吗？
    - 如果要操作的资源不是存储呢？

方案2：zookeeper分布式锁（[七张图彻底讲清楚ZooKeeper分布式锁的实现原理【石杉的架构笔记】](https://juejin.im/post/5c01532ef265da61362232ed)）
- [Apache Curator](https://curator.apache.org/)基于ZooKeeper封装了分布锁服务
- 其底层原理是ZooKeeper的临时顺序节点，以及watch机制
    - 临时特性在客户端断开时触发sessionTimeout，将会导致锁的释放
    - 顺序特性在多个客户端竞争锁时，序号最小的那个客户端才认为获取到锁（需要获取znode下的所有子结点用于判断）
    - 获取锁的结点在使用完锁时，主动删除节点，将触发其他客户端的watch回调，重新进入一轮分布式锁是否获取到的判断


方案3：分布式锁fencing。耗子叔以及Martin Kleppmannd都提到，以上方案都会存在一个问题，客户端取锁后进入Stop The World，在恢复后其实锁已经超时，但客户端仍认为自己持有锁依然去操作共享资源，此时将会导致不一致，如下图所示

![image](https://user-images.githubusercontent.com/4915189/72590334-6b566f80-3938-11ea-9ea4-941ff10507cb.png)

解决方案是使用fencing机制，分布式锁服务在每次取锁成功返回的version需要是递增的，操作存储时存储本身要校验操作者的version是不是最新的——若不是则进行拒绝，过程如下：

![image](https://user-images.githubusercontent.com/4915189/72600359-6d2b2d80-394e-11ea-8128-f62d79847adc.png)

方案4：存储支持version自增和校验功能。但如上文所说，如果存储本身支持version自增和校验功能，还需要分布式锁吗？

- 对于普通update，我们可以使用乐观锁，比如`
UPDATE table_name SET xxx = #{xxx}, version=version+1 where version =#{version};`
- 如果乐观锁失败，我们可以用CAS，比如`
SELECT stock FROM tb_product where product_id=#{product_id}; UPDATE tb_product SET stock=stock-#{num} WHERE product_id=#{product_id} AND stock=#{stock};`

其过程大概如下图所示：

![image](https://user-images.githubusercontent.com/4915189/72600725-27bb3000-394f-11ea-9f68-6c96b340c900.png)

分布式锁总结：每个方案都有trade-off，使用RedLock、ZooKeeper方案，则存在锁过期的问题；使用fencing，则存在分布式锁服务冗余的问题；使用存储本身支持的version管理，则又可能存在性能问题。

## 配置中心 Configuration Management

配置中心，一般指的是软件的动态配置部分，有三个区分的维度：
- 按运行环境分：如开发、预发、线上环境
- 按依赖区分：如依赖基础服务如Redis，如依赖外部服务的URL，如软件内部的依赖
- 按层次分：如IaaS、PaaS、SaaS

配置中心的模型设计，应考虑如下因素：
- 分层：如操作系统层、平台层、应用层，不同层有不同人员负责配置
- 命名空间：需要有namaspace防止应用间的冲突，还需要制定一套命名规范
- 环境差异：同一个key/value，在不同环境的值可以是不同的
- 版本管理以及灰度测试：每一个key/value，都应该进行版本记录便于回滚，同时可以指定该配置灰度的机器范围

配置中心的架构，大致如下：

![image](https://user-images.githubusercontent.com/4915189/72601496-7ddca300-3950-11ea-8134-c643112e15d8.png)

国内比较成熟的开源分布式配置中心：携程的[Apollo](https://github.com/ctripcorp/apollo)

## 边车模式 sidecar

随着微服务的流行，服务需要嵌入越来越多控制层的职责：限流、熔断、日志、服务发现、监视、协议转换。为了实现逻辑和控制的分离，这些控制层职责会被下沉。分别有两种下沉的方式，一是Lib/SDK的方式，二是Sidecar模式。

使用Lib/SDK下沉控制职责，
- 好处：嵌入到代码逻辑，对应用的性能影响较小
- 坏处：Lib/SDK通常和编程语言有关，因此业务逻辑必须使用相同的语言
- 坏处：升级Lib/SDK需要重新打包应用，重新部署所有应用

使用sidecar下沉控制职责，
- 好处：对应用无侵入，逻辑层、控制层可做到分开开发、部署，逻辑层可使用任意编程语言开发
- 坏处：增加服务依赖，增加调用时延，增加运维复杂度（一般是结合docker和kubernates降低运维复杂度）

sidecar服务和应用服务部署在同一结点内（一般是同一机器上，这样通信延迟不会明显增加），具备相同的生命周期，一起创建、一起停止。每个应用服务实例都一一对应有一个sidecar，sidecar可以很方便的对应用服务进行扩展而无需修改应用服务，
- sidecar帮助服务注册到服务发现系统，对其捆绑服务做健康检查，若发现异常从服务发现系统注销捆绑服务
- 当应用服务要调外部服务时，sidecar帮助在服务发现系统中找到对端服务，做服务路由
- sidecar接管进出流量，日志、调用链监控、流控熔断等等都可以放在sidecar实现
- 服务控制系统可以通过sidecar来控制应用服务，如流控、下线等

![image](https://user-images.githubusercontent.com/4915189/74081465-54fc8900-4a8a-11ea-8838-f642af9be652.png)

sidecar在设计上需要注意以下要点，
- service与sidecar的通信是设计重点，千万不要使用对应用有侵入的方式（如共享内存、信号量），建议使用网络通信（通过127.0.0.1通信开销不大）
- service与sidecar的通信协议要兼容原先的service间的通信协议，sidecar与sidecar的通信协议使用更开放和高效的协议
- 业务逻辑不要放在sidecar
- 需要在服务的整体打包、构建、部署、管控设计好，使用上docker和kubernates这类技术
- 小心sidecar的通用功能如重试，有些服务不支持幂等调用，这可能产生副作用
- 应用服务和sidecar可互相传递上下文信息，如应用服务可设置http头告知sidecar最大重试次数、sidecar可在http头告知限流发生

sidecar适合什么场景，
- 无侵入的改造老应用
- 对多种语言混合开发的分布式服务系统进行扩展
- 系统的多应用服务由不同供应商提供，通过sidecar统一通信规范
- 标准化控制面的逻辑，由更专业人员进行开发（分工考虑）

sidecar不适合什么场景，
- 架构并不复杂的时候，使用nginx或haproxy即可；
- 服务间协议不标准；
- 不打算架构为分布式服务系统。

## 服务网格 service mesh

linkerd作者在[What’s a service mesh? And why do I need one? ](https://buoyant.io/2017/04/25/whats-a-service-mesh-and-why-do-i-need-one/)定义了service mesh是什么：
 
> A service mesh is a dedicated infrastructure layer for handling service-to-service communication. It’s responsible for the reliable delivery of requests through the complex topology of services that comprise a modern, cloud native application. In practice, the service mesh is typically implemented as an array of lightweight network proxies that are deployed alongside application code, without the application needing to be aware.

总结来说，
- service mesh是处理服务与服务间通信的基础设施；
- service mesh是一组轻量的服务通讯的网络代理；
- service mesh对于应用是透明无侵入的；
- service mesh用于解耦和分离分布式系统中控制层面的职责；

service mesh本质是一个sidecar集群，[Pattern: Service Mesh](https://philcalcado.com/2017/08/03/pattern_service_mesh.html)介绍了它是如何演化出来的：
- 一开始是最原始的两台主机上进程进行通信；
- 然后分离出网络层来，进程的通信由底层的网络模型完成；
- 由于消费能力不对等，必须在应用层中实现流控；
- 流控功能下沉到了网络层；
- 由于微服务的出现，必须在应用层中实现熔断、服务发现、限流等控制层逻辑，这些逻辑起初是以Lib/SDK的方式实现的；
- 由于Lib/SDK绑定语言、不便于升级的弊端，控制层下沉到sidecar服务；
- sidecar服务集群与管理控制面板，组成了service mesh，如下图；

![image](https://user-images.githubusercontent.com/4915189/74098340-0f0af800-4b52-11ea-9e13-e5718f806d88.png)
service mesh的主流开源方案是linkerd（scala实现，其创始人后面用go和rust实现了另一个版本conduit）和istio。istio的架构如下图：

![image](https://user-images.githubusercontent.com/4915189/74098316-ceab7a00-4b51-11ea-9d63-20d7bdf82969.png)

其中，
- envoy为sidecar服务；
- mixer收集envoy的metrics，通过pilot下发控制规则，通过auth下发安全规则；

service mesh的设计重点，
- 本地sidecar出问题时，能自动切到灾备的sidecar；
- sidecar服务为实例粒度，若上升到一组服务的粒度，进一步整体接入的粒度，那它就成了gateway；
- 能否和kubernates密切结合是关键。

## 网关模式 gateway

service mesh的粒度太细，把粒度粗化到一组服务的级别，职责转为只负责接入，就成了gateway模式。

![image](https://user-images.githubusercontent.com/4915189/74099636-d292c880-4b60-11ea-8fc8-088a51734e4d.png)

如上图，在架构上，gateway模式是一个多层的星形拓扑。gateway一般需要具备以下功能：
- 请求路由：接入请求，路由到后端服务
- 服务注册：开放能力供后端服务注册
- 负载均衡：如何分发请求的策略
- 弹力设计：弹力设计的那些异步、重试、幂等、流控、熔断、监视等都可以实现进去
- 安全方面：SSL加密及证书管理、session鉴权、数据校验、恶意攻击识别
- 灰度发布：对相同服务的不同版本划分不同比例的流量
- API聚合：将多个单独请求聚合成一个请求
- API编排：将前端的api编排能力以插件的方式添加进来

网关的设计重点
- 高性能：使用什么语言实现是重点
- 高可用：集群化、服务化（不停机reload+Admin的API）、持续化（不宕机重启）
- 高扩展：可插拔，如nginx的module

读完本篇有个很大疑问，网关只负责接入流量，那服务的出流量怎么办？即如何访问其他服务。