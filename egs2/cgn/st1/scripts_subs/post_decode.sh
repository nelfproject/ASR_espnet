#!/bin/bash

suffix=PL_C8_CTC_new
ep=77
model=averaged_model_${ep}epochs
_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-subs-chained/st_train_subtitling_chained_${suffix}/st_decode_chained_st_model_${model}
echo $_dir

dsets="dev_s subs_annot"

_nj=64

for dset in $dsets; do
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

