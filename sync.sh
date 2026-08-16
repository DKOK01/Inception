#!/bin/bash
rsync -avz --exclude='.git' -e 'ssh -p 2222' \
  /home/aysadeq/Desktop/Inception/ \
  aysadeq@localhost:~/Inception/
