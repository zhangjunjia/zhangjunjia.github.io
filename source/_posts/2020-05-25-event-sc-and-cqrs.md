---
title: 浅谈event sourcing和cqrs
date: 2020-05-07 21:07:14
tags: ['CQRS', 'EventSourcing']
comments: true
categories: ['系统设计']
---

本文浅谈event sourcing和cqrs的一些认识.

<!--more-->

## Event Sourcing

Martin Fowler在[Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)提到：
> Event Sourcing ensures that all changes to application state are stored as a sequence of events.
> The key to Event Sourcing is that we guarantee that all changes to the domain objects are initiated by the event objects: Complete Rebuild, Temporal Query, Event Replay.
> A system in use during a working day could be started at the beginning of the day from an overnight snapshot and hold the current application state in memory.

概括来说，Event Sourcing有别于CRUD直接操作数据源，只记录数据的状态变化(state event)，通过replay这些event可以得到最终的数据状态视图。它的优点是Complete Rebuild（重新生成状态视图）, Temporal Query（查询历史视图，类似Git查看某个版本数据视图）, Event Replay（新模块可重放event满足自身需求）。在event积累太多的情况下，从头开始replay的耗时将难以接受，可以通过增加Snapshot记录中间状态来解决此问题。

什么时候会用到Event Sourcing？
- 需要做audit trail的时候，即需要审计追踪所有的状态变化；
- 需要借助这些event来debug系统的时候，由于其可重放特性可重现问题；
- 和cqrs结合做读写分离。

## CQRS(Command and Query Responsibility Segregation)

CQRS的想法很朴素，在CRUD模式read/write都是操作同一个数据源，CQRS把write的数据源和read的数据源分开。通过Command模块写到write库，write库的数据异步同步到read库，以供Query模块查询数据。CQRS的优点是数据库分离成了read库和write库，这样他们就可以各自scale了，不存在相互拖累的情况。分离之后，我们可以自行选择更适合的方案实现read库和write库，比如Apache Cassandra实现write库，Elasticsearch实现读库。

Martin Fowler对[CQRS](https://martinfowler.com/bliki/CQRS.html)的评价是较为负面的：
> For some situations, this separation can be valuable, but beware that for most systems CQRS adds risky complexity.

## Event Sourcing + CQRS

这两者经常会被结合起来使用，[codecentric AG: CQRS and Event Sourcing Applications with Cassandra](https://www.slideshare.net/planetcassandra/codecentric-ag-cqrs-and-event-sourcing-applications-with-cassandra)提到了一种两种结合使用的pattern，如下图：

![image](https://user-images.githubusercontent.com/4915189/81551856-1c37bd00-93b5-11ea-94fa-62a167b93f51.png)
（Event Sourcing + CQRS）

上图中，
- Event Store使用Apache Cassandra实现；
- Query Store使用ElasticSearch实现；
- Command Model异步触发Event Processor更新Query Store，具体实现如下：

![image](https://user-images.githubusercontent.com/4915189/81569729-3d5ad680-93d2-11ea-88c2-1666a0295ab5.png)

- Command Model需保证写Event Store和投递消息到Kafka是transaction的；
- Spark Job处理Kafka中的Event将最终数据产出到ElasticSearch；

在需要生成新的数据视图时，只需要新建Spark Job直接重放处理Event Store中的数据，然后将结果写到Query Store中即可。

这种Event Source+ES的组合能同时享受两者的好处，但同时也引入了问题：
- Query Store是最终一致性的，如果要依赖最新状态去做决策抱歉这做不到，如`update table set a = ? where a = ?`这类操作；
- Kafka只支持at least once投递，在产生重复event时消费端必须能够容错；
- Command Service必须能保证并发写的顺序性，并在重放时依然保持该顺序；Kafka的partition间是无序的，顺序写在实际被消费时顺序可能错乱；
- .....

## Reference

[Event Sourcing in practice](https://ookami86.github.io/event-sourcing-in-practice/)
[Event sourcing, CQRS, stream processing and Apache Kafka: What’s the connection?](https://www.confluent.io/blog/event-sourcing-cqrs-stream-processing-apache-kafka-whats-connection/)
[Clarified CQRS](http://udidahan.com/2009/12/09/clarified-cqrs/)
[Building Scalable Applications Using Event Sourcing and CQRS](https://medium.com/technology-learning/event-sourcing-and-cqrs-a-look-at-kafka-e0c1b90d17d8)
[Event Sourcing pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)
[Command and Query Responsibility Segregation (CQRS) pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs)
[Martin Fowler: Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)
[codecentric AG: CQRS and Event Sourcing Applications with Cassandra](https://www.slideshare.net/planetcassandra/codecentric-ag-cqrs-and-event-sourcing-applications-with-cassandra)
[A CQRS Journey by Microsoft](http://msdn.microsoft.com/en-us/library/jj554200.aspx)
[Martin Fowler: CQRS](https://martinfowler.com/bliki/CQRS.html)
