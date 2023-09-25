#!/usr/bin/env bash

scratchdir=$1
mode=$2

mkdir -p $scratchdir/result

if [ "${mode}" = asr ]; then
    outfile=$scratchdir/decode/text
elif [ "${mode}" = subs ]; then
    outfile=$scratchdir/decode/subs
fi

python local/cleanup.py $outfile $scratchdir/data/segments $scratchdir/result/transcription

