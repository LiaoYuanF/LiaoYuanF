---
title: 异步事件框架学习
date: 2024-02-05 13:44:59
tags: 学习笔记
---
最近有使用到事件框架，因此对事件框架的学习简单做一个学习笔记。
因为我使用的是libuv，所以后文中部分跟事件框架特性相关的内容和图片是基于libuv的官方文档而言的，不泛指一切事件框架。
# 核心构成
event-loop + 基于I/O或者其他事件通知的回调函数。
在事件驱动编程中，程序会关注每一个事件，并且对每一个事件的发生做出反应。libuv会负责监听各个来源的事件。用户通过注册回调函数在监听到事件的时候被调用。event-loop会一直保持运行状态。用伪代码描述如下：
```cpp
while there are still events to process:
    e = get the next event
    if there is a callback associated with e:
        call the callback
```
# 异步实现
## 需要非阻塞原因
系统编程中出现输入输出的场景多于数据处理。问题在于传统的输入输出函数(例如read，fprintf)都是阻塞式的。在任务完成前函数不会返回，程序在这段时间内什么也做不了。这导致远低于cpu处理速度的IO传输速度是高性能系统的主要障碍。
## 解决方案一：多线程
每一个阻塞的I/O操作都会被分配到各个线程中。当某个线程一旦阻塞，处理器就可以调度处理其他需要cpu资源的线程（操作系统自行分配cpu资源，采用非阻塞方式来轮流执行任务）。
## 解决方案二：异步
现代操作系统大多提供了基于事件通知的子系统。为异步的实现提供了基础。
例如正常的socket上的read调用会发生阻塞，直到发送方把信息发送过来。但是，实际上程序可以请求操作系统监视socket事件的到来，并将这个事件通知放到事件队列中。这样，程序就可以很简单地检查事件是否到来，通知正在处理其他任务的cpu处理事件，及时地获取数据。
异步的具体表现是程序可以在时空上地某一端表达对某事件的兴趣，并在时空地另一端被动地获取到数据。非阻塞是因为程序不是主动地请求等待，而是被动地被事件调用，期间可以自由地做其他的事。
# 异步实现的基础
为了追本溯源，以 epoll 为例分析可实现异步的操作系统基础。
## epoll简介
epoll 是由 Linux 内核提供的一个系统调用，我们的应用程序可以通过它：

- 告诉系统帮助我们同时监控多个文件描述符
- 当这其中的一个或者多个文件描述符的 I/O 可操作状态改变时，我们的应用程序会接收到来自系统的事件提示（event notification）
## epoll流程示例
![image.png](/images/async-framework/1.png)
使用伪代码写一个epoll的具体实现流程，即如下：
```cpp
// 创建 epoll 实例
int epfd = epoll_create(MAX_EVENTS);
// 向 epoll 实例中添加需要监听的文件描述符，这里是 `listen_sock`
epoll_ctl_add(epfd, listen_sock, EPOLLIN | EPOLLOUT | EPOLLET);

while(1) {
  // 等待来自 epoll 的通知，通知会在其中的文件描述符状态改变时
  // 由系统通知应用。通知的形式如下：
  //
  // epoll_wait 调用不会立即返回，系统会在其中的文件描述符状态发生
  // 变化时返回
  //
  // epoll_wait 调用返回后：
  // nfds 表示发生变化的文件描述符数量
  // events 会保存当前的事件，它的数量就是 nfds
  int nfds = epoll_wait(epfd, events, MAX_EVENTS, -1);

  // 遍历 events，对事件作出符合应用预期的响应
  for (int i = 0; i < nfds; i++) {
    consume events[i]
  }
}

```
## epoll的触发模式
触发模式分为水平触发和边缘触发。
### 名词来源
触发模式是传统电子领域的名词的衍生义，下图为电子领域表示电压变化的时序图。
水平触发：在高低电压的峰谷值周期内部会激活对应的电路。![image.png](/images/async-framework/2.png)
边缘触发：在高低电压变化的瞬间会激活对应的电路。
[image.png](/images/async-framework/3.png)
### epoll中触发模式实例
比如我们有一个fd表示刚建立的客户端连接，随后客户端给我们发送了 5 bytes 的内容。
**如果是水平触发：**

- 我们的应用会被系统唤醒，因为 fd 此时状态变为了可读
- 我们从系统的缓冲区中读取 1 byte 的内容，并做了一些业务操作
- 进入到新的一次事件循环，等待系统下一次唤醒
- 系统继续唤醒我们的应用，因为缓冲区还有未读取的 4 bytes 内容

**如果是边缘触发：**

- 我们的应用会被系统唤醒，因为 fd 此时状态变为了可读
- 我们从系统的缓冲区中读取 1 byte 的内容，并做了一些业务操作
- 进入到新的一次事件循环，等待系统下一次唤醒
- 此时系统并不会唤醒我们的应用，直到下一次客户端发送了一些内容，比如发送了 2 bytes（因为直到下一次客户端发送了请求之前，fd 的状态并没有改变，所以在边缘触发下系统不会唤醒应用）
- 系统唤醒我们的应用，此时缓冲区有 6 bytes = (4 + 2) bytes

**对此场景下两种触发模式的理解：**
水平触发，因为已经是可读状态，所以它会一直触发，直到我们读完缓冲区，且系统缓冲区没有新的客户端发送的内容；
边缘触发，对应的是**状态的变化**，每次有新的客户端发送内容，都会设置可读状态，因此只会在这个时机触发。
## epoll的局限性
epoll 并不能够作用在所有的 IO 操作上，比如文件的读写操作，就无法享受到 epoll 的便利性。
所以在实现异步操作框架时，一般会混合多种非阻塞手段：

- 将各种操作系统上的类似 epoll 的系统调用（比如 Unix 上的 kqueue 和 Windows 上的 IOCP）抽象出统一的 API（内部 API）
- 对于可以利用系统调用的 IO 操作，优先使用统一后的 API
- 对于不支持或者支持度不够的 IO 操作，使用线程池（Thread pool）的方式模拟出异步 API
- 最后，将上面的细节封装在内部，对外提供统一的 API
# 框架逻辑结构
## 基础代码示例
这个是一个异步事件框架的基本骨架，很重要。
主体就是一个while循环，内部依次处理了timer，pending，idle，prepare，io_poll，check，closing的队列事件，这个先后顺序也表示了这些事件的优先级。
```cpp
int uv_run(uv_loop_t* loop, uv_run_mode mode) {
  int timeout;
  int r;
  int ran_pending;

  r = uv__loop_alive(loop);
  if (!r) uv__update_time(loop);

  // 是循环，没错了
  while (r != 0 && loop->stop_flag == 0) {
    uv__update_time(loop);
    // 处理 timer 队列
    uv__run_timers(loop);
    // 处理 pending 队列
    ran_pending = uv__run_pending(loop);
    // 处理 idle 队列
    uv__run_idle(loop);
    // 处理 prepare 队列
    uv__run_prepare(loop);

    // 执行 io_poll
    uv__io_poll(loop, timeout);
    uv__metrics_update_idle_time(loop);

    // 执行 check 队列
    uv__run_check(loop);
    // 执行 closing 队列
    uv__run_closing_handles(loop);

    r = uv__loop_alive(loop);
    if (mode == UV_RUN_ONCE || mode == UV_RUN_NOWAIT) break;
  }

  return r;
}
```
## 抽象的操作概念
event-loop中存在一些操作的抽象概念，通过分析他们的api对他们的抽象进行一个简述。
### Handle
Handle表示需要长期存在的操作，Request表示只需要短暂存在的操作，有着不同的使用方式。
**handle的API如下：**
因为是长期存在的操作，所以基本上会拥有三个步骤：初始化/开始/停止。
```cpp
// IO 操作
int uv_poll_init_socket(uv_loop_t* loop, uv_poll_t* handle, uv_os_sock_t socket);
int uv_poll_start(uv_poll_t* handle, int events, uv_poll_cb cb);
int uv_poll_stop(uv_poll_t* poll);

// timer
int uv_timer_init(uv_loop_t* loop, uv_timer_t* handle);
int uv_timer_start(uv_timer_t* handle, uv_timer_cb cb, uint64_t timeout, uint64_t repeat);
int uv_timer_stop(uv_timer_t* handle);
```
### Requet
**request的API如下：**
requst是个短暂操作，交互形式本质是个请求，提交请求则返回结果。
```cpp
int uv_getaddrinfo
(uv_loop_t* loop, uv_getaddrinfo_t* req, uv_getaddrinfo_cb getaddrinfo_cb, /* ... */);
```
### 联系
 Handle 和 Request 两者不是互斥的概念，Handle 内部实现可能也用到了 Request。因为一些宏观来看的长期操作，在每个时间切片内是可以看成是 Request 的，比如我们处理一个请求，可以看成是一个 Handle，而在当次的请求中，我们很可能会做一些读取和写入的操作，这些操作就可以看成是 Request。
## 不同的回调队列
### timer
timer存在以下三个API：
```cpp
int uv_timer_init(uv_loop_t* loop, uv_timer_t* handle);
int uv_timer_start(uv_timer_t* handle, uv_timer_cb cb, uint64_t timeout, uint64_t repeat);
int uv_timer_stop(uv_timer_t* handle);
```
#### init
init没有什么特殊的地方，只是出初始了一下handle并将handle添加到了队列里。
#### start
start内部做了如下的一些工作：
```cpp
int uv_timer_start(uv_timer_t* handle,
                   uv_timer_cb cb,
                   uint64_t timeout,
                   uint64_t repeat) {
  uint64_t clamped_timeout;

  // loop->time 表示 loop 当前的时间。loop 每次迭代开始时，会用当次时间更新该值
  // clamped_timeout 就是该 timer 未来超时的时间点，这里直接计算好，这样未来就不需要
  // 计算了，直接从 timers 中取符合条件的即可
  if (clamped_timeout < timeout)
    clamped_timeout = (uint64_t) -1;

  handle->timer_cb = cb;
  handle->timeout = clamped_timeout;
  handle->repeat = repeat;

  // 除了预先计算好的 clamped_timeout 以外，未来当 clamped_timeout 相同时，使用这里的
  //自增 start_id 作为比较条件来觉得 handle 的执行先后顺序
  handle->start_id = handle->loop->timer_counter++;

  // 将 handle 插入到 timer_heap 中，这里的 heap 是 binary min heap，所以根节点就是
  // clamped_timeout 值（或者 start_id）最小的 handle
  heap_insert(timer_heap(handle->loop),
              (struct heap_node*) &handle->heap_node,
              timer_less_than);
  // 设置 handle 的开始状态
  uv__handle_start(handle);

  return 0;
}
```
#### stop
stop内部做了如下的一些工作：
```cpp
int uv_timer_stop(uv_timer_t* handle) {
  if (!uv__is_active(handle))
    return 0;

  // 将 handle 移出 timer_heap，和 heap_insert 操作一样，除了移出之外
  // 还会维护 timer_heap 以保障其始终是 binary min heap
  heap_remove(timer_heap(handle->loop),
              (struct heap_node*) &handle->heap_node,
              timer_less_than);
  // 设置 handle 的状态为停止
  uv__handle_stop(handle);

  return 0;
}
```
#### timers串联分析
start 和 stop 其实可以粗略地概括为，往属性 loop->timer_heap 中插入或者移出 handle，并且这个timer_heap 使用 binary min heap 的数据结构。
**整个timers的启动：**
```cpp
void uv__run_timers(uv_loop_t* loop) {
  struct heap_node* heap_node;
  uv_timer_t* handle;

  for (;;) {
    // 取根节点，该值保证始终是所有待执行的 handle中，最先超时的那一个
    heap_node = heap_min(timer_heap(loop));
    if (heap_node == NULL)
      break;

    handle = container_of(heap_node, uv_timer_t, heap_node);
    if (handle->timeout > loop->time)
      break;

    // 停止、移出 handle、顺便维护 timer_heap
    uv_timer_stop(handle);
    // 如果是需要 repeat 的 handle，则重新加入到 timer_heap 中
    // 会在下一次事件循环中、由本方法继续执行
    uv_timer_again(handle);
    // 执行超时 handle 其对应的回调
    handle->timer_cb(handle);
  }
}
```
### pending
#### pending数据结构
使用了一个queue来维护handle。在libuv中，queue是一个环形结构，首尾指针都是本身。具体可以看libuv中的queue.h的头文件，不详细展开了。
#### pending串联分析
```cpp
static int uv__run_pending(uv_loop_t* loop) {
  QUEUE* q;
  QUEUE pq;
  uv__io_t* w;

  if (QUEUE_EMPTY(&loop->pending_queue))
    return 0;

  QUEUE_MOVE(&loop->pending_queue, &pq);

  // 不断从队列中弹出元素进行操作
  while (!QUEUE_EMPTY(&pq)) {
    q = QUEUE_HEAD(&pq);
    QUEUE_REMOVE(q);
    QUEUE_INIT(q);
    w = QUEUE_DATA(q, uv__io_t, pending_queue);
    w->cb(loop, w, POLLOUT);
  }

  return 1;
}
```
### idle，check，prepare
这部分感觉不重要，思想上和pending大同小异，不重点看了。
### io poll
在libuv中，虽然把相关名字取成了poll，但是实际调用的确实是epoll。
```cpp
void uv__io_poll(uv_loop_t* loop, int timeout) {
  while (!QUEUE_EMPTY(&loop->watcher_queue)) {
    // ...
    // `loop->backend_fd` 是使用 `epoll_create` 创建的 epoll 实例
    epoll_ctl(loop->backend_fd, op, w->fd, &e)
    // ...
  }

  // ...
  for (;;) {
  // ...
    if (/* ... */) {
      // ...
    } else {
      // ...
      // `epoll_wait` 和 `epoll_pwait` 只有细微的差别，所以这里只考虑前者
      nfds = epoll_wait(loop->backend_fd,
                        events,
                        ARRAY_SIZE(events),
                        timeout);
      // ...
    }
  }
  // ...

  for (i = 0; i < nfds; i++) {
    // ...
    w = loop->watchers[fd];
    // ...
    w->cb(loop, w, pe->events);
  }
}
```
#### timeout参数
**在epoll_wait中timeout参数的含义：**

- 如果是 -1 表示一直等到有事件产生
- 如果是 0 则立即返回，包含调用时产生的事件
- 如果是其余整数，则以 milliseconds 为单位，规约到未来某个系统时间片内

**在epoll_wait中timeout参数的获得：**
核心思想就是要尽可能的让 CPU 时间能够在事件循环的多次迭代的、多个不同任务队列的执行、中尽可能的分配均匀，避免某个类型的任务产生很高的延迟。
 在uv__next_timeout 实现主要分为三部分：

- 只有在没有 timer 待处理的时候，才会是 -1，-1 会让后续的 uv__io_poll 进入 block 状态、完全等待事件的到达
- 当有 timer，且有超时的 timer handle，则返回 0，这样 uv__io_poll 不会 block 住事件循环，目的是为了快速进入下一次事件循环、以执行超时的 timer
- 当有 timer，不过都没有超时，则计算最小超时时间 diff 来作为 uv__io_poll 的阻塞时间
```cpp
int uv_backend_timeout(const uv_loop_t* loop) {
  // 时间循环被外部停止了，所以让 `uv__io_poll` 理解返回以便尽快结束事件循环
  if (loop->stop_flag != 0)
    return 0;

  // 没有待处理的 handle 和 request，则也不需要等待了，同样让 `uv__io_poll`尽快返回
  if (!uv__has_active_handles(loop) && !uv__has_active_reqs(loop))
    return 0;

  // idle 队列不为空，也要求 `uv__io_poll` 尽快返回，这样尽快进入下一个时间循环
  // 否则会导致 idle 产生过高的延迟
  if (!QUEUE_EMPTY(&loop->idle_handles))
    return 0;

  // 和上一步目的一样，不过这里是换成了 pending 队列
  if (!QUEUE_EMPTY(&loop->pending_queue))
    return 0;

  // 和上一步目的一样，不过这里换成，待关闭的 handles，都是为了避免目标队列产生过高的延迟
  if (loop->closing_handles)
    return 0;

  return uv__next_timeout(loop);
}

int uv__next_timeout(const uv_loop_t* loop) {
  const struct heap_node* heap_node;
  const uv_timer_t* handle;
  uint64_t diff;

  heap_node = heap_min(timer_heap(loop));
  // 如果没有 timer 待处理，则可以放心的 block 住，等待事件到达
  if (heap_node == NULL)
    return -1; /* block indefinitely */

  handle = container_of(heap_node, uv_timer_t, heap_node);
  // 有 timer，且 timer 已经到了要被执行的时间内，则需让 `uv__io_poll`
  // 尽快返回，以在下一个事件循环迭代内处理超时的 timer
  if (handle->timeout <= loop->time)
    return 0;

  // 没有 timer 超时，用最小超时间减去、当前的循环时间的差值，作为超时时间
  // 因为在为了这个差值时间内是没有 timer 超时的，所以可以放心 block 以等待
  // epoll 事件
  diff = handle->timeout - loop->time;
  if (diff > INT_MAX)
    diff = INT_MAX;

  return (int) diff;
}
```
### thread pool
在前面提到过， epoll 目前并不能处理所有的 IO 操作，对于那些 epoll 不支持的 IO 操作，需要内部的线程池来模拟出异步 IO。
#### init
通过 uv_fs_read 的内部实现，找到 uv__work_submit 方法，发现其中初始化的线程池。
```cpp
void uv__work_submit(uv_loop_t* loop,
                     struct uv__work* w,
                     enum uv__work_kind kind,
                     void (*work)(struct uv__work* w),
                     void (*done)(struct uv__work* w, int status)) {
  uv_once(&once, init_once);
  // ...
  post(&w->wq, kind);
}
```
init_once 内部会调用 init_threads 来完成线程池初始化工作。
```cpp
static uv_thread_t default_threads[4];

static void init_threads(void) {
  // ...
  nthreads = ARRAY_SIZE(default_threads);
  val = getenv("UV_THREADPOOL_SIZE");
  // ...
  for (i = 0; i < nthreads; i++)
    if (uv_thread_create(threads + i, worker, &sem))
      abort();
  // ...
}
```
#### post
还是uv__work_submit 方法，内部通过post函数完成任务的提交。
提交任务其实就是将任务插入到线程共享队列 wq，并且有空闲线程时才会通知它们工作。如果当前没有空闲进程，那么工作线程会在完成当前工作后，主动检查 wq 队列是否还有待完成的工作，有的话会继续完成，没有的话，则进入睡眠，等待下次被唤醒。
```cpp
static void post(QUEUE* q, enum uv__work_kind kind) {
  uv_mutex_lock(&mutex);
  // ...
  // 将任务插入到 `wq` 这个线程共享的队列中
  QUEUE_INSERT_TAIL(&wq, q);
  // 如果有空闲线程，则通知它们开始工作
  if (idle_threads > 0)
    uv_cond_signal(&cond);
  uv_mutex_unlock(&mutex);
}
```
#### 更多逻辑
线程池调度这块的实现有些复杂，这边先跳过，之后有机会再补。
### closing
通过closing队列来实现对长操作handle的关闭操作。
调用 uv_close 关闭handle后，libuv 会先释放其占用的资源（比如关闭 fd），随后通过调用 uv__make_close_pending 把 handle 连接到 closing_handles 队列中，该队列会在事件循环中被 uv__run_closing_handles(loop) 调用所执行。
```cpp
void uv_close(uv_handle_t* handle, uv_close_cb close_cb) {
  assert(!uv__is_closing(handle));

  handle->flags |= UV_HANDLE_CLOSING;
  handle->close_cb = close_cb;

  switch (handle->type) {
  // 根据不同的 handle 类型，执行各自的资源回收工作
  case UV_NAMED_PIPE:
    uv__pipe_close((uv_pipe_t*)handle);
    break;

  case UV_TTY:
    uv__stream_close((uv_stream_t*)handle);
    break;

  case UV_TCP:
    uv__tcp_close((uv_tcp_t*)handle);
    break;
  // ...

  default:
    assert(0);
  }
  
  // 添加到 `loop->closing_handles`
  uv__make_close_pending(handle);
}

void uv__make_close_pending(uv_handle_t* handle) {
  assert(handle->flags & UV_HANDLE_CLOSING);
  assert(!(handle->flags & UV_HANDLE_CLOSED));
  handle->next_closing = handle->loop->closing_handles;
  handle->loop->closing_handles = handle;
}
```
