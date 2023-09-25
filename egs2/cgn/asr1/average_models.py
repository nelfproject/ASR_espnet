import os, sys
import glob
import torch

output_dir = sys.argv[1]

#output_dir = '/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-st/st_train_st_transformer_fbp'
#output_dir = '/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-new/asr_train_asr_transformer_wav2vec2_small_specaug'
#output_dir = '/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-fbp-new/asr_train_asr_transformer_fbp_2_specaug_new_bpe5000_digits_lr'

max_epoch = 149
outname = "averaged_model_149epochs.pth"  #'valid.acc.ave.pth'  #averaged_model_TEST.pth'  #_200epochs.pth'


# based on: espnet2/main_funcs/average_nbest_models.py

avg = None
_loaded = {}
n = 0

#for mdl in glob.glob(os.path.join(output_dir, "*epoch.pth")):
for i in range(max_epoch + 1):
    mdl = os.path.join(output_dir, str(i)+"epoch.pth")

    if not os.path.exists(mdl):
        continue

    n += 1

    if mdl not in _loaded:
        _loaded[mdl] = torch.load(mdl, map_location="cpu")

    states = _loaded[mdl]

    if avg is None:
        avg = states
    else:
        for k in avg:
            avg[k] = avg[k] + states[k]

for k in avg:
    if str(avg[k].dtype).startswith("torch.int"):
        pass
    else:
        avg[k] = avg[k] / n

torch.save(avg, os.path.join(output_dir, outname))
