---
layout: post
title: Maven HOWTO
date: '2015-12-20 16:31'
comments: true
categories: ['编程实践']  
tags: ['Maven']
---

Maven版本：3.3.1

<!--more-->

操作系统：Windows 7

Java版本：1.8

移译自[Maven Getting Started Guide](https://maven.apache.org/guides/getting-started/)。

## What And Why

Maven是一个Java的编译（Build）自动化工具，按我的理解，它可以做到：
- 创建自动化
- 包依赖管理自动化
- 编译和单元测试自动化
- 配置注入自动化
- 程序（War或Jar）打包自动化，及远程部署

因此，它是一个可以提升开发效率的工具。

## How

### 配置

#### Java配置

1. 下载[JDK8][2]并安装到你的电脑（本文用的是jdk-8u65-windows-x64.exe）；

2. 配置环境变量，右击“计算机”==>选择“高级系统设置”==>选择“高级”选项卡==>点击“环境变量”按钮：
    - 新建系统变量`JAVA_HOME`，内容为：`C:\Program Files\Java\jdk1.8.0_65`；
    - 修改系统变量`PATH`，在末尾加入内容：`;%JAVA_HOME%\jre\bin`；如无此系统变量则新建系统变量`PATH`，内容为：`%JAVA_HOME%\jre\bin`；
    - 新建系统变量`CLASSPATH`，内容为：`.;%JAVA_HOME%\lib\dt.jar;%JAVA_HOME%\lib\tools.jar`；

3. 注销后登入，打开CMD.exe，输入
    ```
    echo %JAVA_HOME%
    java -version
    ```

    上述两个命令皆有输出则表示安装Java成功。

#### Maven配置

1. 到[Maven下载页][3]下载apache-maven-3.3.1-bin.zip（apache-maven-3.3.3有Bug，其boot文件夹缺少了一个关键Jar包，已向Maven mail-list提出，不知道修复了没有）；

2. 将压缩包解压到一个你喜欢的地方，如`D:\Softwares\apache-maven-3.3.1`；

3. 配置环境变量，右击“计算机”==>选择“高级系统设置”==>选择“高级”选项卡==>点击“环境变量”按钮：
    - 新建系统变量`M2_HOME`，内容为：`D:\Softwares\apache-maven-3.3.1`；
    - 修改系统变量`PATH`，在末尾加入内容：`;%M2_HOME%\bin`；

4. **重新打开**一个CMD.exe窗口，输入：
    ```
    echo %M2_HOME%
    mvn -v
    ```

    上述两个命令皆有输出则表示安装Maven成功。

5. 配置开源中国Maven库（非必要）
    - 第一次运行mvn命令时，需要去官网（国外）的Maven库同步Jar包到本地，据官网说在网络畅通情况下4分钟就同步完毕，后续运行mvn命令就不需要这么长时间了
    - 如果你觉得时间太长无法忍受，可以配置mvn的中国库，参考[OSC的使用帮助](http://maven.oschina.net/help.html)即可配置。简要概括如下：

```xml
<! -- 在mirrors添加如下配置即可 -->
<mirror>
  <id>nexus-osc</id>
  <mirrorOf>*</mirrorOf>
  <name>Nexus osc</name>
  <url>http://maven.oschina.net/content/groups/public/</url>
</mirror>

<! -- 在profiles添加如下配置即可 -->
<profile>
  <id>jdk-1.4</id>
  <activation>
    <jdk>1.4</jdk>
  </activation>
  <repositories>
    <repository>
      <id>jdk14</id>
      <name>Repository for JDK 1.4 builds</name>
      <url>http://www.myhost.com/maven/jdk14</url>
      <layout>default</layout>
      <snapshotPolicy>always</snapshotPolicy>
    </repository>
  </repositories>
</profile>
```


### Demo项目

#### 创建Java项目

运行下述命令创建demo项目my-app：
```bash
mvn -B archetype:generate \
  -DarchetypeGroupId=org.apache.maven.archetypes \
  -DgroupId=com.mycompany.app \
  -DartifactId=my-app
```

my-app的目录结构如下：
```
my-app
|-- pom.xml
`-- src
    |-- main
    |   `-- java
    |       `-- com
    |           `-- mycompany
    |               `-- app
    |                   `-- App.java
    `-- test
        `-- java
            `-- com
                `-- mycompany
                    `-- app
                        `-- AppTest.java
```

其中的pom.xml是Maven的基础配置文件，pom(Project Object Model，项目对象模型)，它的内容及注释如下：
```xml
<! -- pom文件的开始标签 -->
<project xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                      http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <! -- Maven的pom版本 -->
  <modelVersion>4.0.0</modelVersion>
  <! -- 唯一的组织或公司编号，标识此项目所属组 -->
  <groupId>com.mycompany.app</groupId>
  <! -- 此项目属于组的哪个项目 -->
  <artifactId>my-app</artifactId>
  <! -- 可执行程序打包方式 -->
  <packaging>jar</packaging>
  <! -- 项目版本，SNAPSHOT表示开发版 -->
  <version>1.0-SNAPSHOT</version>
  <! -- 项目的显示名称，常用于maven生成的文档 -->
  <name>Maven Quick Start Archetype</name>
  <! -- 项目的主页，常用于maven生成的文档 -->
  <url>http://maven.apache.org</url>
  <! -- 所用的依赖库 -->
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>3.8.1</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
</project>
```

#### 编译

编译项目src/main：`mvn compile`，将更新<project>/target/classes文件夹

#### 测试

编译并运行项目src/test：`mvn test`，将更新<project>/target/test-classes文件夹，并在<project>/target/surefire-reports生成测试报告

编译项目src/test而不运行：`mvn test-compile`

#### 清除

`mvn clean`：删除<project>/target

#### 打包

打包项目到<project>/target：`mvn package`

打包项目到maven本地仓库：`mvn install`

#### 其他

`mvn site`：生成<project>/target/site，即项目主页文档

`mvn eclipse:eclipse`：为项目添加eclipse标识，因此可被eclipse import

`mvn idea:idea`：类似于eclipse

#### 插件

在pom.xml中添加<build>标签，可定制maven的编译过程
```xml
<project ...>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>2.5.1</version>
        <configuration>
          <source>1.5</source>
          <target>1.5</target>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

#### 配置注入

文件结构为：
```
my-app
|-- pom.xml
`-- src
    |-- main
    |   |-- java
    |   |   `-- com
    |   |       `-- mycompany
    |   |           `-- app
    |   |               `-- App.java
    |   `-- resources
    |       `-- META-INF
    |           `-- application.properties
    `-- test
        `-- java
            `-- com
                `-- mycompany
                    `-- app
                        `-- AppTest.java
```

想要注入配置到`application.properties`，方法如下

- pom.xml注入
    - pom.xml配置如下
    
    ```xml
    <build>
      <resources>
        <resource>
          <directory>src/main/resources</directory>
          <filtering>true</filtering>
        </resource>
      </resources>
    </build>
    ```
    - application.properties配置如下
    
    ```
    # application.properties
    application.name=${pom.name}
    application.version=${pom.version}
    ```
    - 即可使用pom.xml中的name和version属性注入到配置文件，运行`mvn process-resources`后application.properties的内容变为
    
    ```
    # application.properties
    application.name=Maven Quick Start Archetype
    application.version=1.0-SNAPSHOT
    ```
- 配置文件注入（配置文件必须在classpath内）
    * pom.xml配置如下，filter.properties的key直接可为src/main/resources下的所有配置文件使用
    
    ``` xml
    <build>
      <filters>
        <filter>src/main/filters/filter.properties</filter>
      </filters>
      <resources>
        <resource>
          <directory>src/main/resources</directory>
          <filtering>true</filtering>
        </resource>
      </resources>
    </build>
    ```
- pom.xml的propertie注入
    * pom.xml配置如下，my.filter.value可直接为src/main/resources下的所有配置文件使用
    
    ```xml
    <project ...>
      <properties>
        <my.filter.value>hello</my.filter.value>
      </properties>
    </project>
    ```
- 运行时注入
    * `mvn process-resources "-Dcommand.line.prop=hello again"`，command.line.prop可直接为src/main/resources下的所有配置文件使用

#### 依赖

```xml
<project ...>
  <dependencies>
    <dependency>
      <! -- ~/.m2/repository中查找junit组的junit包的3.8.1版本，如查询不到则到maven仓库下载 -->
      <! -- 上文mvn package的jar包可在这里使用 -->
      <groupId>junit</groupId>
      <! -- junit组的junit项目 -->
      <artifactId>junit</artifactId>
      <! -- 版本号 -->
      <version>3.8.1</version>
      <! -- test|compile|runtime -->
      <scope>test</scope>
    </dependency>
  </dependencies>
</project>
```

浏览器访问[http://repo.maven.apache.org/maven2](http://repo.maven.apache.org/maven2)可查看maven库的所有可用jar包，以junit为例，查看[http://repo.maven.apache.org/maven2/junit/junit/maven-metadata.xml](http://repo.maven.apache.org/maven2/junit/junit/maven-metadata.xml)可查询junit所有可用版本

使用[http://maven.oschina.net/home.html](http://maven.oschina.net/home.html)可按关键字检索所需jar包

使用`mvn dependency:tree`可查看当前项目的依赖树

#### 远程部署到其他maven库

配置pom.xml如下：
```xml
<project ...>
  <distributionManagement>
    <repository>
      <id>mycompany-repository</id>
      <name>MyCompany Repository</name>
      <url>scp://repository.mycompany.com/repository/maven2</url>
    </repository>
  </distributionManagement>
</project>
```

配置Maven的settings.xml如下：
```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  ...
  <servers>
    <server>
      <id>mycompany-repository</id>
      <username>jvanzyl</username>
      <! -- Default value is ~/.ssh/id_dsa -->
      <privateKey>/path/to/identity</privateKey> (default is ~/.ssh/id_dsa)
      <passphrase>my_key_passphrase</passphrase>
    </server>
  </servers>
  ...
</settings>
```

#### 文档创建

```bash
mvn archetype:generate \
  -DarchetypeGroupId=org.apache.maven.archetypes \
  -DarchetypeArtifactId=maven-archetype-site \
  -DgroupId=com.mycompany.app \
  -DartifactId=my-app-site
```

#### 创建web项目

创建web项目：
```bash
mvn archetype:generate \
    -DarchetypeGroupId=org.apache.maven.archetypes \
    -DarchetypeArtifactId=maven-archetype-webapp \
    -DgroupId=com.mycompany.app \
    -DartifactId=my-webapp
```

web项目的pom.xml配置如下：
```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                      http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
 
  <groupId>com.mycompany.app</groupId>
  <artifactId>my-webapp</artifactId>
  <version>1.0-SNAPSHOT</version>
  <! -- 打包方式 -->
  <packaging>war</packaging>
 
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>3.8.1</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <! -- 最终打包成war的名称 -->
  <build>
    <finalName>my-webapp</finalName>
  </build>
</project>
```

`mvn clean package`编译并打包为war包`target/my-webapp.war`

#### 多个项目组装为一个项目

两个项目要组装为一个项目，目录结构如下：
```
+- pom.xml
+- my-app
| +- pom.xml
| +- src
|   +- main
|     +- java
+- my-webapp
| +- pom.xml
| +- src
|   +- main
|     +- webapp
```

pom.xml如下：
```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                      http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
 
  <groupId>com.mycompany.app</groupId>
  <artifactId>app</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>pom</packaging>
 
  <modules>
    <module>my-app</module>
    <module>my-webapp</module>
  </modules>
</project>
```

配置`my-webapp/pom.xml`使my-webapp引用my-app：
```xml
  ...
  <dependencies>
    <dependency>
      <! -- 这将使得my-app在war包之前得到编译和打包 -->
      <groupId>com.mycompany.app</groupId>
      <artifactId>my-app</artifactId>
      <version>1.0-SNAPSHOT</version>
    </dependency>
    ...
  </dependencies>
```

配置`my-webapp/pom.xml`和`my-app/pom.xml`添加<parent>标签：
```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                      http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <parent>
    <groupId>com.mycompany.app</groupId>
    <artifactId>app</artifactId>
    <version>1.0-SNAPSHOT</version>
  </parent>
  ...
```

`mvn clean install`将编译并打包war包：`my-webapp/target/my-webapp.war`，而my-app项目将作为war包WEB-INF/lib中的一个jar包
