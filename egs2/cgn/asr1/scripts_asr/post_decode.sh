#!/bin/bash

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_interctc_selfcond_3lay/decode_asr_model_valid.acc.ave

vers="v6_averaged_loo"  #_subs_C8_new"
model="valid.acc.ave"  #"init_model"  #averaged_model_71epochs"  #valid.acc.ave
_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_${vers}/decode_asr_model_${model}

#_dir="/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-new/asr_train_asr_transformer_wav2vec2_small_specaug_XLSR/decode_asr_model_valid.acc.ave"

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_interctc_selfcond_11lay/decode_asr_model_valid.acc.ave

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_transformer_fbp_2_specaug_new_bpe5000_digits_lr_maskctc_selfcond_11lay/decode_maskctc_0.9_asr_model_valid.acc_mlm.ave
#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_maskctc_interctc_selfcond_11lay/decode_maskctc_asr_model_valid.acc_mlm.ave

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-new/asr_train_asr_transformer_wav2vec2_small_specaug_XLSR_2B_lasthalf/decode_asr_model_averaged_model

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_v6/decode_asr_model_valid.acc.ave

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-new/asr_train_asr_transformer_wav2vec2_small_specaug_skipconv_256units/decode_asr_model_valid.acc.ave

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_v6_verbsubs/decode_asr_model_averaged_model_100epochs

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_v6_averaged_2/decode_asr_model_valid.acc.ave

#_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_v6_2000h_thresh0.6/decode_asr_model_averaged_model_149epochs

_dset=aphasia_lowthres  #sabed  #subs_annot  #subs_valid_2000h_new  #dev_s  #subs_annot
_logdir=${_dir}/${_dset}/logdir
_nj=64


for f in token token_int score text; do
  if [ -f "${_logdir}/output.1/1best_recog/${f}" ]; then
    for i in $(seq "${_nj}"); do
      echo "${_logdir}/output.${i}/1best_recog/${f}"
      cat "${_logdir}/output.${i}/1best_recog/${f}"
    done | sort -k1 >"${_dir}/${_dset}/${f}"
  fi
done

