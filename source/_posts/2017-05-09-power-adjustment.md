---
title: 最优生产计划
date: 2017-05-09 17:25:16
comments: true
categories: ['算法'] 
tags: ['动态规划']
---

## 目标

已知各类生产产品的生产时间及负荷曲线（负荷曲线对时间的积分即电量），输入「目标生产计划」，计算后输出「最优生产计划」，使得按该计划进行生产成本最优。

<!--more-->

目标生产计划的构成为，

- 计划开始时间
- 计划结束时间
- 生产哪些产品，如：A20件，B30件，C20件，D100件

最优生产计划的构成为，

- t1：开始生产产品P1
- t2：开始生产产品P2
- t3：开始生产产品P3
- ……

## 如何求解

> 成本 = 峰期电费单价 * 峰期电量 + 平期电费单价 * 平期电量 + 谷期电费单价 * 谷期电量
> 
> 注：这里的峰平谷指的是一天的不同时段，高峰期和低谷期的电费单价是不一样的。

最优生产计划即成本最小的生产计划，安排生产计划需要考虑的约束有，

`各产品生产时间+换料时间+下班/休息时间 <= (计划结束时间 - 计划开始时间)` 

这个问题实质是一个动态规划问题，

1. 将「下班/休息时间」从计划时间挖去，得「N段」可用的时间槽；
2. 将生产的总件数看成「M张」选票，投给上述的「N段」时间槽（候选人），假设共有「X种」投票结果；
3. 对计划生产的产品序列进行全排列，假设共有「Y种」排列；
4. 问题转变为从X*Y种排班方式选取最优排班，
	1. 判断该排班方式是否满足时间槽的时间约束，不满足则剔除；
	2. 安排「产品+换料时间」到时间槽，将时间槽内剩余时间切块，以投票的方式填充到时间槽内产品与产品间的间隔，求该时间槽最优解；
	3. 求解每个时间槽的最优解，累加得一次生产安排的最优解，再从多次生产安排选取成本最小的，即为所求。