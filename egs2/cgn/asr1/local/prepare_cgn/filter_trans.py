#!/usr/bin/env python

import os
import sys

input_f = sys.argv[1]
output_f = sys.argv[2]
ignore_list = sys.argv[3]
remove_syms = sys.argv[4]
ignore_syms = sys.argv[5]

remove_set = set(remove_syms.split(';'))
ignore_set = set(ignore_syms.split(';'))

print('Processing input text: %s' % input_f)
print('Removing all utterances that only contain words in: ', remove_set)
print('Creating a list of all utterances containing (among others) words in: ', ignore_set)
print('Removed utterances are also added to the ignore list (for in case your model still contains these)')

outf = open(output_f, 'w', encoding="utf-8")
ignf = open(ignore_list, 'w', encoding="utf-8")

bad_cnt = 0
ignore_cnt = 0
total_cnt = 0

with open(input_f, 'r', encoding="utf-8") as pd:
    line = pd.readline()
    while line:
        total_cnt += 1
        wrds = set(line.rstrip().split(' ')[1:])
        if len(wrds) == 0:  # empty utt
            ignf.write(line)
            bad_cnt += 1
            ignore_cnt += 1
            continue
        if len(wrds - remove_set) >= 0:  # not only xxx and ggg
            outf.write(line)
            if len(wrds & ignore_set) > 0:  # does contain an xxx and/or ggg
                ignf.write(line)
                ignore_cnt += 1
        else:
            ignf.write(line)
            bad_cnt += 1
            ignore_cnt += 1
        line = pd.readline()

outf.close()
ignf.close()

print('Kept %i out of %i utterances after filtering' % (int(total_cnt-bad_cnt), int(total_cnt)))
print('Copied %i utterances to the ignore list, of which %i are already removed from reference' % (int(ignore_cnt), int(bad_cnt)))
