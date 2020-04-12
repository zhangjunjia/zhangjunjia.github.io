---
title: "Core Java 01 | equals vs =="
date: 2018-06-07 12:22:29
tags: ['Java']
comments: true
categories: ['编程语言']
---

Java中，equals和==有何区别？

<!-- more -->

`==`是什么？

- `==`是二元运算符；
- 对于基本数据类型，`==`比较的是值是否相等；
- 对于对象，`==`比较的是两个引用是否指向同一个内存地址；

`equals`是什么？

- `equals`是顶层父类`java.lang.Object`的成员方法，此方法需通过非空对象调用，其源码如下：
```java
public boolean equals(Object obj) {
    return (this == obj);
}
```
- 在子类没有重写`equals`方法的情况下，比较的是两个引用是否指向同一个内存地址；
- 在子类重写了`equals`的情况下，比较的结果视其具体实现而定。例如：8大基本数据的包装数据类型、String类重写了equals方法，比较的是值是否相等。

对于equals，Java有个规定：

> Note that it is generally necessary to override the hashCode method whenever this method is overridden, so as to maintain the general contract for the hashCode method, which states that equal objects must have equal hash codes.

> 长话短说：若两个对象使用equals比较返回true，它们的hashCode方法返回的值必须相等。

Why？下回详解。
