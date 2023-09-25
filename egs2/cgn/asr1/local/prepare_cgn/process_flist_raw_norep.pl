#!/usr/bin/perl

# This script extracts the segmentation from the cgn database and prepares a text file for transcriptions, a segments file for timing details, an utt2spk file and a spk2gender file.
# The input to this script is a file list containing the location of a file on each line.

use lib '/usr/share/perl5/IO/Compress';
use IO::Compress::Gzip;

#
# For each line in the flist, read the corresponding spk file.
#   - make segments file to indicate utterance borders
#   - make scp file with utterance-ids
#   - make utt2spk file to indicate speakerinformation
#   - make txt file with transcription of each utterance
# Then read the speakers.txt file for more info on speakers
#   - make spk2gender file with genderinformation
#

open(UTT, '>:encoding(utf-8)', "$ARGV[0].utt2spk");
open(TXT, '>:encoding(utf-8)', "$ARGV[0].txt");
open(SEG, '>:encoding(utf-8)', "$ARGV[0].segments");
open(SCPR, '>:encoding(utf-8)', "$ARGV[0]_wav_remix.scp");
open(SCP, '>:encoding(utf-8)', "$ARGV[0]_wav.scp");

open (IN, "$ARGV[0].flist");
while(<IN>){
	chop;
	m:^\S+/(.+)\.wav$: || next;
	$basefile=$1;
	$fullfile=$_;
	m:^\S+/(comp-.+)\.wav$:;
	$seafile=$1;
	# write SCP
	print SCP "$basefile $fullfile\n";
	print SCPR "$basefile sox -t wav $fullfile -b 16 -t wav - remix - |\n";
	# write SEA
	open(SEA, "/users/spraak/spchdata/cgn/data/annot/corex/sea/$seafile.sea") || next;
	while (<SEA>) {
		chop;

		# Process start line
		if (m/^(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)/) {
			$uttid=$5;
			$speaker=$4;
			if ($speaker eq "COMMENT") {$speaker="BACKGROUND";}
			$end=$3/1000;
			$start=$2/1000;
			if($end<=$start) {$speaker="BACKGROUND";}
		}
		
		# Find orthographical transcription without trailing '.' or '?'
		if ((m/^ORT\s(.+)(\?|\.)$/) && ($speaker ne "BACKGROUND")) {
                        $text=$1;
                        $text=~tr/\.//d  # remove '...' from transcription
		}
		
		# Write txt, seg, and utt files
		if ((m/^MAR\s(.+) _$/) && ($speaker ne "BACKGROUND")) {
                        @words=split(" ", $text);
                        @mars=split(" ", $1);

                        $repstr="";  # replace *a (=incomplete words) with -xxx
                         
                        # if transcription not empty
                        if ((scalar(@words)>0) && ($#words==$#mars)) {	
                            for ($t=0; $t<scalar(@words); $t++) {
                                if ($mars[$t] eq "incomplete") {
                                    $repword=$words[$t].$repstr;
                                    $words[$t]=$repword
                                }
                            }
                        
                        $text=join(" ", @words);
                        $text=~s/  / /g;  # remove double spaces

         		print TXT "$speaker-$uttid $text\n";
         		print SEG "$speaker-$uttid $basefile $start $end\n";
					$speakersfound{$speaker}=1;
					print UTT "$speaker-$uttid $speaker\n";
			}		
		}	
	}
}

# Create spk2gender
# get gender for each speaker
open(IN, "/users/spraak/spchdata/cgn/data/meta/text/speakers.txt") || die "speakers.txt not found";

# find indexes for ID and gender
$topline=<IN>;
@stuff=split(/\t/, $topline);
for($t=0; $t<$#stuff; $t++) {
	if ($stuff[$t] eq "ID") {
		$ididx=$t;
	} elsif ($stuff[$t] eq "sex") {
		$genderidx=$t;
	}
}

while(<IN>) {
	@stuff=split(/\t/);
	if ($stuff[$genderidx] eq "sex1") {
		$gender="m";
	} else {
		$gender="f";
	}
	$spk2gen{$stuff[$ididx]}=$gender;
}
$spk2gen{"UNKNOWN"}="m";		# unknowns are male 

# and write speakers with gender to specified output
open(SPK, '>:encoding(utf-8)', "$ARGV[0].spk2gender");
foreach $spk (sort keys %speakersfound) {
    # some speakers are not in speakers.txt. We shall assume they are male for no particular reason whatsoever.
    if (!$spk2gen{$spk}) {
        $spk2gen{$spk}="m";
    }
    print SPK "$spk $spk2gen{$spk}\n";
}
