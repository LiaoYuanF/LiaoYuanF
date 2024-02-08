---
title: 模板编程（三）：CRTP
date: 2024-02-09 01:29:40
tags: 模板编程
---
这是模板编程的第三篇，主要聊一下CRTP（Curiously Recurring Template Pattern）的模板编程模式，基本思想是在一个类模板中将派生类作为模板参数传递给基类，从而实现多态的编程技巧。
# 基于虚函数实现的动态多态
如下面的代码所示，C++ 通过类的继承与虚函数的动态绑定，实现了多态。这种特性，使得我们能够用基类的指针，访问子类的实例。例如我们可以实现一个名为 Shape 的基类，以及 Square, Circle 等子类，并通过在子类中重载虚函数 printArea，实现不同形状的面积输出。而后我们可以通过访问 Shape_List 类的实例中存有 Shape 指针的数组，让所有形状都打印一遍。
```
// 基类
class Shape {
public:
    // 虚函数，实现多态
    virtual void printArea() const {
        std::cout << "Shape Area" << std::endl;
    }

    // 基类可能包含其他的成员函数或数据成员
};

// 派生类1
class Circle : public Shape {
public:
    Circle(double radius) : radius(radius) {}

    // 重写基类的虚函数
    void printArea() const override {
        std::cout << "Circle Area: " << 3.14159 * radius * radius << std::endl;
    }

private:
    double radius;
};

// 派生类2
class Square : public Shape {
public:
    Square(double side) : side(side) {}

    // 重写基类的虚函数
    void printArea() const override {
        std::cout << "Square Area: " << side * side << std::endl;
    }

private:
    double side;
};
```
但是问题是在每次执行 shape->printArea() 的时候，系统会检查 shape 指向的实例实际的类型，然后调用对应类型的 printArea 函数。这一步骤需要通过查询虚函数表（vtable）来实现；由于实际 shape 指向对象的类型在运行时才确定（而不是在编译时就确定），所以这种方式称为动态绑定（或者运行时绑定）。
因为每次都需要查询虚函数表，所以动态绑定会降低程序的执行效率。为了兼顾多态与效率，于是使用Curiously Recurring Template Pattern 这一概念改写程序。
# 基于模板实现的静态多态
为了在编译时绑定，我们就需要放弃 C++ 的虚函数机制，而只是在基类和子类中实现同名的函数；同时，为了在编译时确定类型，我们就需要将子类的名字在编译时提前传给基类，因此，我们需要用到 C++ 的模板。所以概括的说，静态多态的核心思路是用模板在静态编译期获得子类的类名以避开查虚函数表。
```
#include <iostream>

// 基类模板
template <typename T>
class Shape {
public:
    // 模板函数，实现静态多态
    void printArea() const {
        static_cast<T const*>(this)->printAreaImpl();
    }

    // 重载++运算符，用于对派生类中的参数进行自增
    T& operator++() {
        static_cast<T*>(this)->increment();
        return *static_cast<T*>(this);
    }
};

// 派生类1
class Circle : public Shape<Circle> {
public:
    Circle(double radius) : radius(radius) {}

    // 派生类实现具体的printArea函数
    void printAreaImpl() const {
        std::cout << "Circle Area: " << 3.14159 * radius * radius << std::endl;
    }

    // 自增半径
    void increment() {
        ++radius;
    }

private:
    double radius;
};

// 派生类2
class Square : public Shape<Square> {
public:
    Square(double side) : side(side) {}

    // 派生类实现具体的printArea函数
    void printAreaImpl() const {
        std::cout << "Square Area: " << side * side << std::endl;
    }

    // 自增边长
    void increment() {
        ++side;
    }

private:
    double side;
};

int main() {
    Circle circle(5.0);
    Square square(4.0);

    // 调用基类模板函数，实现静态多态
    circle.printArea();
    square.printArea();

    // 使用++运算符对派生类中的参数进行自增
    ++circle;
    ++square;

    // 再次调用基类模板函数，查看自增后的结果
    circle.printArea();
    square.printArea();

    return 0;
}

```

在这个例子中，Shape 是一个模板类，它有一个模板函数 printArea。然后，Circle 和 Square 分别是 Shape 的派生类，并在各自的类中实现了 printAreaImpl 函数并且重载了 ++ 运算符。通过CRTP，Shape 的模板函数 printArea 能够调用正确的实现，++ 运算符也能正确的调用，实现了静态多态。在运行时，不需要虚函数表，而是在编译时就完成了函数调用的解析。
# 基于虚函数和模板混合的多态实现
虽然上文基于模版也实现了可用的静态多态，但是还存在问题。
如果是基于虚函数实现的多态，由于不同的子类指针，Circle*，Square*等指针可以很轻易地传给基类Shape*，这样可以在容器中vector<Shape*>很容易存下一系列子类指针，但是在CRTP模式下则不行，Shape<Circle>*，Shape<Square>*完全是不同类型的指针，是无法在一个容器中存放他们的。
事实上， CRTP 本质上是为了解决多态存在的要查虚函数表的慢动态绑定而引入的，而事实上，动态绑定慢，通常是因为多级继承；如果继承很短，那么查虚函数表的开销实际上也没多大。
在之前举出的例子里，我们运用 CRTP，完全消除了动态绑定；但与此同时，我们也在某种意义上损失了多态性。现在我们希望二者兼顾：保留多态性，同时降低多级继承带来的虚函数表查询开销。答案也很简单：让 CRTP 的模板类继承一个非模板的基类——这相当于这个非模板的基类会有多个平级的不同的子类。这样就可以兼顾多态的抽象性和动态绑定的性能性，具体的示例如下。
```
#include <iostream>
#include <vector>

using std::cout; 
using std::endl;
using std::vector;

class Shape {
 public:
    virtual void printArea () const = 0;
    virtual ~Shape() {}
};

template <typename T>
class Shape_CRTP: public Shape {
 public:
    void printArea() const override{
        static_cast<T const*>(this)->printAreaImpl();
    }
    
};

class Circle: public Shape_CRTP<Circle> {
public:
    Circle(double radius) : radius(radius) {}

    // 派生类实现具体的printArea函数
    void printAreaImpl() const {
        std::cout << "Circle Area: " << 3.14159 * radius * radius << std::endl;
    }
private:
    double radius;
};

// 派生类2
class Square : public Shape_CRTP<Square> {
public:
    Square(double side) : side(side) {}

    // 派生类实现具体的printArea函数
    void printAreaImpl() const {
        std::cout << "Square Area: " << side * side << std::endl;
    }
private:
    double side;
};

int main () {
    vector<Shape*> list;
    list.push_back(new Circle(1));
    list.push_back(new Square(1));
    for (auto iter{list.begin()}; iter != list.end(); ++iter) {
        (*iter)->printArea();
    }
    for (auto iter{list.begin()}; iter != list.end(); ++iter) {
        delete (*iter);
    }
    return 0;
}
```
