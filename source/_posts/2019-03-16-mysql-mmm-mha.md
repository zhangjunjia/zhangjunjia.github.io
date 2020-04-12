---
title: mysql mmm和mha对比
date: 2019-03-16 16:50:39
tags: ['MySQL']
comments: true
categories: ['数据库']
---

本文简单介绍MySQL的两个high availability方案，MMM和MHA。

<!--more-->

## MMM

![image.png](https://user-images.githubusercontent.com/4915189/71431448-e5fee700-270c-11ea-8139-12d41a02f4b4.png)

MMM(Master-Master replication managerfor Mysql)的基本组成如下，
- 主节点master1：承载写流量
- 备主节点master2：replicate主节点master1的写流量，在主节点故障时被monitor提升为主节点，出于与master1数据强一致的考虑，replicate模式一般配置为semi-sync
- 从节点slave1：replicate主节点master1的写流量，为使得master1的写足够快，一般将replicate模式设为异步
- 从节点salve2：类似于slave1
- mmm-agent：以上3个节点都需部署的代理，与monitor进行通信
- mmm-mon：即monitor，与各mmm-agent通信探测其健康情况，并决策是否要切换主节点或从节点
- wvip：提供写的虚拟IP，映射到当前活跃的主节点master1
- rvip：提供读的虚拟IP，至少有一个，映射到slave1或slave2

MMM的主节点切换过程如下：

![image.png](https://user-images.githubusercontent.com/4915189/71431454-eac39b00-270c-11ea-9899-b51b6260851f.png)

- master1的mmm-agent与mmm-mon长期通信失败
- mmm-mon请求master1的agent，移除VIP
- mmm-mon请求master2的agent，绑定VIP
- mmm-mon请求slave节点的agent，连接到新master进行replicate

从节点的故障切换类似于上面的过程。

优点如下，

- 读写分离
- fail自动切换

缺点如下，

- mmm-mon存在单点故障
- mmm-agent对网络抖动敏感，可能引起频繁切换
- 可能引起master脑裂（见下文解释）
- 多了一个冗余的master节点
- 需要比较多的VIP数量
- 方案基于VIP，VIP是基于ARP协议，因此所有节点必须处于同一局域网
- 主节点提升需要一定时间
- 写后即时读难以保持一致性（master同步过来的数据可能还在relay log未被应用）

## MHA

MHA(Master High Availability)不同于MMM，它主要保障的是master的高可用。官方的MHA建议至少要有1主2从，淘宝TMHA则支持1主1从。其基本组成如下，

- master：主节点，承载写流量
- slave：从节点，replicate主节点数据，承载读流量
- wvip：提供写的虚拟IP，映射到主节点
- rvip：提供读的虚拟IP，如果只有一个从节点不需要
- manager：与master、slave通信，负责切换主节点。注意，manager通过ssh的方式远程执行主、从节点上的脚本，需要提前将manager节点的ssh公钥放置到主、从节点；另外，manager通过mysql-client的方式去探测主、从节点的可用性，因此主、从库上也要预先为manager节点分配账户与授权

master提升主节点的流程如下，

![image.png](https://user-images.githubusercontent.com/4915189/71431458-ee572200-270c-11ea-846c-bcf25ff79b5a.png)


- 从宕机崩溃的master保存二进制日志事件（binlog events）;
- 识别含有最新更新的slave；
- 应用差异的中继日志（relay log）到其他的slave；
- 应用从master保存的二进制日志事件（binlog events）；
- 移除旧master的VIP地址，提升一个slave为新的master；
- 使其他的slave连接新的master进行复制；
- 在新的master启动vip地址，保证前端请求可以发送到新的master

优点如下，

- 相比MMM不需要冗余的master节点
- 读写分离
- 自动提升主节点

缺点如下，

- manager节点单点故障
- 可能引起master脑裂（见下文解释）
- 使用了VIP，同样有内网限制
- 主节点切换需要一定时间
- 写后即时读难以保持一致性
- 需要支持SSH私钥验证的方式登录

## 扩展知识：VIP与脑裂

VIP的工作原理是，

- 为当期主机配置一个虚拟网卡，如eth0:0，该网卡绑定了唯一的MAC地址和虚拟IP地址VIP
- 局域网内的主机欲与该VIP通信时，先通过ARP协议取到该VIP对应的MAC地址，再将VIP与MAC地址的对应关系缓存在其主机上
- 后续通信时，使用上一步骤取到的MAC作为报文的MAC地址

VIP切换的原理是，

- 将旧master绑定的虚拟网卡注销掉
- 在新的master注册新的虚拟网卡（产生了新的MAC地址）
- 通知局域网节点更新VIP与MAC的对应关系，后续通信采用新MAC地址

脑裂的原因，在于旧master节点没有正常将VIP摘掉，这时局域网机器通过ARP获取VIP的MAC时，就可能取到旧的MAC地址，导致与旧master通信。什么情况会出现这种情况呢？旧master由于上层交换机故障，未与manager节点正常通信，此时VIP是没有摘除掉的，过了一段时间上层交换机恢复了就会导致此问题。

参考文献
- https://github.blog/2018-06-20-mysql-high-availability-at-github/
- https://dzone.com/articles/choosing-mysql-high-availability-solutions
- https://cloud.tencent.com/developer/article/1056162
- http://www.fblinux.com/?p=1044