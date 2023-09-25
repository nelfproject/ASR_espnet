#!/usr/bin/env bash
export PYTHONPATH=""
source /esat/spchtemp/scratch/jponcele/anaconda3/bin/activate espnet2
python --version
export PYTHONPATH="${PYTHONPATH}:/users/spraak/jponcele/s3prl"

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

####################################################
stage=12
stop_stage=13
####################################################

# notes: geen speed perturbation, geen LM, geen word LM, geen NGRAM LM

# EXP
outdir=/esat/spchtemp/scratch/jponcele/espnet2
expdir=${outdir}/exp/exp-new
asr_tag=train_asr_transformer_wav2vec2_small_specaug_XLSR
asr_stats_dir=/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-new/st_stats_XLSR_vl_bpe5000

nj=8
ngpu=1

# DATA
train_set=train_s
valid_set=valid_s_filtered
test_sets="subs_annot"  # dev_s"
traincomps="a;b;c;d;f;g;h;i;j;k;l;m;n;o"
decodecomps="b;f;g;h;i;j;k;l;m;n;o"
local_data_opts="--repstr false --lowercase true --outdir data --traincomps ${traincomps} --decodecomps ${decodecomps}"
feats_type=raw  #fbank_pitch

# LM
use_word_lm=false  # not yet supported!
use_lm=false
lm_config=conf/train_lm_transformer.yaml
use_ngram=false

# ASR
feats_normalize=utterance_mvn  # recommended for pretrained models instead of globalmvn
asr_config=conf/tuning/train_asr_transformer_small_specaug_wav2vec2_frontend_XLSR.yaml
inference_config=conf/decode.yaml
inference_asr_model=valid.acc.ave.pth
inference_nj=64
asr_args="--input_size 0"  # to use raw audio for w2v2 encoder

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
    --inference_asr_model ${inference_asr_model}  \
    --inference_nj ${inference_nj}  \
    --feats_normalize ${feats_normalize}  \
    --train_set "${train_set}" \
    --valid_set "${valid_set}" \
    --test_sets "${test_sets}" \
    --asr_stats_dir "${asr_stats_dir}" \

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
