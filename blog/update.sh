#!/bin/bash
echo "begin deploy"
cd /root/blog/
hexo d -g
echo "begin backup"
cp -rf /root/blog/ /root/LiaoYuanF.github.io/
cd /root/LiaoYuanF.github.io/
git add .
git commit -m "update hexo source"
git push origin HEAD:hexo-source
echo "finished !"
