#!/usr/bin/env python
#coding:utf8

import pdb

def subsets(nums):
    # write your code here
    res = [[]]
    pdb.set_trace()
    for num in nums:
        for tmp in res[:]:
            x = tmp[:]
            x.append(num)
            res.append(x)
    return res

if __name__ == '__main__':
    subsets([1,2,3])
