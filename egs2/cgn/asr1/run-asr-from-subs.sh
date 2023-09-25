#!/usr/bin/env bash
export PYTHONPATH=""
source /esat/spchtemp/scratch/jponcele/anaconda3/bin/activate espnet2
python --version

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

####################################################
stage=12
stop_stage=12
####################################################

# notes: geen speed perturbation, geen LM, geen word LM, geen NGRAM LM

# EXP
outdir=/esat/spchtemp/scratch/jponcele/espnet2
expdir=${outdir}/exp/exp-fbp-new
asr_tag=train_asr_conformer_fbp_2_specaug_new_bpe5000_digits_lr_v6_subs_C8_new

nj=8
ngpu=1

# DATA
train_set=train_s
valid_set=valid_s_filtered
test_sets="aphasia_lowthres"  #"sabed"  #dev_s subs_annot"
traincomps="a;b;c;d;f;g;h;i;j;k;l;m;n;o"
decodecomps="b;f;g;h;i;j;k;l;m;n;o"
local_data_opts="--repstr false --lowercase true --outdir data --traincomps ${traincomps} --decodecomps ${decodecomps}"
feats_type=fbank_pitch

# LM
use_word_lm=false  # not yet supported!
use_lm=false
lm_config=conf/train_lm_transformer.yaml
use_ngram=false

# ASR
feats_normalize=utterance_mvn  # recommended for pretrained models instead of globalmvn
asr_config=conf/tuning/train_asr_conformer_v6.yaml
inference_config=conf/decode.yaml
inference_nj=64
inference_asr_model=init_model.pth  #valid.acc.ave.pth
asr_args=""  # "--input_size 0"  # to use raw audio for w2v2 encoder
#decode_ngram=/esat/spchtemp/scratch/jponcele/espnet2/lm/nbest_words_100k_3gram_tabs.arpa

pretrained_model="/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-subs-chained/st_train_subtitling_chained_PL_C8_new/averaged_model_81epochs.pth"
overwrite_bpemodel="/users/spraak/jponcele/espnet/egs2/cgn/st1/data/vl_token_list_/joint_bpe_unigram5000/bpe.model"
overwrite_token_list="/users/spraak/jponcele/espnet/egs2/cgn/st1/data/vl_token_list_/joint_bpe_unigram5000/tokens.txt"

./asr.sh \
    --stage ${stage} \
    --stop_stage ${stop_stage} \
    --ngpu ${ngpu}  \
    --nj ${nj}  \
    --gpu_inference false  \
    --dumpdir ${outdir}/dump  \
    --expdir ${expdir}  \
    --feats_type ${feats_type}  \
    --local_data_opts "${local_data_opts}"  \
    --audio_format wav  \
    --min_wav_duration 0.1  \
    --max_wav_duration 30  \
    --token_type bpe \
    --nbpe 5000 \
    --bpe_split_digits true \
    --bpemode unigram \
    --oov "<unk>" \
    --lang "vl" \
    --use_lm ${use_lm} \
    --use_word_lm ${use_word_lm}  \
    --lm_config ${lm_config}  \
    --use_ngram ${use_ngram}  \
    --asr_config ${asr_config}  \
    --asr_args "${asr_args}"  \
    --asr_tag ${asr_tag}  \
    --inference_config ${inference_config}  \
    --inference_nj ${inference_nj}  \
    --feats_normalize ${feats_normalize}  \
    --train_set "${train_set}" \
    --valid_set "${valid_set}" \
    --test_sets "${test_sets}" \
    --inference_asr_model "${inference_asr_model}"  \
    --pretrained_model ${pretrained_model}  \
    --overwrite_bpemodel ${overwrite_bpemodel}  \
    --overwrite_token_list ${overwrite_token_list}  \
#    --decode_ngram ${decode_ngram}  \


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
