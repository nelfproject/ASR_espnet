from argparse import Namespace
import copy
import logging
import os
from typing import Optional
from typing import Tuple
from typing import Union

import humanfriendly
import torch
from typeguard import check_argument_types

from espnet.nets.pytorch_backend.frontends.frontend import Frontend
from espnet.nets.pytorch_backend.nets_utils import pad_list
from espnet2.asr.frontend.abs_frontend import AbsFrontend
from espnet2.utils.get_default_kwargs import get_default_kwargs


def base_s3prl_setup(args):
    args.upstream_feature_selection = getattr(args, "upstream_feature_selection", None)
    args.upstream_model_config = getattr(args, "upstream_model_config", None)
    args.upstream_refresh = getattr(args, "upstream_refresh", False)
    args.upstream_ckpt = getattr(args, "upstream_ckpt", None)
    args.init_ckpt = getattr(args, "init_ckpt", None)
    args.verbose = getattr(args, "verbose", False)
    args.tile_factor = getattr(args, "tile_factor", 1)
    return args


class S3prlFrontend(AbsFrontend):
    """Speech Pretrained Representation frontend structure for ASR."""

    def __init__(
        self,
        fs: Union[int, str] = 16000,
        frontend_conf: Optional[dict] = get_default_kwargs(Frontend),
        download_dir: str = None,
        multilayer_feature: bool = False,
        layer_indices: int = None,
        s3prl_path: str = None,
    ):
        #assert check_argument_types()
        super().__init__()
        if isinstance(fs, str):
            fs = humanfriendly.parse_size(fs)

        if download_dir is not None:
            torch.hub.set_dir(download_dir)

        self.multilayer_feature = multilayer_feature
        self.layer_indices = layer_indices
        self.s3prl_path = s3prl_path
        self.upstream, self.featurizer = self._get_upstream(frontend_conf)
        if getattr(
            self.upstream, "model", None
        ) is not None and self.upstream.model.__class__.__name__ in [
            "Wav2Vec2Model",
            "HuberModel",
        ]:
            self.upstream.model.encoder.layerdrop = 0.0
        self.pretrained_params = copy.deepcopy(self.upstream.state_dict())
        self.output_dim = self.featurizer.output_dim

    def _get_upstream(self, frontend_conf):
        """Get S3PRL upstream model."""
        s3prl_args = base_s3prl_setup(
            Namespace(**frontend_conf, device="cpu"),
        )
        self.args = s3prl_args

        if self.s3prl_path is None:
            python_path_list = os.environ.get("PYTHONPATH", "(None)").split(":")
            for p in python_path_list:
                if p.endswith("s3prl"):
                    s3prl_path = p
                    break
            self.s3prl_path = s3prl_path
        assert self.s3prl_path is not None

        s3prl_upstream = torch.hub.load(
            self.s3prl_path,
            s3prl_args.upstream,
            ckpt=s3prl_args.upstream_ckpt,
            model_config=s3prl_args.upstream_model_config,
            refresh=s3prl_args.upstream_refresh,
            source="local",
        ).to("cpu")

        from s3prl.upstream.interfaces import Featurizer

        if self.multilayer_feature is None:
            feature_selection = "last_hidden_state"
        else:
            feature_selection = "hidden_states"

        s3prl_featurizer = Featurizer(
            upstream=s3prl_upstream,
            feature_selection=feature_selection,
            layer_selection=self.layer_indices,
            upstream_device="cpu",
        )

        return s3prl_upstream, s3prl_featurizer

    def _tile_representations(self, feature):
        """Tile up the representations by `tile_factor`.

        Input - sequence of representations
                shape: (batch_size, seq_len, feature_dim)
        Output - sequence of tiled representations
                 shape: (batch_size, seq_len * factor, feature_dim)
        """
        assert (
            len(feature.shape) == 3
        ), "Input argument `feature` has invalid shape: {}".format(feature.shape)
        tiled_feature = feature.repeat(1, 1, self.args.tile_factor)
        tiled_feature = tiled_feature.reshape(
            feature.size(0), feature.size(1) * self.args.tile_factor, feature.size(2)
        )
        return tiled_feature

    def output_size(self) -> int:
        return self.output_dim

    def forward(
        self, input: torch.Tensor, input_lengths: torch.Tensor
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        wavs = [wav[: input_lengths[i]] for i, wav in enumerate(input)]
        self.upstream.eval()
        with torch.no_grad():
            feats = self.upstream(wavs)
        feats = self.featurizer(wavs, feats)

        if self.args.tile_factor != 1:
            feats = self._tile_representations(feats)

        input_feats = pad_list(feats, 0.0)
        feats_lens = torch.tensor([f.shape[0] for f in feats], dtype=torch.long)

        # Saving CUDA Memory
        del feats

        return input_feats, feats_lens

    def reload_pretrained_parameters(self):
        self.upstream.load_state_dict(self.pretrained_params)
        logging.info("Pretrained S3PRL frontend model parameters reloaded!")
