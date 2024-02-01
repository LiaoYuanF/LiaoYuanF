---
title: 如何重构一个项目
date: 2024-02-02 00:14:01
tags: 学习杂记
---
任何一个傻瓜都能写出计算机可以理解的程序，只有写出人类容易理解的程序才是优秀的程序员。
# 什么是重构
> 重构是对软件内部结构的一种调整，目的是在不改变软件可观察行为前提下，提高其可理解性，降低其修改成本。


根据重构的规模程度、时间长短，我们可以将代码重构分为**小型重构**和**大型重构**。

**小型重构**：是对代码的细节进行重构，主要是针对类、函数、变量等代码级别的重构。比如常见的规范命名，消除超大函数，消除重复代码等。一般这类重构修改的地方比较集中，相对简单，影响比较小、时间较短。所以难度相对要低一些，我们完全可以在日常的随版开发中进行。

**大型重构**：是对代码顶层进行重构，包括对系统结构、模块结构、代码结构、类关系的重构。一般采取的手段是进行**服务分层、业务模块化、组件化、代码抽象复用**等。这类重构可能需要进行原则再定义、模式再定义甚至业务再定义。涉及到的代码调整和修改多，所以影响比较大、耗时较长、带来的风险比较大（项目叫停风险、代码Bug风险、业务漏洞风险）。这就需要我们具备大型项目重构的经验，否则很容易犯错，最后得不偿失。所以大型重构其实是一个“无奈”之举。

其实大多数人都是不喜欢重构工作的，主要可能有以下几个方面的担忧：

- 不知道怎么重构、缺乏重构的经验和方法论。
- 很难看到短期收益，如果这些利益是长远的，何必现在就付出这些努力呢？长远看来，说不定当项目收获这些利益时，你已经不负责这块工作了。
- 重构可能会破坏现有程序，带来意想不到的bug。
- 重构可能需要你付出额外的工作，何况可能待重构的代码并不是你编写的。

# 为什么要重构
程序有两面价值：“今天可以为你做什么” 和 “明天可以为你做什么”。大多数时候，我们都只关注自己今天想要程序做什么。不论是修复错误或是添加特性，都是为了让程序力更强，让它在今天更有价值。但是我为什么还是提倡大家要在合适的时机做代码重构，原因主要有以下几点： 

- **让软件架构始终保持良好的设计。**改进我们的软件设计，让软件架构向有利的方向发展，能够始终对外提供稳定的服务、从容的面对各种突发的问题。
- **增加可维护性，降低维护成本，对团队和个人都是正向的良性循环，让软件更容易理解。**无论是后人阅读前人写的代码，还是事后回顾自己的代码，都能够快速了解整个逻辑，明确业务，轻松的对系统进行维护。
- **提高研发速度、缩短人力成本。**大家可能深有体会，一个系统在上线初期，向系统中增加功能时，完成速度非常快，但是如果不注重代码质量，后期向系统中添加一个很小的功能可能就需要花上一周或更长的时间。而代码重构是一种有效的保证代码质量的手段，良好的设计是维护软件开发速度的根本。重构可以帮助你更快速的开发软件，因为它阻止系统腐烂变质，甚至还可以提高设计质量。

![image.png](/images/refactor-project/1.png)
# 怎么进行重构
## 小型重构
小型重构一般都是在日常开发中进行，参考的标准即是我们的开发规范和准则，这里就不再详述具体怎么操作。这里罗列一下常见的代码坏味道，因为这类是我们日常小型重构涉及最多的一类场景。来看几种常见的坏味道场景，这些都是基于真实场景列出来的。
### 业务语义显性化
优秀的代码，配合着命名和注释，应该是一首极容易读懂的诗歌，而不是一个需要推敲的字谜。
如下图中通过把判断条件封装成函数，通过函数名进行语义显化，可以立竿见影的提升代码的可读性。
**原代码**
```java
if(!PvgContext.getCrmUserId().equals(NIL_VALUE) && icbuCustomer.getCustomerGroup() != CustomerGroup.AliCrmCustomerGroup.CANCEL_GROUP)
 {
     //业务逻辑        
 }
```
**重构后**
```java
if(canPickUpToPrivateSea())
 {
     //业务逻辑        
 }

 //判断客户能否捡私入海
 private boolean canPickUpToPrivateSea(){
     if(StringUtil.isBlank(PvgContext.getCrmUserId())){
         return false;
     }
     if(this.getCustomerGroup() == CustomerGroup.AliCrmCustomerGroup.CANCEL_GROUP){
         return false;
     }
     return true;
 }
```
### 泛型问题
```java
//为了大家理解方便，增加了一些注释

//msg是从MQ消费到消息
Map ps = JSON.parseObject(msg); //
String mobile = "xxx"；
ps.put("driverNumber", mobile);
……
// 对ps进行操作
Set<String> keySet = (Set<String>)ps.keySet();
if (keySet.contains("driverPrice") && ps.get("driverPrice") != null) {
	Object factPrice = ps.get("driverPrice");
  if (factPrice instanceof BigDecimal) { 【1】
  	ps.put("driverPrice", String.format("%.2f",((BigDecimal)factPrice).doubleValue()));
  } else if (factPrice instanceof String) { 【2】
  	BigDecimal refund = new BigDecimal((String)factPrice);
    ps.put("refundPrice", refund.stripTrailingZeros().toPlainString());
  }
}
if (keySet.contains(ORDER_TIP_PRICE) && ps.get(ORDER_TIP_PRICE) != null) {
	if (ps.get(ORDER_TIP_PRICE) instanceof BigDecimal) { 【3】
  	BigDecimal tipPrice = (BigDecimal)ps.get(ORDER_TIP_PRICE);
    ps.put(ORDER_TIP_PRICE, String.format(PRECISION_ZERO, tipPrice.doubleValue()));
  }
}
……
// 将ps作为传输传递给服务内部底层接口
msgSendService.innerOrderTempMessage(msg, ps, orderTotalVO);

//看一下底层接口定义
void innerOrderTempMessage(String msg, Map<String, String> ps, PushOrderTotalVO vo);
```
这段真实的代码先不说依靠value类型的不同做不同的业务(【1】【2】【3】)，单看最后一行将泛型已经擦除的map传递给底层的Map<String, String>限定的接口中就是有很大的问题的，未来底层接口使用String value = ps.get(XXX)获取一个非String类型时就会出现类型转换异常。
### 无病呻吟
```java
Config config = new Config();
// 设置name和md5
config.setName(item.getName());
config.setMd5(item.getMd5());
// 设置值
config.setTypeMap(map);
// 打印日志
LOGGER.info("update done ({},{}), start replace", getName(), getMd5());


......

ExpiredConfig expireConfig = ConfigManager.getExpiredConfig();
// 为空初始化
if (Objects.isNull(expireConfig)) {
  expireConfig = new ExpiredConfig();
}

......
Map<String, List<TypeItem>> typeMap = ……;   
Map<String, Map<String, Map<String, List<Map<String, Object>>>>> jsonMap = new HashMap<>();

// 循环一级map
jsonMap.forEach((k1, v1) -> {
    // 循环里面的二级map
    v1.forEach((k2, v2) -> {
        // 循环里面的三级map
        v2.forEach((k3, v3) -> {
            // 循环最里面的list,哎！
            v3.forEach(e -> {
                // 生成key
                String ck = getKey(k1, k2, k3);
                // 为空处理
                List<TypeItem> types = typeMap.get(ck);
                if (CollectionUtils.isEmpty(types)) {
                    types = new ArrayList<>();
                    typeMap.put(ck, types);
                }
                // 设置类型
            }
       }
  }
}
```
代码本身一眼就能看明白是在干什么，写代码的人非要在这个地方加一个不关痛痒的注释，这个注释完全是口水话，毫无价值可言。
### if-else过多
```java
// 下面截取的get25000OrderState的部分代码
private static List<String> get25000OrderState(OrderTotalVO orderTotalVO) {
    String mainState = String.valueOf(orderTotalVO.getOrderState());
    String state = String.valueOf(orderTotalVO.getOrderState());
    List<String> stateList = Lists.newArrayList();

    ……

    DispatchType dispatchType = DispatchType.getEnum(orderTotalVO.getDispatchType());
    ServiceType serviceType = ServiceType.typeOf(orderTotalVO.getServiceType());
    if (serviceType == ServiceType.CHARTERED_CAR) {
        state = state + "_" + serviceType;
    } else {
        if (OrderPropertiesEnum.DISPATCH_ORDER.valid(orderTotalVO.getOrderProperties())) {
            state = state + "_dispatch";
        } else if(OrderPropertiesEnum.ORDER_MARK_CALL_ORDER.valid(orderTotalVO.getOrderProperties())){		state = state + "_" + dispatchType.getCode() + "_phoneCall";                                                                                   } else {
            state = state + "_" + dispatchType.getCode() + "_" + pastOrderId;
            if(isHighQuality(orderTotalVO.getHighQualityFlag()) && DispatchType.DRIVER_GRAB.getCode() == dispatchType.getCode()){
                state += "_highQuality";
            }
        }
    }
    stateList.add(state);
    if (isOtherPassengerOrder(orderTotalVO)) {
        state = mainState + "_" + "forOther_aly";
        stateList.add(state);
    }
    BigDecimal tickOtherPrice = orderTotalVO.getTicketOtherPrice();
    if (tickOtherPrice != null && BigDecimal.ZERO.compareTo(tickOtherPrice) < 0) {
        if (OrderPropertiesEnum.DISPATCH_ORDER.valid(orderTotalVO.getOrderProperties())) {
            state = mainState + "_" + "driverTicketOtherPrice_dispatch";
        } else {
            state = state + "_" + "driverTicketOtherPrice";
        }
    } else {
        if (OrderPropertiesEnum.DISPATCH_ORDER.valid(orderTotalVO.getOrderProperties())) {
            state = mainState + "_" + "driverTicketPrice_dispatch";
        } else {
            state = state + "_" + "driverTicketPrice";
        }
    }
    stateList.add(state);
	……
    return stateList;
}
```
这种在if-else内外都关联业务逻辑的场景，比单纯if-else代码还要复杂，让代码阅读性大大降低，让很多人望而却步。被逼到迫不得已估计开发人员是不会动这样的代码的，因为你不知道你动的一小点，可能会让整个业务系统瘫痪。

### 重复代码
代码坏味道最多的恐怕就是重复代码，如果你在一个以上的地方看到相同的代码结构，那么可以肯定：遗漏了抽象。重复的代码可能成为一个单独的方法或干脆是另一个类。将重复代码放进类似的抽象，增加了你的设计语言的词汇量。其它程序员可以用到你创建的抽象设施。编码变得越来越快，错误越来越少，因为你提升了抽象层级。

最常见的一种重复场景就是在“**同一个类的两个函数含有相同的表达式**”，这种形式的重复代码可以在当前类提取公用方法，以便在两处复用。
还有一种和这类场景相似，就是在“**两个互为兄弟的子类含有相同的表达式**”，这种形式可以将相同的代码提取到共同父类中，针对有差异化的部分，使用抽象方法延迟到子类实现，这就是常见的模板方法设计模式。如果两个毫不相干的类出现了重复代码，这个时候应该考虑将重复代码提炼到一个新类中，然后在这两个类中调用这个新类的方法。

### 单一功能职责
```java
@Data
public class BuyerInfoParam {
    // Required Param
    private Long buyerCompanyId;
    private Long buyerAccountId;
    private Long callerCompanyId;
    private Long callerAccountId;

    private String tenantId;
    private String bizCode;
    private String channel; //这个Channel在查询中不起任何作用，不应该放在这里
}
```
功能单一是SRP最基本要求，也就是你一个类的功能职责要单一，这样内聚性才高。比如这个参数类，是用来查询网站Buyer信息的，按照SRP，里面就应该放置查询相关的Field就好了。
可是呢事实中下面的三个参数其实查询时根本用不到，而是在组装查询结果的时候用到，这给我阅读代码带来了很大的困惑，因为我一直以为这个channel（客户来源渠道）是一个查询需要的一个重要信息。
那么如果和查询无关，为什么要把它放到查询param里面呢，问了才知道，只是为了组装查询结果时拿到数据而已。重构时，果断删掉。
Tips：不要为了图方便，而破坏SOLID原则，方便的后果就是代码腐化，看不懂，往后要付出的代价更高。
### 其他问题
#### 函数过长
一个好的函数必须满足单一职责原则，短小精悍，只做一件事。过长的函数体和身兼数职的方法都不利于阅读，也不利于进行代码复用。
#### 命名规范
一个好的命名需要能做到“名副其实、见名知意”，直接了当，不存在歧义。
#### 不合理的注释
注释是一把双刃剑，好的注释能够给我们好的指导，不好的注释只会将人误导。针对注释，我们需要做到在整合代码时，也把注释一并进行修改，否则就会出现注释和逻辑不一致。另外，如果代码已清晰的表达了自己的意图，那么注释反而是多余的。
#### 无用代码
无用代码有两种方式，一种是没有使用场景，如果这类代码不是工具方法或工具类，而是一些无用的业务代码，那么就需要及时的删除清理。另外一种是用注释符包裹的代码块，这些代码在被打上注释符号的时候就应该被删除。
#### 过大的类
一个类做太多事情，维护了太多功能，可读性变差，性能也会下降。举个例子，订单相关的功能你放到一个类A里面，商品库存相关的也放在类A里面，积分相关的还放在类A里面……试想一下，乱七八糟的代码块都往一个类里面塞，还谈啥可读性。应该按单一职责，使用不同的类把代码划分开。

## 大型重构
![image.png](/images/refactor-project/2.png)
### 事前准备
事前准备作为重构的第一步，这一部分涉及到的事情比较杂，也是最重要的，如果之前准备不充分，很有可能导致在事中执行或重构上线后产生的结果和预期不一致的现象。
在这个阶段大致可分为三步：

- **明确重构的内容、目的以及方向、目标**

在这一步里面，最重要的是把方向明确清楚，而且这个方向是经得起大家的质疑，能够至少满足未来三到五年的方向。另外一个就是这次重构的目标，由于技术限制、历史包袱等原因，这个目标可能不是最终的目标，那么需要明确最终目标是怎么样的，从这次重构的这个目标到最终的目标还有哪些事情要做，最好都能够明确下来。

- **整理数据**

这一步需要对涉及重构部分的现有业务、架构进行梳理，明确重构的内容在系统的哪个服务层级、属于哪个业务模块，依赖方和被依赖方有哪些，有哪些业务场景，每个场景的数据输入输出是怎样的。这个阶段就会有产出物了，一般会沉淀项目部署、业务架构、技术架构、服务上下游依赖、强弱依赖、项目内部服务分层模型、内容功能依赖模型、输入输出数据流等相关的设计图和文档。
附上整个系统的架构和此次重点重构的部分（深色标记部分）
![image.png](/images/refactor-project/3.png)

- **项目立项**

项目立项一般是通过会议进行，对所有参与重构的部门或小组进行重构工作的宣讲，周知大概的时间计划表（粗略的大致时间），明确各组主要负责的人。另外还需要周知重构涉及到哪些业务和场景、大概的重构方式、业务影响可能有哪些，难点及可能在哪些步骤出现瓶颈。
注意：会议结束后需要进行会议纪要邮件周知。
### 事中执行
事中执行这一步骤的事情和任务相对来说比较繁重一些，时间付出会相对来说比较多。

- **架构设计与评审**

架构设计评审主要是对标准的业务架构、技术架构、数据架构进行设计与评审。通过评审去发现架构和业务上的问题，这个评审一般是团队内评审，如果在一次评审后，发现架构设计并不能被确定，那就需要再调整，直到团队内对方案架构设计都达成一致，才可以进行下一步，评审结果也需要在评审通过后进行邮件周知参与人。
该阶段产出物：重构后的服务部署、系统架构、业务架构、标准数据流、服务分层模式、功能模块UML图等。

- **详细落地设计方案与评审**

这个落地的设计方案是事中执行最重要的一个方案，关系到后面的研发编码、自测与联调、依赖方对接、QA测试、线下发布与实施预案、线上发布与实施预案、具体工作量、难度、工作瓶颈等。这个详细落地方案需要深入到整个研发、线下测试、上线过程、灰度场景细节处包括AB灰度程序、AB验证程序。
在方案设计中最重要的一环是AB验证程序和AB验证开关，这是评估和检验我们是否重构完成的标准依据。一般的AB验证程序大致如下：
![image.png](/images/refactor-project/4.png)
在数据入口处，使用相同的数据，分别向新老流程都发起处理请求。处理结束之后，将处理结果分别打印到日志中。最后通过离线程序比较新老流程处理的结果是否一致。遵循的原则就是在相同入参的情况下，响应的结果也应该一致。
在AB程序中，会涉及到两个开关。**灰度开关**（只有它开启了，请求才会被发送到新的流程中进行代码执行）。**执行开关**（如果新流程中涉及到写操作，这里需要用开关控制在新流程写还是在老流程中写）。转发之前需要将灰度开关和执行开关（一般配置到配置中心，能随时调整）写入到线程上下文中，以免出现在修改配置中心开关时，多处获取开关结果不一致。

- **代码的编写、测试、线下实施**

这一步就是按照详细设计的方案，进行编码、单测、联调、功能测试、业务测试、QA测试。通过后，在线下模拟上线流程和线上开关实施过程，校验AB程序，检查是否符合预期，新流程代码覆盖度是否达到上线要求。如果线下数据样本比较少，不能覆盖全部场景，需要通过构造流量覆盖所有的场景，保证所有的场景都能符合预期。当线下覆盖度达到预期，并且AB验证程序没有校验出任何异常时，才能执行上线操作。
### 
### 事后观测与复盘
这个阶段需要在线上按照线下模拟的实施流程进行线上实施，分为上线、放量、修复、下线老逻辑、复盘这样几个阶段。其中最重要最耗费精力的就是放量流程了。

- **灰度开关流程**

逐步放量到新的流程中进行观察，可以按照1%、5%、10%、20%、40%、80%、100%的进度进行放量，让新流程逐步的进行代码逻辑覆盖，注意这个阶段不会打开真实执行写操作的开关。当新流程逻辑覆盖度达到要求、并且AB验证的结果都符合预期后，才可以逐步打开执行写操作开关，进行真实业务的执行操作。

- **业务执行开关流程**

在灰度新流程的过程中符合预期后，可以逐步打开业务执行写操作开关流程，仍然可以按照一定的比例进行逐步放量，打开写操作后，只有新逻辑执行写操作，老逻辑将关闭写操作。这个阶段需要观察线上错误、指标异常、用户反馈等问题，确保新流程没有任何问题。
放量工作结束后，在稳定一定版本后，就可以将老逻辑和AB验证程序进行下线，重构工作结束。如果有条件可以开一个重构复盘会，检查每个参与方是否都达到了重构要求的标准，复盘重构期间遇到的问题、以及解决方案是什么样的，沉淀方法论避免后续的工作出现类似的问题。

# 总结
## 代码技巧

- 写代码的时候遵循一些基本原则，比如单一原则、依赖接口/抽象而不是依赖具体实现。
- 严格遵循编码规范、特殊注释使用 TODO、FIXME、XXX 进行注释。
- 单元测试、功能测试、接口测试、集成测试是写代码必不可少的工具。
- 我们是代码的作者，后人是代码的读者。写代码要时刻审视，做前人栽树后人乘凉、不做前人挖坑后人陪葬的事情。
- 不做破窗效应的第一人，不要觉得现在代码已经很烂了，没有必要再改，直接继续堆代码。如果是这样，总有一天自己会被别人的代码恶心到，“出来混迟早是要还的”。
## 重构技巧

- 从上至下，由外到内进行建模分析，理清各种关系，是重构的重中之重。
- 提炼类，复用函数，下沉核心能力，让模块职责清晰明了。
- 依赖接口优于依赖抽象，依赖抽象优于依赖实现，类关系能用组合就不要继承。
- 类、接口、抽象接口设计时考虑范围限定符，哪些可以重写、哪些不能重写，泛型限定是否准确。
- 大型重构做好各种设计和计划，线下模拟好各种场景，上线一定需要AB验证程序，能够随时进行新老切换。

代码重构的技巧是可以通过学习去掌握，大型项目的重构也可以按照方法论来参考执行。但是有些方法之外的还是需要我们自己去琢磨，有所思、有所想：
1、抽象的分析问题能力、结构化思维能力、复杂问题分解能力
2、代码洁癖、工匠精神
3、产品思维

