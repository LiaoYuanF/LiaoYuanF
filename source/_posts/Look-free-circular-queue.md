---
title: 线程安全的无锁循环队列
date: 2023-12-28 13:30:34
tags: 工具集合
---
想要探寻一下和ChatGpt的合作开发模式，因此尝试能否单纯依靠prompt进行修正，由Gpt来实现一个具有一定复杂度的循环队列。
# 需求的自然语言描述
用C++ 20的语言标准，实现线程安全的循环队列，提供详细注释
具体要求如下：

1. 环形队列要支持阻塞读和非阻塞读，阻塞写和非阻塞写
2. 支持模板，存放的数据类型可以自定义
3. 代码风格使用google C++风格
4. 在开发中尽可能提高队列的性能，并说明采取了哪些手段提高性能，说明理由
# Gpt第一轮尝试
## Gpt给出的结果
```cpp
#include <iostream>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>

// 线程安全的循环队列模板
template <typename T>
class ThreadSafeQueue {
public:
    explicit ThreadSafeQueue(size_t capacity) : capacity_(capacity) {}

    // 阻塞写入队列
    void Enqueue(const T& item) {
        std::unique_lock<std::mutex> lock(mutex_);
        // 使用条件变量等待队列不满
        notFull_.wait(lock, [this] { return queue_.size() < capacity_; });
        queue_.push(item);
        lock.unlock();
        // 通知等待的线程队列不为空
        notEmpty_.notify_one();
    }

    // 非阻塞写入队列
    bool TryEnqueue(const T& item) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (queue_.size() < capacity_) {
            queue_.push(item);
            // 通知等待的线程队列不为空
            notEmpty_.notify_one();
            return true;
        }
        return false;
    }

    // 阻塞读取队列
    T Dequeue() {
        std::unique_lock<std::mutex> lock(mutex_);
        // 使用条件变量等待队列不空
        notEmpty_.wait(lock, [this] { return !queue_.empty(); });
        T item = queue_.front();
        queue_.pop();
        lock.unlock();
        // 通知等待的线程队列不满
        notFull_.notify_one();
        return item;
    }

    // 非阻塞读取队列
    bool TryDequeue(T& item) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!queue_.empty()) {
            item = queue_.front();
            queue_.pop();
            // 通知等待的线程队列不满
            notFull_.notify_one();
            return true;
        }
        return false;
    }

private:
    size_t capacity_;
    std::queue<T> queue_;
    std::mutex mutex_;
    std::condition_variable notFull_;
    std::condition_variable notEmpty_;
};
```
## 对代码的分析
代码最低限度地实现了我们提出的需求，比如阻塞/非阻塞读写、支持模板、代码风格等。但是代码中存在着许多显而易见的问题。

1. 可能是我使用的“队列”一词对gpt造成了先入为主的印象，导致它在数据结构上采用了deque的结构，当deque需要增长时，它会分配一个新的内存块，并将其链接到现有的块，这样一个动态的结构天生会对内存的分配存在开销，偏离了我们提出的高性能的目的。
2. gpt在代码设计中，为了保障线程安全的要求，使用了互斥锁，这一块是可以优化的，可以通过原子变量的CAS操作来规避掉锁的开销。
#  Gpt的第二轮尝试
## 对功能修改的描述
目前代码存在一些问题，考虑针对以下点进行优化：

1. 由于采用deque的数据结构，导致存在动态分配内存的开销
2. mutex互斥锁的存在降低了效率，能否通过原子变量实现无锁操作
## Gpt给出的结果
```cpp
#include <iostream>
#include <vector>
#include <atomic>
#include <condition_variable>
#include <thread>

template <typename T>
class ThreadSafeQueue {
public:
    explicit ThreadSafeQueue(size_t capacity) : capacity_(capacity), head_(0), tail_(0) {
        data_.resize(capacity);
    }

    // 阻塞写入队列
    void Enqueue(const T& item) {
        while (true) {
            size_t currentTail = tail_.load(std::memory_order_relaxed);
            size_t nextTail = (currentTail + 1) % capacity_;

            if (nextTail != head_.load(std::memory_order_acquire)) {
                data_[currentTail] = item;
                tail_.store(nextTail, std::memory_order_release);
                return;
            }
            // 队列已满，等待
            std::this_thread::yield();
        }
    }

    // 非阻塞写入队列
    bool TryEnqueue(const T& item) {
        size_t currentTail = tail_.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % capacity_;

        if (nextTail != head_.load(std::memory_order_acquire)) {
            data_[currentTail] = item;
            tail_.store(nextTail, std::memory_order_release);
            return true;
        }
        return false;
    }

    // 阻塞读取队列
    T Dequeue() {
        while (true) {
            size_t currentHead = head_.load(std::memory_order_relaxed);
            size_t currentTail = tail_.load(std::memory_order_acquire);

            if (currentHead != currentTail) {
                T item = data_[currentHead];
                head_.store((currentHead + 1) % capacity_, std::memory_order_release);
                return item;
            }
            // 队列为空，等待
            std::this_thread::yield();
        }
    }

    // 非阻塞读取队列
    bool TryDequeue(T& item) {
        size_t currentHead = head_.load(std::memory_order_relaxed);
        size_t currentTail = tail_.load(std::memory_order_acquire);

        if (currentHead != currentTail) {
            item = data_[currentHead];
            head_.store((currentHead + 1) % capacity_, std::memory_order_release);
            return true;
        }
        return false;
    }

private:
    size_t capacity_;
    std::vector<T> data_;
    std::atomic<size_t> head_;
    std::atomic<size_t> tail_;
};
```
## 对代码的分析
从这轮优化中粗看，gpt已经修复了上文中提到的两个问题，使用了std::atomic来管理head_和tail_，并通过原子操作实现队列的无锁操作。在阻塞写入和读取的过程中，移除了两个条件变量，使用std::this_thread::yield()来让出CPU。
可以简单分析一下，这轮优化过程中使用到的一些知识点：
### 为什么舍弃条件变量
**std::condition_variable** 是 C++ 标准库中的一个多线程同步工具，用于在多个线程之间进行条件同步。采用**condition_variable** 主动来实现线程的等待和唤醒机制显然比盲目地std::this_thread::yield()让出时间片更为合理，如果在阻塞写或者阻塞读的情况下，有可能造成频繁的线程切换，造成开销。
但是**condition_variable** 必须搭配mutex使用，在我们限定无锁编程的情况下，**condition_variable** 显然是无法被采用的，所以被舍弃了。
### 阻塞写时安全性论证
```cpp
void Enqueue(const T& item) {
    while (true) {
        size_t currentTail = tail_.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % capacity_;
        if (nextTail != head_.load(std::memory_order_acquire)) {
            data_[currentTail] = item;
            tail_.store(nextTail, std::memory_order_release);
            return;
        }
        // 队列已满，等待
        std::this_thread::yield();
    }
}
```
这是gpt给出的代码，如我们提示的那样使用上了原子变量，试图通过内存序来保障读写之间的安全性。但是很明显，这段代码是在多写情况下是线程不安全的。
**错误一：**
下面的两行代码之间不是原子的，多个线程在同一时刻可能读取相同的 tail_ 值，然后计算出相同的 nextTail，这可能导致它们尝试在相同的位置写入数据，从而导致数据覆盖。
```cpp
size_t currentTail = tail_.load(std::memory_order_relaxed);
size_t nextTail = (currentTail + 1) % capacity_;
```
**错误二：**
虽然 head_ 的加载使用了 memory_order_acquire，但是在实际的操作中，其他线程可能在这段时间内修改了 head_ 的值，导致脏读的出现，从而导致判断错误。
```cpp
if (nextTail != head_.load(std::memory_order_acquire)) {
    data_[currentTail] = item;
    // something else
}
```
所以从上面指出的这两个错误来看，这部分代码存在着比较致命的问题。
# Gpt的第三轮尝试
## 对功能修改的描述
目前代码存在一些问题，考虑针对以下点进行优化：

1. 目前代码面对多线程写入的场景时，因为临界区的存在，存在不安全的问题，考虑用CAS操作进行优化
## Gpt给出的结果
```cpp
#include <iostream>
#include <vector>
#include <atomic>
#include <condition_variable>
#include <thread>

template <typename T>
class ThreadSafeQueue {
public:
    explicit ThreadSafeQueue(size_t capacity) : capacity_(capacity), head_(0), tail_(0) {
        data_.resize(capacity);
    }

    // 阻塞写入队列
    void Enqueue(const T& item) {
        size_t currentTail;
        size_t nextTail;

        do {
            currentTail = tail_.load(std::memory_order_relaxed);
            nextTail = (currentTail + 1) % capacity_;

            if (nextTail == head_.load(std::memory_order_acquire)) {
                // 队列已满，等待
                std::this_thread::yield();
                continue;
            }

            // 尝试使用CAS进行原子操作
        } while (!tail_.compare_exchange_weak(currentTail, nextTail, std::memory_order_acq_rel));

        // CAS成功，可以进行写入操作
        data_[currentTail] = item;
    }

    // 非阻塞写入队列
    bool TryEnqueue(const T& item) {
        size_t currentTail = tail_.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % capacity_;

        if (nextTail == head_.load(std::memory_order_acquire))
            return false;

        if (tail_.compare_exchange_weak(currentTail, nextTail, std::memory_order_acq_rel)) {
            // CAS成功，可以进行写入操作
            data_[currentTail] = item;
            return true;
        }

        return false;
    }

    // 阻塞读取队列
    T Dequeue() {
        size_t currentHead;
        size_t currentTail;

        do {
            currentHead = head_.load(std::memory_order_relaxed);
            currentTail = tail_.load(std::memory_order_acquire);

            if (currentHead == currentTail) {
                // 队列为空，等待
                std::this_thread::yield();
                continue;
            }

            // 尝试使用CAS进行原子操作
        } while (!head_.compare_exchange_weak(currentHead, (currentHead + 1) % capacity_, std::memory_order_acq_rel));

        // CAS成功，可以进行读取操作
        return data_[currentHead];
    }

    // 非阻塞读取队列
    bool TryDequeue(T& item) {
        size_t currentHead = head_.load(std::memory_order_relaxed);
        size_t currentTail = tail_.load(std::memory_order_acquire);

        if (currentHead == currentTail)
            return false;

        if (head_.compare_exchange_weak(currentHead, (currentHead + 1) % capacity_, std::memory_order_acq_rel)) {
            // CAS成功，可以进行读取操作
            item = data_[currentHead];
            return true;
        }

        return false;
    }

private:
    size_t capacity_;
    std::vector<T> data_;
    std::atomic<size_t> head_;
    std::atomic<size_t> tail_;
};

```
## 对代码的分析
我们回到上文中有问题的函数，经过更新之后的代码片段如下所示：
```cpp
void Enqueue(const T& item) {
    size_t currentTail;
    size_t nextTail;
    do {
        currentTail = tail_.load(std::memory_order_relaxed);
        nextTail = (currentTail + 1) % capacity_;
        if (nextTail == head_.load(std::memory_order_acquire)) {
            // 队列已满，等待
            std::this_thread::yield();
            continue;
        }
        // 尝试使用CAS进行原子操作
    } while (!tail_.compare_exchange_weak(currentTail, nextTail, std::memory_order_acq_rel));
    // CAS成功，可以进行写入操作
    data_[currentTail] = item;
}
```
在这个函数内部，如我们提示的那样，将尾指针移动的逻辑包裹在了一个compare_exchange_weak操作的内部，如果当前内存中的tail_变量与我们预期的currentTail不一样，则重新load，重新计算nextTail，如果和预期的一致，则更新tail_为nextTail。
# 一些更远的优化点
此时，这份代码基本已经成型，但是gpt的自由发挥距离我想要的代码还有一定差距。

1. 阻塞接口和非阻塞接口的代码重复度其实很高，可以通过加一个参数来合并两个接口。
2. 该模板完全的左值传入，有一定的性能的开销，可以修改一下同时左值和右值传入。

改良后的代码如下：
```cpp
#include <iostream>
#include <vector>
#include <atomic>
#include <condition_variable>
#include <thread>

template <typename T>
class ThreadSafeQueue {
public:
    explicit ThreadSafeQueue(size_t capacity) : capacity_(capacity), head_(0), tail_(0) {
        data_.resize(capacity);
    }

    // 通用的入队操作
    template <typename U>
    bool Enqueue(U&& item, bool blocking = true) {
        size_t currentTail;
        size_t nextTail;

        do {
            currentTail = tail_.load(std::memory_order_relaxed);
            nextTail = (currentTail + 1) % capacity_;

            if (nextTail == head_.load(std::memory_order_acquire)) {
                if (blocking) {
                    std::this_thread::yield();
                    continue;
                } else {
                    return false;  // 如果是非阻塞模式，直接返回失败
                }
            }

            // 尝试使用CAS进行原子操作
        } while (!tail_.compare_exchange_weak(currentTail, nextTail, std::memory_order_acq_rel));

        // CAS成功，可以进行写入操作
        data_[currentTail] = std::forward<U>(item);
        return true;
    }

    // 通用的出队操作
    template <typename U>
    bool Dequeue(U& item, bool blocking = true) {
        size_t currentHead;
        size_t currentTail;

        do {
            currentHead = head_.load(std::memory_order_relaxed);
            currentTail = tail_.load(std::memory_order_acquire);

            if (currentHead == currentTail) {
                if (blocking) {
                    std::this_thread::yield();
                    continue;
                } else {
                    return false;  // 如果是非阻塞模式，直接返回失败
                }
            }

            // 尝试使用CAS进行原子操作
        } while (!head_.compare_exchange_weak(currentHead, (currentHead + 1) % capacity_, std::memory_order_acq_rel));

        // CAS成功，可以进行读取操作
        item = std::move(data_[currentHead]);
        return true;
    }

private:
    size_t capacity_;
    std::vector<T> data_;
    std::atomic<size_t> head_;
    std::atomic<size_t> tail_;
};

```

