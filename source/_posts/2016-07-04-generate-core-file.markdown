---
layout: post
title: linux程序崩溃时无corefile
date: '2016-07-04 17:52'
comments: true
categories: ['编程实践'] 
tags: ['Linux']
---

运行在beaglebone上的linux程序崩溃时（非daemon）没有生成corefile，解决思路如下：

<!--more-->

运行程序前设置`ulimit -c unlimited`（可配置在其start脚本）；

若上述设置还不能解决问题，则
1. 安装libc的调试包：`apt-get install libc6-dbg`；
2. 使用gdb包裹你的程序（这时候不能是daemon了），命令如下：
`gdb --batch -x your_gdbinit_file your_program`

注1：libc6-dbg的作用如下，
> libc6-dbg - Embedded GNU C Library: detached debugging symbols

注2：`your_gdbinit_file`是gdbinit文件，用于指示gdb在batch模式下该执行何种指令，内容举例如下：

```
run
bt
generate-core-file
quit
```

其中`bt`用于输出错误堆栈，`generate-core-file`用于生成core文件（文件格式为core.pid）；
