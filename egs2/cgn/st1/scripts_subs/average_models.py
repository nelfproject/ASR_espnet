import os, sys
import glob
import torch

suffix="C8_new_frozenasr_v2_bpe_joint_w0.25"
output_dir = "/esat/spchtemp/scratch/jponcele/espnet2/exp/exp-subs-chained/st_train_subtitling_chained_PL_" + suffix

print(output_dir)

min_epoch = 1  # 1
max_epoch = 25  #214

outname = 'averaged_model_' + str(max_epoch)+ 'epochs.pth'  #valid.acc_asr.ave.pth'

nbest = 10

# based on: espnet2/main_funcs/average_nbest_models.py

avg = None
_loaded = {}
n = 0

#for mdl in glob.glob(os.path.join(output_dir, "*epoch.pth")):
while n < nbest:
    for i in range(min_epoch, max_epoch + 1):

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
    break

for k in avg:
    if str(avg[k].dtype).startswith("torch.int"):
        pass
    else:
        avg[k] = avg[k] / n

torch.save(avg, os.path.join(output_dir, outname))
