#!/bin/bash

. ./path.sh

suffix="espnet-asr-verbsubs"
expdir="/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_v6_verbsubs"
model="decode_asr_model_averaged_model_100epochs"
dual=false

IFS=";"

outdir=/esat/spchtemp/scratch/jponcele/Dutch_Scripts/
scoredir=/esat/spchtemp/scratch/jponcele/Dutch_Scripts

cp ${expdir}/${model}/dev_s/text ${outdir}/examples_jakob/recog_${suffix}.txt
cp ${expdir}/${model}/subs_annot/text ${outdir}/examples_jakob_subs/recog_${suffix}.txt

if $dual; then
  cp ${expdir}/${model}/subs_annot/subs ${outdir}/examples_jakob_subs/bleu/recog_${suffix}.txt
else
  cp ${expdir}/${model}/subs_annot/text ${outdir}/examples_jakob_subs/bleu/recog_${suffix}.txt
fi

export PYTHONPATH=""
source /esat/spchtemp/scratch/jponcele/anaconda3/bin/activate tf21
python --version
export LC_ALL='en_US.utf8'
  
cd $scoredir  

echo "######## SCORING DEV_S #########"
python score.py -i examples_jakob/recog_${suffix}.txt -t prepare_cgn/files/dev_s_shrt/text -c -d -n -l single_space sub_words sub_patterns strip_hyphen lower -w nl_rm_fillers.lst nl_abbrev.lst -p nl_getallen100.lst nl_getallen1000.lst -r resources/


echo "######## SCORING SUBS ANNOT #########"
python score.py -i examples_jakob_subs/recog_${suffix}.txt -t prepare_cgn/files/subs_annot/text -c -d -n -l single_space sub_words sub_patterns strip_hyphen lower -w nl_rm_fillers.lst nl_abbrev.lst -p nl_getallen100.lst nl_getallen1000.lst -r resources/ #-a -e -o examples_jakob_subs/analysis


echo "######## SCORING BLEU ########"
python score_bleu.py -i examples_jakob_subs/bleu/recog_${suffix}.txt -t prepare_cgn/files/subs_annot/subtitles -c -d -n -l single_space sub_words sub_patterns strip_hyphen lower -w nl_rm_fillers.lst nl_abbrev.lst -p nl_getallen100.lst nl_getallen1000.lst -r resources/ #-a -e -o examples_jakob_subs/analysis
