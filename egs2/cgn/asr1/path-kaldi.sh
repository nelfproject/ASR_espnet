source /users/spraak/bbagher/.bashrc

#export CUDA_CACHE_DISABLE=1
#export KALDI_ROOT=/users/spraak/spch/prog/spch/kaldi
export KALDI_ROOT=/esat/spchtemp/spchdisk_orig/bbagher/kaldi-original
#[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh

# contents of env.sh
export PATH=/esat/spchtemp/spchdisk_orig/bbagher/kaldi-original/tools/python:${PATH}
export LIBLBFGS=/esat/spchtemp/spchdisk_orig/bbagher/kaldi-original/tools/liblbfgs-1.10
export LIBFST=/esat/spchtemp/spchdisk_orig/bbagher/kaldi-original/tools/openfst-1.6.7
export LIBLIB=/esat/spchtemp/spchdisk_orig/bbagher/kaldi-original/tools

export EXLIB=/esat/spchtemp/scratch/jponcele/KALDI-2021/local/lib

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:${LIBLIB}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:${LIBFST}/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:${LIBLBFGS}/lib/.libs
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:${EXLIB}

export IRSTLM=/esat/spchtemp/spchdisk_orig/bbagher/kaldi-original/tools/irstlm
export PATH=${PATH}:${IRSTLM}/bin
####
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export PATH=$KALDI_ROOT/tools/kaldi_lm:$PATH


#export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:/esat/spchdisk/scratch/jponcele/kaldi-master/tools/jakoblib/libgfortran-3.0
#export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:/esat/spchdisk/scratch/jponcele/kaldi-master/tools/jakoblib/libcublas
#export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:/esat/spchdisk/scratch/jponcele/kaldi-master/tools/jakoblib/lib

export LC_ALL=C
