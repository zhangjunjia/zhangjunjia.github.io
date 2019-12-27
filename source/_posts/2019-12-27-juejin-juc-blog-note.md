---
title: 【博客笔记】掘金的knock_小新的Java并发系列
date: 2019-12-27 22:14:52
tags: ['Java']
---

博客地址：https://juejin.im/post/5b4f54d66fb9a04f8d6bb44a

<!--more-->

## JMM相关

JMM：cpu、cache、mem为物理层，stack、heap为逻辑层。static修饰的变量、新建的object、object的成员在heap，剩余的在stack。方法参数、object引用、局部变量等在stack。

happens-before：无论指令如何重排序，JMM需保证几种必要的时序正确：lock、volatile、start()、join()、interrupt()、finalize()、代码执行顺序。

volatile：通过读写内存屏障，实现了可见性保证。

## Lock相关

synchronized：偏向锁（单线程）、轻量锁（多线程轻量竞争）、重量锁。CAS需要物理层支持，有ABA问题。

ReentrantLock：fair与unfair的差别主要在于tryAcquire时是否排队；AQS是基础抽象类，定义了acquire和release等基础行为，且实现了共有抽象方法。

Semaphore：fair与unfair的差别是tryAcquireShared是否排队；获取失败添加到等待队列，等待队列先进先出（对于队列而言是公平）。

CountDownLatch：CountDownLatch的await等待countDown全部释放，才可以开始下一轮次。

CountDownLatch和Semaphore区别：state每次只减1，为0时才释放所有等待线程；提供了超时acquire的方法，等不到可以去做其他事情。

ReentrantReadWriteLock：读锁共享，写锁独占。读锁检测到没有写锁，或写锁是当前线程，且数量未超上限，则获取，读锁与Semaphore的区别如是也。写锁需要全部读锁释放才可获取，会发生写饥饿，与ReentrantLock的区别如是也。

StampedLock：StampedLock写锁获取与rwlock类似，但释放不是减一而是加一，目的是记录获取过写锁，防止乐观读锁出现ABA问题；读锁容量在127内是加一减一，若溢出则用readerOverflow变量加减一，之所以读容量较小是为了腾出更多容量来记录写锁行为，这点个人觉得难以理解。乐观读锁实际没有获取锁，其validate()相当于一个double check，如果此间没有过写锁行为，则验证通过，否则需要考虑升级为悲观读锁。

## 容器相关

ConcurrentHashMap：插入时若未初始化CAS实例化，桶未有结点则CAS插入到头，正在扩容协助扩容，hash冲突则使用synchronized加锁当前桶。

ArrayBlockingQueue：通过独占锁互斥读写、通过两个conditon阻塞或唤醒生产与消费者、通过takeIndex、putIndex、count维护一个滑动的读写窗口。超时poll和offer则结合awaitNanos实现。

ConcurrentSkipListMap：并发下的有序map实现

有界阻塞队列包括：ArrayBlockingQueue、LinkedBlockingQueue以及LinkedBlockingDeque三种，LinkedBlockingDeque应用场景很少，一般用在“工作窃取”模式下。ArrayBlockingQueue和LinkedBlockingQueue基本就是数组和链表的区别。无界队列包括PriorityBlockingQueue、DelayQueue和LinkedTransferQueue。PriorityBlockingQueue用在需要排序的队列中。DelayQueue可以用来做一些定时任务或者缓存过期的场景。LinkedTransferQueue则相比较其他队列多了transfer功能。最后剩下一个不存储元素的队列SynchronousQueue，用来处理一些高效的传递性场景。

LinkedBlockingQueue底层是链表，它使用了两个独占锁来控制头部消费和尾部生产，使用AtomicInteger的count来控制并发更新。

## 线程池相关

1. 举个例子来说明为什么要使用线程池，有什么好处？
    - 客户端&服务端通信，线程创建销毁开销中，线程池可复用
1. jdk1.8中提供了哪几种基本的线程池？
    - 单线程（无界队列）、固定线程（无界队列）、无限线程（同步队列）、定时线程
1. 线程池几大组件的关系？
    - Excutor是顶级接口，接受Runnable作为入参
    - ExcutorService接口扩展了Excutor接口，新增了线程控制和状态判断的方法
    - Excutors是创建线程池的工厂
    - ThreadPoolExecutor是具体实现类
1. ExecutorService的生命周期？
    - RUNNING、SHUTDOWN、STOP、TIDYING、TERMINATED
1. 线程池中的线程能设置超时吗？
    - submit得到future后调用get
1. 怎么取消线程池中的线程？
    - 同上
1. 如何设置一个合适的线程池大小？
    - 视工作负载、CPU核心数而定
1. 当使用有界队列时，如何设置一个合适的队列大小？
    - 视平均消费时长、消费线程数而定
1. 当使用有界队列时，如果队列已满，如何选择合适的拒绝策略？
    - 直接拒绝、报错拒绝、执行调用方的拒绝策略（阻塞）
1. 如何统计线程池中的线程执行时间？
    - ThreadPoolExecutor的beforeExcute和afterExcute方法