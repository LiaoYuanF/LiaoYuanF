---
title: 性能优化（二）：交易系统
date: 2024-02-05 14:11:05
tags: 性能优化
---
> 如果你对性能不敏感的话，你不应该直接写python调库吗？

# 接收数据前网络时延
和软件提供商，期货公司，交易所之间的连接。
# 数据进入CPU前时延
尽量减少数据拷贝以及context switches。比如Solarflare的nic卡就是通过interrupt kernel来达到kernel bypassing的效果
# 具体的服务器设置

- disable hyperthreading
- turn on over clocking
- disable Nagle's algorithm
- set cpu affinity and isolation
# 代码编程注意点
### 能用单线程，就不要多线程
如果必须存在IPC，那么使用共享内存作为唯一的IPC机制，可能需要手动实现无锁内存池、无锁队列和顺序锁等来保证共享的数据在多进程下是安全
### 优化剪短关键路径
### 降低run-time处理数据的复杂度
能用CRTP的地方就别用dynamic polymorphism。能用expression templates来帮助计算的，就可以考虑使用它。
### 避免run-time的memory allocation
可以考虑重复使用同类的object，或者是memory pool，这样可以避免overhead，也可以减少memory fragmentation。
### 允许undefined behavior的存在
要了解自己待处理的数据，这样在一定条件下可以允许undefined behavior的存在。比如，vector[] vs vector.at()，因为safety check有时候都会expensive。
### 利用好cache
尽量使用contiguous blocks of memory。基本的规则大概就是： 能在cache里面存下data和instructions，就不用access main memory，能在registers里面存下，就不要access cache。

- 尽量让可能被同时使用的数据挨在一起
- 减少指针链接（比如用array取代vector，因为链接指向的地方可能不在缓存里）
- 尽量节省内存（比如用unique_ptr<Data[]>取代vector<Data>，比如成员变量按照从大到小排序，比如能用int8的地方就不用int16）
- 指定cpu affinity时考虑LLC缓存（同核的两个超线程是共享L1，同cpu的两个核是共享L3，不同NUMA核是通过QPI总线）
- 会被多个核同时读写的数据按照缓存行对齐（避免false sharing）
### 注意struct padding
### 避免不必要的branch和table lookup
使用virtual functions和大量叠加的if语句，都有可能增加cache misses和pipeline clearances的可能性。
### 确定合适的container
部分STL中的container比如std::undered_map，性能对于低时延系统就不够用。
### 用好编译器提供的builtins
比如__expected，__prefetch之类
### 了解编译器和连接器在做什么
最好不要简单的假设-O2就可以帮你解决全部问题。有时候，O2/O3的优化，因为各种原因，反而会让代码变慢。比如： https://stackoverflow.com/questions/43651923/gcc-fails-to-optimize-aligned-stdarray-like-c-array%E3%80%82
# 参考链接 

- optiver的cppcon17分享：https://www.youtube.com/watch?v=NH1Tta7purM%E3%80%82
- DRW前员工Matt Godbolt的分享：https://www.youtube.com/watch?v=fV6qYho-XVs%E3%80%82
- 如何使用cache friendly代码：https://cppatomic.blogspot.com/2018/02/cache-friendly-code.html
