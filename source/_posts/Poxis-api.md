---
title: 共享内存（二）：POSIX Api
date: 2024-02-02 14:31:42
tags: 共享内存
---
POSIX本质上就是 mmap 对文件的共享方式映射，只不过映射的是 tmpfs 文件系统上的文件。
# POSIX Api简介
POSIX本质上就是 mmap 对文件的共享方式映射，只不过映射的是 tmpfs 文件系统上的文件。tmpfs是Linux提供的一种“临时”的文件系统，它可以将内存的一部分空间拿来当做文件系统使用，使内存空间可以当做目录文件来用。Linux提供的POSIX共享内存，实际上就是在/dev/shm下创建一个文件，并将其mmap之后映射其内存地址即可。
# mmap系列函数简介
mmap函数主要的功能就是将文件或设备映射到调用进程的地址空间中，当使用mmap映射文件到进程后,就可以直接操作这段虚拟地址进行文件的读写等操作,不必再调用read，write等系统调用。在很大程度上提高了系统的效率和代码的简洁性。
## mmap函数主要的作用

- 对普通文件提供内存映射I/O，可以提供无亲缘进程间的通信；
- 提供匿名内存映射，以供亲缘进程间进行通信。
-  对shm_open创建的POSIX共享内存区对象进程内存映射，以供无亲缘进程间进行通信。
## mmap函数主要的API
### mmap 映射内存
mmap成功后，返回值即为fd映射到内存区的起始地址，之后可以关闭fd，一般也是这么做的，这对该内存映射没有任何影响。
```cpp
/**
* start：指定描述符fd应被映射到的进程地址空间内的起始地址，通常被设置为NULL，自动选择起始地址
* len：映射到进程地址空间的字节数，它从被映射文件开头的第offset个字节处开始，offset通常被设置为0
* prot：内存映射区的保护由该参数来设定
* 	PROT_READ：数据可读
* 	PROT_WRITE：数据可写
* 	PROT_EXEC：数据可执行
* 	PROT_NONE：数据不可访问
* flags：设置内存映射区的类型标志
* 	MAP_SHARED：表示调用进程对被映射内存区的数据所做的修改对于共享该内存区的所有进程都可见，而且确实改变其底层的支撑对象
* 	MAP_PRIVATE：调用进程对被映射内存区的数据所做的修改只对该进程可见，而不改变其底层支撑对象
*	MAP_FIXED：该标志表示准确的解释start参数，一般不建议使用该标志，对于可移植的代码，应该把start参数置为NULL，且不指定MAP_FIXED标志
*	MAP_ANON：Linux中定义的非标准参数，提供匿名内存映射机制
* fd：有效的文件描述符。如果设定了MAP_ANONYMOUS（MAP_ANON）标志，在Linux下面会忽略fd参数，而有的系统实现如BSD需要置fd为-1
* offset：相对文件的起始偏移
*/
void *mmap(void *start, 
           size_t len, 
           int prot, 
           int flags, 
           int fd, 
           off_t offset);
```

![image.png](/images/shared-mem/2.png)
### munmap删除映射
```cpp
/**
* start：被映射到的进程地址空间的内存区的起始地址，即mmap返回的地址
* len：映射区的大小
*/
int munmap(void *start, size_t len);
```
### msync实时同步
对于一个MAP_SHARED的内存映射区，内核的虚拟内存算法会保持内存映射文件和内存映射区的同步，也就是说，对于内存映射文件所对应内存映射区的修改，内核会在稍后的某个时刻更新该内存映射文件。如果我们希望硬盘上的文件内容和内存映射区中的内容实时一致，那么我们就可以调用msync开执行这种同步：
```cpp
/**
* start：被映射到的进程地址空间的内存区的起始地址，即mmap返回的地址
* len：映射区的大小
* flags：同步标志
*	MS_ASYNC：异步写，一旦写操作由内核排入队列，就立刻返回；
*	MS_SYNC：同步写，要等到写操作完成后才返回。
*	MS_INVALIDATE：使该文件的其他内存映射的副本全部失效。
*/
int msync(void *start, size_t len, int flags);
```
## mmap实现线程中通信
### 通过匿名内存映射提供亲缘进程间的通信
我们可以通过在父进程fork之前指定MAP_SHARED调用mmap，通过映射一个文件来实现父子进程间的通信，POSIX保证了父进程的内存映射关系保留到子进程中，父子进程对内存映射区的修改双方都可以看到。
在Linux 2.4以后，mmap提供匿名内存映射机制，即将mmap的flags参数指定为：MAP_SHARED | MAP_ANON。这样就彻底避免了内存映射文件的创建和打开，简化了对文件的操作。匿名内存映射机制的目的就是为了提供一个穿越父子进程间的内存映射区，很方便的提供了亲缘进程间的通信。
简化测试代码：
```cpp
int main(int argc, char **argv)
{
    int *memPtr;
    memPtr = (int *) mmap(NULL, sizeof(int), PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANON, 0, 0);
    if (memPtr == MAP_FAILED)	return -1;
    *memPtr = 0;
    if (fork() == 0)
    {
        *memPtr = 1;
        cout<<"child:set memory "<<*memPtr<<endl;
        exit(0);
    }
    sleep(1);
    cout<<"parent:memory value "<<*memPtr<<endl;
    return 0;
}
```
### 通过内存映射文件提供无亲缘进程间的通信
通过在不同进程间对同一内存映射文件进行映射，来进行无亲缘进程间的通信。
简化测试代码：
```cpp
//process 1
int main()
{
    int *memPtr;
    int fd;
    fd = open(PATH_NAME, O_RDWR | O_CREAT, 0666);
    if (fd < 0)
    {
        return -1;
    }
 
    ftruncate(fd, sizeof(int));
    memPtr = (int *)mmap(NULL, sizeof(int), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
 
    if (memPtr == MAP_FAILED)
    {
        cout<<"mmap failed..."<<strerror(errno)<<endl;
        return -1;
    }
 
    *memPtr = 111;
	cout<<"process:"<<getpid()<<" send:"<<*memPtr<<endl;
 
    return 0;
}
 
//process 2
int main()
{
    int *memPtr;
    int fd;
    fd = open(PATH_NAME, O_RDWR | O_CREAT, 0666);
    if (fd < 0)
    {
        return -1;
    }
 
    memPtr = (int *)mmap(NULL, sizeof(int), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
 
    if (memPtr == MAP_FAILED)
    {
        cout<<"mmap failed..."<<strerror(errno)<<endl;
        return -1;
    }
 
    cout<<"process:"<<getpid()<<" receive:"<<*memPtr<<endl;
 
    return 0;
}
```
# 基于mmap的POSIX共享内存
## 具体步骤

1. 通过shm_open创建或打开一个POSIX共享内存对象
2. 然后调用mmap将它映射到当前进程的地址空间
## POSIX共享内存底层支撑对象
![image.png](/images/shared-mem/3.png)
### 内存映射文件(memory-mapped file)
由open函数打开，由mmap函数把所得到的描述符映射到当前进程空间地址中的一个文件。共享的数据载体是物理文件。
### 主流：共享内存区对象(shared-memory object)
由shm_open函数打开一个Posix.1 IPC名字，所返回的描述符由mmap函数映射到当前进程的地址空间。共享的数据载体是物理内存。
## 共享内存区对象API
### shm_open打开共享内存区
shm_open用于创建一个新的共享内存区对象或打开一个已经存在的共享内存区对象。
```cpp
/**
* name：POSIX IPC的名字
* oflag：操作标志，包含：O_RDONLY，O_RDWR，O_CREAT，O_EXCL，O_TRUNC。
* 其中O_RDONLY和O_RDWR标志必须且仅能存在一项
* mode：用于设置创建的共享内存区对象的权限属性。
* 该参数必须一直存在，如果oflag参数中没有O_CREAT标志，该位可以置0
*/
int shm_open(const char *name, int oflag, mode_t mode);
```
### shm_unlink删除共享内存对象
shm_unlink用于删除一个共享内存区对象，跟其他文件的unlink以及其他POSIX IPC的删除操作一样，对象的析构会到对该对象的所有引用全部关闭才会发生。
```cpp
int shm_unlink(const char *name);
```
### 代码简单测试实例
```cpp
//process 1
#define SHM_NAME "/memmap"
#define SHM_NAME_SEM "/memmap_sem" 
char sharedMem[10];
int main()
{
    int fd;
    sem_t *sem;
 
    fd = shm_open(SHM_NAME, O_RDWR | O_CREAT, 0666);
    sem = sem_open(SHM_NAME_SEM, O_CREAT, 0666, 0);
 
    if (fd < 0 || sem == SEM_FAILED)
    {
        cout<<"shm_open or sem_open failed...";
        cout<<strerror(errno)<<endl;
        return -1;
    }
 
    ftruncate(fd, sizeof(sharedMem));
 
    char *memPtr;
    memPtr = (char *)mmap(NULL, sizeof(sharedMem), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
 
    char msg[] = "yuki...";
 
    memmove(memPtr, msg, sizeof(msg));
    cout<<"process:"<<getpid()<<" send:"<<memPtr<<endl;
 
    sem_post(sem);
    sem_close(sem);
 
    return 0;
}
 
//process 2
int main()
{
    int fd;
    sem_t *sem;
 
    fd = shm_open(SHM_NAME, O_RDWR, 0);
    sem = sem_open(SHM_NAME_SEM, 0);
 
    if (fd < 0 || sem == SEM_FAILED)
    {
        cout<<"shm_open or sem_open failed...";
        cout<<strerror(errno)<<endl;
        return -1;
    }
 
    struct stat fileStat;
    fstat(fd, &fileStat);
 
    char *memPtr;
    memPtr = (char *)mmap(NULL, fileStat.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
 
    sem_wait(sem);
 
    cout<<"process:"<<getpid()<<" recv:"<<memPtr<<endl;
 
    sem_close(sem);
 
    return 0;
}
```

