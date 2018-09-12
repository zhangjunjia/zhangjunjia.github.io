---
layout: post
title: 关于SIGPIPE
date: '2016-08-05 20:14'
comments: true
categories: ['编程实践'] 
tags: ['C/C++', 'TCP/IP', 'Linux']
---

Unix有一个信号名称为SIGPIPE，wiki上的解释是：

<!--more-->

The SIGPIPE signal is sent to a process when it attempts to write to a pipe without a process connected to the other end。通俗翻译下：如果连接的另一端已断开，那么此时写数据到另一端会产生SIGPIPE信号。

## SIGPIPE的原因

SIGPIPE的根本原因是：已连接套接字收到RST分节，但应用程序没有发现，继续调用send()或write()往该套接字写数据，而导致内核产生SIGPIPE信号。那什么情况下对端会发送RST分节呢？UNP卷1的解释有以下三种：

1. **对端无应用监听**：数据（含目的端口target_port）到达对端机器，到对端根本就没有应用在target_port等待数据（有可能是该应用被强制杀死），这时对端返回一个RST分节；
2. **对端想取消已建立的连接**：对端通过设置linger，调用close强制发送RST分节，直接略过了TIME_WAIT的状态；
3. **对端认为收到的数据无效**：假定对端崩溃后重启，其TCP丢失了之前的所有连接信息（根据ACK数值大小来决策？），因此对端收到数据后发回一个RST分节；

关于上面提到的第2点，UNP卷1认为它存在隐患：2MSL内，双端又建立了连接，此时上一次连接的数据可能还未消逝，从而导致“新生”连接收到脏数据（丢弃还是发生RST分节？）。

## SIGPIPE的处理

如果能在发送前检测是否收到RST分节，再决策是否发送，能否解决问题呢？答案是不能。因为有可能在检测完之后，发送之前，应用收到了一个RST分节。况且，调用send()和write()并不意味着真的把数据发送出去，而**只是数据写入到了已连接套接字的发送缓冲区**，何时真正发送出去不是应用层所能够决策的。

处理方法有以下2种：

**全局忽略SIGPIPE**：掉用`signal(SIGPIPE, SIG_IGN);`忽略该信号，然后在调用write()或send()之后检查其返回值和errno，若返回值为-1则表明出错，同时errno会被置为EPIPE，应用再做相应的清理工作；

**仅相关线程忽略SIGPIPE**：参考[Ignore SIGPIPE without affecting other threads in a process](http://www.microhowto.info/howto/ignore_sigpipe_without_affecting_other_threads_in_a_process.html)，该文章给出了非常详细的示范。
