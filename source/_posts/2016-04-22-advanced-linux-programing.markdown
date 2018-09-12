---
layout: post
title: 读《Advanced Linux Programing》
date: '2016-04-22 19:03'
comments: true
categories: ['读书笔记']  
tags: ['Linux', 'C/C++']
---

《Advanced Linux Programing》读书笔记。

<!--more-->

## 一些介绍

Linux Kernel

- 硬件交互；
- 内存管理；
- 文件管理；
- 多进程管理；
- 共享库载入；

GNU Project

- 编辑器；
- 编译器；
- Shell（/bin/bash，Bourne-Again SHell）；

注意：

1. Linux Kernel加GNU Project，构成了现在主流的Linux操作系统，所以应该称之为GNU/Linux；
2. Linux操作系统只是UNIX的一种系统实现，其他类UNIX操作系统有FreeBSD、Solaris等；

## Hello, World（快速了解）

### 从文本到可执行程序

```c
/** main.c **/
#include <stdio.h>

void sayHello() {
    printf("Hello, World\n");
}

int main() {
    sayHello();
    return 0;
}
```

Shell下运行`gcc -o main main.c`即可得到可执行文件`main`，执行`./main`即可在控制台上看到`Hello, World`的输出。那么，它的原理是什么？从`main.c`到`main`，经历了以下步骤：

- main.c --> main.i --> main.s --> main.o --> main
- 程序文本 + **预处理器(cpp)** --> 被修改的源程序文本 + **编译器(ccl)** --> 汇编文本 + **汇编器(as)** --> 可重定向目标文件（二进制） + printf.o + **链接器(ld)** --> main（可执行程序）

对应到Shell下，经历了以下命令：

```bash
gcc -E main.c -o main.i
gcc -S main.i -o main.s --> main.s
gcc -c main.s -o main.o --> main.o
gcc main.o -o main --> main

# 上面4句等价于下面一句，gcc自动进行预处理、编译、汇编和链接
gcc main.c -o main

```

`-E`进行预处理，将头文件插入C文件同时执行宏替换；`-S`用于生成汇编绘本；`-c`命令用于汇编；`-o`命令用于指定输出文件名称。

### 编写可用g++编译的c程序

```c
/** main.c **/
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
void sayHello();
#ifdef __cplusplus
}
#endif

void sayHello() {
    printf("Hello, World\n");
}

int main() {
    sayHello();
    return 0;
}
```

### 其他常用gcc命令

- `-I`指定存放头文件的路径（相对或绝对路径）；
- `-D`定义一个宏；
- `-O`指定优化级别；
- `-l`指定要链接的库；
- `-L`指定搜索动态链接库的路径；

```bash
# 生成可执行文件main
# 从绝对路径/root/搜索头文件
# 定义宏DEBUG
# 定义优化级别为2（0<1<2<3，0表示不优化）
# 链接数学库m
# 在/usr/local/lib下查找数学库m的动态链接库
gcc main.c -o main -I /root/ -D DEBUG=2 -O2 -lm -L/usr/local/lib
```

### 如何节省编译的工作

1. 写MakeFile；
2. 使用autoconf、automake和libtool；

简单的makefile举例：

```
main.o: main.c
        gcc -c main.c -o main.o

all: main

main: main.o
        gcc main.o -o main

clean:
        rm main.o main
```

如何使用这个makefile：

```bash
# 编译（把all换成main效果一致）
# 方法1：用-f指定makefile文件
make -f makefile all
# 方法2：不指定makefile文件，默认会在当前文件夹寻找
# 按顺序寻找文件GNUmakefile-->makefile-->Makefile，找不到则报错
make all

# 清除编译结果，以下二选一
make clean
make -f makefile clean
```

makefile的基本组成如下（**command必须以一个tab开始**）：

```
# target表示目标体，它位于冒号之前
# dependency_files表示依赖的文件或target，它位于冒号之后
# command表示达成这个目标所需执行命令
target: dependency_files
        command
```

makefile里面也可定义和调用变量：

```
CC=gcc
EXE=main

main.o: main.c
        $(CC) -c main.c -o main.o

all: $(EXE)

$(EXE): main.o
        gcc main.o -o $(EXE)

clean:
        rm main.o $(EXE)
```

也可在外部调用时传入变量（会将makefile中已存在的变量覆盖掉），命令如下：

```bash
make EXE=mm all
make EXE=mm clean
```

### 使用GDB调试程序简介

使用`gdb 程序名（相对或绝对路径）`进入gdb：
2. 输入`break main`为main函数设置断点，输入`break main.c:5`为`main.c`的第5行设置断点；
3. 输入`i b`查看当前断点；
4. 输入`delete 1`删除第一个断点；
5. 输入`disable 1`停用第一个断点；
6. 输入`list main.c:5`可在gdb显示代码；
6. 输入`r`或`run`运行，这时用户将无法再输入命令，直到运行到断点时，gdb将交回命令行控制权，这时输入`n`或`next`表示运行到下一行，`s`或`step`表示进入当前行调用的函数，输入`return`返回到上一层函数；
7. gdb交回命令行控制权时，输入`print 参数名`可查看当前作用域内的具体参数值；
8. 假如程序意外退出，这时输入`where`、`bt`或`backtrace`可以查看错误堆栈；

### 如何查看帮助手册

终端下输入`man 命令名称`（如`man printf`）将看到如下提示：

```
Man: 寻找所有匹配的手册页 (set MAN_POSIXLY_CORRECT to avoid this)
 * printf (1)
   printf (3)
   printf (1p)
   printf (3p)
Man: 您需要什么手册页？
Man: 
```

1. 数字1表示这是一个用户命令（user commands，如**echo**）；
2. 数字2表示这是一个系统调用（system calls，如**fork**）；
3. 数字3表示这是一个标准库（stand library，如**printf**）；
4. 带p后缀的为POSIX标准，释义：POSIX标准定义了操作系统应该为应用程序提供的接口标准，一个POSIX兼容的操作系统编写的程序，应该可以在任何其它的POSIX操作系统（即使是来自另一个厂商）上编译执行；

## 编程实践

### 环境交互

1. 临时文件（用于暂时存放数据），使用下述命令查看具体用途
    - `man mkstemp`
    - `man tmpfile`
1. 环境变量（设置运行环境）
    - shell下`echo $USER`或`printenv USER`打印环境变量`USER`；
    - shell下`export USER=jayzee`设置环境变量`USER`为`jayzee`；
    - shell下`env`查询当前用户所有环境变量；
    - Linux下调用一个C/C++程序时，该程序继承其调用者的所有环境变量，标准库`stdlib.h`的`getenv`、`setenv`和`unsetenv`用于获取、操纵环境变量；
1. shell下调用程序结束后，使用`echo $?`获取程序退出代码（0表示正常）；
1. IO（输入输出流）
    - 程序中，宏`stdin`表示输入流，对应int值0；宏`stdout`表示标准输出流，对应int值1；宏`stderr`表示错误输出流，对应int值2；
    - `stdin`只能是buffered的，但其buffered size可以修改；
    - `stderr`只能是unbuffered，一有错误立即输出；
    - 当程序直接在shell调用并且直接输出到控制台时，`stdout`是line-buffered的，否则是buffered的，但其buffered size可以修改，`man setvbuf`查看标准库如何设置输入输出流；
    - 程序写文件也是默认buffered，写完后应使用`fflush(your_file)`立即清空buffer写入到文件；
    - shell命令`your_program > output_file.txt 2>&1`表示将`your_program`的标准输出写入到文件`output_file.txt`（`>`执行覆盖写，`>>`执行追加写），并且将错误输出流重定向到标准输出流，Linux规定文件名必须在流重定向之前；
    - shell命令`program 2>&1 | filter`表示将标准输出使用管道过滤，Linux规定重定向必须在过滤器之前；
1. `man getopt_long`查看`getopt.h`库如何处理程序参数（类似于`ls -l`的`-l`）；

### 好的编程习惯

使用断言assert：

- 所有需确认值为true或非0的需使用`assert(condition)`；
- 编译时指定`-DNDEBUG`可移除所有assert语句，所以**千万不要把程序的重要逻辑放在assert语句中**；

处理系统调用失败：

- 系统调用如`fork`失败时会返回非零值，这时宏`errno`会被设置，下次系统调用失败时又会覆盖这个宏的值；
- `man strerror`查看如何使用`string.h`的`strerror`的具体字符串释义，细节如下：

```
EINTR : blocking function interrupt, like sleep, read, select
EPERM : Permission denied
EROFS : PATH is on a read-only file system
ENAMETOOLONG : PATH is too long
ENOENT : PATH does not exit
ENOTDIR : A component of PATH is not a directory
EACCES : A component of PATH is not accessible
EFAULT : PATH contains an invalid memory address.  This is probably a bug
ENOMEM : Ran out of kernel memory
```

申请内存与释放内存：

- 申请内存与释放内存的语句必须成对，即有申请内存则相应的要有释放内存；

### 链接程序（库：快速开发，软件复用）

以下文字部分引用自[C++静态库与动态库 - 吴秦 - 博客园](http://www.cnblogs.com/skynet/p/3372855.html)，向该作者致敬。

下文用到的main.c文件：

```bash
/** main.c **/
int add(int x, int y) {
    return x + y;
}
```

#### 静态链接

静态库的特点：

- 静态库对函数库的链接是放在编译时期完成的；
- 程序在运行时与函数库再无瓜葛，移植方便；
- 浪费空间和资源，因为所有相关的目标文件与牵涉到的函数库被链接合成一个可执行文件；

静态库的创建：

- 静态库的命名规范为lib[your_library_name].a：lib为前缀，中间是静态库名，扩展名为.a；
- 首先将代码文件编译成目标文件.o，再通过ar工具将目标文件打包.a静态库文件；

```bash
# 假定有一个math.c文件，提供加法函数int add(int x, int y)，我们现在将其打包成静态库
gcc -c math.c -o math.o
ar -crv libmath.a math.o
```

使用静态库：

- 在编译时指定静态库搜索路径（-L选项）、指定静态库名称（不需要lib前缀和.a后缀，-l选项）；

```bash
# -l为什么一定要放在末尾？它会去查找库的所有被引用的函数或宏等并插入到最终的可执行程序，放在末尾是为了这种依赖搜索在最后执行
gcc main.c -o main -Lfilepath_of_your_static_library -lmath
```

静态库优缺点：

- 优点：编译成可执行文件后与其编译时引用的静态库再无任何瓜葛；
- 缺点：导致可执行程序体量庞大，同一个操作系统上运行的多个程序引用同一个静态库会导致内存浪费（相同的代码），导致客户的全量更新；

#### 动态链接

动态库的特点：

- 动态库把对一些库函数的链接载入推迟到程序运行的时期；
- 可以实现进程之间的资源共享（因此动态库也称为共享库）；
- 将一些程序升级变得简单；
- 甚至可以真正做到链接载入完全由程序员在程序代码中控制（显示调用）；

动态库的创建：

- 动态库的命名规范为lib[your_library_name].so：lib为前缀，中间是动态库名，扩展名为.so；
- 首先将代码文件编译成目标文件.o，再通过gcc工具将目标文件打包.so动态库文件；
    - `-fPIC`创建与地址无关的编译程序（pic，position independent code），是为了能够在多个应用程序间共享；
    - `-shared`指定生成动态链接库；

```bash
# 假定有一个math.c文件，提供加法函数int add(int x, int y)，我们现在将其打包成动态库
gcc -fPIC -c math.c -o math.o
gcc -shared -o libmath.so math.o
# 上面两条命令等价于
gcc -fPIC -shared -o libmath.so math.c
```

使用动态库：

- 在编译时指定动态库搜索路径（-L选项）、指定动态库名称（不需要lib前缀和.so后缀，-l选项）；

```bash
gcc main.c -o main -Lfilepath_of_your_static_library -lmath
```

- 注意，运行上述生成的可执行文件时，操作系统会去一些指定路径查找并载入该动态库，如查找不到将抛出找不到动态库的异常信息，这些指定路径是：
    - 环境变量LD_LIBRARY_PATH，如`LD_LIBRARY_PATH=/usr/local/lib:/opt/lib`；
    - /etc/ld.so.cache文件列表，需要额外操作如下：
        + 编辑/etc/ld.so.conf文件，加入库文件所在目录的路径；
        + 运行ldconfig ，该命令会重建/etc/ld.so.cache文件；
    - /lib/，/usr/lib目录；
- `-L`指定的库搜索路径下即有动态库也有静态库，则动态库具有较高优先级被链接；

动态库优缺点：

- 缺点：增量更新必须考虑向后兼容；
- 优点：增量更新，避免内存浪费（同一个操作系统上运行的多个程序引用同一个动态库只需要一份共享库示例）；

#### 链接检查辅助命令

`nm`命令：打印出库中的涉及到的所有符号。库既可以是静态的也可以是动态的。nm列出的符号有很多，常见的有三种，

- 一种是在库中被调用，但并没有在库中定义(表明需要其他库支持)，用U表示；
- 一种是库中定义的函数，用T表示，这是最常见的；
- 一种是所谓的弱态”符号，它们虽然在库中被定义，但是可能被其他库中的同名符号覆盖，用W表示；

`ldd`命令：查看一个可执行程序依赖的共享库。

## 进程

本章节部分内容引用自[Linux下Fork与Exec使用 - hicjiajia - 博客园](http://www.cnblogs.com/hicjiajia/archive/2011/01/20/1940154.html)和[系统调用跟我学(3)](http://www.ibm.com/developerworks/cn/linux/kernel/syscall/part3/index.html)，向作者致敬。

### 进程查看

`pid`指进程id，`ppid`指父进程id。

1. Linux所有**用户进程**呈树状结构，这棵用户进程树的根节点是init进程（内核启动的第一个用户级进程），init进程的`pid`为1，其ppid为0；
2. shell下运行`ps -e -o pid,ppid,command`可查看所有用户进程的pid、ppid和command；
3. `unistd.h`提供`getpid()`和`getppid()`获取进程的ID和父ID；

### 进程创建

#### system函数：执行shell命令

system函数用于在C/C++语言中执行shell命令，其API如下：

```bash
#include <stdlib.h>
int system(const char *command);
```

其具体实现是：

1. 先执行系统调用`fork()`创建子进程；
2. 再执行`execl("/bin/sh", "sh". "-c", command, (char *) 0);`去调用shell执行command；

#### fork函数，exec族函数

##### fork函数：创建子进程，进程分叉

fork函数API如下：

```bash
#include <unistd.h>
pid_t fork(void);
```

fork函数的特点：

- fork调用之后，父进程进入`pid>0`的分支，子进程进入`pid==0`的分支；
- fork创建的子进程是父进程的一个完整拷贝，**当且仅当fork之后的代码即将开始更新内存，真实的拷贝才会发生**（也就是上述例子并没有发生拷贝），为什么这么设计，我们会在下面讲到；
- fork创建的子进程拥有一个新的进程pid号，子进程的ppid为调用fork函数的进程id；

pid_t是一个整型变量。具体示例如下：

```c
/* zombie.c */
#include <sys/types.h>
#include <unistd.h>
int main() {
    pid_t pid;
    pid=fork();
    if(pid<0) /* 如果出错 */
        printf("error occurred!\n");
    else if(pid==0) /* 如果是子进程 */
        exit(0);
    else /* 如果是父进程 */
        sleep(60); /* 休眠60秒，这段时间里，父进程什么也干不了 */
    wait(NULL); /* 收集僵尸进程 */
}
```

##### exec函数族：对当前进程进行替换

exec并不是一个具体函数，它是以下六个函数：

```c
#include <unistd.h>
int execl(const char *path, const char *arg, ...);
int execlp(const char *file, const char *arg, ...);
int execle(const char *path, const char *arg, ..., char *const envp[]);
int execv(const char *path, char *const argv[]);
int execvp(const char *file, char *const argv[]);
int execve(const char *path, char *const argv[], char *const envp[]);
```

其中`execl`是基函数，其他5个是它的变种（区别在于传参形式不同，带v的表示参数以数组传递，带l的表示参数以陈列的方式传递）。

exec函数族特点：

- 只保留当前进程的pid，其他进程相关的数据段全部废弃；对系统而言，还是同一个进程号，但其实已经是另外一个程序了，即调用exec函数族的进程已“死亡”了；
- 上面说到，fork的数据拷贝只发生在子进程更新内存时，fork调用后立即执行exec函数族使得我们能够产生一个全新的进程（**这意味着当前进程的所有线程、文件描述符等都被释放**），与fork调用进程再无任何瓜葛；

举一个具体例子如下：

```c
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

char command[256];
void main()
{
   int rtn; /*子进程的返回数值*/
   while(1) {
       /* 从终端读取要执行的命令 */
       printf( ">" );
       fgets( command, 256, stdin );
       command[strlen(command)-1] = 0;
       if ( fork() == 0 ) {/* 子进程执行此命令 */
          execlp( command, NULL );
          /* 如果exec函数返回，表明没有正常执行命令，打印错误信息*/
          perror( command );
          exit( errno );
       }
       else {/* 父进程， 等待子进程结束，并打印子进程的返回值 */
          wait ( &rtn );
          printf( " child process return %d\n", rtn );
       }
   }
}
```

### 信号处理

信号是一种异步的进程通信机制，是软件层面的中断，进程接收到线程必须进行处理，有以下三种处理方式：

- 使用进程对信号的静默处理；
- 忽略该信号；
- 使用特定的信号处理函数进行处理；

上述的后两种方式需要使用`signal()`函数进行处理，举例如下：

```c
// 忽略SIGPIPE信号
signal ( SIGPIPE, SIG_IGN );
// 使用PrepareExit处理SIGINT信号
signal ( SIGINT, (__sighandler_t ) PrepareExit );
```

Linux的信号如下：

```
信号值 默认处理动作 发出信号的原因
SIGHUP 1 A 终端挂起或者控制进程终止
SIGINT 2 A 键盘中断（如break键被按下）
SIGQUIT 3 C 键盘的退出键被按下
SIGILL 4 C 非法指令
SIGABRT 6 C 由abort(3)发出的退出指令
SIGFPE 8 C 浮点异常
SIGKILL 9 AEF Kill信号
SIGSEGV 11 C 无效的内存引用
SIGPIPE 13 A 管道破裂: 写一个没有读端口的管道
SIGALRM 14 A 由alarm(2)发出的信号
SIGTERM 15 A 终止信号
SIGUSR1 30,10,16 A 用户自定义信号1
SIGUSR2 31,12,17 A 用户自定义信号2
SIGCHLD 20,17,18 B 子进程结束信号
SIGCONT 19,18,25 进程继续（曾被停止的进程）
SIGSTOP 17,19,23 DEF 终止进程
SIGTSTP 18,20,24 D 控制终端（tty）上按下停止键
SIGTTIN 21,21,26 D 后台进程企图从控制终端读
SIGTTOU 22,22,27 D 后台进程企图从控制终端写

处理动作一项中的字母含义如下：
A 缺省的动作是终止进程
B 缺省的动作是忽略此信号，将该信号丢弃，不做处理
C 缺省的动作是终止进程并进行内核映像转储（dump core），内核映像转储是指将进程数据在内存的映像和进程在内核结构中的部分内容以一定格式转储到文件系统，并且进程退出执行，这样做的好处是为程序员提供了方便，使得他们可以得到进程当时执行时的数据值，允许他们确定转储的原因，并且可以调试他们的程序
D 缺省的动作是停止进程，进入停止状况以后还能重新进行下去，一般是在调试的过程中（例如ptrace系统调用）
E 信号不能被捕获
F 信号不能被忽略
```

**注意**：
信号处理函数可被新产生的信号所中断，所以信号处理函数应该做尽可能少的工作；


### 进程终止

#### 信号终止

1. `SIGINT`：CRTL+C产生；
2. `SIGTERM`：shell下`kill pid`产生；
3. `abort()`：发送一个`SIGABRT`信号给自己；
4. `SIGKILL`：强制退出信号，shell下`kill -9 pid`产生；

当进程终止时，shell调用`echo $?`可取得该进程的exit code，

- 如果该进程由信号终止，exit code为128加上信号值；
- 调用`exit(int exit_code)`函数退出，exit_code的范围需在0到128之间；

如何给进程发送指定信号，

- 在shell下使用`kill -s SIGNAL_NAME pid`，可以给进程pid发送SIGNAL_NAME信号；
- 程序使用`kill(pid, SIGNAL_NAME)`函数；

#### wait

Unix的进程终止时，一些资源（如进程pid、进程exit code、收到的信号、占用CPU时间等）并不会被立即释放（堆栈等内存立即释放），死亡进程的父进程必须调用`wait`函数对进程进行“收尸”，即释放进程的pid和exit code等资源。

`wait`函数的API定义如下：

```c
pid_t wait(int *status);
```

一些说明：

- `wait`函数是阻塞式的，在子进程未结束时将阻塞；
- 如果`pid_t`为-1，表明`wait`调用失败，这是因为调用进程没有子进程导致；否则，表明收集子进程“死亡”信息成功，`pid_t`的值为“死亡”进程pid；
- `status`是一个指针，如果这个指针为空，表明我们不关心进程的“死亡”信息细节，只是发起了回收这个动作；否则，status将包含进程“死亡”的一些信息；
- 调用`WIFEXITED(status)`，若返回值回0表明进程异常退出（如信号导致退出），这时调用`WTERMSIG(status)`将得到使进程死亡的信号int值；否则表示程序正常退出，这时候调用`WEXITSTATUS(status)`可获取“死亡”进程的exit code（如“死亡”进程调用`exit(7)`退出，则`WEXITSTATUS(status)`的结果为7）；

```c
/* wait2.c */
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

main()
{
    int status;
    pid_t pc,pr;
    pc=fork();
    if(pc<0)     /* 如果出错 */
        printf("error ocurred!\n");
    else if(pc==0){ /* 子进程 */
        printf("This is child process with pid of %d.\n",getpid());
        exit(3);    /* 子进程返回3 */
    }
    else{       /* 父进程 */
        pr=wait(&status);
        if(WIFEXITED(status)){  /* 如果WIFEXITED返回非零值 */
            printf("the child process %d exit normally.\n",pr);
            printf("the return code is %d.\n",WEXITSTATUS(status));
        }else           /* 如果WIFEXITED返回零，这时pr存储死亡进程pid */
            printf("the child process %d exit abnormally with signal number %d.\n",pr,WTERMSIG(status));
    }
}
```

#### 僵尸进程

如果子进程死亡，父进程却没有调用`wait`对其进行“收尸”，子进程就会变成一个僵尸进程，

```
$ ps -ax
  PID TTY      STAT   TIME COMMAND
 1177 pts/0    S      0:00 -bash
 1577 pts/0    S      0:00 ./zombie
 1578 pts/0    Z      0:00 [zombie <defunct>]
 1579 pts/0    R      0:00 ps -ax
```

若STAT为Z则表明则是一个僵尸进程，关于僵尸进程，

- 在父进程退出时，init进程会自动对其下的所有僵尸子进程进行清理；
- 子进程意外死亡时，父进程会受到一个SIGCHLD信号，父进程可以注册这个信号的处理函数进行“收尸”；
- `wait3`和`wait4`函数为异步的，可以周期调用这两个函数执行回收；

## 线程

### 线程创建

**线程创建**：`int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
void *(*start_routine) (void *), void *arg);`

- `pthread_create`的返回值为0表示创建线程成功；
- `thread`是指向`pthread_t`的指针；
- `pthread_attr_t`在下一个例子介绍；
- `start_routine`是一个无形参且无返回值的函数指针；
- `arg`是上面提到的函数指针所接收的参数；

**线程回收**：`int pthread_join(pthread_t thread, void **retval);`

- `retval`实际上是一个指向整型指针的指针，它存放的是线程调用`exit`或`pthread_exit`的退出值；
- `When a joinable thread terminates, its memory resources (thread descriptor and stack) are not deallocated until another thread performs pthread_join on it. Therefore, pthread_join must be called  once  for each joinable thread created to avoid memory leaks.`
- 这是一个阻塞式的方法，当监控到有线程结束时才返回；

**线程退出**：`void pthread_exit(void *retval);`

- `retval`实际是一个整型指针，在退出时标识线程的退出值；

```c
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

int code = 11;

void hello(void *args) {
    char *str = (char *) args;
    sleep(5);
    printf("Hello, %s!\n", str);
    pthread_exit(&code);
}

int main() {
    pthread_t thread;
    int status = pthread_create(&thread, NULL, (void *)hello, (void *) "Jayzee");
    printf("thread create status : %d\n", status);
    int *exit_code = 0;
    status = pthread_join(thread, (void *) &exit_code);
    printf("thread join status : %d\n", status);
    printf("thread exit code : %d\n", *exit_code);
    return 0;
}
```

------

下面的例子在`pthread_create`时用到了`pthread_attr_t`，必须经历下面四个过程

1. 先实例化`pthread_attr_t`；
2. 再设置`pthread_attr_t`；
3. 在线程创建时使用该`pthread_attr_t`；
4. 线程创建完后销毁`pthread_attr_t`；

注意：

1. 创建线程时设置其为detach态，意味着我们不关心它的返回值，只是进行线程相关资源回收；
2. 也可创建线程时不指定detach态，在线程创建后可使用`int pthread_detach(pthread_t thread);`设置其为detach态；

```c
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

int code = 11;

void hello(void *args) {
    char *str = (char *) args;
    sleep(5);
    printf("Hello, %s!\n", str);
    pthread_exit(&code);
}

int main() {
    pthread_t thread;
    pthread_attr_t attr;
    pthread_attr_init (&attr);
    pthread_attr_setdetachstate (&attr, PTHREAD_CREATE_DETACHED);
    int status = pthread_create (&thread, &attr, (void *)hello, (void *) "Jayzee");
    pthread_attr_destroy (&attr);
    printf("thread create status : %d\n", status);
    return 0;
}
```

### 线程取消

```
int pthread_setcancelstate(int state, int *oldstate);
int pthread_setcanceltype(int type, int *oldtype);
int pthread_cancel(pthread_t thread);
```

- `pthread_setcancelstate`在运行时设置线程的状态`state`，并取得其之前的状态`oldstate`；
- `pthread_setcanceltype`在运行时设置线程的类型`type`，并取得其之前的类型`oldtype`；
- `pthread_cancel`用于取消线程的执行；


注意，

1. type：`PTHREAD_CANCEL_DEFERRED`或`PTHREAD_CANCEL_ASYNCHRONOUS`
2. state：`PTHREAD_CANCEL_ENABLE`或`PTHREAD_CANCEL_DISABLE`
3. type和state作用于`pthread_cancel`：
    - 当state为`PTHREAD_CANCEL_DISABLE`时，设置的type和调用`pthread_cancel`不会对线程造成任何影响；
    - 否则，当设置的type为`PTHREAD_CANCEL_DEFERRED`时，为非阻塞取消（等待达到取消的条件，如释放锁）；当设置的type为`PTHREAD_CANCEL_ASYNCHRONOUS`时为异步取消（即线程立即被取消，但不同操作系统有可能实现不同，理应处理释放锁）；

```c
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

int code = 11;

void hello(void *args) {
    pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, &last_state); 
    pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, &last_type);
    char *str = (char *) args;
    sleep(5);
    printf("Hello, %s!\n", str);
    pthread_exit(&code);
}

int main() {
    pthread_t thread;
    int status = pthread_create(&thread, NULL, (void *)hello, (void *) "Jayzee");
    printf("thread create status : %d\n", status);
    int *exit_code = 0;
    status = pthread_join(thread, (void *) &exit_code);
    printf("thread join status : %d\n", status);
    printf("thread exit code : %d\n", *exit_code);
    pthread_cancel(thread);
    return 0;
}
```

### 线程特定数据

```
int pthread_key_create(pthread_key_t *key, void (*destructor)(void*));
int pthread_setspecific(pthread_key_t key, const void *value);
void *pthread_getspecific(pthread_key_t key);
```

1. 使用`pthread_key_create`创建`key`，`destructor`为线程结束时用于析构的函数指针，一个进程内的多个线程可以共用一个`key`；
2. `pthread_setspecific`为线程设定key-value，`pthread_getspecific`根据key获得value；
3. 当线程结束时，若`pthread_getspecific`的内容不为空，且`destructor`不为空，则`pthread_getspecific`的内容将作为`destructor`的参数来执行析构函数；

```c
#include <malloc.h>
#include <pthread.h>
#include <stdio.h>

/* The key used to associate a log file pointer with each thread. */
static pthread_key_t thread_log_key;

/* Write MESSAGE to the log file for the current thread. */
void write_to_thread_log (const char* message) {
    FILE* thread_log = (FILE*) pthread_getspecific (thread_log_key);
    fprintf (thread_log, "%s\n", message);
}

/* Close the log file pointer THREAD_LOG. */
void close_thread_log (void* thread_log) {
    fclose ((FILE*) thread_log);    
}

void* thread_function (void* args) {
    char thread_log_filename[20];
    FILE* thread_log;
    /* Generate the filename for this thread’s log file. */
    sprintf (thread_log_filename, "thread%d.log", (int) pthread_self ());
    /* Open the log file. */
    thread_log = fopen (thread_log_filename, "w");
    /* Store the file pointer in thread-specific data under thread_log_key. */
    pthread_setspecific (thread_log_key, thread_log);
    write_to_thread_log ("Thread starting.");
    /* Do work here... */
    return NULL;
}

int main () {
    int i;
    pthread_t threads[5];
    /* Create a key to associate thread log file pointers in
    thread-specific data. Use close_thread_log to clean up the file
    pointers. */
    pthread_key_create (&thread_log_key, close_thread_log);
    /* Create threads to do the work. */
    for (i = 0; i < 5; ++i)
        pthread_create (&(threads[i]), NULL, thread_function, NULL);
    /* Wait for all threads to finish. */
    for (i = 0; i < 5; ++i)
        pthread_join (threads[i], NULL);
    return 0;
}  
```

```
void pthread_cleanup_push(void (*routine)(void *), void *arg);
void pthread_cleanup_pop(int execute);
```

1. `pthread_cleanup_push`在线程运行时为线程压栈清理函数；
2. `pthread_cleanup_pop`从栈弹出一个清理函数，如果`execute`不为0则执行这个清理函数；
3. 线程结束时，所有压栈的清理函数会自动被弹出栈进行执行；
4. 当在线程内使用longjump前，应手动调用`pthread_cleanup_pop`执行清理；

### 线程同步

#### 互斥锁

```
int pthread_mutex_destroy(pthread_mutex_t *mutex);
int pthread_mutex_init(pthread_mutex_t *restrict mutex,
    const pthread_mutexattr_t *restrict attr);
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
```

1. `pthread_mutex_destroy`销毁互斥锁，`pthread_mutex_init`创建互斥锁；
2. `pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;`表示定义并默认实例化一个互斥锁；

```
int pthread_mutex_lock(pthread_mutex_t *mutex);
int pthread_mutex_trylock(pthread_mutex_t *mutex);
int pthread_mutex_unlock(pthread_mutex_t *mutex);
```

1. `pthread_mutex_lock`为阻塞锁，`pthread_mutex_trylock`为非阻塞锁（获取不到锁）则立即返回，`pthread_mutex_unlock`为释放锁；

```c
#include <pthread.h>

int main() {
    pthread_mutexattr_t attr;
    pthread_mutex_t mutex;
    pthread_mutexattr_init (&attr);
    // 带错误检查的互斥锁
    pthread_mutexattr_setkind_np (&attr, PTHREAD_MUTEX_ERRORCHECK_NP);
    pthread_mutex_init (&mutex, &attr);
    pthread_mutex_lock(&mutex);
    /** do some work **/
    pthread_mutex_unlock(&mutex);
    pthread_mutexattr_destroy (&attr);
}
```

#### 信号量

```
int sem_init(sem_t *sem, int pshared, unsigned int value);
int sem_post(sem_t *sem);
int sem_wait(sem_t *sem);
```

1. `sem_init`实例化信号量`sem`，`pshared`为0表示进程内共享（非0为进程间共享），`value`为初始容量值（默认容量值为0）；
2. `sem_wait`将容量值减一，`sem_wait`之后若容量值小于0则线程阻塞；`sem_post`将容量值加一；
3. 假设容量值为负，一次`sem_post`只能唤醒一个线程；
4. `sem_wait`和`sem_post`是线程安全的；

```c
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <semaphore.h>

sem_t semaphore;

void threadfunc() {
    int i = 0;
    for (; i<10; i++) {
        // 实际上不会这么使用，这里仅是展示
        sem_wait(&semaphore);
        printf("Hello from da thread!\n");
        sem_post(&semaphore);
        sleep(1);
    }
}

int main(void) {
    // 实例化
    sem_init(&semaphore, 0, 1);
    
    pthread_t *mythread;    
    mythread = (pthread_t *)malloc(sizeof(*mythread));
    
    // 启动线程
    printf("Starting thread, semaphore is unlocked.\n");
    pthread_create(mythread, NULL, (void*)threadfunc, NULL);
    pthread_join(mythread, NULL);
    
    return 0;
}
```

#### 条件值

```
int pthread_cond_init(pthread_cond_t *restrict cond,
    const pthread_condattr_t *restrict attr);
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
int pthread_cond_signal(pthread_cond_t *cond);
int pthread_cond_wait(pthread_cond_t *restrict cond,
   pthread_mutex_t *restrict mutex);
```

1. `pthread_cond_t cond = PTHREAD_COND_INITIALIZER;`等价于`pthread_cond_init(&pthread_cond_t, NULL);`
2. 当调用`pthread_cond_signal`或`pthread_cond_wait`时，必须获得锁；
3. 调用`pthread_cond_wait`时，自动释放锁，直到被`pthread_cond_signal`唤醒时，才重新自动获得锁；
4. `pthread_cond_timedwait`可批量唤醒等待的线程；

```c
#include <stdio.h>
#include <pthread.h>

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
int condition = 0;
int count = 0;

int consume( void )
{
    while( 1 )
    {
        pthread_mutex_lock( &mutex );
        while( condition == 0 )
            pthread_cond_wait( &cond, &mutex );
        printf( "Consumed %d\n", count );
        condition = 0;
        pthread_cond_signal( &cond );        
        pthread_mutex_unlock( &mutex );
    }

    return( 0 );
}

void* produce( void * arg )
{
    while( 1 )
    {
        pthread_mutex_lock( &mutex );
        while( condition == 1 )
            pthread_cond_wait( &cond, &mutex );
        printf( "Produced %d\n", count++ );
        condition = 1;
        pthread_cond_signal( &cond );        
        pthread_mutex_unlock( &mutex );
    }
    return( 0 );
}

int main( void )
{
    pthread_create( NULL, NULL, &produce, NULL );
    return consume();
}
```

### 线程实现

Linux的线程实现是系统调用`clone()`，它创建一个与父进程共用资源的子进程。

## 进程间通信

### 共享内存

```
#include <sys/ipc.h>
#include <sys/shm.h>
int shmget(key_t key, size_t size, int shmflg);
void *shmat(int shmid, const void *shmaddr, int shmflg);
int shmdt(const void *shmaddr);
int shmctl(int shmid, int cmd, struct shmid_ds *buf);
```

1. `shmget`申请共享内存；
2. `shmat`取得已申请的共享内存，共享内存使用者计数器加1；
3. `shmdt`断开已申请的共享内存，共享内存使用者计数器减1，如果计时器减到0，这块共享内存会被系统标注并删除；
4. `shmctl`对共享内存的标识信息进行设置；

### 进程信号量

```
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
int semget(key_t key, int nsems, int semflg);
int semctl(int semid, int semnum, int cmd, ...);
int semop(int semid, struct sembuf *sops, size_t nsops);
```

1. `semget`用于申请信号量；
2. `semctl`用于释放或实例化信号量；
3. `semop`用于执行wait或post；

### 映射到内存

```
#include <sys/mman.h>
void *mmap(void *addr, size_t length, int prot, int flags,
    int fd, off_t offset);
```

`mmap`是一种内存映射文件的方法，即将一个文件或者其它对象映射到进程的地址空间，实现文件磁盘地址和进程虚拟地址空间中一段虚拟地址的一一对映关系。实现这样的映射关系后，进程就可以采用指针的方式读写操作这一段内存，而系统会自动回写脏页面到对应的文件磁盘上，即完成了对文件的操作而不必再调用read,write等系统调用函数。相反，内核空间对这段区域的修改也直接反映用户空间，从而可以实现不同进程间的文件共享。

### 管道

```
#include <unistd.h>
int pipe(int pipefd[2]);
```

`pipe`的一端写，由内核缓存，直到另一端将其读出。

### Socket

```
#include <sys/types.h>
#include <sys/socket.h>
int socket(int domain, int type, int protocol);
int close(int fd);
int connect(int sockfd, const struct sockaddr *addr,
    socklen_t addrlen);
int bind(int sockfd, const struct sockaddr *addr,
    socklen_t addrlen);
int listen(int sockfd, int backlog);
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
```

1. `socket`创建一个socket；
2. `close`关闭一个socket；
3. `connect`建立两个socket的连接；
4. `bind`将socket绑定到地址和端口；
5. `listen`配置socket接受连接的条件；
6. `accept`接收一个socket连接并为其创建一个socket；

## 设备

### 操作

```
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
int mknod(const char *pathname, mode_t mode, dev_t dev);
```

`mknod`用于创建一个设备。

```
#include <sys/ioctl.h>
int ioctl(int d, unsigned long request, ...);
```

`ioctl`用于控制设备，常用于驱动编程。

### 特殊设备

`/dev/null`是一个内容为空的设备，将IO流定向到`/dev/null`意味着丢弃其内容；

`/dev/zero`是一个无限长的文件；

`/dev/random`可用于产生随机数；

`/dev/tty*`是串行终端设备，如串口；

`pty`是伪终端，接受键盘的输入并显示到运行它的终端界面；

`pty`的实现涉及到两个概念：

- `ptmx`：被连接的master主机；
- `pts`：发起向master主机连接的slave主机`pts`，我们常用的SSH登录就意外着在master主机建立一个`pts`进程；

## 常用/proc简介

`/proc/cpuinfo`查看cpu信息；

`/proc/meminfo`查看内存信息；

`/proc/self`查看自身信息；

`/proc/pid_number`查看pid为pid_number的进程信息；

`/proc/loadavg`查看负载信息；

`/proc/uptime`查看启动时间；

`/proc/interrupts`查看中断情况；

## 常用系统调用

`strace`查看系统调用情况；

`access`检测是否具备读写权限；
`fcntl`操纵文件描述符；

`fsync`和`fdatasync`将缓冲区的文件改动同步到实际文件；

`getrlimit`取得系统的资源限定情况；

`getrusage`取得系统资源使用情况；

`gettimeofday`取得系统时间；

`mlock`锁住一块内存；

`mprotect`保护一块内存；

## 用户与用户组

### 用户与用户组ID

每个用户名对应到一个用户ID，每个用户ID可从属于多个用户组ID。Shell下输入`id`得到如下输出：

```
# uid为0表示root用户
uid=0(root) gid=0(root) groups=0(root),1001(nagcmd)
```

### 文件与用户（组）的关系

`ls -l APL.txt`后得到如下输出：

```
-rw-r--r-- 1 Jayzee None   1237 五月 18 12:19 APL.txt
```

`-rw-r--r--`解释：

- 第一个字符`-`表示这是一个文件，`d`表示这是一个文件夹；
- 2至4字符`rw-`表示拥有者`Jayzee`的权限，顺序为：读（r）、写（w）、执行（x），可读写但不可执行；
- 5至7字符`r--`表示所属组`None`的权限；
- 8至10字符`r--`表示组外其他用户的权限；

`man chmod`查看如何更改文件的权限；
`man chown`查看如何更改文件的拥有者和所属组；

**特殊**

```
drwxrwxrwt   1 root root 26416 5月  18 21:53 tmp
```

只适用于文件夹：当文件夹的所属组或组外的执行（x）被设置为（t）时，表示当且仅当你是该文件夹内文件的创建者，才可以删除该文件；（正常情况下如果该文件夹内文件的权限是对于组或组外可读写，不需要是文件的创建者也可删除的），这里的`t`称为sticky bits。

### 真实的用户ID和有效的用户ID

定义`euid`为有效用户id（effective），`uid`为真实用户id（real）；

`man 2 getuid`查看如何使用C函数获取uid；
`man 2 geteuid`查看如何使用C函数获取euid；

为什么要引入euid？

1. 当用户发出对文件的操作时，Linux Kernel根据用户的euid检查用户是否具备权限；
2. euid可被修改，uid不可被修改；
3. euid被修改代表着用户的切换，uid不被修改表示最初登入系统的uid不变；

用户登录系统时用户id发生什么变化？

1. Linux的登录进程检查登入者输入的账号密码是否正确；
2. 若正确，使用`exec`为其创建一个User Shell（pts）；
3. Linux的登录进程设置这个User Shell的euid和uid为同一个值，即该用户的uid（只有euid为0的User Shell可设置euid和uid）；

设置说明：

1. 当我们设置`euid = uid`时，表示返回到最初登录用户的Shell；
2. 当我们设置`uid = euid`时，表示Linux的登录进程将euid与uid同步，该登录用户与Linux的登录进程（root）再无联系；

`su`命令的原理：

1. `/bin/su`的拥有者为root，其执行项不是（x）而是（s），当文件拥有者的执行项不是（x）而是（s）时，此文件可被执行，且执行文件时调用`geteuid`函数返回的是该可执行文件拥有者的uid而不是调用者的euid；
2. Linux利用此技术实现普通用户到root用户时，uid不变，而euid变为0；
3. 当调用`su`时，调用者原User Shell阻塞，Kernel创建一个新User Shell给调用者使用；

注：组ID也分真实和有效，与用户ID类同，故不展开叙述；
