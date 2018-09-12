---
title: 如何诊断java程序CPU占用率过高
date: 2018-07-07 23:13:53
tags: ['Java']
---

在最近一次编程时，我的一个Java应用在嵌入式设备bbblack上的CPU占用率高达60%至70%，简单记录我是如何诊断这个问题的。

<!--more-->

GitHub上有一个项目[jvmtop](https://github.com/patric-r/jvmtop)，借助于jvmtop这个工具，我们可以指定Java进程的pid进行profile，命令如下：

```java
jvmtop <pid>
```

产生的输出大概如下：
```
JvmTop 0.4.1 alpha   amd64,  4 cpus, Linux 2.6.18-34
 https://github.com/patric-r/jvmtop

 PID 3539: org.apache.catalina.startup.Bootstrap
 ARGS: start
 VMARGS: -Djava.util.logging.config.file=/home/webserver/apache-tomcat-5.5[...]
 VM: Sun Microsystems Inc. Java HotSpot(TM) 64-Bit Server VM 1.6.0_25
 UP: 869:33m #THR: 106  #THRPEAK: 143  #THRCREATED: 128020 USER: webserver
 CPU:  4.55% GC:  3.25% HEAP: 137m / 227m NONHEAP:  75m / 304m
 Note: Only top 10 threads (according cpu load) are shown!

  TID   NAME                                    STATE    CPU  TOTALCPU BLOCKEDBY
     25 http-8080-Processor13                RUNNABLE  4.55%     1.60%
 128022 RMI TCP Connection(18)-10.101.       RUNNABLE  1.82%     0.02%
  36578 http-8080-Processor164               RUNNABLE  0.91%     2.35%
  36453 http-8080-Processor94                RUNNABLE  0.91%     1.52%
     27 http-8080-Processor15                RUNNABLE  0.91%     1.81%
     14 http-8080-Processor2                 RUNNABLE  0.91%     3.17%
 128026 JMX server connection timeout   TIMED_WAITING  0.00%     0.00%
 128025 JMX server connection timeout   TIMED_WAITING  0.00%     0.00%
 128024 JMX server connection timeout   TIMED_WAITING  0.00%     0.00%
 128023 JMX server connection timeout   TIMED_WAITING  0.00%     0.00%
```

通过其输出，我们可以判断出是哪个线程占用较高CPU，以及线程出于什么样的状态。使用`jvmtop -e <pid>`还可以具体确定是哪个方法占用CPU时间片最多。通过这些信息，我定位到了异常：**我的某个循环体出现了死循环**。
