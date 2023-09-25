#!/bin/bash

. ./path.sh

#dual=true
suffix="espnet-subs-parallel-noPL"
expdir="/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-subs-chained/st_train_subtitling_parallel_noPL"
model="st_decode_subs_st_model_valid.acc_asr.ave"
dual=false

IFS=";"

outdir=/esat/spchtemp/scratch/jponcele/Dutch_Scripts/examples_jakob_subs/
scoredir=/esat/spchtemp/scratch/jponcele/Dutch_Scripts

if $dual; then
  cp ${expdir}/${model}/subs_annot/subs ${outdir}/recog_${suffix}.txt
else
  cp ${expdir}/${model}/subs_annot/text ${outdir}/recog_${suffix}.txt
fi

export PYTHONPATH=""
source /esat/spchtemp/scratch/jponcele/anaconda3/bin/activate tf21
python --version
export LC_ALL='en_US.utf8'
  
cd $scoredir  

python score_bleu.py -i examples_jakob_subs/recog_${suffix}.txt -t prepare_cgn/files/subs_annot/subtitles -c -d -n -l single_space sub_words sub_patterns strip_hyphen lower -w nl_rm_fillers.lst nl_abbrev.lst -p nl_getallen100.lst nl_getallen1000.lst -r resources/ #-a -e -o examples_jakob_subs/analysis


