#!/usr/bin/env bash

scratchdir=$1
modeldir=$2
mode=$3

. ./cmd.sh
. ./path.sh

inference_nj=1  #4
batch_size=1

_cmd="${decode_cmd}"
_ngpu=0

decodedir=$scratchdir/decode
logdir=$decodedir/log
datadir=$scratchdir/feats

mkdir -p $decodedir
mkdir -p $logdir

min() {
  local a b
  a=$1
  for b in "$@"; do
      if [ "${b}" -le "${a}" ]; then
          a="${b}"
      fi
  done
  echo "${a}"
}

if [ "${mode}" = asr ]; then
    inference_tool="espnet2.bin.asr_inference"
    _opts="--config ${modeldir}/decode.yaml --asr_train_config ${modeldir}/train.yaml --asr_model_file ${modeldir}/model.pth "
elif [ "${mode}" = subs ]; then
    inference_tool="espnet2.bin.subtitling_inference_chained"
    _opts="--config ${modeldir}/decode.yaml --st_train_config ${modeldir}/train.yaml --st_model_file ${modeldir}/model.pth "
else
    echo "Invalid decoding mode: mode = ${mode}"
    exit 1;
fi

_feats_type="$(<${datadir}/feats_type)"
if [ "${_feats_type}" = raw ]; then
    _scp=wav.scp
    if [[ "${audio_format}" == *ark* ]]; then
        _type=kaldi_ark
    else
        _type=sound
    fi
else
    _scp=feats.scp
    _type=kaldi_ark
fi

key_file=${datadir}/${_scp}
_nj=$(min "${inference_nj}" "$(<${key_file} wc -l)")

split_scps=""
for n in $(seq "${_nj}"); do
    split_scps+=" ${logdir}/keys.${n}.scp"
done
            
utils/split_scp.pl "${key_file}" ${split_scps}

echo "[Decode] Decoding started... log: '${logdir}/inference.*.log'"

# If number of threads is a problem, use the following line for inference
#OMP_NUM_THREADS=${_nj},3,1 ${_cmd} --num_threads 4 --max-jobs-run 1 ${_cmd} .....

#${_cmd} --gpu "${_ngpu}" JOB=1:"${_nj}" "${logdir}"/inference.JOB.log \
OMP_NUM_THREADS=${_nj},3,1 ${_cmd} --num_threads 4 --max-jobs-run 1 JOB=1:"${_nj}" "${logdir}"/inference.JOB.log \
		python -m ${inference_tool} \
                    --batch_size ${batch_size} \
                    --ngpu "${_ngpu}" \
                    --data_path_and_name_and_type "${datadir}/${_scp},speech,${_type}" \
                    --key_file "${logdir}"/keys.JOB.scp \
                    --output_dir "${logdir}"/output.JOB \
                    ${_opts} ${inference_args}

echo "[Decode] Decode done. Collecting output."
for f in token token_int score text subs score_subs token_subs token_int_subs; do
    if [ -f "${logdir}/output.1/1best_recog/${f}" ]; then
        for i in $(seq "${_nj}"); do
            cat "${logdir}/output.${i}/1best_recog/${f}"
        done | LC_ALL=C sort -k1 >"${decodedir}/${f}"
    fi
done

echo "[Decode] Done."
