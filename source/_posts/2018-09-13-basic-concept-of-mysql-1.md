---
title: MySQL基础回顾01 | 表连接与Group By
date: 2018-09-13 20:00:03
tags: 'MySQL'
---

MySQL基础回顾第一篇，回顾4种表连接的含义、与笛卡尔积的区别以及group by的用途。

<!-- more -->

## 表连接

User表信息如下：

userid|username|orgid
---|---|---
1|jay|10
2|tom|11
3|shelly|12

Org表信息如下：

orgid|orgname
---|---
10|gdut
12|gzut
15|skj

### 表连接语法

表连接的语法为：`A [left|right|inner|full] join B on A.x = B.y`。`[]`内的选项4选一，不填写时默认表示表示`inner`。4个选项的含义如下：

- inner：内连接
- left：左连接
- right：右连接
- full：全连接

### 表连接解释

下图为表连接的文氏图表示，中间蓝色部分表示`A.x = B.y`的A表与B表的行记录，即A的x字段与B的y字段相等，x与y称为连接字段。习惯上，我们把join左边的表称为左表，其右边的表称为右表，在本例中A是左表，B是右表。

![image.png](https://upload-images.jianshu.io/upload_images/908013-e4bd042c0115b6cf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

对于join，可以理解为把A的所有列和B的所有列并在一起。以上面的表格为例，A表和B表的列并在一起变成了：

userid|username|orgid(user表)|orgid(org表)|orgname
---|---|---|---|---

此时由于orgid字段重名，我们需通过select挑出需要的字段。以上面的表格为例，可编写SQL如下挑出所需字段：

```
SELECT u.userid, u.username, u.orgid, o.orgname FROM user u join org o ON u.orgid = o.orgid
```

left join时，A表（左表）的所有行原封不动的保留，B表（右表）的行保留情况如下，

- 上午文氏图的蓝色部分：B表的所有行原封不动的保留；
- 上午文氏图的右白色部分：B表的所有行的值全部显示为NULL；

userid|username|orgid|orgname
---|---|---|---
1|jay|10|gdut
2|tom|11|NULL
3|shelly|12|gzut

right join时，与right join刚好相反，B表（右表）的所有行原封不动的保留，A表（左表）仅有与B表orgid重叠的行原封不动的保留。

userid|username|orgid|orgname
---|---|---|---
1|jay|10|gdut
3|shelly|12|gzut
NULL|NULL|15|skj

inner join，仅保留A表与B表orgid重叠的行。

userid|username|orgid|orgname
---|---|---|---
1|jay|10|gdut
3|shelly|12|gzut

full join，用集合运算可理解为`(left join) + (right join) - (inner join)`。

userid|username|orgid|orgname
---|---|---|---
1|jay|10|gdut
2|tom|11|NULL
3|shelly|12|gzut
NULL|NULL|15|skj

## 笛卡尔积Cross Join

这是一种特殊的Join，以上文的user表cross join org表为例，全连接SQL如下：

```
SELECT 
    u.userid,
    u.username,
    u.orgid,
    o.orgname
FROM
    user u cross join org o -- 注：cross join可用逗号表示
```

得到的结果如下：

userid|username|orgid|orgname
---|---|---|---
1|jay|10|gdut
1|jay|10|gzut
1|jay|10|skj
2|tom|11|gdut
2|tom|11|gzut
2|tom|11|skj
3|shelly|12|gdut
3|shelly|12|gzut
3|shelly|12|skj

也就说，在cross join不设定where条件的情况下，得到的结果是一个笛卡尔积，总行数等于左表的行数乘以B表的行数。在指定where条件的情况下，下文的SQL等同于inner join。

```
SELECT 
    u.userid,
    u.username,
    u.orgid,
    o.orgname
FROM
    user u, org o -- 注：cross join可用逗号表示
WHERE
    u.orgid = o.orgid
```

## group by

`group by`的语义是把行进行分组，如：

```
SELECT 
    u.userid,
    u.username,
    u.orgid,
    o.orgname
FROM
    user u cross join org o
GROUP BY u.userid
```

以上SQL，会把userid相同的分成一个组，然后仅保留组内的第一条记录，得到的结果为：

userid|username|orgid|orgname
---|---|---|---
1|jay|10|gdut
2|tom|11|gdut
3|shelly|12|gdut

基于`group by`分组的特性，一般其会配置聚合函数使用，如count()和avg()等函数。修改SQL如下：

```
SELECT 
    u.userid, count(*)
FROM
    user u cross join org o
GROUP BY u.userid
```

将得到结果：

userid|count
---|---
1|3
2|3
3|3

`group by`后跟一个字段，表示一维分组，如果跟两个字段则为二维分组，三个字段及以上以此类推。以二重`group by`为例，`group by a, b`可以通俗的理解为：**所有a字段值相同，同时b字段值相同的行，会被分到同一组**。