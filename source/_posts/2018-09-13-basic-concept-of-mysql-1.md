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

![image](https://note.youdao.com/yws/res/74/4BA9A3876ECE410B8CF884F84E929FA5)

对于join，可以理解为把A的所有列和B的所有列并在一起。以上面的表格为例，A表和B表的列并在一起变成了：

userid|username|orgid(user表)|orgid(org表)|orgname
---|---|---|---|---

此时由于orgid字段重名，我们需通过select挑出需要的字段。以上面的表格为例，可编写SQL如下：

```
SELECT 
    u.userid,
    u.username,
    u.orgid,
    o.orgname
FROM
    user u join org o
ON
    u.orgid = o.orgid
```

（TODO）
inner join时，A表（左表）的所有行原封不动的保留，B表（右表）的情况见下方解释。如上文的文氏图，A表由左白色和蓝色两部分组成，

- 蓝色部分：B表的所有行原封不动的保留；
- 右白色部分：B表的所有行的值全部显示为NULL；

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

（未完待续）