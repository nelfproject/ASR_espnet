#!/bin/bash

# Move every X-th utterance of the training set to the validation/test set
X=50
outdir=data
subsdir=/users/spraak/jponcele/vrt-scraper/vrtnew_subtitles_4feb

. utils/parse_options.sh

train_set=subs_train
valid_set=subs_valid
test_set=subs_test

mkdir -p ${outdir}/${train_set} ${outdir}/${valid_set} ${outdir}/${test_set}

awk 'NR%Z>0' Z="${X}" ${subsdir}/segments > ${outdir}/${train_set}/segments
awk 'NR%Z==0' Z="${X}" ${subsdir}/segments > ${outdir}/${valid_set}/tmp
awk 'NR%2==0' ${outdir}/${valid_set}/tmp > ${outdir}/${valid_set}/segments
awk 'NR%2>0' ${outdir}/${valid_set}/tmp > ${outdir}/${test_set}/segments

rm -f ${outdir}/${valid_set}/tmp

for x in ${train_set} ${valid_set} ${test_set}; do
    cp ${subsdir}/text ${outdir}/$x/text
    cp ${subsdir}/wav.scp ${outdir}/$x/wav.scp
    awk '{print $1, $1}' ${outdir}/$x/text > ${outdir}/$x/utt2spk  # FAKE: every utt a different speaker
    utils/fix_data_dir.sh $outdir/$x || exit 1;
    echo "Number of segments in $x: " $(wc -l < $outdir/$x/segments)
done

echo "### DONE!"
