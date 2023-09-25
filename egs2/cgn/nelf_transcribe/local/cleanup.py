#!/usr/bin/env python

import os, sys
import datetime

text = sys.argv[1]
segments = sys.argv[2]
outfile = sys.argv[3]

seg2text = dict()
with open(text, 'r') as pd:
    line = pd.readline()
    while line:
        seg = line.rstrip().split(' ')[0]
        txt = ' '.join(line.rstrip().split(' ')[1:])
        seg2text[seg] = txt
        line = pd.readline()

with open(segments, 'r') as pd, open(outfile, 'w') as td:
    line = pd.readline()
    while line:
        seg, fn, st, et = line.rstrip().split(' ')
        st, et = float(st), float(et)
        st = '{:02d}:{:02d}:{:05.2f}'.format(int(st // 3600), int(st % 3600 // 60), st % 60)
        et = '{:02d}:{:02d}:{:05.2f}'.format(int(et // 3600), int(et % 3600 // 60), et % 60)
        td.write('[ %s --> %s ] %s\n' % (st, et, seg2text[seg]))
        line = pd.readline()

