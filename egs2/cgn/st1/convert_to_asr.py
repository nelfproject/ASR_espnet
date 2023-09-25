import torch
from espnet2.tasks.subtitle_chained import SubtitleTask
from espnet2.torch_utils.load_pretrained_model import load_pretrained_model

dtype = "float32"

subs_model, subs_train_args = SubtitleTask.build_model_from_file(
            subs_train_config, subs_model_file, device
        )
subs_model.to(dtype=getattr(torch, dtype)).eval()



def build_model_from_file(
        cls,
        config_file: Union[Path, str] = None,
        model_file: Union[Path, str] = None,
        device: str = "cpu",
) -> Tuple[AbsESPnetModel, argparse.Namespace]:

        config_file = Path(model_file).parent / "config.yaml"

    with config_file.open("r", encoding="utf-8") as f:
        args = yaml.safe_load(f)
    args = argparse.Namespace(**args)
    model = cls.build_model(args)
    if not isinstance(model, AbsESPnetModel):
        raise RuntimeError(
            f"model must inherit {AbsESPnetModel.__name__}, but got {type(model)}"
        )
    model.to(device)
    if model_file is not None:
        if device == "cuda":
            # NOTE(kamo): "cuda" for torch.load always indicates cuda:0
            #   in PyTorch<=1.4
            device = f"cuda:{torch.cuda.current_device()}"
        model.load_state_dict(torch.load(model_file, map_location=device))

    return model, args


# 2. Build model
    model = cls.build_model(args=args)
    if not isinstance(model, AbsESPnetModel):
        raise RuntimeError(
            f"model must inherit {AbsESPnetModel.__name__}, but got {type(model)}"
        )
    model = model.to(
        dtype=getattr(torch, args.train_dtype),
        device="cuda" if args.ngpu > 0 else "cpu",
    )

for p in args.init_param:
    if len(p.split(';')) > 1:  # ;-separated argument instead of list
        # p = p[1:-1]  # remove double quotes, very hacky...
        for pp in p.split(';'):
            logging.info(f"Loading pretrained params from {pp}")
            load_pretrained_model(
                model=model,
                init_param=pp,
                ignore_init_mismatch=args.ignore_init_mismatch,
                # NOTE(kamo): "cuda" for torch.load always indicates cuda:0
                #   in PyTorch<=1.4
                map_location=f"cuda:{torch.cuda.current_device()}"
                if args.ngpu > 0
                else "cpu",
                convert_to_dual=args.convert_to_dual,
            )