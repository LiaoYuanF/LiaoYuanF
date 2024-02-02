---
title: 共享内存（一）：SystemV Api
date: 2024-02-02 14:31:01
tags: 共享内存
---
SymtemV Api是相对来说更为传统的共享内存接口组，更适用于需要底层控制的传统IPC场景。
#  基本API
## shmget 获取共享内存 
使用shmget函数获取共享内存，函数原型如下：
```cpp
/**
* 参数 key 一般由 ftok() 函数生成，用于标识系统的唯一IPC资源
* 参数 size 指定创建的共享内存大小
* 参数 shmflg 指定 shmget() 的动作，比如 IPC_CREAT 表示要创建新的共享内存
* 函数调用成功时返回一个新建或已经存在的的共享内存标识符
* 取决于shmflg的参数。失败返回-1，并设置错误码
*/
int shmget(key_t key, size_t size, int shmflg);
```
shmget函数返回的是一个标识符，而不是可用的内存地址。
## shmat 关联共享内存
使用shmat函数把共享内存关联到某个虚拟内存地址上，函数原型如下：
```cpp
/**
* 参数 shmid 是 shmget() 函数返回的标识符
* 参数 shmaddr 是要关联的虚拟内存地址，如果传入0，表示由系统自动选择合适的虚拟内存地址
* 参数 shmflg 若指定了 SHM_RDONLY 位，则以只读方式连接此段，否则以读写方式连接此段
* 函数调用成功返回一个可用的指针（虚拟内存地址），出错返回-1
*/
void *shmat(int shmid, const void *shmaddr, int shmflg);
```
## shmdt 取消关联共享内存
当一个进程不需要共享内存的时候，就需要取消共享内存与虚拟内存地址的关联。取消关联共享内存通过 shmdt函数实现，原型如下：
```cpp
/**
* 参数 shmaddr 是要取消关联的虚拟内存地址，也就是 shmat() 函数返回的值
* 函数调用成功返回0，出错返回-1
*/
int shmdt(const void *shmaddr);
```
# 共享内存原理
概括而言，共享内存是通过将不同进程的虚拟内存地址映射到相同的物理内存地址来实现的。
![image.png](/images/shared-mem/1.png)
在Linux 内核中，每个共享内存都由一个名为 shmid_kernel 的结构体来管理，而且Linux限制了系统最大能创建的共享内存为128个。
```cpp
/**
* 用于管理共享内存的信息
*/
struct shmid_ds {
 struct ipc_perm  shm_perm; /* operation perms */
 int   shm_segsz; /* size of segment (bytes) */
 __kernel_time_t  shm_atime; /* last attach time */
 __kernel_time_t  shm_dtime; /* last detach time */
 __kernel_time_t  shm_ctime; /* last change time */
 __kernel_ipc_pid_t shm_cpid; /* pid of creator */
 __kernel_ipc_pid_t shm_lpid; /* pid of last operator */
 unsigned short  shm_nattch; /* no. of current attaches */
 unsigned short   shm_unused; /* compatibility */
 void    *shm_unused2; /* ditto - used by DIPC */
 void   *shm_unused3; /* unused */
};

struct shmid_kernel
{ 
 struct shmid_ds  u;
 /* the following are private */
 unsigned long  shm_npages; /* size of segment (pages) */
 pte_t   *shm_pages; /* array of ptrs to frames -> SHMMAX */ 
 struct vm_area_struct *attaches; /* descriptors for attaches */
};

/**
* shm_segs数组 用于管理系统中所有的共享内存
*/
static struct shmid_kernel *shm_segs[SHMMNI]; // SHMMNI等于128
```
## shmget 函数实现
shmget 函数的实现比较简单，首先调用 findkey  函数查找值为 key 的共享内存是否已经被创建，findkey 函数返回共享内存在 shm_segs 数组 的索引。如果找到，那么直接返回共享内存的标识符即可。否则就调用 newseg 函数创建新的共享内存。newseg 函数的实现也比较简单，就是创建一个新的 shmid_kernel 结构体，然后设置其各个字段的值，并且保存到 shm_segs 数组 中。
```cpp
asmlinkage long sys_shmget (key_t key, int size, int shmflg)
{
 struct shmid_kernel *shp;
 int err, id = 0;

 down(&current->mm->mmap_sem);
 spin_lock(&shm_lock);
 if (size < 0 || size > shmmax) 
 {
      err = -EINVAL;
 } else if (key == IPC_PRIVATE) 
 {
      err = newseg(key, shmflg, size);
 } else if ((id = findkey (key)) == -1) 
 {
      if (!(shmflg & IPC_CREAT))
           err = -ENOENT;
      else
           err = newseg(key, shmflg, size);
 } else if ((shmflg & IPC_CREAT) && (shmflg & IPC_EXCL)) 
 {
      err = -EEXIST;
 } else {
      shp = shm_segs[id];
      if (shp->u.shm_perm.mode & SHM_DEST)
           err = -EIDRM;
      else if (size > shp->u.shm_segsz)
           err = -EINVAL;
      else if (ipcperms (&shp->u.shm_perm, shmflg))
           err = -EACCES;
      else
           err = (int) shp->u.shm_perm.seq * SHMMNI + id;
 }
 spin_unlock(&shm_lock);
 up(&current->mm->mmap_sem);
 return err;
}
```
## shmat 函数实现
```cpp
asmlinkage long sys_shmat (int shmid, char *shmaddr, int shmflg, ulong *raddr)
{
    struct shmid_kernel *shp;
    struct vm_area_struct *shmd;
    int err = -EINVAL;
    unsigned int id;
    unsigned long addr;
    unsigned long len;

    down(&current->mm->mmap_sem);
    spin_lock(&shm_lock);
    if (shmid < 0)		
        goto out;

   /**
   * 通过 shmid 标识符来找到共享内存描述符
   * 系统中所有的共享内存到保存在 shm_segs 数组中
   */
    shp = shm_segs[id = (unsigned int) shmid % SHMMNI];
    if (shp == IPC_UNUSED || shp == IPC_NOID)		
        goto out;
   
    /**
    * 找到一个可用的虚拟内存地址
    * 如果在调用 shmat() 函数时没有指定了虚拟内存地址
    * 那么就通过 get_unmapped_area() 函数来获取一个可用的虚拟内存地址
    */
    if (!(addr = (ulong) shmaddr)) {
         if (shmflg & SHM_REMAP)
              goto out;
         err = -ENOMEM;
         addr = 0;
         again:
             //获取一个空闲的虚拟内存空间
             if (!(addr = get_unmapped_area(addr, shp->u.shm_segsz))) 
                  goto out;
             if(addr & (SHMLBA - 1)) 
             {
                  addr = (addr + (SHMLBA - 1)) & ~(SHMLBA - 1);
                  goto again;
              }
    } else if (addr & (SHMLBA-1)) 
    {
         if (shmflg & SHM_RND)
              addr &= ~(SHMLBA-1);       /* round down */
         else
              goto out;
    }
   
    /**
    * 通过调用 kmem_cache_alloc() 函数创建一个 vm_area_struct 结构，
    * vm_area_struct 结构用于管理进程的虚拟内存空间
    */
    spin_unlock(&shm_lock);
    err = -ENOMEM;
    shmd = kmem_cache_alloc(vm_area_cachep, SLAB_KERNEL);
    spin_lock(&shm_lock);
    if (!shmd)
         goto out;
    if ((shp != shm_segs[id]) || (shp->u.shm_perm.seq != (unsigned int) shmid / SHMMNI)) 
    {
         kmem_cache_free(vm_area_cachep, shmd);
         err = -EIDRM;
         goto out;
    }
   
    /**
    * 设置刚创建的 vm_area_struct 结构的各个字段
    */
    shmd->vm_private_data = shm_segs + id;
    shmd->vm_start = addr;
    shmd->vm_end = addr + shp->shm_npages * PAGE_SIZE;
    shmd->vm_mm = current->mm;
    shmd->vm_page_prot = (shmflg & SHM_RDONLY) ? PAGE_READONLY : PAGE_SHARED;
    shmd->vm_flags = VM_SHM | VM_MAYSHARE | VM_SHARED
       | VM_MAYREAD | VM_MAYEXEC | VM_READ | VM_EXEC
       | ((shmflg & SHM_RDONLY) ? 0 : VM_MAYWRITE | VM_WRITE);
    shmd->vm_file = NULL;
    shmd->vm_offset = 0;
    //这个字段比较重要，数据结构如下
    shmd->vm_ops = &shm_vm_ops;
    //shm_vm_ops 的 nopage 回调为 shm_nopage() 函数
    //当发生页缺失异常时将会调用此函数来恢复内存的映射
    /**
    * static struct vm_operations_struct shm_vm_ops = {
    * 	shm_open,  //open - callback for a new vm-area open 
    * 	shm_close,  //close - callback for when the vm-area is released 
    * 	NULL,   //no need to sync pages at unmap 
    * 	NULL,   //protect 
    * 	NULL,   //sync 
    * 	NULL,   //advise 
    * 	shm_nopage,  //nopage 
    * 	NULL,   //wppage 
    * 	shm_swapout  //swapout 
    * };
    */
    shp->u.shm_nattch++;     /* prevent destruction */
    spin_unlock(&shm_lock);
    err = shm_map(shmd);
    spin_lock(&shm_lock);
    if (err)
         goto failed_shm_map;

    insert_attach(shp,shmd);  /* insert shmd into shp->attaches */

    shp->u.shm_lpid = current->pid;
    shp->u.shm_atime = CURRENT_TIME;

    *raddr = addr;
    err = 0;
    out:
        spin_unlock(&shm_lock);
        up(&current->mm->mmap_sem);
        return err;
        ...
}
```
从代码可看出，shmat 函数只是申请了进程的虚拟内存空间，而共享内存的物理空间并没有申请。 事实上，当进程发生缺页异常的时候会调用 shm_nopage 函数来恢复进程的虚拟内存地址到物理内存地址的映射。
## shm_nopage 函数实现
shm_nopage 函数是当发生内存缺页异常时被调用的，主要功能是当发生内存缺页时，申请新的物理内存页，并映射到共享内存中。由于使用共享内存时会映射到相同的物理内存页上，从而不同进程可以共用此块内存。

```cpp
static struct page * shm_nopage(struct vm_area_struct * shmd, unsigned long address, int no_share)
{
    pte_t pte;
    struct shmid_kernel *shp;
    unsigned int idx;
    struct page * page;

    shp = *(struct shmid_kernel **) shmd->vm_private_data;
    idx = (address - shmd->vm_start + shmd->vm_offset) >> PAGE_SHIFT;

    spin_lock(&shm_lock);
    again:
        pte = shp->shm_pages[idx]; // 共享内存的页表项
        if (!pte_present(pte)) 
        {   // 如果内存页不存在
            if (pte_none(pte)) {
                spin_unlock(&shm_lock);
                page = get_free_highpage(GFP_HIGHUSER); // 申请一个新的物理内存页
                if (!page)
                    goto oom;
                clear_highpage(page);
                spin_lock(&shm_lock);
                if (pte_val(pte) != pte_val(shp->shm_pages[idx]))
                    goto changed;
            } else {
               ...
            }
            shm_rss++;
            pte = pte_mkdirty(mk_pte(page, PAGE_SHARED));   // 创建页表项
            shp->shm_pages[idx] = pte;                      // 保存共享内存的页表项
        } else
              --current->maj_flt;  /* was incremented in do_no_page */
    done:
        get_page(pte_page(pte));
        spin_unlock(&shm_lock);
        current->min_flt++;
        return pte_page(pte);
        ...
}
```
