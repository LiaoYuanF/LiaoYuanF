---
title: 模板编程（一）：特化
date: 2024-02-09 01:25:55
tags: 模板编程
---
这是模板编程系列的第一篇，主要回顾了模板的基础和特化与偏特化的实现语法。
# 模版的介绍
## 模板的基本概念
模板（Templates）是编程语言提供的一种泛型编程机制，允许程序员编写通用的代码，而不需要指定具体数据类型，使得可以处理多种数据类型而不必为每种类型编写特定的代码。
在C++中，可以通过 template 这个关键字来定义和实现基础的模板编程。
## 模板的本质——从运行期到编译期
模板的功能看起来非常吸引人，编译器智能地根据输入的类型选择对应的对该类型的处理逻辑，似乎是一种非常理想的**编程范式****1**，在这种范式之下，我们的代码优雅得可以消灭一切对类型判断的if-else分支。那么编译器的这种智能的表象下的本质是什么：
> 在我看来，模板的本质是代码枚举，将代码在运行期间的可能性，转移到编译期间通过编译器对代码的枚举进行覆盖。

上面的本质是我对模板的一种粗暴的、不准确的、但是易于理解的总结，姑且写在文章开头，可以留待之后的文章中继续讨论。
# 模板的基础语法
在开始实践之前，先简单回顾一下模板的基础语法和一些编程规则。
## 模板类和模板函数
模板类和模板函数是模板的最基础的应用，也是平常使用中接触的最多的使用方式。
在模板类中，传入的模板参数一般被用来替换类中元素的类型，使得同一个类在模板的帮助下表现出泛化的特性。
平时基于可读性和分离编译考虑，如下面的示例，我一般会更喜欢把模板类内的函数实现放在类的外部。
```cpp
template <typename T>
class vector
{
public:
	// 这里只有声明
    void clear();            
private:
    T* elements;
};
// 函数的实现放在这里
template <typename T>
void vector<T>::clear()        
{
    // Function body
}
```
相较于模板类的模板参数的占位对象的统一，模板函数的占位对象会显得更多五花八门。
在模板函数中，除了函数名和形参之外，函数签名之中其他部分都可以用占位符代替。甚至函数内的对象的类型也可以是占位符，这就导致模板函数的形式很多样化。
```cpp
template <typename T> 
void foo(T const& v);

template <typename T> 
T foo();

template <typename T, typename U> 
U foo(T const&);

template <typename T> 
void foo()
{
    T var;
    // ...
}
```
事实上，除了typename关键字外，还有一种模板整型的应用场景，在这种场景下，整型模版参数的作用，就是定义一个常数，替一个常数占位。
```cpp
template <int Size> struct Array
{
    int data[Size];
};

Array<16> arr;
```
# 模板特化与偏特化
> 所谓模板特例化即对于通例中的某种或某些情况做单独专门实现，最简单的情况是对每个模板参数指定一个具体值，这成为完全特例化（full specialization），另外，可以限制模板参数在一个范围取值或满足一定关系等，这称为部分特例化（partial specialization）。
> 用数学上集合的概念，通例模板参数所有可取的值组合构成全集U，完全特例化对U中某个元素进行专门定义，部分特例化对U的某个真子集进行专门定义。

当然，其实如果把模板当作是一门独立的图灵完备的编程语言的话，那么模板的特化与偏特化其实是这个语言中“if else then”的逻辑判断语句，实现了根据“入参”进行判断从而走向不同的分支，这也是模板元编程的基础之一，当然这一点会在之后的篇章详细展开。
## 模板特化
如果说，模板提供给了我们很好的对公共特性的抽象能力，那么，模版的特化，就是给予我们针对一些非公共特性进行特殊化的处理。类比成面向对象的抽象，基类可以类比为模板抽象出了最大公约数的能力，那么部分特殊的能力就由继承基类的派生类来实现。
最基本的代码示例如下：
```cpp
// 模板的一般形式（原型）
template <typename T> class AddFloatOrMulInt
{
    static T Do(T a, T b)
    {
        return T(0);
    }
};

// 指定T是int时候的特化
template <> class AddFloatOrMulInt<int>
{
public:
    static int Do(int a, int b)  
    {
        return a * b;
    }
};

// 指定T是float时候的特化
template <> class AddFloatOrMulInt<float>
{
public:
    static float Do(float a, float b)
    {
        return a + b;
    }
};
```
在这个示例中，模板函数除了针对泛化的类型提供了能力之外，还对int或者float两种类型进行了特化处理，自定义了一些操作以应对他们所需要的区别性。
## 模板偏特化
如果说模板的特化是对某个固定的类型进行特化处理，那么偏特化可以理解为批量特化，即对批量符合特征的类型进行特化处理：比如说如果传入指针则进行特化处理。
如下面的示例所示，该模版的偏特化实现了对所有传入类型是指针的批量特化。
```cpp
// 通用模板
template <typename T>
struct MyTemplate {
    void print() {
        std::cout << "Generic Template" << std::endl;
    }
};

// 模板偏特化：当传入类型是指针时
template <typename T>
struct MyTemplate<T*> {
    void print() {
        std::cout << "Partial Specialization for Pointers" << std::endl;
    }
};
```
或者如下的另外一个例子，实现了对传入的两个类型相同时候的批量特化。
```cpp
// 通用模板
template <typename T, typename U>
struct MyTemplate {
    void print() {
        std::cout << "Generic Template" << std::endl;
    }
};

// 模板偏特化：当两个模板参数相同时
template <typename T>
struct MyTemplate<T, T> {
    void print() {
        std::cout << "Partial Specialization for T and T" << std::endl;
    }
};
```
## 不定长模板参数
在C++11中，引入了变参模板（Variadic Template），这一特性拓展了模板的参数的自由度，我们可以通过tuple在C++11标准发布前后的变更来了解变参模板的使用。
引入变参模板之前，**tuple代码****2**如下：
```cpp
// Tuple 的声明，来自 boost
struct null_type;

template <
  class T0 = null_type, class T1 = null_type, class T2 = null_type,
  class T3 = null_type, class T4 = null_type, class T5 = null_type,
  class T6 = null_type, class T7 = null_type, class T8 = null_type,
  class T9 = null_type>
class tuple;

// Tuple的一些用例
tuple<int> a;
tuple<double&, const double&, const double, double*, const double*> b;
tuple<A, int(*)(char, int), B(A::*)(C&), C> c;
tuple<std::string, std::pair<A, B> > d;
tuple<A*, tuple<const A*, const B&, C>, bool, void*> e;
```
这是tuple在boost中的实现，但是这个方案的缺陷很明显：代码臃肿和潜在的正确性问题。此外，过度使用模板偏特化、大量冗余的类型参数也给编译器带来了沉重的负担。此外，boost中也还有不少类似实现，比如MPL库也使用了这个手法将boost::mpl::vector映射到boost::mpl::vector _n_上。
在引入了变参模板之后，tuple的模板可以被如此实现：
```cpp
template <typename... Ts> class tuple;
```
这里的typename... Ts相当于一个声明，是说Ts不是一个类型，而是一个不定常的类型列表。需要注意的是，因为C++的模板是自左向右匹配的，所以不定长参数只能结尾。
```cpp
//模板的原型
template <typename... Ts, typename U> class X {};              // (1) error!
template <typename... Ts>             class Y {};              // (2)
//偏特化时，模板参数列表并不代表匹配顺序，
//它们只是为偏特化的模式提供的声明
//它们的匹配顺序，只是按照<U, Ts...>来
//而之前的参数只是声明Ts是一个类型列表，而U是一个类型，排名不分先后
template <typename... Ts, typename U> class Y<U, Ts...> {};    // (3)
template <typename... Ts, typename U> class Y<Ts..., U> {};    // (4) error!
```
# 参考资料
[https://sg-first.gitbooks.io/cpp-template-tutorial/content/](https://sg-first.gitbooks.io/cpp-template-tutorial/content/)
[https://www.cnblogs.com/liangliangh/p/4219879.html](https://www.cnblogs.com/liangliangh/p/4219879.html)

编程范式1：是一种编程风格或方法论，这个概念并没有一个确切的起源，它是随着计算机科学和软件工程的发展逐渐演变和形成的，它描述了解决问题和构建软件的基本方式。不同的编程范式强调不同的原则、思想和实践，影响着程序的结构和组织方式。常见的编程范式包括**命令式编程、声明式编程、函数式编程、面向对象编程、泛型编程等**。

tuple代码2 ：这段代码来自于Boost库中的tuple实现，具体代码位置：[https://github.com/boostorg/tuple/blob/develop/include/boost/tuple/detail/tuple_basic.hpp](https://github.com/boostorg/tuple/blob/develop/include/boost/tuple/detail/tuple_basic.hpp) 
## 
# 

