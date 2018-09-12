---
layout: post
title: 使用ant自动生成WAR包需知
date: '2016-06-28 11:07'
comments: true
categories: ['编程实践']  
tags: ['Java', 'Eclipse']
---

由于早期的eclipse web工程没有使用Maven管理，每次生成WAR包都得在IDE下执行编译、打包，觉得很繁琐，遂决定使用ant自动生成WAR包。记录注意点如下：

<!--more-->

- 下载、安装、配置[ant](http://ant.apache.org/bindownload.cgi)；
- 使用IDE如eclipse自动生成工程的ant文件到工程根目录，取名为build.xml，在build.xml找到`<javac`开头的标签并配置上`encoding="UTF-8"`（按你的实际编码设定，否则会出现编译问题），并新增`target`标签如下：
```
    <target name="war">
        <war destfile = "releases/gx-desk.war" webxml = "WebContent/WEB-INF/web.xml">
           <fileset dir = "WebContent">
              <include name = "**/*"/>
           </fileset>
           <classes dir="build/classes"/>
           <webinf dir="WebContent/WEB-INF/lib"/>
        </war>
    </target>
```
- 写一个bash脚本自动化编译和打包；

------

附件1：bash脚本

```bash
#!/bin/sh

## dependency : sencha cmd

## 1. export build.xml, setup javac and war
## 2. download ant
## 3. add ant/bin to $PATH
## 4. setup ANT_HOME

cd /d/SVN/Workspace/gx-desk/

if [ -d "WebContent2" ]; then
    echo "ERROR: WebContent2 exists, please check !"
    exit 0
fi

cd WebContent/

sencha app build

if [ $? -ne 0 ] ; then
    echo "ERROR: sencha build error !"
    exit 0
else
    # frontend
    cd ..
    mv WebContent WebContent2 
    mkdir WebContent
    cp WebContent2/build/production/Desktop/* WebContent/ -rf
    cp WebContent2/WEB-INF WebContent/ -rf
    rm WebContent/WEB-INF/lib/* -rf

    # backend
    cd src/main/resources/
    mv config.properties config.properties.bak
    mv config.properties.hwcloud config.properties
    mv spring/applicationContext.xml spring/applicationContext.xml.bak
    mv spring/applicationContext.xml.hwcloud spring/applicationContext.xml
    cd -

    # ant
    ant clean
    ant
    if [ $? -ne 0 ] ; then
        echo "ERROR: ant build error !"
    else
        ant war
    if [ $? -ne 0 ] ; then
        echo "ERROR: ant war error !"
    else
       scp -v -P62627 releases/gx-desk.war gx@125.94.212.178:~/
    fi
    fi
    # reverse
    rm WebContent -rf
    mv WebContent2 WebContent
    cd src/main/resources/
    mv config.properties config.properties.hwcloud
    mv config.properties.bak config.properties
    mv spring/applicationContext.xml spring/applicationContext.xml.hwcloud
    mv spring/applicationContext.xml.bak spring/applicationContext.xml
    
fi

exit 0

```

附件2：build.xml

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- WARNING: Eclipse auto-generated file.
              Any modifications will be overwritten.
              To include a user specific buildfile here, simply create one in the same
              directory with the processing instruction <?eclipse.ant.import?>
              as the first entry and export the buildfile again. --><project basedir="." default="build" name="gx-desk">
    <property environment="env"/>
    <property name="ECLIPSE_HOME" value="../../../Softwares/IDE/eclipse/"/>
    <property name="junit.output.dir" value="junit"/>
    <property name="debuglevel" value="source,lines,vars"/>
    <property name="target" value="1.8"/>
    <property name="source" value="1.8"/>
    <path id="Web App Libraries.libraryclasspath"/>
    <path id="EAR Libraries.libraryclasspath"/>
    <path id="Apache Tomcat v8.0 [Apache Tomcat v8.0 GX].libraryclasspath">
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/annotations-api.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/antlr-2.7.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/aopalliance-1.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/asm-all-3.3.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/aspectjweaver-1.8.9.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/aspose-cells-7.7.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/bcprov-jdk16-146.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/c3p0-0.9.1.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/cas-client-core-3.4.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/catalina-ant.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/catalina-ha.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/catalina-storeconfig.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/catalina-tribes.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/catalina.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/cglib-2.2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/com.springsource.org.codehaus.jackson-1.4.3.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-beanutils.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-codec-1.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-codec-1.7.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-collections-3.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-configuration-1.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-dbcp.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-digester-2.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-fileupload-1.2.2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-io-2.0.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-lang-2.4.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-lang-2.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-logging-1.1.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-logging-1.2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-math3-3.5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/commons-pool.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/dom4j-1.6.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/ecj-4.4.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/ehcache-core-2.6.7.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/el-api.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/ezmorph-1.0.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/groovy-all-1.8.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/gson-2.2.4.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/guava-12.0.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/guice-2.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/hadoop-auth-2.2.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/hadoop-common-2.2.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/hbase-client-0.98.3-hadoop2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/hbase-common-0.98.3-hadoop2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/hbase-protocol-0.98.3-hadoop2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/hibernate-jpa-2.0-api-1.0.0.Final.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/hibernate3.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/htrace-core-2.04.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/httpclient-4.3.5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/httpclient-cache-4.3.5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/httpcore-4.3.2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/iText-2.1.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/iTextAsian.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jackson-annotations-2.7.5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jackson-core-2.7.5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jackson-core-asl-1.4.3.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jackson-databind-2.7.5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jackson-mapper-asl-1.4.3.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jasper-el.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jasper.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jasperreports-5.0.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jasperreports-applet-5.0.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jasperreports-fonts-5.0.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/javassist-3.9.0.GA.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/javax.ws.rs.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jcip-annotations-1.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jcommon-1.0.13.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jedis-2.6.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jfreechart-1.0.10.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/json-lib-2.2.3.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jsp-api.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jsr311-api-1.1.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jta-1.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jtransforms-2.4.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/junit-4.8.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/jxl.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/log4j-over-slf4j-1.7.2.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/log4j.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/logback-classic-1.0.13.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/logback-core-1.0.13.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/mail.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/mina-core-2.0.4.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/mybatis-3.0.5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/mybatis-ehcache-1.0.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/mybatis-spring-1.0.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/mysql-connector-java-5.1.17-bin.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/nekohtml-1.9.20.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/netty-3.6.6.Final.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/ojdbc5.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/openid4java-nodeps-0.9.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/poi-3.9-20121203.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/protobuf-java-2.5.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/quartz-2.2.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/servlet-api.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/slf4j-api-1.6.6.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-aop-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-asm-3.2.0.M1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-aspects-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-beans-3.2.0.M1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-beans-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-context-3.2.0.M1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-context-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-context-support-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-core-3.2.0.M1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-core-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-expression-3.2.0.M1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-expression-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-instrument-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-instrument-tomcat-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-jdbc-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-jms-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-ldap-core-2.0.2.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-messaging-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-orm-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-oxm-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-acl-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-aspects-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-cas-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-config-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-core-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-ldap-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-openid-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-taglibs-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-security-web-4.1.0.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-test-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-tx-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-web-3.2.0.M1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-web-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-webmvc-3.2.0.M1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-webmvc-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-webmvc-portlet-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/spring-websocket-4.3.1.RELEASE.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-api.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-coyote.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-dbcp.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-i18n-es.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-i18n-fr.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-i18n-ja.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-jdbc.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-jni.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-spdy.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-util-scan.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-util.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/tomcat-websocket.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/websocket-api.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/xercesImpl-2.10.0.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/xml-apis-1.4.01.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/xstream-1.4.1.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/zmq.jar"/>
        <pathelement location="../../../Softwares/Apache/apache-tomcat-gx/lib/zookeeper-3.4.6.jar"/>
    </path>
    <path id="gx-desk.classpath">
        <pathelement location="build/classes"/>
        <path refid="Web App Libraries.libraryclasspath"/>
        <path refid="EAR Libraries.libraryclasspath"/>
        <path refid="Apache Tomcat v8.0 [Apache Tomcat v8.0 GX].libraryclasspath"/>
    </path>
    <target name="init">
        <mkdir dir="build/classes"/>
        <copy includeemptydirs="false" todir="build/classes">
            <fileset dir="src/main/java">
                <exclude name="**/*.java"/>
            </fileset>
        </copy>
        <copy includeemptydirs="false" todir="build/classes">
            <fileset dir="src/main/resources">
                <exclude name="**/*.java"/>
            </fileset>
        </copy>
        <copy includeemptydirs="false" todir="build/classes">
            <fileset dir="src/test/java">
                <exclude name="**/*.java"/>
            </fileset>
        </copy>
        <copy includeemptydirs="false" todir="build/classes">
            <fileset dir="src/test/resources">
                <exclude name="**/*.java"/>
            </fileset>
        </copy>
    </target>
    <target name="clean">
        <delete dir="build/classes"/>
    </target>
    <target depends="clean" name="cleanall"/>
    <target depends="build-subprojects,build-project" name="build"/>
    <target name="build-subprojects"/>
    <target depends="init" name="build-project">
        <echo message="${ant.project.name}: ${ant.file}"/>
        <javac encoding="UTF-8" debug="true" debuglevel="${debuglevel}" destdir="build/classes" includeantruntime="false" source="${source}" target="${target}">
            <src path="src/main/java"/>
            <src path="src/main/resources"/>
            <src path="src/test/java"/>
            <src path="src/test/resources"/>
            <classpath refid="gx-desk.classpath"/>
        </javac>
    </target>
    <target description="Build all projects which reference this project. Useful to propagate changes." name="build-refprojects"/>
    <target description="copy Eclipse compiler jars to ant lib directory" name="init-eclipse-compiler">
        <copy todir="${ant.library.dir}">
            <fileset dir="${ECLIPSE_HOME}/plugins" includes="org.eclipse.jdt.core_*.jar"/>
        </copy>
        <unzip dest="${ant.library.dir}">
            <patternset includes="jdtCompilerAdapter.jar"/>
            <fileset dir="${ECLIPSE_HOME}/plugins" includes="org.eclipse.jdt.core_*.jar"/>
        </unzip>
    </target>
    <target description="compile project with Eclipse compiler" name="build-eclipse-compiler">
        <property name="build.compiler" value="org.eclipse.jdt.core.JDTCompilerAdapter"/>
        <antcall target="build"/>
    </target>
    <target name="war">
        <war destfile = "releases/gx-desk.war" webxml = "WebContent/WEB-INF/web.xml">
           <fileset dir = "WebContent">
              <include name = "**/*"/>
           </fileset>
           <classes dir="build/classes"/>
           <webinf dir="WebContent/WEB-INF/lib"/>
        </war>
    </target>
</project>
```
