---
layout: post
title: 多对一autossh隧道管理
date: '2016-06-22 21:05'
comments: true
categories: ['编程实践']  
tags: ['Linux', 'Network']
---

笔者的云端主机开放了两个端口，一个为SSH端口（假定为62638），一个为应用程序TCP端口（假定为62639，长连接），现有多个客户端连接到应用程序TCP端口进行数据通信，但假如我想通过云主机远程到某一个客户进行调试，该如何实现呢？

<!--more-->

这里就需要用到autossh了，简要介绍其思路：客户安装配置autossh，主动去连接云端主机建立autossh隧道，**此隧道在云端主机有一个对端端口**，云端主机直接ssh此端口就会到达隧道的另一端——客户端。

具体实现过程如下，注意：
1. 下文的bbblack是客户端用于登入云端主机的普通账户；
2. 125.94.212.178为云端主机公网IP；

## 客户端配置autossh

1. 编辑/etc/ssh/ssh_config，修改`StrictHostKeyChecking ask`为`StrictHostKeyChecking no`并去除其前面的注释；
2. 执行ssh-keygen得id_rsa.pub，将id_rsa.pub上传到云主机的/home/bbblack/.ssh/customer_name_authorized_keys（**customer_name_authorized_keys为客户名称开头，加_上authorized_keys为后缀**）；
3. 安装autossh；
4. crontab配置每5分钟执行一次以下脚本（autossh.sh），

```bash
#!/bin/sh
# 隧道在云主机的对端是1235端口，在客户端是22端口（ssh的默认端口）
tokeep=1235:localhost:22
# 检测此连接是否存在，否则建立autossh连接
if $(/bin/ps ax|grep $tokeep|grep -v "grep" > /dev/null)
then
    echo "ok" > /dev/null
else
    # autossh本身会去检测并维持隧道的长连接
    /usr/bin/autossh -M 1234 -NR 1235:localhost:22 bbblack@125.94.212.178 -p62638 > /root/autossh.log 2>&1 &
fi
exit 0
```

## 云端配置autossh

1. 编辑/etc/ssh/ssh_config，修改`StrictHostKeyChecking ask`为`StrictHostKeyChecking no`并去除其前面的注释；
2. 编辑/etc/ssh/sshd_config，修改`AuthorizedKeysFile`配置项为`AuthorizedKeysFile      .ssh/authorized_keys`，若上文的customer_name_authorized_keys与.ssh/authorized_keys内容相同，则客户端无需输入密码通过authorized_keys就能连接上云端；

### 在只有一个客户的情况下

将上文的customer_name重命名为authorized_keys，过一会客户端就会连接上云端，使用`lsof -i:1235`可查看连接建立情况，使用`ssh -p1235 user_name@localhost`可登录到客户端（**user_name为客户端的linux user name**）；

### 在有多个客户的情况下

最简单的一种方案是：使每条隧道的云端主机对端端口唯一，也就是每个客户的隧道互相独立，但如果客户太多，会将云端的端口耗尽。笔者想要的效果是所有客户共用一个云端对端端口，即一次只有一条隧道，一次只能远程登录到一个客户。那么问题来了？如何实现？

使用下述脚本（autossh-helper.sh）即可解决上述问题，

```bash
#!/bin/sh

filepath=$1
port1=1235

[ $# -eq 0 ] && { echo "Usage: $0 authorized_keys_filepath"; exit 999; }

if [ -f "$filepath" ] ; then
    # kill 1235
    pid=$(lsof -i:$port1 -t)
    echo $pid|while read line
    do
        if [ "" != "$line" ] ; then
            $(kill $line)
        fi
    done

    # clear known_hosts
    echo > /home/bbblack/.ssh/known_hosts

    # authorized_keys changed
    cp $filepath /home/bbblack/.ssh/authorized_keys
    echo "done ..."
else
    echo "$filepath not exists ..."
fi

exit 0
```

**FIXME** 
但是，以非root用户bbblack使用上述脚本有个问题，它需要定位出绑定在1235的pid号是多少，而1235是由sshd进程以bbblack用户在隧道建立时绑定的，这时候不管使用`lsof`还是`netstat`都无法在bbblack用户下定位出绑定在1235的pid号是多少（原因未知）。所以需要配置lsof为setuid程序（有何安全隐患？），root用户运行`chmod u+s /usr/bin/lsof`即可。

接着，以bbblack账户（无需root用户）运行`./autossh-helper.sh customer_name_authorized_keys`（customer_name_authorized_keys为上文提到的文件）即可实现客户切换，其原理无非是一次只有一个客户独占ssh的authorized_keys，其他没有独占的客户由于不满足ssh登入的条件因而无法建立隧道。

但是问题到这里还没有结束，云端的主机由于安全的需要一般都会配置denyhosts，denyhosts会不断检查ssh日志的失败记录，把那些连续失败多次的IP记为黑名单（ssh不可用），于是会出现这样一个现象，即使你运行了上述的autossh-helper.sh切换客户，依然还是没有客户建立隧道，这就是因为该客户所在公网IP被加入黑名单的原因。

有什么解决办法呢？这时候我们的应用程序TCP端口（假定为62639，长连接）派上了用场。这里我们假设，该客户所在公网IP虽然被加入黑名单，但应用程序TCP端口（假定为62639，长连接）依然正常，因为云端和客户端需要源源不断的交互数据，此端口为长连接。若不满足此假设，则以下解决方案无效。

解决方法就是，在执行autossh-helper.sh前，将与云端应用程序正常通信的客户端公网IP从黑名单解除即可。即在执行autossh-helper.sh前，必须先以**root用户**（因为denyhosts需要以root用户执行，这是个遗憾）执行脚本如下（public-ip-helper.sh）：

```bash
#!/bin/sh

if [ `whoami` = "root" ]; then
    echo "" > /dev/null
else
    echo "please login as root !"
    exit 1
fi

tokill=/usr/bin/denyhosts
/bin/ps ax|grep $tokill|grep -v "grep"|awk '{print $1}'|while read line
do
    kill $line
done

netstat -npt|grep 62639|cut -d ":" -f2|cut -d ":" -f1|while read str
do
HOST=${str##* }
echo $HOST >> /usr/share/denyhosts/allowed-hosts
echo '
/etc/hosts.deny
/usr/share/denyhosts/data/hosts
/usr/share/denyhosts/data/hosts-restricted
/usr/share/denyhosts/data/hosts-root
/usr/share/denyhosts/data/hosts-valid
/usr/share/denyhosts/data/users-hosts
' | grep -v "^$" | xargs sed -i "/${HOST}/d"
done

/etc/init.d/denyhosts start
```
