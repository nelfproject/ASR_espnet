#!/bin/bash

. ./path.sh

vers="PL_C8_new_frozenasr_v2_bpe_joint_lowlr"
ep="20"
suffix="espnet-subs-chained-${vers}"
expdir="/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-subs-chained/st_train_subtitling_chained_${vers}"
model="st_decode_chained_st_model_averaged_model_${ep}epochs"


IFS=";"

outdir=/esat/spchtemp/scratch/jponcele/Dutch_Scripts/examples_jakob/
scoredir=/esat/spchtemp/scratch/jponcele/Dutch_Scripts

cp ${expdir}/${model}/dev_s/text ${outdir}/recog_${suffix}.txt

export PYTHONPATH=""
source /esat/spchtemp/scratch/jponcele/anaconda3/bin/activate tf21
python --version
export LC_ALL='en_US.utf8'
  
cd $scoredir  

python score.py -i examples_jakob/recog_${suffix}.txt -t prepare_cgn/files/dev_s_shrt/text -c -d -n -l single_space sub_words sub_patterns strip_hyphen lower -w nl_rm_fillers.lst nl_abbrev.lst -p nl_getallen100.lst nl_getallen1000.lst -r resources/


