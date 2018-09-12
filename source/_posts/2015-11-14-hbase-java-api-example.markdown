---
layout: post
title: HBase Java API用到的一些特性
date: '2015-11-14 23:13'
comments: true
categories: ['编程实践']  
tags: ['HBase', 'Java']
---

本文介绍用到的一些HBase Java API。

<!--more-->

## 已知rowkey∈[startRow, stopRow)，timestamp为0，查询第一条记录和最后一条记录

关键：使用PageFilter设置返回行数，使用scan.setReversed(true)设置反向扫描；

- 查询第一条记录

```java
// 已知变量
byte[] startRow, stopRow;
// TODO 在这里实例化startRow和stopRow
Scan scan = new Scan();
scan.setStartRow(startRow);
scan.setStopRow(stopRow);
try {
	// 限定timestamp
	scan.setTimeStamp(0l);
	// 使用new PageFilter(num)限定返回结果行数，num为1表示只返回一行记录
	scan.setFilter(new PageFilter(1));
} catch (IOException e) {
	// TODO 处理异常
}
// TODO 在这里添加要查询的colum family和qualifier并执行查询和结果解析
```

- 查询最后一条记录

```java
// 已知变量
byte[] startRow, stopRow;
// TODO 在这里实例化startRow和stopRow
Scan scan = new Scan();
// 由于设置了反向扫描，stopRow和startRow需要调转位置
scan.setStartRow(stopRow);
scan.setStopRow(startRow);
try {
	// 反向扫描
	scan.setReversed(true);
	// 限定timestamp
	scan.setTimeStamp(0l);
	// 使用new PageFilter(num)限定返回结果行数，num为1表示只返回一行记录
	scan.setFilter(new PageFilter(1));
} catch (IOException e) {
	// TODO 处理异常
}
// TODO 在这里添加要查询的colum family和qualifier并执行查询和结果解析
```
