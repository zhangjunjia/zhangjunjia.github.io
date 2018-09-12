---
layout: post
title: Spring Boot初探
date: '2016-01-23 15:02'
comments: true
categories: ['编程实践']  
tags: ['Spring']
---

本着实用主义的目的简单介绍Spring Boot。

<!--more-->

## 概要

- 它的出现并不是为了取代传统的Spring Framework，而是提供一种新的Spring开发体验——尽可能消除大量繁琐的XML配置
- 个人觉得Spring Framework的Java注解式开发已经做得够好了（省去大量的配置工作），并不是非得用Spring Boot不可的
- 官网的[Guide](http://docs.spring.io/spring-boot/docs/current-SNAPSHOT/reference/htmlsingle/)已经写得非常好了，我只是从实用主义讲如何快速入门

## 代码与相关理论

### 准备工作

访问[Spring Initializr](https://start.spring.io/)生成以maven构建的demo项目，Dependencies我分别勾选了[Web]和[Security]，在终端下定位到生成的demo项目运行`mvn eclipse:eclipse`生成eclipse标识，接下来就可以使用eclipse进行开发了。

### 代码（自动生成）游园活动

代码结构如下：
```
demo
 + src/test/java
   + com.example
     - DemoApplicationTests.java
 + src/main/java
   + com.example
     - DemoApplication.java
 + src/main/resources
   + templates
   + static
   - application.properties
 - pom.xml 
```

#### pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>demo</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <!-- 不同于传统Spring的地方：兼容将项目打包成war丢到外置Tomcat容器，也可打包成jar使用内置Tomcat运行Spring Web项目，直接运行jar包即可 -->
    <packaging>jar</packaging>

    <name>demo</name>
    <description>Demo project for Spring Boot</description>

    <!-- 必须要引入的parent，parent包含了大量基础的spring依赖，因此你不需要在pom.xml配置一堆所需引用的spring jar包 -->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>1.3.2.RELEASE</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <java.version>1.8</java.version>
    </properties>

    <!-- 以组件的形式在这里添加一条dependency，即官网宣称的开箱即用，简直傻瓜式啊 -->
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>    

</project>
```
可开箱即用的其他dependency如下：
- [官网](http://docs.spring.io/spring-boot/docs/current-SNAPSHOT/reference/htmlsingle/#using-boot-starter-poms)
- [非官网](https://github.com/spring-projects/spring-boot/blob/master/spring-boot-starters/README.adoc)

#### DemoApplication.java

```java
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * @SpringBootApplication等价于 @Configuration @EnableAutoConfiguration @ComponentScan
 * @Configuration标注配置类，即以往的XML配置文件被映射成了一个类
 * @EnableAutoConfiguration，表示由Spring Boot启动默认配置，如web项目将默认配置内置tomcat端口号8080
 * @ComponentScan放置在basePackage（例子中是com.example），com.example.*下的所有Java文件将被扫描解释
 */
@SpringBootApplication
public class DemoApplication {

    // 这里的args一般传的是配置类
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}

```

#### DemoApplicationTests.java

```java
package com.example;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.boot.test.SpringApplicationConfiguration;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;

@RunWith(SpringJUnit4ClassRunner.class) // 指定以spring-junit运行单元测试
@SpringApplicationConfiguration(classes = DemoApplication.class) // 指定我们的应用类
@WebAppConfiguration // 表明要测试的是一个web应用
public class DemoApplicationTests {

    @Test
    public void contextLoads() {
    }

}
```

#### application.properties

Spring Boot的默认配置文件，假设我在此文件有一个键值`name=jayzee`，那么我在java代码中可以直接使用如下（Spring Boot自动注入）：

```java
@Value("${name}")
private String name;
```

我在此文件添加一个键值`server.port=8090`修改内置tomcat的默认端口为8090。

#### templates

[Template engines](http://docs.spring.io/spring-boot/docs/current-SNAPSHOT/reference/htmlsingle/#boot-features-spring-mvc-template-engines)说到：
- 此文件夹用于放置动态html如jsp（官网建议尽量少用，因为在内置tomcat下运行将不起作用）等其他模板文件

#### static

[Static Content](http://docs.spring.io/spring-boot/docs/current-SNAPSHOT/reference/htmlsingle/#boot-features-spring-mvc-static-content)
- 此文件用于存放静态资源文件如：html、js、css和json等
- 如果这里存放有index.html，则默认作为项目的home page
- 前台代码`<link href="/css/spring-2a2d595e6ed9a0b24f027f2b63b134d6.css"/>`直接引用`/static/css/spring-2a2d595e6ed9a0b24f027f2b63b134d6.css`

### 结尾

终端定位到demo项目，运行

```
mvn package
java -jar target/demo-0.0.1-SNAPSHOT.jar
```

访问`http://localhost:8090/`则可看到弹出一个登录窗口（因为我们引入了security组件）。

[Security](http://docs.spring.io/spring-boot/docs/current-SNAPSHOT/reference/htmlsingle/#boot-features-security)提到，默认账户是`user`，随机密码在启动tomcat时在控制台打印。

其他资源：
- [spring boot之login+jdbc完整例子](http://www.tianmaying.com/tutorial/spring-mvc-microblog)
- [此博文demo项目源码](https://github.com/JayzeeZhang/spring-boot-demo)
