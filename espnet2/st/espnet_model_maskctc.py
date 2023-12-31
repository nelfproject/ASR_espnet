from contextlib import contextmanager
from distutils.version import LooseVersion
import logging
from typing import Dict
from typing import List
from typing import Optional
from typing import Tuple
from typing import Union

import torch
from typeguard import check_argument_types

from espnet.nets.e2e_asr_common import ErrorCalculator as ASRErrorCalculator
from espnet.nets.e2e_mt_common import ErrorCalculator as MTErrorCalculator
from espnet.nets.pytorch_backend.nets_utils import th_accuracy
from espnet.nets.pytorch_backend.transformer.add_sos_eos import add_sos_eos
from espnet.nets.pytorch_backend.transformer.label_smoothing_loss import (
    LabelSmoothingLoss,  # noqa: H301
)
from espnet2.asr.ctc import CTC
from espnet2.asr.decoder.mlm_decoder import MLMDecoder
from espnet2.asr.decoder.abs_decoder import AbsDecoder
from espnet2.asr.encoder.abs_encoder import AbsEncoder
from espnet2.asr.frontend.abs_frontend import AbsFrontend
from espnet2.asr.postencoder.abs_postencoder import AbsPostEncoder
from espnet2.asr.preencoder.abs_preencoder import AbsPreEncoder
from espnet2.asr.specaug.abs_specaug import AbsSpecAug
from espnet2.layers.abs_normalize import AbsNormalize
from espnet2.torch_utils.device_funcs import force_gatherable
from espnet2.train.abs_espnet_model import AbsESPnetModel
from espnet2.text.token_id_converter import TokenIDConverter

from espnet2.st.espnet_model import ESPnetSTModel

if LooseVersion(torch.__version__) >= LooseVersion("1.6.0"):
    from torch.cuda.amp import autocast
else:
    # Nothing to do if torch<1.6.0
    @contextmanager
    def autocast(enabled=True):
        yield


class ESPnetSTModelMaskCTC(ESPnetSTModel):
    """CTC-attention hybrid Encoder-Decoder model"""

    def __init__(
        self,
        vocab_size: int,
        token_list: Union[Tuple[str, ...], List[str]],
        frontend: Optional[AbsFrontend],
        specaug: Optional[AbsSpecAug],
        normalize: Optional[AbsNormalize],
        preencoder: Optional[AbsPreEncoder],
        encoder: AbsEncoder,
        postencoder: Optional[AbsPostEncoder],
        decoder: AbsDecoder,
        extra_asr_decoder: Optional[AbsDecoder],
        extra_mt_decoder: Optional[AbsDecoder],
        ctc: CTC,
        interctc_weight: float = 0.0,
        src_vocab_size: int = 0,
        src_token_list: Union[Tuple[str, ...], List[str]] = [],
        asr_weight: float = 0.0,
        mt_weight: float = 0.0,
        mtlalpha: float = 0.0,
        ignore_id: int = -1,
        lsm_weight_asr: float = 0.0,
        lsm_weight_mt: float = 0.0,
        length_normalized_loss: bool = False,
        report_cer: bool = True,
        report_wer: bool = True,
        report_bleu: bool = False,
        sym_space: str = "<space>",
        sym_blank: str = "<blank>",
        sym_mask: str = "<mask>",
        extract_feats_in_collect_stats: bool = True,
    ):
        assert check_argument_types()

        super().__init__(
            vocab_size=vocab_size,
            token_list=token_list,
            frontend=frontend,
            specaug=specaug,
            normalize=normalize,
            preencoder=preencoder,
            encoder=encoder,
            postencoder=postencoder,
            decoder=decoder,
            extra_asr_decoder=extra_asr_decoder,
            extra_mt_decoder=extra_mt_decoder,
            ctc=ctc,
            interctc_weight=interctc_weight,
            src_vocab_size=src_vocab_size,
            src_token_list=src_token_list,
            asr_weight=asr_weight,
            mt_weight=mt_weight,
            mtlalpha=mtlalpha,
            ignore_id=ignore_id,
            lsm_weight_asr=lsm_weight_asr,
            lsm_weight_mt=lsm_weight_mt,
            length_normalized_loss=length_normalized_loss,
            report_cer=report_cer,
            report_wer=report_wer,
            report_bleu=report_bleu,
            sym_space=sym_space,
            sym_blank=sym_blank,
            extract_feats_in_collect_stats=extract_feats_in_collect_stats,
        )

        # Add <mask> and override inherited fields
        token_list.append(sym_mask)
        vocab_size += 1
        self.vocab_size = vocab_size
        self.mask_token = vocab_size - 1
        self.token_list = token_list.copy()

        src_token_list.append(sym_mask)
        src_vocab_size += 1
        self.src_vocab_size = src_vocab_size
        self.src_mask_token = src_vocab_size - 1
        self.src_token_list = src_token_list.copy()

    def forward(
        self,
        speech: torch.Tensor,
        speech_lengths: torch.Tensor,
        text: torch.Tensor,
        text_lengths: torch.Tensor,
        src_text: Optional[torch.Tensor],
        src_text_lengths: Optional[torch.Tensor],
    ) -> Tuple[torch.Tensor, Dict[str, torch.Tensor], torch.Tensor]:
        """Frontend + Encoder + Decoder + Calc loss

        Args:
            speech: (Batch, Length, ...)
            speech_lengths: (Batch,)
            text: (Batch, Length)
            text_lengths: (Batch,)
            src_text: (Batch, length)
            src_text_lengths: (Batch,)
        """
        assert text_lengths.dim() == 1, text_lengths.shape
        # Check that batch_size is unified
        assert (
            speech.shape[0]
            == speech_lengths.shape[0]
            == text.shape[0]
            == text_lengths.shape[0]
        ), (speech.shape, speech_lengths.shape, text.shape, text_lengths.shape)

        # additional checks with valid src_text
        if src_text is not None:
            assert src_text_lengths.dim() == 1, src_text_lengths.shape
            assert text.shape[0] == src_text.shape[0] == src_text_lengths.shape[0], (
                text.shape,
                src_text.shape,
                src_text_lengths.shape,
            )

        batch_size = speech.shape[0]

        # for data-parallel
        text = text[:, : text_lengths.max()]
        if src_text is not None:
            src_text = src_text[:, : src_text_lengths.max()]

        # mask1 = (src_text.sum(-1) > 0).sum().cpu().detach().item()
        # mask2 = (text.sum(-1) > 0).sum().cpu().detach().item()
        # print('\n')
        # print(mask1)
        # print(mask2)

        # 1. Encoder
        encoder_out, encoder_out_lens = self.encode(speech, speech_lengths)

        # 2a. Attention-decoder branch (ST)
        #loss_st_att, acc_st_att, bleu_st_att = self._calc_mt_att_loss(
        #    encoder_out, encoder_out_lens, text, text_lengths, st=True
        #)
        loss_st_att, acc_st_att, bleu_st_att = 0.0, None, None

        # 2b. CTC branch
        if self.asr_weight > 0:
            assert src_text is not None, "missing source text for asr sub-task of ST"

        if self.asr_weight > 0 and self.mtlalpha > 0:
            mask = src_text.sum(-1) > 0
            loss_asr_ctc, cer_asr_ctc = self._calc_ctc_loss(
                encoder_out, encoder_out_lens, src_text, src_text_lengths, mask
            )
        else:
            loss_asr_ctc, cer_asr_ctc = 0.0, None

        # 2c. Attention-decoder branch (extra ASR)
        if self.asr_weight > 0 and self.mtlalpha < 1.0:
            mask = src_text.sum(-1) > 0
            (
                loss_asr_att,
                acc_asr_att,
                cer_asr_att,
                wer_asr_att,
            ) = self._calc_asr_att_loss(
                encoder_out, encoder_out_lens, src_text, src_text_lengths, mask
            )
        else:
            loss_asr_att, acc_asr_att, cer_asr_att, wer_asr_att = 0.0, None, None, None

        # 2d. Attention-decoder branch (extra MT)
        if self.mt_weight > 0:
            mask = text.sum(-1) > 0
            loss_mt_att, acc_mt_att, _ = self._calc_mt_att_loss(
                encoder_out, encoder_out_lens, text, text_lengths, mask, st=False
            )
        else:
            loss_mt_att, acc_mt_att = 0.0, None

        # 3. Loss computation
        asr_ctc_weight = self.mtlalpha
        loss_st = loss_st_att
        if asr_ctc_weight == 1.0:
            loss_asr = loss_asr_ctc
        elif asr_ctc_weight == 0.0:
            loss_asr = loss_asr_att
        else:
            loss_asr = (
                asr_ctc_weight * loss_asr_ctc + (1 - asr_ctc_weight) * loss_asr_att
            )
        loss_mt = loss_mt_att  # self.mt_weight * loss_mt_att
        loss = (
            (1 - self.asr_weight - self.mt_weight) * loss_st
            + self.asr_weight * loss_asr
            + self.mt_weight * loss_mt
        )

        stats = dict(
            loss=loss.detach() if type(loss) is not float else loss,
            loss_asr=loss_asr.detach() if type(loss_asr) is not float else loss_asr,
            loss_mt=loss_mt.detach() if type(loss_mt) is not float else loss_mt,
            loss_st=loss_st.detach() if type(loss_st) is not float else loss_st,
            acc_asr=acc_asr_att,
            acc_mt=acc_mt_att,
            acc=acc_st_att,
            cer_ctc=cer_asr_ctc,
            cer=cer_asr_att,
            wer=wer_asr_att,
            bleu=bleu_st_att,
        )

        # force_gatherable: to-device and to-tensor if scalar for DataParallel
        loss, stats, weight = force_gatherable((loss, stats, batch_size),
                                               loss.device if type(loss) is not float else speech.device)
        return loss, stats, weight

    def collect_feats(
        self,
        speech: torch.Tensor,
        speech_lengths: torch.Tensor,
        text: torch.Tensor,
        text_lengths: torch.Tensor,
        src_text: Optional[torch.Tensor],
        src_text_lengths: Optional[torch.Tensor],
    ) -> Dict[str, torch.Tensor]:
        if self.extract_feats_in_collect_stats:
            feats, feats_lengths = self._extract_feats(speech, speech_lengths)
        else:
            # Generate dummy stats if extract_feats_in_collect_stats is False
            logging.warning(
                "Generating dummy stats for feats and feats_lengths, "
                "because encoder_conf.extract_feats_in_collect_stats is "
                f"{self.extract_feats_in_collect_stats}"
            )
            feats, feats_lengths = speech, speech_lengths
        return {"feats": feats, "feats_lengths": feats_lengths}

    def encode(
        self, speech: torch.Tensor, speech_lengths: torch.Tensor
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        """Frontend + Encoder. Note that this method is used by st_inference.py

        Args:
            speech: (Batch, Length, ...)
            speech_lengths: (Batch, )
        """
        with autocast(False):
            # 1. Extract feats
            feats, feats_lengths = self._extract_feats(speech, speech_lengths)

            # 2. Data augmentation
            if self.specaug is not None and self.training:
                feats, feats_lengths = self.specaug(feats, feats_lengths)

            # 3. Normalization for feature: e.g. Global-CMVN, Utterance-CMVN
            if self.normalize is not None:
                feats, feats_lengths = self.normalize(feats, feats_lengths)

        # Pre-encoder, e.g. used for raw input data
        if self.preencoder is not None:
            feats, feats_lengths = self.preencoder(feats, feats_lengths)

        # 4. Forward encoder
        # feats: (Batch, Length, Dim)
        # -> encoder_out: (Batch, Length2, Dim2)
        encoder_out, encoder_out_lens, _ = self.encoder(feats, feats_lengths)

        # Post-encoder, e.g. NLU
        if self.postencoder is not None:
            encoder_out, encoder_out_lens = self.postencoder(
                encoder_out, encoder_out_lens
            )

        assert encoder_out.size(0) == speech.size(0), (
            encoder_out.size(),
            speech.size(0),
        )
        assert encoder_out.size(1) <= encoder_out_lens.max(), (
            encoder_out.size(),
            encoder_out_lens.max(),
        )

        return encoder_out, encoder_out_lens

    def _extract_feats(
        self, speech: torch.Tensor, speech_lengths: torch.Tensor
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        assert speech_lengths.dim() == 1, speech_lengths.shape

        # for data-parallel
        speech = speech[:, : speech_lengths.max()]

        if self.frontend is not None:
            # Frontend
            #  e.g. STFT and Feature extract
            #       data_loader may send time-domain signal in this case
            # speech (Batch, NSamples) -> feats: (Batch, NFrames, Dim)
            feats, feats_lengths = self.frontend(speech, speech_lengths)
        else:
            # No frontend and no feature extract
            feats, feats_lengths = speech, speech_lengths
        return feats, feats_lengths

    def _calc_mt_att_loss(
        self,
        encoder_out: torch.Tensor,
        encoder_out_lens: torch.Tensor,
        ys_pad: torch.Tensor,
        ys_pad_lens: torch.Tensor,
        mask: torch.Tensor,
        st: bool = True,
    ):
        if mask.sum() == 0:
            return 0.0, None, None

        ys_in_pad, ys_out_pad = add_sos_eos(ys_pad, self.sos, self.eos, self.ignore_id)
        ys_in_lens = ys_pad_lens + 1

        # 1. Forward decoder
        if st:
            decoder_out, _ = self.decoder(
                encoder_out, encoder_out_lens, ys_in_pad, ys_in_lens
            )
        else:
            decoder_out, _ = self.extra_mt_decoder(
                encoder_out, encoder_out_lens, ys_in_pad, ys_in_lens
            )

        decoder_out_m = decoder_out[mask]
        ys_out_pad_m = ys_out_pad[mask]
        ys_pad_m = ys_pad[mask]

        # 2. Compute attention loss
        loss_att = self.criterion_st(decoder_out_m, ys_out_pad_m)
        acc_att = th_accuracy(
            decoder_out_m.view(-1, self.vocab_size),
            ys_out_pad_m,
            ignore_label=self.ignore_id,
        )

        # Compute cer/wer using attention-decoder
        if self.training or self.mt_error_calculator is None:
            bleu_att = None
        else:
            ys_hat = decoder_out_m.argmax(dim=-1)
            bleu_att = self.mt_error_calculator(ys_hat.cpu(), ys_pad_m.cpu())

        return loss_att, acc_att, bleu_att

    def _calc_asr_att_loss(
        self,
        encoder_out: torch.Tensor,
        encoder_out_lens: torch.Tensor,
        ys_pad: torch.Tensor,
        ys_pad_lens: torch.Tensor,
        mask: torch.Tensor,
    ):
        if mask.sum() == 0:
            return 0.0, None, None, None

        ys_in_pad, ys_out_pad = add_sos_eos(ys_pad, self.sos, self.eos, self.ignore_id)
        ys_in_lens = ys_pad_lens + 1

        # 1. Forward decoder
        decoder_out, _ = self.decoder(
            encoder_out, encoder_out_lens, ys_in_pad, ys_in_lens
        )

        decoder_out_m = decoder_out[mask]
        ys_out_pad_m = ys_out_pad[mask]
        ys_pad_m = ys_pad[mask]

        # 2. Compute attention loss
        loss_att = self.criterion_asr(decoder_out_m, ys_out_pad_m)
        acc_att = th_accuracy(
            decoder_out_m.view(-1, self.vocab_size),
            ys_out_pad_m,
            ignore_label=self.ignore_id,
        )

        # Compute cer/wer using attention-decoder
        if self.training or self.asr_error_calculator is None:
            cer_att, wer_att = None, None
        else:
            ys_hat = decoder_out_m.argmax(dim=-1)
            cer_att, wer_att = self.asr_error_calculator(ys_hat.cpu(), ys_pad_m.cpu())

        return loss_att, acc_att, cer_att, wer_att

    def _calc_ctc_loss(
        self,
        encoder_out: torch.Tensor,
        encoder_out_lens: torch.Tensor,
        ys_pad: torch.Tensor,
        ys_pad_lens: torch.Tensor,
        mask: torch.Tensor,
    ):
        # Mask
        if mask.sum() == 0:
            return 0.0, None

        encoder_out_m = encoder_out[mask]
        encoder_out_lens_m = encoder_out_lens[mask]
        ys_pad_m = ys_pad[mask]
        ys_pad_lens_m = ys_pad_lens[mask]

        # Calc CTC loss
        loss_ctc = self.ctc(encoder_out_m, encoder_out_lens_m, ys_pad_m, ys_pad_lens_m)

        # Calc CER using CTC
        cer_ctc = None
        if not self.training and self.asr_error_calculator is not None:
            ys_hat = self.ctc.argmax(encoder_out_m).data
            cer_ctc = self.asr_error_calculator(ys_hat.cpu(), ys_pad_m.cpu(), is_ctc=True)
        return loss_ctc, cer_ctc
