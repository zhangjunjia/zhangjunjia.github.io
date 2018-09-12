---
layout: post
title: SVN嵌套权限管理
date: '2016-05-05 13:48'
comments: true
categories: ['编程实践']  
tags: ['SVN']
---

公司有一个ExtJS+Java的云平台项目，该项目模块化得较好，一个包就是一个模块。

<!--more-->

该项目需要多人协作，同时又要让协作者不能获取到全部模块（防止代码泄露）。以往我的做法是分子项目然后使用BeyondCompare作合并，但这样太费时费力了，后来发现SVN能完美达成我的需求。

介绍我的SVN的authz（Linux环境）配置如下：

```
[groups]
admin = jayzee,luzhiquan,hwq
user = yifei,shenkai,linjie,cjm
# gx-desk
[myproject:/gx-desk]
@admin = rw
@user = r
## gx-desk src
[myproject:/gx-desk/src]
@user = rw
[myproject:/gx-desk/src/main/resources]
@user = r
[myproject:/gx-desk/src/main/resources/com]
@user = rw
## gx-desk WebContent
[myproject:/gx-desk/WebContent]
@user = rw
[myproject:/gx-desk/WebContent/.sencha]
@user = r
[myproject:/gx-desk/WebContent/Chart]
@user = r
[myproject:/gx-desk/WebContent/app/App.js]
@user = r
[myproject:/gx-desk/WebContent/app/view/infomanage]
@user =
linjie = rw
```

1. SVN的权限具有继承关系，上例中，`/gx-desk`为项目的根，它设置admin用户可读写，而普通用户可读不可写；
2. `/gx-desk/src`继承了上一级的权限，其下方的`@user = rw`表示我们将`/gx-desk/src`的权限重写为可读写；
3. 其他的以此类推，基于此我们就可以实现嵌套的内存管理啦！

注：
`@user = `表示不可读和不可写；
