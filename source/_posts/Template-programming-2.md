---
title: 模板编程（二）：SFINAE
date: 2024-02-12 20:38:49
tags: 模板编程
---
在C++模板编程中，SFINAE（Substitution Failure Is Not An Error）是处理模板参数推导失败的时选择替换方案（例如控制编译器重载函数或者是进行模版特化）的一项重要机制。
# SFINAE的原理
SFINAE机制源于C++模板参数推导失败时的编译器行为。当编译器在实例化模板时遇到模板参数推导失败的情况时，并不会报错，而是会尝试继续寻找其他可行的实例化方式。如果找到了替代方案，则继续编译；如果找不到，则会报错。
它的这一行为在我的理解中，有着两方面的作用，一方面是保证编译器在泛型函数、偏特化、及一般重载函数中遴选函数原型的候选列表时不被打断；另一方面是这一个特性可以在元编程中实现部分的编译期自省和反射机制。
# SFINAE的代码示例
当编译器在实例化模板时尝试用某些类型替换模板参数时，如果替换导致了编译错误，SFINAE机制会使编译器选择另一种模板，而不是产生编译错误。
```cpp
struct X {
    typedef int type;
};

struct Y {
    typedef int type2;
};

template <typename T> void foo(typename T::type);    // Foo0
template <typename T> void foo(typename T::type2);   // Foo1
template <typename T> void foo(T);                   // Foo2

void callFoo() {
    foo<X>(5);    // Foo0: Succeed, Foo1: Failed,  Foo2: Failed
    foo<Y>(10);   // Foo0: Failed,  Foo1: Succeed, Foo2: Failed
    foo<int>(15); // Foo0: Failed,  Foo1: Failed,  Foo2: Succeed
}
```
在这个例子中，就展示了SFIAE机制如何选择模板进行匹配的机制，当发现某个模版难以匹配上的时候，会选择其他可匹配的模板进行匹配，由此衍生出一个问题，就是当如果有多个模板可以被匹配的情况下，编译器如何决定被匹配的优先级？
事实上，在模板实例化时如果有模板通例、特例加起来多个模板版本可以匹配，则依据如下规则：对版本AB，如果 A 的模板参数取值集合是B的真子集，则优先匹配 A，如果 AB 的模板参数取值集合是“交叉”关系（AB 交集不为空，且不为包含关系），则发生编译错误，对于函数模板，用函数重载分辨（overload resolution）规则和上述规则结合并优先匹配非模板函数。
# SFINAE的应用
## 条件编译
SFINAE的主要应用之一是在模板编程中实现条件编译。通过合理地设计模板参数，我们可以利用SFINAE机制来选择性地启用或禁用模板的特定实例化版本。
通过下面这个函数，我们借助了SFINAE机制实现了一个类模板，并借此对对象中是否有foo这一成员函数进行判断。
```
#include <iostream>

// 检查是否有名为foo的成员函数的函数模板
template <typename T>
class has_foo {
    // 检查是否有foo成员函数的辅助模板
    template <typename U>
    static char test(decltype(&U::foo));

    template <typename U>
    static long test(...);

public:
    static constexpr bool value = sizeof(test<T>(nullptr)) == sizeof(char);
};

// 示例类型
struct A {
    void foo() {}
};

struct B {
    // 没有foo成员函数
};

int main() {
    std::cout << "A has foo member function: " << has_foo<A>::value << std::endl; // 输出true
    std::cout << "B has foo member function: " << has_foo<B>::value << std::endl; // 输出false

    return 0;
}

```
## 模板元编程
SFINAE机制还可以在元编程中被用以实现部分的编译期自省和反射机制，这一部分会在元模板编程阶段详细展开描述。

