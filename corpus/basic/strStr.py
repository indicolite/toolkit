#!/usr/bin/env python
#coding:utf8
import pdb

def strStr( source, target):
    # Write your code here
    if source is None or target is None:
        return -1
    len_s = len(source)
    len_t = len(target)
    pdb.set_trace()
    for i in range(len_s - len_t + 1):
        for j in range(len_t):
            if source[i+j] != target[j]:
                break
        else:
            return i
    return -1

if __name__ == '__main__':
    strStr("source", "rce")
