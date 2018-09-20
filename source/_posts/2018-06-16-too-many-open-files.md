---
title: Too many open files in java
date: 2018-06-16 17:00:05
tags: ['Java']
---

Linux平台下，每个进程能打开的文件描述符是有上限的，这个参数可以通过`ulimit`命令查看和在运行时设置，但若想持久化该配置，需配置到`sysctl.conf`，具体如何
配置请自行百度。本文记录Java进程「too many open files」的错误，其原因便是打开的文件描述符超过了OS的上限。

<!--more-->

## Linux平台下如何诊断可能存在「too many open files」错误

- 首先，通过`ps`命令查找到进程ID，如`2343`
- 然后，使用`ls -l /proc/2343/fd`命令可以查看到具体打开了什么类型的文件描述符，如常见的pipe和socket。使用`ls -l /proc/2343/fd|wc -l`可对进程打开的文件描述符进行计数，如果这个数值不断在增大，说明程序存在文件描述符未正常关闭的BUG。注：这里的`2343`请替换为实际进程ID。

## 常见原因是什么

- 一种常见原因是文件流没有正常关闭，解决办法是使用try-finally或try-with-resources确保流的正常关闭。特殊的是，对于`new BufferedReader(new InputStreamReader(process.getInputStream()))`这类代码，在关闭`BufferedReader`时会自动关闭`InputStreamReader`
- 另一种常见原因是`Runtime.getRuntime().exec()`所导致的问题，[StackOverFlow](https://stackoverflow.com/questions/15956452/troubleshooting-too-many-files-open-with-lsof)上有详细的介绍，示例如下：

```java
    try
    {
        // exec()常用来做操作系统调用
        p = Runtime.getRuntime().exec("something");
    }
    finally
    {
        if (p != null)
        {
            // 调用完毕后，必须显示关闭标准输出流、错误输出流和输入流，否则会导致文件描述符没有正常释放
            // 可直接p.getOutputStream().close()关闭
            IOUtils.closeQuietly(p.getOutputStream());
            IOUtils.closeQuietly(p.getInputStream());
            IOUtils.closeQuietly(p.getErrorStream());
            // 注意，destroy()方法并不负责流的关闭，这是一个非常隐晦的错误
            p.destroy();
        }
    }
```

