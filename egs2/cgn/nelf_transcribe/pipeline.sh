#!/usr/bin/env bash

fileid=$1
inputfile=$2
scratchdir=$3
curdir=`pwd`

modeldir=./model/asr_v1  #./model/subs_v1
mode=asr  #subs

# 1. Segment input file
echo "### Segmenting input file ###"
. segment.sh $fileid $inputfile $scratchdir

# 2. Prepare data files
echo "### Preparing data files ###"
. prepare.sh $fileid $inputfile $scratchdir

# 3. Extract filterbanks
echo "### Extracting filterbanks ###"
. extract_feats.sh $scratchdir

# 4. Decode input file
echo '### Decoding ###'
. decode.sh $scratchdir $modeldir $mode

# 5. Clean output
echo '### Cleaning output ###'
. clean_up.sh $scratchdir $mode
