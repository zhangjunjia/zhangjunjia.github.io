---
title: 浅谈有状态Java服务热部署方案
date: 2020-04-25 21:03:36
tags: ['Java', '系统设计']
comments: true
categories: ['系统设计', '编程语言']
---

近期工作中需解决Java有状态服务的热部署问题，将调研的方案以及其trade-off阐述如下。

<!--more-->

## Java语言层面解决方案

**方案一**是ClassLoader方案。

Java的类加载遵循双亲委派模式，检查类加载时从`AppClassLoader->ExtClassLoader->BoostrapClassLoader`自底向上检查类是否加载，若已加载则直接取缓存的Class返回。否则，按照`BoostrapClassLoader->ExtClassLoader->AppClassLoader`的顺序自顶向下尝试加载类，若上层不具备加载能力则由下层负责，直至类加载成功或抛出异常。Classpath的类默认由AppClassLoader加载，双亲委派模式使得Class只会加载一次，后续对Class的获取都是从ClassLoader中取缓存。

使用自定义ClassLoader可以破坏双亲委派模式的这种缓存机制，需要继承ClassLoader类重写`loadClass`方法破坏双亲委派的向上查找行为。当`.class`文件变化时，创建新的自定义ClassLoader实例`cl`，然后用`cl`读取`.class`文件加载新的Class，再用该Class的`newInstance`方法创建新的对象，这样就规避了双亲加载的Class缓存机制。这种做法的限制是，由于对象的方法/属性是动态变化的，因此只能通过反射调用去操作该对象的方法和成员变量。

文章[Add dynamic Java code to your application](https://www.javaworld.com/article/2071777/add-dynamic-java-code-to-your-application.html?page=1)提出了一种使用ClassLoader以及预定义好的Interface接口，热部署接口实现类的思路。

**方案二**是Java Agent方案。

Java程序启动时借助`-javaagent`的VM参数可以实现在main函数之前的`premain`调用，`premain`可以设置`ClassFileTransformer`实现对指定Class的拦截，拦截后可以借助于ASM等字节码修改技术对Class进行修改。

在Java程序启动后，可以利用JVM的attach技术将agent代码attach到指定的JVM，将会触发`agentmain`调用。`agentmain`调用将对attach之后的类加载行为进行拦截，也可以使用`retransformClasses`触发特定Class的立即转换，转换代码同样需设置`ClassFileTransformer`，同样是借助ASM等字节码修改技术修改Class。也可借助`redefineClasses`调用强制覆盖指定Class的字节码。

以上两种方式的实现都得借助于`Instrument`类，这种做法的限制是只能**修改方法体内的内容**，此外的行为都做不了。

**方案三**是OSGi。这种方案需要对现有代码按照OSGi标准进行大改造，会引入额外工作量，一般不予考虑，可参考[Apache Karaf](http://karaf.apache.org/)。

**方案四**是ClassLoader与Java Agent的结合。其思想是，通过Java Agent拦截修改原有类的字节码，将方法调用/属性访问等行为都转变成代理行为，具体实现则放到自定义ClassLoader动态加载的Class通过`newInstance`方法创建的对象。

假设原始的Worker类代码及使用方式如下：

```java
Worker worker = new Worker();
System.out.println(worker.workCount);
worker.run(1);

Class Worker {
    ......
    int workCount = 0;
    public void run(int ticket) {
        ......
    }
}
```

通过Java Agent拦截修改后，其实现变成以下方式：
```java
Worker worker = new Worker();
System.out.println((int) worker._property_invoke_get('workCount'));
worker._method_invoke_noreturn('run', 1);

Class Worker {
    ......
    int workCount = 0;
    public void run(int ticket) {
        ......
    }
    public Object _property_invoke_get(String property) {
        // 属性路由
    }
    public void _method_invoke_void(String method) {
        // 方法路由
    }
}
```

属性路由、方法路由的具体实现，则调用自定义ClassLoader动态加载的Class创建出来的实例实现。这样既满足`Instrument`只能修改方法体的规约，又可以动态新增/修改类成员、类方法了。缺点是实现起来有一定复杂度。

## 状态下沉方案

Facebook的论文[Fast Database Restarts at Facebook](https://research.fb.com/wp-content/uploads/2016/11/fast-database-restarts-at-facebook.pdf)阐述了一种借助于shared memory实现快速部署的方案。

在服务RUNNING阶段，他们并未使用shared memory，他们服务的数据仍然存在于Java Heap。在Java程序即将结束前，会把Java Heap数据逐一复制到shared memory；在Java程序启动后，再逐一将shared memory的数据复制到Java Heap。服务RUNNING阶段，之所以不直接把数据存储在shared memory，他们主要考虑的是内存碎片的不可控。
> We worried that an allocator in shared memory would lead to increased fragmentation over time.

使用shared memory必然会带来的问题是：
- Java官方不支持直接操作shared memory。Tomcat基于Apache Portable Runtime库做了JNI封装， 论文基于Boost:Interprocess做了JNI封装，才得以访问shared memory。
- shared memory的二进制数据和Java堆对象的相互转换，必然存在序列化/反序列化的开销。

和shared memory方案类似的一种方案是：我们可以创建一个[RAM drive](https://en.wikipedia.org/wiki/RAM_drive)，Java程序停止前将数据offload到RAM drive，Java程序启动后再从RAM drive中将状态还原到Java Heap。无论是shared memory还是RAM drive，都需要考虑边复制边释放的问题，否则内存占用就double了。

除了将状态数据下沉到shared memory，还可以考虑将状态下沉到诸如Redis、Memcached之类的服务，但这除了带来序列化/反序列化问题，还带来了网络开销问题。

## 异步系统方案

假如对于有状态服务的调用是同步的，可以考虑进行异步化改造。

```
改造前：调用方 -> 有状态服务
改造后：调用方 -> 分布式消息队列 -> 弱状态服务
```

调用方的调用不直接投递到有状态服务，而是暂存在分布式消息队列，这样有状态服务完成部署后重新从分布式消息队列拉取任务进行消费即可。

## Reference

[深入浅出JVM ClassLoader](https://www.jianshu.com/p/85eba062b9c1)
[Java程序员必知：深入理解Instrument](https://www.jianshu.com/p/5c62b71fd882)
[Fast Database Restarts at Facebook](https://research.fb.com/wp-content/uploads/2016/11/fast-database-restarts-at-facebook.pdf)
[Add dynamic Java code to your application](https://www.javaworld.com/article/2071777/add-dynamic-java-code-to-your-application.html?page=1)
