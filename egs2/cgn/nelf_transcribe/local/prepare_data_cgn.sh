#!/bin/bash

# Copied from /esat/spchtemp/scratch/jponcele/Dutch_Scripts/prepare_cgn
# Can replace process_flist_raw.pl with process_flist_raw_norep.pl to not get -xxx appended to cut words

### SETTINGS ###################################
# Whether to append -xxx to words that are cut (*a)
repstr=false

# Lowercase all transcriptions
lowercase=true

# Directory to write to
outdir=data

# Suffix appended to train set
suffix=

# Choose which language to use
lang="vl"  #"vl;nl"

# Move every X-th speaker of the training set to the validation set
valid_X=50

# Choose which components to use in train and test set
traincomps="a;b;c;d;f;g;h;i;j;k;l;m;n;o"
decodecomps="b;f;g;h;i;j;k;l;m;n;o"  # without comp a,c,d

# Directory containing data, structure should be $wavdir/comp-*/$lang/*.wav
wavdir=/esat/spchtemp/scratch/jponcele/cgn_wav_data
cur_dir=local/prepare_cgn

# Remove all utterances from the dev set containing only these words
filtersyms="xxx;ggg"

# Create an 'ignore-list' with all remaining utterances in the dev set that contain this word
# (+ also the removed utterances)
ignoresyms="xxx;ggg"
#####################################################

. utils/parse_options.sh

mkdir -p $outdir

train_set=train_s
valid_set=valid_s
test_set=dev_s

if [ ! -z "${suffix}" ]; then
    train_set+="_${suffix}"
    valid_set+="_${suffix}"
    test_set+="_${suffix}"
fi

echo "### Creating train and dev set split"

# create train & dev set
## Create .flist files (containing a list of all .wav files in the corpus)
rm -f $outdir/tempdecode.flist $outdir/temptrain.flist
IFS=';'
for l in $lang; do
	for i in $decodecomps; do
		find ${wavdir}/comp-${i}/${l} -name '*.wav' | grep -vE '[A-B][0-9].wav' >>$outdir/tempdecode.flist
	        
        done
	for j in $traincomps; do
		find ${wavdir}/comp-${j}/${l} -name '*.wav' | grep -vE '[A-B][0-9].wav' >>$outdir/temptrain.flist
        done
done

IFS=' '
# now split into train and dev   // -vF selects non-matching lines in file, -F the matching lines
grep -vF -f ${cur_dir}/${lang}_comps_devset.txt $outdir/temptrain.flist | sort >$outdir/${train_set}.flist
grep -F -f  ${cur_dir}/${lang}_comps_devset.txt $outdir/tempdecode.flist | sort >$outdir/${test_set}.flist

rm -f $outdir/temptrain.flist $outdir/tempdecode.flist

echo "### Extracting data from CGN database"

# create utt2spk, spk2utt, txt, segments, scp, spk2gender
for x in ${test_set} ${train_set}; do
        if ! "${repstr}"; then
    	    $cur_dir/process_flist_raw_norep.pl $outdir/$x
    	else
    	    $cur_dir/process_flist_raw.pl $outdir/$x
    	fi
done

echo "### Postprocessing files in train set"
for x in ${train_set}; do
	mkdir -p $outdir/$x
        mv $outdir/${x}.flist $outdir/$x/flist || exit 1;
	    mv $outdir/${x}_wav.scp $outdir/$x/wav.scp || exit 1;
        mv $outdir/${x}_wav_remix.scp $outdir/$x/wav_remix.scp || exit 1;

        # don't remove segments from unknown speakers for training data
        mv $outdir/$x.txt $outdir/$x/text || exit 1;
        mv $outdir/$x.segments $outdir/$x/segments || exit 1;

        if "${lowercase}"; then
            mv $outdir/$x/text $outdir/$x/text_cased
            awk '{out=""; for (i=2; i<=NF; i++) out=out" "tolower($i); print $1out}' $outdir/$x/text_cased > $outdir/$x/text
        fi

	    mv $outdir/$x.utt2spk $outdir/$x/utt2spk || exit 1;
        $cur_dir/utt2spk_to_spk2utt.pl $outdir/$x/utt2spk > $outdir/$x/spk2utt
	    $cur_dir/filter_scp.pl $outdir/$x/spk2utt $outdir/${x}.spk2gender > $outdir/$x/spk2gender || exit 1;
        rm -f $outdir/$x.spk2gender

        # filter everything to only keep utterances that are present in all files
        $cur_dir/fix_data_dir_alt.sh $outdir/$x || exit 1;
done

echo "### Postprocessing files in dev set"
for x in ${test_set}; do
        mkdir -p $outdir/$x
        mv $outdir/${x}.flist $outdir/$x/flist || exit 1;
        mv $outdir/${x}_wav.scp $outdir/$x/wav.scp || exit 1;
        mv $outdir/${x}_wav_remix.scp $outdir/$x/wav_remix.scp || exit 1;

        # remove segments from unknown speakers
        cat $outdir/$x.txt | sed '/UNKNOWN-fv*/d' > $outdir/$x/text || exit 1;
        rm -f $outdir/$x.txt
        cat $outdir/$x.segments | sed '/UNKNOWN-fv*/d' > $outdir/$x/segments || exit 1;
        rm -f $outdir/$x.segments

        cat $outdir/$x.utt2spk | sed '/UNKNOW*/d' > $outdir/$x/utt2spk || exit 1;
        rm -f $outdir/$x.utt2spk
        $cur_dir/utt2spk_to_spk2utt.pl $outdir/$x/utt2spk > $outdir/$x/spk2utt
        $cur_dir/filter_scp.pl $outdir/$x/spk2utt $outdir/${x}.spk2gender > $outdir/$x/spk2gender || exit 1;
        rm -f $outdir/$x.spk2gender

	    # filter out transcriptions with only xxx/ggg
        # and create an ignore list containing all remaining sentences with xxx
	    python $cur_dir/filter_trans.py $outdir/$x/text $outdir/$x/text_filt $outdir/$x/ignore_list $filtersyms $ignoresyms || exit 1;
        rm -f $outdir/$x/text
        mv $outdir/$x/text_filt $outdir/$x/text

        if "${lowercase}"; then
            mv $outdir/$x/text $outdir/$x/text_cased
            awk '{out=""; for (i=2; i<=NF; i++) out=out" "tolower($i); print $1out}' $outdir/$x/text_cased > $outdir/$x/text
        fi

        # final cleanup filter
        $cur_dir/fix_data_dir_alt.sh $outdir/$x || exit 1;
done

echo "### Generating validation set"
cp -r $outdir/${train_set} $outdir/${valid_set}
for x in ${train_set} ${valid_set}; do
    if [ "${x}" = ${train_set} ]; then
        awk 'NR%Z>0' Z="${valid_X}" $outdir/$x/spk2utt > $outdir/$x/spk2utt_filt
    else
        awk 'NR%Z==0' Z="${valid_X}" $outdir/$x/spk2utt > $outdir/$x/spk2utt_filt
    fi

    $cur_dir/spk2utt_to_utt2spk.pl $outdir/$x/spk2utt_filt > $outdir/$x/utt2spk_filt

    mv -f $outdir/$x/spk2utt_filt $outdir/$x/spk2utt
    mv -f $outdir/$x/utt2spk_filt $outdir/$x/utt2spk

    $cur_dir/fix_data_dir_alt.sh $outdir/$x || exit 1;
done

echo "### Final dataprep results"
for x in ${train_set} ${valid_set} ${dev_set}; do
    echo "Number of segments in $x: " $(wc -l < $outdir/$x/segments)
done

echo "### DONE!"
