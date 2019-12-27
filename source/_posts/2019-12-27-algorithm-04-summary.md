---
title: 算法训练营毕业总结
date: 2019-12-27 22:18:05
tags: ['Algorithm']
---

参加即可时间算法训练营的总结。

<!--more-->

# 数据结构篇

https://naotu.baidu.com/file/b832f043e2ead159d584cca4efb19703?token=7a6a56eb2630548c

## 数组

按索引查找快，O(1)；非尾端插入、非尾端删除慢，平均O(n)

## 链表

按索引查找慢，平均O(n)；定位到元素后，插入、删除快，平均O(1)

## 跳表

元素有序，可以理解为多层的单链表，形状类似于金字塔，解决单链表查询慢的问题。通俗理解：
- 最底下一层，第n层：原始数据单链表
- n-1层：节点数相比第n层减半的单链表，其第i个元素（i>=0）指向并等于第n层的2i个元素
- n-2层：类似上面以此类推
- 第1层：类似上面以此类推

定位元素层第1层往下找，每次查找都能将目标值所在空间折半。单链表是一维，跳表是二维，属于一种升维的思想解决问题

## 栈

先进后出，FILO。n个元素入栈1，将栈1元素逐一出栈放到栈2，将栈2元素逐一出栈可以达到FIFO

## 队列

先进先出，FIFO

## 双端队列

头尾两端都可以入、出元素的特殊队列

## 优先队列

插入为O(1)，取出元素为O(nlogn)的特殊队列，每次取元素都会导致重平衡，顶层一般用堆实现

## 哈希表

JDK8的HashMap的源码分析

get操作

- 通过hash方法计算hash
- 通过hash去getNode，先由hash定位到所在通，取桶的第一个节点进行hash值compare，相等则返回。否则遍历桶的所有结点去匹配，桶的数据结构即可能是平衡二叉树，也可能是单链表

put操作

- 计算key的hash
- 检测table是否为空，如果是调用resize进行实例化
- 计算value需要存储到哪个slot，如果该slot为空，直接新建一个slot（单链表），并将value作为头结点，然后返回
- 否则，取出value所在slot，命名其为s
  - 判断value的hash值和s的头结点的hash值是否相同，若相同则覆盖返回
  - 否则判断s是否是一个平衡二叉树，若是则调用putTreeVal将value放到树中，putTreeVal会使得树进入平衡状态
  - 再否则，遍历单链表，若找到hash值相同的结点，覆盖之；否则，将value加在s的尾部，此时需要判断s是否需要进行树化（单个slot的节点数大于等于8需要树化），因为攻击者可能设计一些key使得他们落在同一个slot，此时slot单链表会拉的很长，同时由于负载因子设置不合理此时并未发生重平衡，那对slot的访问就变成了O(N)的复杂度
- 最后，判断总size是否超出threhold（根据capacity和负载因子计算出来的值），是的话调用resize()将size翻倍并重新放置各个Node

注：hashmap之所以设计负载因子，是为了防止结点都落在了一个slot上，threhold=capacity x 负载因子。每个slot的元素都接近threhold是理想的平衡状态，一旦有某个slot超了将导致重平衡。

# 算法篇

## 树的遍历

```python
# 前中后序遍历模板
def preorder(root):
    traverse_path.append(root.val)
    preorder(root.left)
    preorder(root.right)
def inorder(root):
    inorder(root.left)
    traverse_path.append(root.val)
    inorder(root.right)
def postorder(root):
    postorder(root.left)
    postorder(root.right)
    traverse_path.append(root.val)
```

## 递归模板

```python
# 递归模板
def recursie(level, p1, p2, ...):
    if level > MAX_LEVEL:
        # process result
        return
    # process current level logic
    process(level, p1, p2, ...)
    # drill down
    recurse(level + 1, p1, p2, ...)
    # reverse current level logic if needed
```

## 分治模板

```python
# 分治模板
def divide_conquer(problem, p1, p2, ...):
    if not problem:
        return

    # prepare
    subproblems = split_problem(problem, p1, p2, ...)

    # divide
    subresults = [divide_conquer(subproblems[i], p1, p2, ...) for i in range(len(subproblems))]

    # combine
    result = process_result(subresults)

    # reverse
```

## DFS深度优先模板

```python
# depth-first search
# 深度优先（DFS）遍历代码模板
# 递归调用
visited = set()
def dfs(root):
    if root in visited:
        return # terminator
    visited.add(root)
    # process logic here
    for node in root.children():
        if not node in visited:
            dfs(node)
```

```python
# depth-first search
# 深度优先（DFS）遍历代码模板
# 非递归（手动维护栈）
def dfs(root):
    visited, stack = set(), [root]
    while stack:
        node = stack.pop()
        if not node in visited:
            visited.add(node)
            process(node)
            for child in reversed(node.children()): # add from right to left
                stack.append(child)
```

## 广度优先模板

```python
# breadth-first search
# 广度优先遍历（BFS）代码模板
# 非递归，自己的理解
def bfs():
    visited, deque = set(), [root]
    while deque:
        node = queue.popleft() # 从左到右一层层遍历
        if node not in visited:
            visited.add(node)
            deque.append(node.childrens) # 下一层加到最右端
```

## 二分查找模板

```python
# binary search代码模板
left, right = 0, len(array) - 1
while left <= right:
    mid = (left + right) / 2
    if array[mid] == target:
        return or break
    elif array[mid] < target:
        left = mid + 1
    else:
        right = mid - 1
```

## 动态规划总结

dynamic programing = simplifying a complicated problem by breaking it down into simpler problems(in a recursive manner)

动态规划与分治没有本质区别
- 共性：找重复子问题
- 差异：找最优子结构、中途可淘汰次优解

dynamic program三要素
- subproblem(recursive manner)最优子结构
- memorize记忆中间状态
- 找递推公式

## Trie树

Trie树（字典树、字符查找树、键树）
- 多叉树
- 每个节点不存储单词本身，只存储指向到下n个节点的n个不同字母
- 从根节点到某一节点的路径的所有字母组合起来，即为表示的单词（字符串），每个节点的数值即为该单词在文本中出现的频次
- 常用于搜索引擎的词频统计，能最大程度减少无谓的字符串比较，这方面的效率优于哈希表

## 并查集

并查集
- makeSet(s)：用s个单元素新建并查集
- unionSet(x, y)：若x和y所在并查集不相交，进行合并
- find(x)：找出x所在并查集的代表（群主），可用来快速判断两个元素是否在同一个并查集（比较代表）

朋友圈数量解题思路
- N个人：N个只有一个元素的独立集合
- 关系M[i][j]为1：将两个并查集进行合并
- 结果：最后剩多少个独立的集合

find函数需要考虑路径压缩，防止拉链太长：
```python
def find(x):
    if f[x] != x:
        f[x] = find(f[x]) # 路径压缩，防止拉链太长
    return f[x]
```

## 双向BFS

双向BFS总结
```python
# breadth-first search
# 广度优先遍历（BFS）代码模板
# 非递归，自己的理解
def bfs():
    forward, backward = set(start_node), set(target_node)
    while forward:
        temp = set()
        for node in forward:
            for child in node.childrens:
                if child in backward: # 前后相交则结束
                    return
                temp.add(child) # 记录下一层
        forward = temp
        if len(backward) < len(forward): # 从元素小的那一层开始遍历
            forward, backward = forward, backward
```

## 启发式搜索A*

```python
# A*代码模板
def AstartSearch():
    visited = set(root)
    pq = collections.priority_queue() # 优先级 —> 估价函数
    pq.append(root)
    while pq:
        node = pq.pop()
        process(node)
        next = [node for node in node.children if node not in visited]
        pq.push(next)
```

## 位运算

位运算实战技巧
```
判断奇偶
x % 2 == 0 => (x & 1) == 0
x % 2 == 1 => (x & 1) == 1

除以2
x/2 => x >> 1

清零最低位的1
x & (x-1)

取到最低位的1
x & -x
```

## LRU

lru实现：hashmap+deque(double linked list)

## 布隆过滤器

bloom filter(capacity, k)
- bit = hash(num, seed) % capacity，seed的范围是1到k
- 插入：计算k次bit，将bit所在位置1
- 查找：计算k次bit，如果bit所在位都为1，则数可能存在，否则一定不存在

## 动态规划复习

重温动态规划三要素：dynamic program = subproblem(recursive) + memorize + 递推公式

精简为二要素：状态定义、状态转移方程

LeetCode网友整理的多维DP的代码模板
```python
for 状态1 in 状态1的所有取值：
    for 状态2 in 状态2的所有取值：
        for ...
            dp[状态1][状态2][...] = 择优(选择1，选择2...)
```

## 字符串匹配算法

Rabin-Karp：https://shimo.im/docs/KXDdkT99TVtXvTXP/read
KMP
- https://www.bilibili.com/video/av11866460?from=search&seid=17425875345653862171
- http://www.ruanyifeng.com/blog/2013/05/Knuth%E2%80%93Morris%E2%80%93Pratt_algorithm.html


https://naotu.baidu.com/file/0a53d3a5343bd86375f348b2831d3610?token=5ab1de1c90d5f3ec