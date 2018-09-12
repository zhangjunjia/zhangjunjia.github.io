---
layout: post
title: Multi virtual HOST of Tomcat
date: '2016-08-17 17:51'
comments: true
categories: ['编程实践'] 
tags: ['Tomcat']
---

本文介绍tomcat如何设置multi vitual host。

<!--more-->

## why and how does it work

注：以下的全部域名是为了举例虚构，出于一些考虑，笔者不打算公布真实域名。

笔者有个域名为[gx.com](http://www.gx.com)，指向个人主页。同时，该域名下有个资源[gx.com/product](http://gx.com/product)，指向笔者的产品界面。某天从同事那了解到还可以设置二级域名，于是，我想把我的产品界面链接[gx.com/product](http://gx.com/product)改为[product.gx.com](http://product.gx.com)，用二级域名的方式来指向（如何创建二级域名请自行搜索）。

笔者的个人主页和产品界面都部署在同一主机的同一个Tomcat容器下（80端口），查了下资料，通过配置Tomcat就可以实现我的上述要求。且先不说如何配置，其工作原理是什么呢？Tomcat在80端口监听HTTP连接，它是如何判断一个HTTP请求到底是要请求[gx.com](http://www.gx.com)的资源，还是要请求[product.gx.com](http://product.gx.com)的资源呢？

```
GET / HTTP/1.1
Host: www.gx.com
Proxy-Connection: keep-alive
User-Agent: Mozilla/5.0 (Windows NT 6.2) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Encoding: gzip,deflate,sdch
Accept-Language: en-US,en;q=0.8
```

原来是通过报文的Header来区分的。至于请求转发的原理，请参考[Tomcat 系统架构与设计模式，第 1 部分: 工作原理](http://www.ibm.com/developerworks/cn/java/j-lo-tomcat1/)。

## how

下面讲解如何配置，先贴上笔者的最终配置。

```xml
<Engine defaultHost="www.gx.com" name="Catalina">

      <!--For clustering, please take a look at documentation at:
          /docs/cluster-howto.html  (simple how to)
          /docs/config/cluster.html (reference documentation) -->
      <!--
      <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster"/>
      -->

      <!-- Use the LockOutRealm to prevent attempts to guess user passwords
           via a brute-force attack -->
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <!-- This Realm uses the UserDatabase configured in the global JNDI
             resources under the key "UserDatabase".  Any edits
             that are performed against this UserDatabase are immediately
             available for use by the Realm.  -->
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm" resourceName="UserDatabase"/>
      </Realm>

      <Host appBase="primaryapps" autoDeploy="true" name="product.gx.com" unpackWARs="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs" pattern="%h %l %u %t &quot;%r&quot; %s %b" prefix="cloud_access_log" suffix=".txt"/>
      </Host>

      <Host appBase="webapps" autoDeploy="true" name="www.gx.com" unpackWARs="true">
        <Context path="" docBase="guanxing" debug="0"/>
        <!-- Access log processes all example.
             Documentation at: /docs/config/valve.html
             Note: The pattern used is equivalent to using pattern="common" -->
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs" pattern="%h %l %u %t &quot;%r&quot; %s %b" prefix="localhost_access_log" suffix=".txt"/>

      </Host>
      ......
</Engine>
```

- 第01行：`defaultHost`必须指向其中一个Host的name，即为域名；
- 第20行：域名[product.gx.com](http://product.gx.com)的配置，这里我没有配置Context标签，按照官网的说明，它会自动去寻找`<tomcat_home>/<appBase>/ROOT`（见附件1）作为此域名的容器应用（本文为`<tomcat_home>/primaryapps/ROOT`）；
- 第24行：域名[gx.com](http://www.gx.com)的配置；
- 第25行：域名[gx.com](http://www.gx.com)的容器应用为`<tomcat_home>/webapps/guanxing`；

------

**附件1**
>
When autoDeploy or deployOnStartup operations are performed by a Host, the name and context path of the web application are derived from the name(s) of the file(s) that define(s) the web application. Consequently, the context path may not be defined in a META-INF/context.xml embedded in the application and there is a close relationship between the context name, context path, context version and the base file name (the name minus any .war or .xml extension) of the file.
>
If no version is specified then the context name is always the same as the context path. **If the context path is the empty string them the base name will be ROOT (always in upper case) ** otherwise the base name will be the context path with the leading '/' removed and any remaining '/' characters replaced with '#'.
>
If a version is specified then the context path remains unchanged and both the context name and the base name have the string '##' appended to them followed by the version identifier.
>
Some examples of these naming conventions are given below.
>
http://tomcat.apache.org/tomcat-7.0-doc/config/context.html
