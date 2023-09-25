#!/bin/bash

suffix=PL_C8_new_frozenasr_v2_bpe_joint
ep=19
model=averaged_model_${ep}epochs  #valid.acc_subs.ave
_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-subs-chained/st_train_subtitling_chained_${suffix}/st_decode_chained_st_model_${model}


echo $_dir

_nj=64
for dset in dev_s subs_annot; do
  echo "Processing ${dset}"
  _logdir=${_dir}/${dset}/logdir
  for f in token token_int score text subs score_subs token_subs token_int_subs; do
    if [ -f "${_logdir}/output.1/1best_recog/${f}" ]; then
      for i in $(seq "${_nj}"); do
        #echo "${_logdir}/output.${i}/1best_recog/${f}"
        cat "${_logdir}/output.${i}/1best_recog/${f}"
      done | sort -k1 >"${_dir}/${dset}/${f}"
    fi
  done
done
  

IFS=";"
scoredir=/esat/spchtemp/scratch/jponcele/Dutch_Scripts


cp ${_dir}/dev_s/text ${scoredir}/examples_jakob/recog_${suffix}.txt
cp ${_dir}/subs_annot/text ${scoredir}/examples_jakob_subs/recog_${suffix}.txt
  
export PYTHONPATH=""
source /esat/spchtemp/scratch/jponcele/anaconda3/bin/activate tf21
python --version
export LC_ALL='en_US.utf8'

cd $scoredir
python score.py -i examples_jakob/recog_${suffix}.txt -t prepare_cgn/files/dev_s_shrt/text -c -d -n -l single_space sub_words sub_patterns strip_hyphen lower -w nl_rm_fillers.lst nl_abbrev.lst -p nl_getallen100.lst nl_getallen1000.lst -r resources/  

python score.py -i examples_jakob_subs/recog_${suffix}.txt -t prepare_cgn/files/subs_annot/text -c -d -n -l single_space sub_words sub_patterns strip_hyphen lower -w nl_rm_fillers.lst nl_abbrev.lst -p nl_getallen100.lst nl_getallen1000.lst -r resources/ #-a -e -o examples_jakob_subs/analysis

