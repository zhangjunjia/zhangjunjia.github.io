---
layout: post
title: C/C++的const
date: '2016-08-02 09:04'
comments: true
categories: ['编程实践'] 
tags: ['C/C++']
---

C/C++都有const关键字？它有什么用途以及用来干嘛呢？

<!--more-->

## const variable

const修饰variable，意味着**该变量不可修改**，即变量是readonly的，这一点C和C++相同。例子如下：

```c
int main() {
    const int a = 0; // 等价于：int const a = 0;
    a = 1; // error：a是readonly的，不可修改
    return 0;
}
```

考虑到指针也是variable，上述特点对指针也适用，称为const pointer，const pointer的**dereference（*号取值）不受影响**。例子如下：

```c
int main() {
    typedef int * int_ptr;
    int a = 0, b = 1;
    const int_ptr ip = &a; // 等价于：int_ptr const ip = &a;
    ip = &b; // error：ip是readonly的，其值（标识地址）不可修改
    *ip = 2; // 不影响指针的dereference
    return 0;
}
```

假如不想使用typedef的方式表示上述的const pointer，则必须写成如下形式：

```c
int a = 0;
int * const ptr = &a;
int const * ptr = &a; // error：这表示指向const int的指针
const int * ptr = &a; // error：这表示指向const int的指针
```

const variable的特点如下：

1. 声明和定义必须在同一个地方（声明变量时实例化）；
2. const variable不可修改；
3. const和type类型可以互换（指针不使用typedef的方式定义时需要格外注意）；

## pointer to const variable

指针指向const variable，意味着**不能通过指针去修改指针指向的内存**，即指针指向的内存是readonly的，但**指针本身的值修改不受影响（即可以重新绑定地址）**，这一点C和C++也相同，例子如下：

```c
int main() {
    typedef int * const int_cst_ptr; // const pointer
    typedef int const int_cst; // const int
    int a = 0;
    int *b = &a;
    int_cst_ptr *ptr1 = &b;
    int_cst *ptr2 = &a;
    *ptr1 = NULL; // error：pointer to const，指针指向内存readonly
    *ptr2 = 1; // error：pointer to const，指针指向内存readonly
    ptr1 = NULL; // 指针本身的值修改不受影响（即可以重新绑定地址）
    ptr2 = NULL;
}
```

假设不使用typedef，上述例子需写成：

```c
int main() {
    int a = 0;
    int *b = &a;
    int * const *ptr1 = &b; // 从右到左：ptr1 is a pointer to const pointer to int
    int const *ptr2 = &a;
    *ptr1 = NULL; // error：pointer to const，指针指向内存readonly
    *ptr2 = 1; // error：pointer to const，指针指向内存readonly
    ptr1 = NULL; // 指针本身的值修改不受影响（即可以重新绑定地址）
    ptr2 = NULL;
}
```

pointer to const variable的特点：

1. 指针指向内存不可修改；
2. 指针本身的值（代表的地址）可以修改；

举一个复杂点的例子，即有指针又有数组的情况：

```c
#include <stdio.h>
#include <string.h>

int main(int argc,char *argv[]) {
    int i = 0;
    for(; i<argc; i++) {
        printf("argv[%d] : %s\n", i, argv[i]);
        argv[i] = "a";
    }
    // char *const argv2[] = argv;
    char *const argv3[] = {"a", "b"};
    // argv3[0] = "test";
    char *const argv4[2];
    char *str = argv4[0];
    printf("str: %s\n", str);
    printf("strlen(str): %d\n", strlen(str));
    *str = 'a';
    *(str+1) = '\0';
    printf("str: %s\n", str);
    return 0;
}
```

上述代码可正常编译，被注释掉的行是因为其会在编译时出错。在x86的Linux下运行得到的结果为，

```
argv[0] : ./a.out
str: ,ݳ▒
strlen(str): 4
str: a
```

而在x64的Linux下运行得到的结果为，

```
argv[0] : ./a.out
str: AWA▒▒AVI▒▒AUI▒▒ATL▒%h
strlen(str): 23
段错误
```

关于该代码的几点说明如下，

1. `char *const argv2[] = argv;`之所以被注释是因为不能够将一个数组赋值给另外一个数组；
2. `char *const argv3[] = {"a", "b"};`定义并显示实例化了argv3，argv3是一个数组，它包含2个char * const（const pointer to char）元素，因此argv3[0]的指针值不可修改；
3. 在两个平台下运行结果不同说明若不显示实例化数组内容，数组的内容是不可预料的，对数组内容的修改结果也是不可预料的；

## const pointer to const variable

const pointer指向const variable，这意外着**指针本身值（代表的地址）不可修改**，同时**指针指向的内存也不可修改**，这点C和C++也相同。例子如下：

```c
int main() {
    typedef int * const int_cst_ptr; // const pointer
    typedef int const int_cst; // const int
    int a = 0;
    int *b = &a;
    int_cst_ptr * const ptr1 = &b;
    int_cst * const ptr2 = &a;
    *ptr1 = NULL; // error：pointer to const，指针指向内存readonly
    *ptr2 = 1; // error：pointer to const，指针指向内存readonly
    ptr1 = NULL; // error：const pointer，指针本身值不可修改
    ptr2 = NULL; // error：const pointer，指针本身值不可修改
}
```

假设不使用typedef，上述例子需写成：

```c
int main() {
    int a = 0;
    int *b = &a;
    int * const * const ptr1 = &b; // 这时候表达式越来越复杂
    int const * const ptr2 = &a;
    *ptr1 = NULL; // error：pointer to const，指针指向内存readonly
    *ptr2 = 1; // error：pointer to const，指针指向内存readonly
    ptr1 = NULL; // error：const pointer，指针本身值不可修改
    ptr2 = NULL; // error：const pointer，指针本身值不可修改
}
```

const pointer to const variable的特点：

1. 指针本身值（代表的地址）不可修改；
2. 指针指向的内存也不可修改；

## linkage

有以下代码文件：

头文件linkage.h，

```c
extern const int counter;
void print_counter();
```

c文件linkage.c，

```c
#include "stdio.h"
#include "linkage.h"

void print_counter() {
    printf("counter: %d\n", counter);
}
```

c文件main.c，

```c
#include "linkage.h"

const int counter = 12;

int main(int argc,char *argv[]) {
    print_counter();
    return 0;
}
```

执行下述语句，

```
gcc -c linkage.cpp -o linkage.o
gcc -c main.cpp -o main.o
gcc linkage.o main.o -o main
./main
```

得到的输出是预期的值：12。

将上述的linkage.c文件重命名为linkage.cpp，main.c重命名为main.cpp，执行下述语句，

```
g++ -c linkage.cpp -o linkage.o
g++ -c main.cpp -o main.o
g++ linkage.o main.o -o main
./main
```

得到的输出却是：0。

回想一下在C语言里面使用全局变量的注意点，

1. 在一个头文件声明该变量，即上述代码的`extern const int counter;`，它的作用是告诉编译器，我有这么一个类型的变量存在；
2. 在一个C文件定义该变量，即上述代码的`const int counter = 12;`，它的作用是为该全局变量申请存储；
3. 在其他需要此全局变量的C文件，include步骤1提到的头文件，全局变量得以共享；

对于C语言，const全局变量与非const变量一样，都是全局共享的，C++ Primer将此称为**external linkage**；
但对于C++，const全局变量确是local to file的（作用域仅限于文件内），问题就处在于`const int counter = 12;`这一行代码，在C++里这意味着定义了一个const int变量，但仅限于文件内部使用，C++ Primer将此称为**internal linkage**。

那么，如何在C++共享const全局变量呢？方法很简单，将步骤2的定义代码修改为`extern const int counter = 12;`即可。

## top-level const和low-level const

C++里面，将const variable称为**top-level const**，将pointer to const variable称为**low-level const**，而且还规定，

1. const variable赋值给普通variable或pointer to const variable时，top-level const的const被忽略，等同于普通变量间赋值；
2. pointer to const variable赋值给普通variable或const variable时，low-level const的const不能被忽略；

有以下main.cpp文件，

```c
int main() {
    const int a = 0;
    int b = a; // const int --> int, top to normal
    const int c = b; // int --> const int, normal to top
    int * const ptr = &a; // const int * --> int * const, low to top
    int * ptr2 = &a; // const int * --> int *, low to normal
    int * ptr3 = ptr; // int * const --> int *, top to normal
    const int * ptr4 = ptr; // int * const --> const int *, top to low
    return 0;
}
```

运行`g++ main.c`，得到的输出如下：

```
main.cpp: In function ‘int main()’:
main.cpp:5:24: error: invalid conversion from ‘const int*’ to ‘int*’ [-fpermissive]
     int * const ptr = &a; // const int * --> int * const, low to top
                        ^
main.cpp:6:19: error: invalid conversion from ‘const int*’ to ‘int*’ [-fpermissive]
     int * ptr2 = &a; // const int * --> int *, low to normal
                   ^
```

这说明在C++里面，low-level const赋值或强转给其他类型时，const是不能被忽略的，否则会在编译时报错。

将上述代码保存为main.c后执行`gcc main.c`，得到的输出如下：

```
main.c: In function ‘main’:
main.c:4:23: warning: initialization discards ‘const’ qualifier from pointer target type [enabled by default]
     int * const ptr = &a; // const int * --> int * const, low to top
                       ^
main.c:5:18: warning: initialization discards ‘const’ qualifier from pointer target type [enabled by default]
     int * ptr2 = &a; // const int * --> int *, low to normal
                  ^
```

这说明在C里面，并没有严格规定top-level const和low-level const，但是对于low-level const的情况，还是会有warning，因此必须小心使用，同时必须注意编译器的所有warning。
