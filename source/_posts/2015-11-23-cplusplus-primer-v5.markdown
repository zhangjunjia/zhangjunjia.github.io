---
layout: post
title: 《C++ Primer v5》读书笔记
date: '2015-11-23 20:31'
comments: true
categories: ['读书笔记']  
tags: ['C/C++']
---

《C++ Primer v5》的读书笔记。

<!--more-->

## CHAPTER 1 GETTING STARTED

- Variable type: when we wrote`T t`, we sayed that "t has type T", or "t is a T"

- gcc/g++ warning all options: `-Wall` for *nix, `/W4` for windows

- Flush the stream: we should always put `std::cout << std::endl;` at the end of `std::cout` to flush the stream of std-out, or else it won't output immediately

- Left operating left: `std::cout << "text 1" << " and text 2" << std::endl;` equals to
```c++
std::cout << "text 1";
std::cout << " and text 2";
std::cout << std:endl;
```

<!--more-->

- istream hits invalid state: `while (std::cin >> value)` will end at
	1. hit the **end-of-file**
	1. encounter an invalid input, such as reading a value is not a integer

## CHAPTER 2 VARIABLES AND BASIC TYPES

### Primitive built-in types

- Signed and unsigned types
	1. except for bool and extended character types, the integral types may be signed or unsigned(float is not integral types)
	1. there are three character types (two in real usage): char, signed char and unsigned char
		- char is signed in some machine and unsiged in others
	1. use an unsigned when you are sure of it's usage
	1. don't use plain char or bool in arithmetic experssions
	1. double is better for float, float has not enough precison and in some machines double computation is faster than float

- Type conversions
	1. when assign a float to int, 
		- the fractional part of float is truncated as temp
		- give temp to the int mentioned above
	1. when assign an out-of-value to unsigned type, the lower bits doesn't change, the higher bit out-of-range is truncated, this is same to modulo
	1. when assign an out-of-value to signed type, the result is undefined

### Variables

- List initialization
```c++
int sold = 0;   // ok
int sold = {0}; // ok
int sold{0};    // ok
int sold(0);    // ok
int sold(1d);   // ok but truncated
int sold{1d};   // error:narrowing conversation required
```

- Default initialization: built-in type defined outside any function body are initialized to zero, inside the function is uninitialized

- declaration and definition are different
	1. declaration secifies the type and name of a variable
	1. definition inits the variable
	1. to use the same variable in multiple files, you must only have one definition and multi declaration
```c++
// declaration but not definition, must be outside the function
extern int j; 
// declaration and definition
int j;        
// only definition, declaration is override, must be outside the function
extern double pi = 3.14; 
```

- illegal variable names
```c++
int __a; // contains 2 underscores
int _Ab; // start with underscore, and follow with a upper letter immediately
```

- get variables outer scope
```c++
std::cout << ::reused << std::endl; // use '::'
```

### Compound Types

- Reference: 
	1. a reference to object, it's not an object
	1. must be initialized, can't re-bind
```c++
int val1 = 1024;
double val2 = 123;
int &relVal1 = val1; // ok
int &relVal2;        // error, must be init
int &relVal3 = val2; // error, type error
```

- Pointers
	- different to reference
		1. it's an object
		1. can be rebind
		1. needn't initialized when defined
		1. like built-in types, it has undefined value in function if it's not defined
	- pointer value state
		1. point to an object
		1. point to the location just immediately past the end of an object (illegal pointer)
		1. null pointer
		1. invalid pointer (not initialized)
	- special
		1. same type valid pointers can use in comparation (address compare)
		1. void pointers
			- can compare to another pointer
			- pass or return it from a function
			- assign it to another void* pointer
		1. define two pointer in a line: `int *p1, *p2`, '*' only works for the variable name
		1. reference to pointers (example below)

```c++
// normal
double val = 123;
double *pd1 = &val; 
             // ok, give the pointer itself a new value
int *pd2 = &val;    // error, types differ
pd2 = pd1;   // error, types differ
pd1 = val;   // error, can't assign object to pointer

// special
int *p1, p2; // only p1 is pointer
int i=0;
int *p;
int *&r = p; // read from right to left: r is a reference to pointer
r = &i;
*r = 0;      // set i to 0
```

### const Qualifer

- local to file
	1. default internal linkage in C++
		- if we define `const int ivv = 0` in source file, and `extern const int ivv` in header file, 'ivv' only works in that source file, this is the so-called 'local-to-file', differ to the normal case
		- to use 'ivv' in multi files, we should declare `extern const int ivv` in header file, and define `extern const int ivv = 0` in source file
	1. default external linkage in C
		- in C, const variable's scope is the same to normal case

- reference to const
	1. const reference to const object/normal/plain/expression/double, means read only
	1. if reference to double, it's a tempory value, if the origin double changes, the reference to const will never know that
```c++ 
// ok initialization
const int ci = 1024;
int i = 1024;
double dval = 3.14;
const int &r1 = ci; // from const object
const int &r2 = i;  // from normal int
const int &r3 = 12; // from plain int
const int &r4 = r1 * 2; // from expression
const int &r5 = dval; // dval --> temp int --> r5
// error case
r1 = 123; // can't rebind
int &r6 = ci; // only const reference can reference to const object
```

- pointer to const(**can't change the memory the address points to**)
	1. similar to 'reference to const', it stores the address of a object and has read access but not write access to the address
	1. **can rebind**

- const pointers(**can't change the address**)
	1. can't rebind, must be initialized at first time
	1. itself const, always point to the same address
	1. **can change the address's real value**
```c++
int errNumb = 0;
int *const curErr = &errNumb; // const pointers
const int *curPnt = &errNumb; // pointer to const
const int i = 123;
const int *const curNor = &i; // a const pointer to a const int
```

- top-level & low-level const
	1. top-level: itself const, const objects(pointers)
	1. low-level: pointer or reference to const
	1. when we copy a object, top-level is ignored and low-level will never be ignored
```c++
const int a = 0;
int b = a; // ok: top-level ignore
int const *m = 0;
int *n = m; // error: low-level can't be ignore
```

- constexpr:**applies to the pointer** but not the type to which the pointer points
```c++
const int *p = 0; // pointer to const
constexpr int *q = 0; // a const pointer to int
```

### Dealing with type

- type alias
	1. typedef is the alias of an object
```c++
typedef double wages; // `wages` is same to double
using wages = double;
// pointer
typedef char *pstring; // pstring is an object: char*, pointer to char
const pstring cstr = 0; // same to `const (char*) cstr = 0`, cstr is a const pointer to char
```

- auto: automatically determines the type, **ignores the top-level**
- decltype: similar to auto, but **top-level is keeped**
	1. decltype((v)) is always a reference type
```c++
const int i = 0;
auto a = i; // normal int 
decltype(i) b = 0; // const int
```













## CHAPTER 3 STRINGS, VECTORS, AND ARRAYS

### Namespace using Declarations

```c++
// main.cpp
using std::cout; // 只使用于本源文件，引入另外一个命名空间的成员到当前作用域
int main(){
    cout << "hello" << endl;
    return 0;
}
```

<!--more-->

### Library string Type

使用前提：

- 头文件引入：`#include <string>`
- 作用域引入：`using std::string`

#### 定义

```c++
// 默认实例化为空
string s1;
// 直接实例化为指定值
string s1(10, 'c');
string s2("haha");
// 复制实例化
string s3 = "haha";
```

#### 字符串操作

几个特殊的字符串操作举例如下：

- 输入和输出

```c++
string word;
while(cin >> word) // is>>s，返回is
    cout << word << endl; // os << s，返回os
while(getline(cin, word)) // 返回is
    cout << word << endl;
```
- 比较：比较从左到右第一个不同的字符的ASCII值，如从左到右无不同字符则长度较长的字符串大
```c++
// s2大s1，s3大于前两个字符串
string s1 = "hello";
string s2 = "hello, world";
string s3 = "hexo";
```
- size()
```c++
string s1;
auto size = s1.size(); // string::size_type，一个无符号整型
```
- 拼接
```c++
// string类型间可自由拼接
string s1 = "t";
string s2 = "x";
s1 += s2;
// string和literals
string s3 = "t" + "x"; // error：字面量不可相加
string s4 = "t" + s1 + "x"; // 合法，运算顺序从左到右
```

#### 处理字符串内的字符

一共有两类操作，

- 字符串遍历（copy和reference）
- 数组下标（reference）

```c++
string s1 = "test";
// 字符串遍历
for(auto c : s1) // c是copy，改变c的值不影响字符串
    // do sth
for(auto &c : s1) // c是reference
    // do sth
s1[0] = 'y'; // 引用第0个数组下标的字符
```

### Library vector Type

使用前提：
- 头文件引入：`#include <vector>`
- 作用域引入：`using std::vector`

#### 定义

*注意括号和花括号的不同*：
```c++
// 默认实例化为空
vector<string> v1; 
// 指定元素数量
vector<int> v2(10); // 10个0
vector<int> v3(10, 1); // 10个1
// 列表实例化
vector<int> {10, 1}; // 10和1两个元素
```

#### 操作

注意：

- 数组下标可操作vector的尺寸之外的元素如`vector[size+1] = 3`，但这并不会向vector新增一个元素，而且会产生越界异常
```c++
vector<int> v1(10, 1);
v1.push_back(2); // 插入
v1[0] = 3; // 数组下标引用
v1.size(); // vector::size_type
// 比较操作需要装相同元素，且相同元素间可比较
```

### Introducing Iterators

#### 定义

string有两种iterator类型，指向某个具体字符：

- string::iterator指向的元素可读写
- string::const_iterator指向的元素只可以读

vector有两种iterator类型，指向某个具体元素：

- vector::iterator
- vector::const_iterator

```c++
string s1("123");
auto i1 = s1.begin(); // 指向第一个元素
auto i2 = s1.end(); // 指向最后一个元素的尾部
auto i3 = s1.cbegin(); // 只可读
```

#### 操作

常用操作如下：
```c++
vector s1{"123"};
auto i1 = s1.begin();
*i1 = "345"; // dereference，取得引用
(*i1).size(); // 调用第一个元素的成员size()
*i1.size(); // error：调用顺序是*(i1.size())
i1++; // 可进行加减运算，指向不同成员
// 比较运算符规则：出现在容器前面的元素较小
```

注意：在使用iterator遍历vector时不能使用push_back，它会使得之前指向它的iterator都无效

### Arrays

#### 定义

```c++
// 默认实例化
int arr[10]; // 10个int值，在函数外int值默认为0，函数内int值为undefined，与built-in类型的默认值规则相同
// 显示实例化
int arr2[10] = {0, 1, 2}; // 后七个元素的值同上
// 字符数组
char c1[] = "C++"; // 共4个元素，最后一个为'\0'
// 不能复制和赋值
int arr3 [] = arr; // error
arr2 = arr; // error
// 复杂的定义
int *ptr[10]; // ptr是一个数组，该数组含有10个int型指针
int (*ptr)[10]; // ptr是一个指针，指向含有10个int元素的数组
```

#### 操纵数组

1. 使用数组下标
2. 使用for-each，如`for(auto tmp : arr)或for(auto &tmp : arr)`

#### 数组与指针

- 数组名指向第一个元素
```c++
string nums[] = {"one", "two", "three"};
// 下面两个式子等效
string *ptr = nums;
ptr = &nums[0];
```

- auto和decltype具有不同效果
```c++
int ia[] = {1,2,3};
auto ia2(ia); // 等效于&ia[0]
decltype(ia) ia3 = {4,5,6}; // 具有与ia一样的类型
```

- 指针与数组
```c++
int arr[] = {1,2,3};
int *ptr = 0; // 指针状态1：空指针
ptr = arr; // 指针状态2：指向某个对象
ptr = arr[3]; // 指针状态3：指向一块内存的结束地址，指针本身有效，不能使用*号取值
ptr = arr[4]; // 指针状态4：这是一个无效的指针，指针地址未定义，不能使用*号取值
```

- begin和end函数取数组首尾
```c++
int ia[] = {1,2,3};
int *begin = begin(ia);
int *end = end(ia);
vector<int> ivec(begin(ia), end(ia)); // 将ia的内容复制到ivec
```

- 数组指针运算
    - 指向相同数组的指针才可使用关系运算符；
    - built-in数组指针下标可使用负数，如：`p[-2]`，p指向一个数组的元素；vector等library type的数组下标必须是正数；

#### c类型字符串

```c++
string s = "c++"; // 可使用c类型字符串为string类型赋值
const char *str = s; // error：反之则不行，应使用s.c_str()
```

### 多维数组

```c++
int ia[3][4];
// 指针p为类型int (*p)[4]，指向含有4个int的数组
for(auto p = begin(ia); p != end(ia); ++p) {
    // q指向int[4]的第一个元素
    for(auto q = begin(*p); q != end(*p); ++q) {
        cout << *q << '';
    } 
}
```
