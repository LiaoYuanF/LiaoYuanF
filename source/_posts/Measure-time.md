---
title: Linux下高精度测时
date: 2024-02-05 15:01:25
tags: 随感杂记
---
目前大多数Linux下的高精度测试基本通过tsc寄存器实现的，简单记录一下可能存在的问题。
## 如何获取tsc
X86 平台提供读取tsc的指令 **rdtsc/rdtscp** 可以用户态轻量获取tsc的值。
相比vsdo提供的**gettimeofday**更高效。
## tsc的可靠性问题

- **Invariant**：单核情况下的tsc受cpu动态变化的主频影响，进入某些异常状态下（C-State状态--尚未研究这个状态会发生什么）甚至会停止计数。
- **Reliable**：多核情况下的tsc可能存在不同步，存在一个核间的“可视时延”（找不到准确翻译了），大致就是核间所见非所得的情况。
## 可靠性问题解法
### 单核情况下的解法
存疑-未详细验证：intel在x86的cpu层面做出了增强，新增了两个特性

- **constant_tsc**：含义是以固定的频率跳动，与cpu当前的频率无关。
- **nonstop_tsc**：进入C-State也不会停止跳动。

解决了单核情况下的问题，使得tsc以理想的恒定频率跳动。
### 多核架构下的解法
Linux 内核启动时，探测tsc是否同步，采用尝试校准多个核心上的tsc以相同的频率和起始值启动运行。这通过写入MSR寄存器值来设置tsc的特性，需要cpu支持，目前仅仅intel的cpu才可能被认为是多核同步的。如果tsc经过内核测试和校准，被认为是可以核心间同步的，则会被当作时钟源来使用。
通过下面指令来确定时钟源：
```
sudo cat /sys/devices/system/clocksource/clocksource0/current_clocksource
```
# TSCNS代码的解读
对外提供的主要接口以及实现
## init
初始化数据
void init(int64_t init_calibrate_ns, int64_t calibrate_interval_ns)
双参数可设置，用以确定初始校准等待时间和校准间隔时间 
## getTscGhz
通过算数运算计算CPU主频
算数计算公式
expected_err_at_next_calibration = ns_err + (ns_err - last_ns_err) / (ns - last_ns) * calibate_interval_ns;
new_ns_per_tsc =ns_per_tsc * (1.0 - expected_err_at_next_calibration / calibate_interval_ns)
TscGhz = 1.0 / new_ns_per_tsc 
## calibrate
The calibrate() function is non-blocking and cheap to call but not thread-safe, so user should have only one thread calling it. The calibrations will adjust tsc frequency in the library to trace that of the system clock and keep timestamp divergence in a minimum level.
## rdns
Getting nanosecond timestamp in a single step.
# 参考链接

- http://oliveryang.net/2015/09/pitfalls-of-TSC-usage/#32-software-tsc-usage-bugs
- https://github.com/MengRao/tscns

