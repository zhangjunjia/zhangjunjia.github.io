---
title: C语言指针与数组
date: 2017-05-04 17:09:07
comments: true
categories: ['编程实践'] 
tags: ['C/C++', '指针']
---

C语言数组下标`[]`符号竟是个语法糖？

<!--more-->

```c
#include <stdio.h>

struct node {
    int a[100];
    int b[100];
};

int main() {
    struct node ins;
    int i = 0;
    for(; i<200; i++) {
        ins.a[i] = 1;
    }
    return 0;
}
```

问：上述程序在运行时是否会产生数组越限？

答：不会。

> 《C程序设计语言》（第2版·新版）P84写到：
> 对数组元素a[i]的引用也可以写成*(a+i)这种形式，在计算数组元素a[i]的值时，C语言实际上先将其转换为*(a+i)的形式，然后再进行求值。

如果你没注意到此特性，将有可能导致灾难。