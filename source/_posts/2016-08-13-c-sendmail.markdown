---
layout: post
title: 使用C语言调用sendmail的一些注意点
date: '2016-08-13 08:46'
comments: true
categories: ['编程实践']
tags: ['C/C++', 'Linux']
---

本文简单介绍C语言调用sendmail遇到的一些问题。

<!--more-->

## sendmail原理

先附上邮件发送的原理图如下，该图转自[基础邮件原理（MUA/MTA/MDA）](http://www.itye.org/archives/1304)，

![mail](/images/pics/mail.jpg)

sendmail作为MTA，在DNS定位到对方的MTA地址后，将邮件发送到对端MTA。

## 使用sendmail注意

笔者在Shell下调用sendmail的语法如下（当然，这不是唯一的调用方式，详细请`man sendmail`），

```
sendmail -f<sender> -vt receiver < mail.txt
```

其中，

- `-f`指定发件人邮箱；
- `receiver`指定收件人邮箱；
- `-v`表示以调试输出的模式打印；
- `-t`表示读取mail.txt里面的`To`和`Cc`等字段；

举个实际的例子如下，

```
sendmail -fjayzee@jayzee.com -vt jayzee@qq.com < mail.txt
```

mail.txt的内容，

```
Suject: Hello

World
```

但是，在执行上述语句前，你需要注意以下事项，

- 你的发件邮箱不需要是真实邮箱，但必须符合`xxx@xxx.com`的格式，否则会被你的收件人的邮件服务器拒绝；
- 将你的发件邮箱添加到收件邮箱的白名单，否则极有可能被当成垃圾邮件拦截；
- 你的mail.txt的`Subject`表示标题，紧接着是一个空行和正文，建议加上该空行，因为笔者在debian wheezy上使用sendmail发邮件时没有空行会报错，但在ubuntu又不会；
- 配置你的/etc/hosts如下，
```
127.0.0.1	localhost	jayzee.com
```

为什么hosts要如上配置呢？原因是在邮件发送失败时，sendmail会把邮件返回给sender，在此例子中即`jayzee@jayzee.com`，而由于配置了hosts，相当于收件人其实是`jayzee@127.0.0.1`，这就保证了在邮件发送失败时邮件会回送给本机的jayzee用户，然后便可在本机的`/var/mail/jayzee`回溯到发送失败的详细信息啦。

关于为什么本机会收到邮件，stackoverflow上有一段很好的解释，
> Just to offer some clarification, it's been the tradition for a long time for UNIX boxes to run a "locally configured" mailer daemon that ** doesn't route messages through the Internet, but only copies messages to other users spool directories ** (as @John T mentioned). It is real SMTP-compliant email, it's just not routed over the Internet because it doesn't need to be.

## 使用C语言调用sendmail

使用C语言调用sendmail，

- 首先，准备好mail.txt；
- 其次，如果你想在调用结束时读取到调用信息，可考虑使用管道，如`popen(...)`；否则，使用`system(...)`就足够了。

## sendmail错误处理

`sysexits.h`标识出了sendmail调用的返回值，但没有一个是标识邮件是否发送成功的。C编程时若要判断sendmail是否发送成功，只能在程序端对回显信息（使用`popen`才取得回显信息）进行分析。

还有一个思路是，专门建一个用户用于发送邮件，且需要保证该用户发送邮件是同步的，这样通过检测`/var/mail/$USER`的文件状态变化（比如配置邮件发送失败才回送，这样该文件的最后修改时间就发生了变化）就能判断是否发送成功了，这里需要在调用sendmail时恰当配置其`-N`选项。

> `-N dsn` Set delivery status notification conditions to dsn, which can be 'never' for no notifications or a comma separated list of the values 'failure' to be notified if  delivery  failed, 'delay' to be notified if delivery is delayed, and 'success' to be notified when the message is successfully delivered.

至于这里为什吗不考虑邮件delay的情况，文章[Why Am I Getting a “Delivery Status Notification (Delay)” on an Email I Sent?](https://askleo.com/why_am_i_getting_a_delay_notification_on_an_email_i_sent-2/)给出解释如下，
> Delivery Status Notification (Delay)
> This is an automatically generated Delivery Status Notification.
> THIS IS A WARNING MESSAGE ONLY.
> **YOU DO NOT NEED TO RESEND YOUR MESSAGE**.
> Delivery to the following recipients has been delayed.
> 
> if you get this “Delivery Status Notification (Delay)” warning, there’s nothing you can really do, other than to **make sure you sent it to the correct address.**

## 伪代码

```c
#include 相关头文件

int main() {
    if(网络在线) {
        stat1=/var/mail/user最后修改时间
        system(sendmail -N failure -fuser@user.com -vt 收件人邮箱 < mail.txt);
        stat2=/var/mail/user最后修改时间
        if(stat1 != stat2) {
            发送失败
            清空user@user.com的邮件队列避免重发
        } else {
            发送成功
        }
    } else {
        发送失败
    }
    return 0;
}
```

## 参考文献


1. 360converter博客：[基础邮件原理（MUA/MTA/MDA）](http://www.itye.org/archives/1304)
2. Ask Leo：[Why Am I Getting a “Delivery Status Notification (Delay)” on an Email I Sent?](https://askleo.com/why_am_i_getting_a_delay_notification_on_an_email_i_sent-2/)
