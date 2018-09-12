---
layout: post
title: LVM用到的一些特性
date: '2016-05-09 17:25'
comments: true
categories: ['编程实践']  
tags: ['LVM']
---

我选用LVM的目的是，

<!--more-->

1. 可以将多个物理盘组装成一个逻辑盘（你只需读写一个盘）；
2. 可实现动态扩容；

## 初始安装时的配置

笔者已有的两个空闲物理分区为：
1. /dev/xvde1 250G
2. /dev/xvde2 250G

创建vg、pv和lv：

```bash
## 将物理分区设置为pv
pvcreate /dev/xvde2
## 创建vg，同时将pv添加进vg
vgcreate gx /dev/xvde2
## 创建lv，并指定其容量大小
lvcreate -n lv1 -l 100%FREE gx
## 格式化lv为ext4
mkfs.ext4 /dev/gx/lv1
```

如何使用lv呢？编辑`/etc/fstab`，加入：

```
/dev/gx/lv1      /media/disk    ext4    defaults,noatime,nodiratime 0       0
```

重启操作系统后，你将看到lv被挂载到`/media/disk`，它的大小为250G左右。那么，如何实现动态扩容呢？

```bash
## 将物理分区设置为pv
pvcreate /dev/xvde1
## 扩容vg
vgextend gx /dev/xvde1
## 扩容lv
lvextend -l +100%FREE /dev/gx/lv1
## 通知文件系统更新
resize2fs /dev/gx/lv1
```

执行完上述命令后，`/media/disk`将变为500G左右。

## 重装系统后的配置

由于lvm的所有信息都是写在pv的metadata，重装系统后依然有效，重装后执行，

```bash
## 扫描pv
pvscan
## 扫描lv
lvscan
## 扫描vg
vgscan
## 通知操作系统激活vg
vgchange -a y
```

编辑`/etc/fstab`，加入：

```
/dev/gx/lv1      /media/disk    ext4    defaults,noatime,nodiratime 0       0
```
