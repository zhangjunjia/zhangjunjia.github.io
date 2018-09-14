---
title: Java Mina close_wait issue
date: 2018-06-14 11:02:06
tags: ['Java', 'Mina', 'TCP/IP']
---

在Linux下使用Java Mina编写TCP/IP通信程序时，发现TCP Server出现了大量的CLOSE_WAIT，why？

<!--more-->

close_wait状态出现在TCP四次挥手，「被动关闭的TCP端」才会出现此状态，详见下图。

![TCP四次挥手](https://img-blog.csdn.net/20170606084851272?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvcXpjc3U=/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)

从图片可以得到以下信息，

- 主动关闭端主动发送FIN报文
- 被动关闭端接收到FIN报文后，协议栈一般会自动回复ACK报文，此时被动关闭端进入了**close_wait**状态。再次强调下，一旦被动关闭端收到了FIN报文并回复ACK，它便进入了close_wait状态
- 直到被动关闭端发送了FIN报文后，close_wait状态才解除，被动关闭端进入last_ack的状态

这里有两个问题，

- 被动关闭端如何发送FIN报文？
- 如果被动关闭端不主动close()会有什么后果？

相应的答案是，

- 主动close()已建立的socket连接，放在mina便是`session.closeNow()`
- 被动关闭端会一直处在close_wait状态，直到达到一个超时时间才释放socket。这个时间默认是2小时，可通过修改系统配置缩短（搜索tcp keepalive setup）

强调一点，**在close_wait状态解除前，除非tcp端口发生变化，否则主动关闭端将无法再次与被动关闭端建立tcp连接，这放在生产环境便是灾难。为什么会这样呢？因为TCP连接是一个4元标识，本地IP+本地端口+远端IP+远端端口唯一标识一个TCP连接，处于close_wait状态相当于keep住了一个4元标识，任何与此标识相同的连接请求（三次握手）将被TCP拒绝。**


最重要的结论来了：**如果你遇到这类问题，说明你的程序存在BUG，没有正常close()掉失效的TCP连接**。若使用mina编程，可在sessionIdle()关闭失效的连接避免此错误。

注：使用`lsof`命令可查看进程是否有socket处于close_wait状态。


## 参考文献

https://blog.csdn.net/qzcsu/article/details/72861891
