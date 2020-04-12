---
layout: post
title: docker初探
date: '2016-06-29 17:57'
comments: true
categories: ['工具篇'] 
tags: ['Docker']
---

想在公司安装bugzilla用于bug跟踪，又不想做太多的安装配置，这时候使用docker是非常不错的方式，记录一些安装过程中用到的命令参数。我的bugzilla在docker中的容器名称为bugzilla。

<!--more-->

1. 启动/停止容器bugzilla：`docker start/stop bugzilla`；
1. 查看容器bugzilla日志：`docker logs bugzilla`；
1. 查看运行中的容器：`docker ps`；
1. 与容器bugzilla进行内容传输：
    ```
    docker cp [OPTIONS] CONTAINER:PATH LOCALPATH|-
    docker cp [OPTIONS] LOCALPATH|- CONTAINER:PATH
    ```
1. 在容器bugzilla内执行命令：
    ```
    docker exec [OPTIONS] CONTAINER COMMAND [ARG...]
    ```
1. 登入容器bugzilla：
   ```
   docker exec -it bugzilla bash
   ```
