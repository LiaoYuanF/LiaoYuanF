---
title: Socket中的字节序转换
date: 2024-02-05 13:56:32
tags: 随感杂记
---
经常忘记几个字节序转换的api名字，顺手记一下这几个api相关以加深印象。
# 转换类型相关api
```cpp
htonl()--"Host to Network Long"
ntohl()--"Network to Host Long"
htons()--"Host to Network Short"
ntohs()--"Network to Host Short"  
```
# 两种字节序
## 网络字节序NBO（Network Byte Order）
按从高到低的顺序存储，在网络上使用统一的网络字节顺序，可以避免兼容性问题。
## 主机字节序HBO（Host Byte Order）
不同的机器HBO不相同，与CPU设计有关，数据的顺序是由CPU决定的,而与操作系统无关。 
如 Intel X86结构下,short型数0x1234表示为34 12, int型数0x12345678表示为78 56 34 12如IBM power PC结构下,short型数0x1234表示为12 34, int型数0x12345678表示为12   34 56 78。
## 需要进行字节序转换原因
由于不同的字节序导致不同体系结构的机器之间无法通信,所以要转换成一种约定的数序,也就是网络字节顺序,其实就是如同powerpc那样的顺序 。在PC开发中有ntohl和htonl函数可以用来进行网络字节和主机字节的转换。
