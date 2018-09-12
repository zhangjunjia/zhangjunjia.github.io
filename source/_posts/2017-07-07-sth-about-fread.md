---
title: 关于C语言的fread函数
date: 2017-07-07 17:14:16
tags: ['C/C++']
comments: true
categories: ['编程实践']
---

关于C函数fread的一道小小题目。

<!--more-->

```c
#include <stdio.h>
#include <stdlib.h>

// text.txt的内容只有一行，该行的内容为一个数值：7

int main() {
    char *file = "text.txt";
    FILE *fp = fopen(file, "r");
    if(fp) {
        char str[128];
        int rc = fread(str, 5, 1, fp);
        printf("size is : %d\n", rc);
        if(rc) 
            printf("content is : %d\n", atoi(str));
        fclose(fp);
    }
    return 0;
}
```

你猜运行上面的结果会输出什么？答案是：
> size is : 0

但我期望的结果是：
> size is : 2
> content is : 7

问题出在哪里？且看看fread的定义：
> ```size_t fread(void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);```

这里的`size`表示读取的步长大小（字节数），`nitems`为读取多少步，返回结果是实际读取了多少步。上面的代码问题在于，读取的步长大小为5字节，但文件内容并没有5个字节这么多，于是返回结果`rc`为0，自然得不到期望输出了。将上述代码的第11行修改如下即可：

    int rc = fread(str, 1, 5, fp);

即步长为1，预期可以读到5步，实际上只读了两步就结束了（其中一个字节为换行符），因为遇到了文件结束符。