---
title: Cpp-basics-1
date: 2023-12-03 22:13:11
tags: Cpp
abstract: Cpp语言的常用关键字
---
## volatile特性
### 易变性
在汇编层面反映出来，就是两条语句，下一条语句不会直接使用上一条语句对应的volatile变量的寄存器内容，而是重新从内存中读取。
### 不可优化性
volatile告诉编译器，不要对我这个变量进行各种激进的优化，甚至将变量直接消除，保证程序员写在代码中的指令，一定会被执行。
### 顺序性
能够保证volatile变量间的顺序性，编译器不会进行乱序优化。
### 拓展
volatile变量，与非volatile变量之间的操作，是可能被编译器交换顺序的。
volatile变量间的操作，是不会被编译器交换顺序的。
哪怕将所有的变量全部都声明为volatile，杜绝了编译器的乱序优化，但是针对生成的汇编代码，CPU有可能仍旧会乱序执行指令，导致程序依赖的逻辑出错，volatile对此无能为力。针对这个多线程的应用，正确的做法，是构建一个happens-before语义。
## static特性
静态变量的初始化在程序启动时进行（对于全局静态变量），或在其所在函数首次被调用时进行（对于局部静态变量）。
### 修饰局部变量
一般情况下，对于局部变量是存放在栈区的，并且局部变量的生命周期在该语句块执行结束时便结束了。但是如果用static进行修饰的话，该变量便存放在静态数据区，其生命周期一直持续到整个程序执行结束。
但是在这里要注意的是，虽然用static对局部变量进行修饰过后，其生命周期以及存储空间发生了变化，但是其作用域并没有改变，其仍然是一个局部变量，作用域仅限于该语句块。
### 修饰全局变量
对于一个全局变量，它既可以在本源文件中被访问到，也可以在同一个工程的其它源文件中被访问(只需用extern进行声明即可)。用static对全局变量进行修饰改变了其作用域的范围，由原来的整个工程可见变为本源文件可见。
### 修饰函数
用static修饰函数的话，情况与修饰全局变量大同小异，就是改变了函数的作用域。
### 修饰类变量
如果对类中的某个变量进行static修饰，表示该变量为类以及其所有的对象所有,它们在存储空间中都只存在一个副本,可以通过类和对象去调用。
### 修饰类函数
如果在C++中对类中的某个函数用static进行修饰，则表示该函数属于一个类而不是属于此类的任何特定对象。因此，对静态成员的使用不需要用对象名。
## const特性
### 修饰基本数据类型
修饰符const可以用在类型说明符前，也可以用在类型说明符后，其结果是一样的。在使用这些常量的时候，只要不改变这些常量的值便好。
### 修饰指针或引用
修饰原则：如果const位于星号*的左侧，则const就是用来修饰指针所指向的变量，即指针指向为常量；如果const位于星号的右侧，const就是修饰指针本身，即指针本身是常量。
### 修饰函数参数
调用函数的时候，用相应的变量初始化const常量，则在函数体中，按照const所修饰的部分进行常量化,保护了原对象的属性。
### 修饰函数返回值
声明了返回值后，const按照"修饰原则"进行修饰，起到相应的保护作用。
### 修饰类
不能在类声明中初始化const数据成员。正确的使用const实现方法为：const数据成员的初始化只能在类构造函数的初始化表中进行。
## extern作用
### 引用外部依赖
#### 作用
修饰符extern用在变量或者函数的声明前，用来说明“此变量/函数是在别处定义的，要在此处引用,注意extern声明的位置对其作用域也有关系，如果是在main函数中进行声明的，则只能在main函数中调用，在其它函数中不能调用。
#### 优势
其实要调用其它文件中的函数和变量，只需把该文件用#include包含进来即可，但使用extern会加速程序的编译过程，这样能节省时间。
### 指定调用规范
在C++中extern还有另外一种作用，用于指示调用规范。比如在C＋＋中调用C库函数，就需要在C＋＋程序中用extern “C”声明要引用的函数。这是给链接器用的，告诉链接器在链接的时候用C函数规范来链接。主要原因是C＋＋和C程序编译完成后在目标代码中命名规则不同，用此来解决名字匹配的问题。
## final作用
当不希望某个类被继承，或不希望某个虚函数被重写，可以在类名和虚函数后添加final关键字，添加final关键字后被继承或重写，编译器会报错。
## inline作用
inline 起到内联作用,因为在编译时函数频繁调用会占用很多的栈空间，进行入栈出栈操作也耗费计算资源，所以可以用inline关键字修饰频繁调用的小函数,编译器会在编译阶段将代码体嵌入内联函数的调用语句块中。
## explicit作用
声明为explicit的构造函数不能在隐式转换中使用，explicit关键字只能用于修饰只有一个参数的类构造函数，它的作用是表明该构造函数是显式的。
## this指针作用
define定义的常量没有类型，只是进行了简单的替换，可能会有多个拷贝，占用的内存空间大，const定义的常量是有类型的，存放在静态存储区，只有一个拷贝，占用的内存空间小;define定义的常量是在预处理阶段进行替换，而const在编译阶段确定它的值。
## Static与Const区别
const强调值不能被修改，而static强调唯一的拷贝，对所有类的对象都共用
## define与Const区别
define定义的常量没有类型，只是进行了简单的替换，可能会有多个拷贝，占用的内存空间大，const定义的常量是有类型的，存放在静态存储区，只有一个拷贝，占用的内存空间小;define定义的常量是在预处理阶段进行替换，而const在编译阶段确定它的值。
## define与typedef区别
#define 是预处理命令,只做简单的代码替换，typedef 是编译时处理,给已存在的类型一个别名。
## define与inline区别

1. 内联函数在编译时展开，而宏在预编译时展开。
2. 在编译的时候，内联函数直接被嵌入到目标代码中去，而宏只是一个简单的文本替换。 
3. 内联函数可以进行诸如类型安全检查、语句是否正确等编译功能，宏不具有这样的功能。 
4. 宏不是函数，而inline是函数。 
5. 宏在定义时要小心处理宏参数，一般用括号括起来，否则容易出现二义性。而内联函数不会出现二义性。 
6. inline可以不展开，宏一定要展开。因为inline指示对编译器来说，只是一个建议，编译器可以选择忽略该建议，不对该函数进行展开。
## 几个不同的函数的拷贝实现
### strcat: char *strcat(char *dst, char const *src)

- 头文件: #include <string.h>
- 作用: 将dst和src字符串拼接起来保存在dst上
- 注意事项:
   - dst必须有足够的空间保存整个字符串
   - dst和src都必须是一个由'\0'结尾的字符串(空字符串也行)
   - dst和src内存不能发生重叠
- 函数实现:
   - 首先找到dst的end
   - 以src的'\0'作为结束标志, 将src添加到dst的end上
```
char *strcat (char * dst, const char * src){
  assert(NULL != dst && NULL != src);   // 源码里没有断言检测
  char * cp = dst;
  while(*cp )
       cp++;                      /* find end of dst */
  while(*cp++ = *src++) ;         /* Copy src to end of dst */
  return( dst );                  /* return dst */
  }
```
### strcpy: char *strcpy(char *dst, const char *src)

- 头文件:#include <string.h>
- 作用: 将src的字符串复制到dst字符串内
- 注意事项:
   - src必须有结束符'\0', 结束符也会被复制
   - src和dst不能有内存重叠
   - dst必须有足够的内存
- 函数实现:
```
char *strcpy(char *dst, const char *src){   // 实现src到dst的复制
  if(dst == src) return dst;              //源码中没有此项
  　  assert((dst != NULL) && (src != NULL)); //源码没有此项检查，判断参数src和dst的有效性
  　　char *cp = dst;                         //保存目标字符串的首地址
  　　while (*cp++ = *src++);                 //把src字符串的内容复制到dst下
  　　return dst;
  }
```
### strncpy: char *strncpy(char *dst, char const *src, size_t len)

- 头文件: #include <string.h>
- 作用: 从src中复制len个字符到dst中, 如果不足len则用NULL填充, 如果src超过len, 则dst将不会以NULL结尾
- 注意事项:
   - strncpy 把源字符串的字符复制到目标数组，它总是正好向 dst 写入 len 个字符。
   - 如果 strlen(src) 的值小于 len，dst 数组就用额外的 NULL 字节填充到 len 长度。
   - 如果 strlen(src)的值大于或等于 len，那么只有 len 个字符被复制到dst中。这里需要注意它的结果将不会以NULL字节结尾。
- 函数实现:
```
char *strncpy(char *dst, const char *src, size_t len)
  {
  assert(dst != NULL && src != NULL);     //源码没有此项
  char *cp = dst;
  while (len-- > 0 && *src != '\0')
      *cp++ = *src++;
  *cp = '\0';                             //源码没有此项
  return dst;
  }
```
### memset: void *memset(void *a, int ch, size_t length)

- 头文件: #include <string.h>
- 作用:
   - 将参数a所指的内存区域前length个字节以参数ch填入，然后返回指向a的指针。
   - 在编写程序的时候，若需要将某一数组作初始化，memset()会很方便。
   - 一定要保证a有这么多字节
- 函数实现:
```
void *memset(void *a, int ch, size_t length){
  assert(a != NULL);     
  void *s = a;     
  while (length--)     
  {     
      *(char *)s = (char) ch;     
      s = (char *)s + 1;     
  }     
  return a;     
  }
```
### memcpy：void *memcpy(void *dst, const void *src, size_t length)

- 头文件: #include <string.h>
- 作用:
   - 从 src 所指的内存地址的起始位置开始，拷贝n个字节的数据到 dest 所指的内存地址的起始位置。
   - 可以用这种方法复制任何类型的值，
   - 如果src和dst以任何形式出现了重叠，它的结果将是未定义的。
- 函数实现:
```
void *memcpy(void *dst, const void *src, size_t length)
  {
  assert((dst != NULL) && (src != NULL));
  　　char *tempSrc= (char *)src;            //保存src首地址
  　　char *tempDst = (char *)dst;           //保存dst首地址
  　　while(length-- > 0)                    //循环length次，复制src的值到dst中
     　　*tempDst++ = *tempSrc++ ;
  　　return dst;
  }
```
### strcpy 和 memcpy 的主要区别

- 复制的内容不同: strcpy 只能复制字符串，而 memcpy 可以复制任意内容，例如字符数组、整型、结构体、类等。
- 复制的方法不同: strcpy 不需要指定长度，它遇到被复制字符的串结束符'\0'才结束，所以容易溢出。memcpy 则是根据其第3个参数决定复制的长度，遇到'\0'并不结束。
- 用途不同: 通常在复制字符串时用 strcpy，而需要复制其他类型数据时则一般用 memcpy
## auto&decltype作用
使用他们可以在编译期就推导出变量或者表达式的类型。
## 强制类型转换
### static_cast
用于各种隐式转换。具体的说，就是用户各种基本数据类型之间的转换，比如把int换成char，float换成int等。以及派生类（子类）的指针转换成基类（父类）指针的转换。
特性:

1. 它没有运行时类型检查，所以是有安全隐患的。
2. 在派生类指针转换到基类指针时，是没有任何问题的，在基类指针转换到派生类指针的时候，会有安全问题。
3. static_cast不能转换const，volatile等属性
### dynamic_cast
用于动态类型转换。具体的说，就是在基类指针到派生类指针，或者派生类到基类指针的转换。
### const_cast
用于去除const常量属性，使其可以修改 ，也就是说，原本定义为const的变量在定义后就不能进行修改的，但是使用const_cast操作之后，可以通过这个指针或变量进行修改; 另外还有volatile属性的转换。
### reinterpret_cast
除了非指针之间外几乎什么都可以转，用在任意的指针之间的转换，引用之间的转换，指针和足够大的int型之间的转换，整数到指针的转换等，但是不够安全。
