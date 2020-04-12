---
title: 《左耳听风》笔记：性能设计篇
date: 2020-02-15 20:20:26
tags: ['系统设计']
comments: true
categories: ['系统设计']
---

极客时间《左耳听风》专栏读书笔记之性能设计篇。

<!--more-->

# 性能设计
## 缓存 cache

本篇主要讲解了缓存读取更新的三种设计模式，cache章节的图片取自[A beginner’s guide to Cache synchronization strategies](https://vladmihalcea.com/a-beginners-guide-to-cache-synchronization-strategies/)。

模式其一，cache aside。其特点是cache本身不与storage打交道，cache中item的新增由应用调用触发，其过程如下：

![image](https://user-images.githubusercontent.com/4915189/74585594-07979300-5019-11ea-85ed-ebcee5b003af.png)

- miss：应用读cache发现缓存不存在，应用从数据库加载记录写入到cache，需要注意如果数据库也读不到最后设置某个占位符到cache防止因为不存在的key导致频繁读盘
- hit：从cache取值返回
- update：更新数据库，然后覆盖cache

图片中的update的方案：更新数据库，然后覆盖cache。这可能存在问题，假定以下时序：
- A更新数据库；
- B更新数据库；
- B覆盖cache；
- A覆盖cache（BOOM，脏数据）

另一个update方案：先更新数据库，再删除cache。也存在问题，假定有以下时序：
- cache已失效；
- A读cache，发现cache不存在；
- A读数据库，网络拥堵；
- B更新数据库；
- B使缓存失效；
- 网络拥堵结束，A将数据写到cache（BOOM，脏数据）
- 总结：以上时序出现概率特别低，因为读操作一般远快于写操作（需要加锁）。但还是有可能发生的，业务需要能容忍，cache需要加过期时间，这是在不动用分布式锁下的较简单方案（Facebook的方案）。

模式其二，read/write-through，程序不直接和storage打交道，由cache代理负责缓存更新，如下：

![image](https://user-images.githubusercontent.com/4915189/74585915-27c95100-501d-11ea-87ad-9c80fa8bca6b.png)

![image](https://user-images.githubusercontent.com/4915189/74587953-741f8b80-5033-11ea-86a2-1527ec0b6391.png)

模式其三，write back，是基于r/w through的优化，将写批量化提交，缺点是未提交的写可能丢失。

![image](https://user-images.githubusercontent.com/4915189/74587969-94e7e100-5033-11ea-8018-1ad3817d47c7.png)

需要注意的是，LRU是把无序的key-value数据结构变成有序的，在读写时都需要加锁修改数据结构，在高并发时可能成为瓶颈。

## 异步处理 asynchronize

弹性设计讲了异步通讯，异步处理是指收到上游任务后立即返回一个确认信号，然后使用PULL模型或PUSH模型（需要考虑消费者的更多信息防止投递不出去或压垮消费者）将任务分发给下游消费者处理。

异步处理一般会搭配另外一个设计模式event sourcing（事件溯源）。event sourcing不直接修改结果数据，而是把对数据的操作存储为一个个不可变的event，通过顺序重放event即可得出最终结果。

异步处理也可用于处理分布式事务，如A给B转账。
- A扣款，生成扣款凭证；
- 凭证发到B，B收款，B对凭证和收款的处理是幂等的；
- 转账失败需要事务补偿；

异步处理设计需要有以下考量：
- 异步处理完成需要通知发起方；
- 发起方定时检查那些没有回传的任务，需要异步处理系统支持幂等；
- 事务需要补偿；
- 强一致不适合使用异步处理；
- 异步处理需要监控队列堆积；

## 数据库扩展

读写分离
- 写库容易出现单点故障
- 需要强一致性的还是得落在写库上

CQRS(Command and Query Responsibility Segregation)
- command只返回执行状态，会修改数据
- query返回结果数据，但不修改状态
- command和query分离，提高系统扩展性，将command转为event sourcing可使得写无状态化

![image](https://user-images.githubusercontent.com/4915189/74600725-6f5ce500-50d0-11ea-87e4-3b75d7c7b8a9.png)

sharding是解决数据库太大的问题，把单体库按照某个规则分为多个库。分片的方式其一是按业务（需要仔细评估业务），其二是按哈希（扩展时会有重哈希的问题）。sharding后，需要有一个数据访问层解析SQL将任务分发给多个库，同时数据访问层还需要聚合多个库的结果返回给调用方。

根本的解法，还是得将数据库、微服务从单体库拆分开。

## 秒杀 flash sales

第一道关，带简单逻辑的CDN（需要和运营商沟通，亚马逊目前有Lambda）。100W用户经过CDN这第一道关后，只放一定比例的用户到数据中心，这个比例值是动态算出来的。

第二道关，数据中心的应对真实流量，之前所讲的弹性设计都可以在这里用上。

CDN玩法非常适合那些用户有地域特征分布的。

## 边缘计算 edge computing

边缘计算是为了降低数据中心架构复杂度，把一部分计算逻辑分到离用户较近的边缘节点。其关键技术有两个：API Gateway、Serverless/Faas。