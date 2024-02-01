---
title: 设计模式（一）：责任链
date: 2023-12-16 20:55:02
tags: design pattern
---
责任链模式是一种将请求沿着处理者链依次进行发送的设计模式。系统收到请求后，在链上的每个处理者均可对请求进行处理，或将其传递给链上的下个处理者。每个处理者都作为链上一个可活动的节点，使得责任链模式相较于if-else的分支语句，具有了更好的灵活性和扩展性。


# 背景
在商品上架的审批流系统的开发过程中，有着供应商、商品品控人员、上架风控人员等多种角色参与这一流程，并在其中进行着有先后依赖顺序的不同任务。这一流程会与其他系统（角色权限系统、商品库存系统等）具有深度耦合。
在设计之初有着足够简单的业务流程：

1. 供应商发起上架流程审批，成功则进入2，不成功重新发起1
2. 商品品控人员进行商品品控达标度进行检查，成功进入3，不成功返回1
3. 上架风控人员对上架的营销规则进行检查，成功上架，不成功返回1

在这个业务流程中，因为足够简单，所以可以用简单的if语句完成所有的分支判断。单如果随着业务复杂度的增加，引入新角色，供应商资质管理员，新的流程的分支会变多：

1. 供应商发起上架流程审批，成功则进入2，不成功重新发起1
2. 商品品控人员进行商品质量达标度进行检查，成功进入4，部分成功进入3，完全不成功返回1
3. 供应商资质管理员对供应商的资质进行检查，成功进入4，不成功返回1
4. 上架风控人员对上架的营销规则进行检查，成功上架，不成功返回1

在这个流程中，虽然只增加了一个角色和部分简单逻辑，但对原本if语句的冲击是很大的，为了兼容新的角色需要在多处进行改动，于是在迭代的过程中，势必会出现这样一种局面：

1. 在审批流中的代码本来就已经混乱不堪，之后每次新增功能都会使其更加臃肿。
2. 对审批流中的某个检查步骤进行修改时会影响其他的检查步骤。
3. 当希望复用这些审核逻辑来保护其他系统组件时，只需要复制部分逻辑就足够，但会面对所需的部分逻辑与整体审批流耦合得太深而很难剥离出来的问题。
# 解决方案
与许多其他行为设计模式一样，责任链会将特定行为转换为被称作处理者的独立对象。

- 在上述示例中，每个检查步骤都可被抽取为仅有单个方法的类，提供检查操作。
- 请求及其数据则会被作为参数传递给该方法。

责任链模式将这些处理者连成一条链，链上的每个处理者都有一个成员变量来保存对于下一处理者的引用。

- 除了处理请求外，处理者还负责沿着链传递请求。
- 请求会在链上移动，直至所有处理者都有机会对请求进行处理。

最重要的是：处理者可以决定要不要沿着链继续传递请求，这样可以高效地取消所有后续处理步骤。
还有一种稍微不同的更经典的方式，处理者接收到请求后自行决定是否能够对其进行处理。

- 如果自己能够处理，处理者就不再继续传递请求。
- 在这种情况下，每个请求要么最多有一个处理者对其进行处理，要么没有任何处理者对其进行处理

连成链的方式比较多样，可以用UML中展示的那样，一个处理对象使用SetNext()引用下一个处理对象。 也可以使用array或者list存储所有处理对象，使用循环方式遍历。

- 对于第二种方式，感觉有些像观察者模式。
- 两者具体实现、目的都差不多。主要区别在于：
   - 观察者模式中的处理对象功能可能完全无关，观察者模式主要负责将信息传递给处理对象即可
   - 责任链模式的处理对象功能一般相似，另外责任链模式也关注请求是否正确被处理

![image.png](/images/design-pattern/1.png)
责任链模式的核心在于将处理对象整理成链路。
# 适用场景

- 程序需要使用不同方式处理请求
   - 将多个处理者连接成一条链。接收到请求后，“询问” 每个处理者是否能对其进行处理。这样所有处理者都有机会来处理请求。
- 当必须按顺序执行多个处理者时，可以使用该模式。
   - 无论你以何种顺序将处理者连接成一条链，所有请求都会严格按照顺序通过链上的处理者。
- 如果所需处理者及其顺序必须在运行时进行改变，可以使用责任链模式。
   - 如果在处理者类中有对引用成员变量的设定方法，能动态地插入和移除处理者，或者改变其顺序。
# 实现步骤

1. 声明处理者接口并提供请求处理方法的签名。
   - 确定客户端如何将请求数据传递给方法。 最灵活的方式是将请求转换为对象， 然后将其以参数的形式传递给处理函数。
2. 为了消除具体处理者中的重复代码，可以根据处理者接口创建抽象处理者基类。
   - 该类需要有一个成员变量来存储指向链上下一个处理者的引用。如果需要在运行时对链进行改变，需要定义一个设定方法来修改引用成员变量的值。
   - 还可以提供处理方法的默认行为。如果还有剩余对象，默认行为直接将请求传递给下个对象。具体处理者可以通过调用父对象的方法来使用这一行为。
3. 依次创建具体处理者子类并实现其处理方法。 每个处理者在接收到请求后都必须做出两个决定：
   - 是否自行处理这个请求
   - 是否将该请求沿着链进行传递
4. 客户端可以自行组装链，或者从其他对象处获得预先组装好的链。
   - 在后一种情况下，需要实现工厂类来根据配置或环境设置来创建链
5. 客户端可以触发链中的任一处理者，不仅仅是第一个。请求将通过链进行传递，直至某个处理者拒绝继续传递，或者请求到达链尾。
6. 由于链的动态性，客户端需要处理以下情况：
   - 部分请求可能无法到达链尾
   - 其他请求可能直到链尾都未被处理
# 优缺点
优点：

- 可以控制请求处理的顺序。
- 单一职责原则。解耦了发起操作和执行操作的类。
- 开闭原则。 可以在不更改现有代码的情况下在程序中新增处理者。

缺点：

- 部分请求最终可能都未被处理。
# 与其它模式的关系

- 责任链模式、命令模式、中介者模式和观察者模式用于处理请求发送者和接收者之间的不同连接方式：
   - 责任链模式按照顺序将请求动态传递给一系列的潜在接收者。
   - 命令模式在发送者和请求者之间建立单向连接。
   - 中介者模式清除了发送者和请求者之间的直接连接，强制它们通过一个中介对象进行间接沟通。
   - 观察者模式允许接收者动态地订阅或取消接收请求。
- 责任链可以和组合模式结合使用
   - 叶组件接收到请求后，将请求沿包含全体父组件的链一直传递至对象树的底部。
- 责任链上的处理器可使用命令模式实现
   - 可以对由请求代表的同一个上下文对象执行许多不同的操作。
   - 或者，请求自身就是一个命令对象。可以对一系列不同对象组成的链执行相同的操作。
- 责任链和装饰模式的类结构非常相似。 两者都依赖递归组合将需要执行的操作传递给对象。两者也有几点不同
   - 责任链上的处理器可以相互独立地执行，还可以随时停止传递请求
   - 各种装饰可以在遵循基本接口的情况下扩展对象的行为
   - 装饰无法中断请求的传递
# 示例
```cpp
#include <iostream>
#include <string>

// 定义处理者接口
class Approver {
public:
virtual void processRequest(const std::string& request) = 0;
virtual ~Approver() {}
};

// 创建抽象处理者基类
class BaseApprover : public Approver {
private:
Approver* nextApprover;

public:
BaseApprover() : nextApprover(nullptr) {}

// 设置下一个处理者
void setNextApprover(Approver* next) {
    nextApprover = next;
}

// 处理请求的默认行为
void processRequest(const std::string& request) override {
    if (nextApprover != nullptr) {
        nextApprover->processRequest(request);
    } else {
        std::cout << "Request not handled by any approver." << std::endl;
    }
}
};

// 具体处理者子类：商品品控人员
class QualityControlApprover : public BaseApprover {
public:
void processRequest(const std::string& request) override {
    if (request == "QualityCheck") {
        std::cout << "QualityControlApprover handles the request." << std::endl;
    } else {
        BaseApprover::processRequest(request);
    }
}
};

// 具体处理者子类：供应商资质管理员
class SupplierQualificationApprover : public BaseApprover {
public:
void processRequest(const std::string& request) override {
    if (request == "SupplierQualificationCheck") {
        std::cout << "SupplierQualificationApprover handles the request." << std::endl;
    } else {
        BaseApprover::processRequest(request);
    }
}
};

// 具体处理者子类：上架风控人员
class RiskControlApprover : public BaseApprover {
public:
void processRequest(const std::string& request) override {
    if (request == "MarketingRuleCheck") {
        std::cout << "RiskControlApprover handles the request and approves the product for shelf." << std::endl;
    } else {
        BaseApprover::processRequest(request);
    }
}
};

int main() {
    // 创建责任链
    QualityControlApprover qualityControlApprover;
    SupplierQualificationApprover supplierQualificationApprover;
    RiskControlApprover riskControlApprover;

    // 设置责任链顺序
    qualityControlApprover.setNextApprover(&supplierQualificationApprover);
    supplierQualificationApprover.setNextApprover(&riskControlApprover);

    // 模拟商品上架流程
    std::cout << "Scenario 1:" << std::endl;
    qualityControlApprover.processRequest("QualityCheck");

    std::cout << "\nScenario 2:" << std::endl;
    qualityControlApprover.processRequest("SupplierQualificationCheck");

    std::cout << "\nScenario 3:" << std::endl;
    qualityControlApprover.processRequest("MarketingRuleCheck");

    std::cout << "\nScenario 4:" << std::endl;
    qualityControlApprover.processRequest("SomeOtherCheck");

    return 0;
}

```


