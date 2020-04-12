---
title: 聊天室高并发架构概要
date: 2020-02-09 20:25:32
tags: ['系统设计']
comments: true
categories: ['系统设计']
---

简单总结下我理解的聊天室的高并发架构概要设计。

<!--more-->

![image](https://user-images.githubusercontent.com/4915189/74101810-b00ca980-4b78-11ea-897c-d8b416eb6cab.png)

- client在页面初始化时，先访问scheduler服务获取可用的gateway列表，然后长连接gateway接入聊天室服务集群；
- scheduler服务应设计为异地多活，通过DNS路由给不同scheduler服务集群；
- scheduler收集所有gateway的metrics，根据HTTPDNS信息、gateway负载信息决定要返回哪些gateway；
- scheduler长连接gateway列表的第一个gateway，若失败则尝试连接列表的下一个直至连接成功，若列表的gateway都连接失败则重新向scheduler获取gateway列表（根据聊天室返回不同类型gateway，gateway资源是隔离的）；
- scheduler以stick connection的方式和gateway连接上，此时该gateway是有状态的；
- gateway在负载较大出于自保护的考虑，可能主动断掉一部分client的connection，即反向压力（back pressure）。client收到反向压力信号，主动去连接下一个可用的gateway。

client连接上gateway后，其消息流转流程如下：

![image](https://user-images.githubusercontent.com/4915189/74102481-af771180-4b7e-11ea-9073-7aed55fed1a4.png)

- gateway作为聊天室服务集群的接入层，需要考虑限流、降级、鉴权以及反向压力等设计；
- gateway通过之后的消息，投递给实时消息队列nsq；
- 具体业务逻辑的logic模块，异步消费上游消息后，将回复给client的消息投递到另一个nsq，等待gateway进行消费；
- 若有其他业务方需要投递消息给client，也是将消息投递到nsq，等待gateway消费；
- 需要有一个分布式配置中心（携程的Apollo），通过配置的实时变更实现开关、限流值调整、灰度等等动态特性。