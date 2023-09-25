#!/usr/bin/env bash

## load your python environment
export PYTHONPATH=""
source /esat/spchtemp/scratch/jponcele/anaconda3/bin/activate espnet2
python --version

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

####################################################
# set the stage you want to run
stage=11
stop_stage=11
####################################################

# notes: no speed perturbation, no LM, no word LM, no NGRAM LM
# EXP
outdir=/esat/spchtemp/scratch/jponcele/espnet2
expdir=${outdir}/exp/exp-subs-chained
st_tag=train_subtitling_chained_PL_C8_new
st_stats_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-st/st_stats_fbank_pitch_vl_joint_bpe5000  

# number of cpu's used
nj=4
# number of gpu's used
ngpu=1

# DATA
st_train_set=st_train
st_valid_set=st_valid
st_test_set="subs_annot"

asr_train_set=train_s
asr_valid_set=valid_s
asr_test_set=dev_s
subs_train_set=subs_train
subs_valid_set=subs_valid
subs_test_set=subs_test

# data preparation tags
traincomps="a;b;c;d;f;g;h;i;j;k;l;m;n;o"
decodecomps="b;f;g;h;i;j;k;l;m;n;o"
local_data_opts="--repstr false --lowercase true --outdir data --traincomps ${traincomps} --decodecomps ${decodecomps}"

subs_dir=/users/spraak/jponcele/vrt-scraper/vrtnew_subtitles_4feb
local_subs_opts="--outdir data --subsdir ${subs_dir}"

feats_type=fbank_pitch

# LM
use_word_lm=false  # not yet supported!
use_lm=false
lm_config=conf/train_lm_transformer.yaml
use_ngram=false

# Subs Training
feats_normalize=utterance_mvn  # recommended for pretrained models instead of globalmvn
st_config=conf/tuning/train_subtitling_chained_C8_new.yaml
inference_config=conf/st_decode_chained.yaml
inference_nj=64
inference_st_model=averaged_model_81epochs.pth  #valid.acc_asr.ave.pth
st_args="--batch_type custom_folded --valid_batch_type custom_folded"  # "--input_size 0"  # to use raw audio for w2v2 encoder

./subs.sh \
    --stage ${stage} \
    --stop_stage ${stop_stage} \
    --ngpu ${ngpu}  \
    --nj ${nj}  \
    --gpu_inference false  \
    --dumpdir ${outdir}/dump  \
    --expdir ${expdir}  \
    --feats_type ${feats_type}  \
    --audio_format wav  \
    --min_wav_duration 0.1  \
    --max_wav_duration 30  \
    --token_joint true \
    --src_token_type bpe \
    --src_nbpe 5000 \
    --src_bpemode unigram \
    --src_case lc  \
    --tgt_token_type bpe \
    --tgt_nbpe 5000 \
    --tgt_bpemode unigram \
    --tgt_case lc  \
    --oov "<unk>" \
    --lang "vl" \
    --src_lang "verbatim" \
    --tgt_lang "subtitle" \
    --local_subs_opts "${local_subs_opts}"  \
    --local_data_opts "${local_data_opts}"  \
    --use_lm ${use_lm} \
    --use_word_lm ${use_word_lm}  \
    --lm_config ${lm_config}  \
    --use_ngram ${use_ngram}  \
    --st_config ${st_config}  \
    --st_args "${st_args}"  \
    --st_tag ${st_tag}  \
    --inference_config ${inference_config}  \
    --inference_nj ${inference_nj}  \
    --feats_normalize ${feats_normalize}  \
    --st_train_set "${st_train_set}" \
    --st_valid_set "${st_valid_set}" \
    --st_test_set "${st_test_set}" \
    --asr_train_set ${asr_train_set} \
    --asr_valid_set ${asr_valid_set} \
    --asr_test_set ${asr_test_set} \
    --subs_train_set ${subs_train_set} \
    --subs_valid_set ${subs_valid_set} \
    --subs_test_set ${subs_test_set} \
    --st_stats_dir ${st_stats_dir}  \
    --inference_st_model ${inference_st_model}  \

#    --pretrained_asr ${pretrained_asr} \

#train_set=train_si284
#valid_set=test_dev93
#test_sets="test_dev93 test_eval92"
#
#./asr.sh \
#    --lang "en" \
#    --use_lm true \
#    --token_type char \
#    --nbpe 80 \
#    --nlsyms_txt data/nlsyms.txt \
#    --lm_config conf/train_lm_transformer.yaml \
#    --asr_config conf/train_asr_transformer.yaml \
#    --inference_config conf/decode.yaml \
#    --train_set "${train_set}" \
#    --valid_set "${valid_set}" \
#    --test_sets "${test_sets}" \
#    --bpe_train_text "data/train_si284/text" \
#    --lm_train_text "data/train_si284/text data/local/other_text/text" "$@"
