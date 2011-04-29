#!/usr/bin/python

import sys, os, time
from stat import *

def execute(subsys, period, cache):
    fname = os.path.join(cache, subsys)
    if os.path.exists(fname):
        # XXX possible race
        cretime = os.stat(fname)[ST_CTIME]
    else:
        return "nodata"

    if (time.time() - cretime) > (period * 60):
        return "expired"
        

    status = 'broken'
    f = open(fname, 'r')
    for l in f.readlines():
        if l.startswith('CHECK'):
            status = l[6:].rstrip()
            break

    f.close()
    return status
