#!/usr/bin/env bash

filename=$1
inputfile=$2
scratchdir=$3

curdir=`pwd`

vaddir=$scratchdir/VAD
mkdir -p $vaddir

# 1. Apply rVAD to input wav file
echo "[Segment] Applying rVAD"
cd local/rVAD
# use rVAD_fast_lowthres.py for smaller segments
python rVAD_fast.py $inputfile $vaddir/${filename}.VAD.txt
cd $curdir

# 2. Convert to tensors
echo "[Segment] Converting to tensor"
python local/rVAD/vad_to_ark.py $filename $vaddir/${filename}.VAD.txt $vaddir/${filename}.VAD.ark $vaddir/${filename}.VAD.scp

# 3. Convert 0/1 string to segmentation
echo "[Segment] Converting to segmentation"
. ./path-kaldi.sh >/dev/null 2>/dev/null
copy-int-vector scp:$vaddir/${filename}.VAD.scp ark,t:- 2>/dev/null | sed -e "s/\[ //g;s/ \]//g" | utils/segmentation.pl --remove-noise-only-segments false 2>/dev/null > $vaddir/segments
. ./path.sh

# 4. Extend segment boundaries to include all audio
echo "[Segment] Extending segments $vaddir/segments"
python local/rVAD/extend_segments.py $vaddir
mv $vaddir/segments $vaddir/segments.orig
mv $vaddir/segments_extended $vaddir/segments


