# MODELS: VRAM-TIER AWARE MODEL GUIDE FOR ULTIMATE AI COMFY RADEON

This guide helps you pick models based on your GPU memory (VRAM) and intended use, especially for video workflows.

## VRAM Tiers explained
- 8 GB or less: best for tiny models and quick iterations, some quantized variants may fit.
- 12 GB: comfortable with mid-sized diffusion models and several LoRA/control variations.
- 16 GB: standard for many quality diffusion models and some video-oriented architectures.
- 24 GB+: for bigger models, high-res outputs, and complex video workflows.

## Model tiers
- low-vram: works on 8GB GPUs with careful optimizations and quantized weights.
- mid-vram: suitable for 12-16GB GPUs with a mix of standard and variant models.
- high-vram: for 16GB+ GPUs; best quality, longer prompts, and video pipelines.

## Models
| Model | Source | License | VRAM Needed | Auto-Download? | Folder |
|---|---|---|---|---|---|
| stable-diffusion-1-5 | Stability AI | MIT | 8-12 GB | Yes | models/stable-diffusion-1-5/ |
| stable-diffusion-2-1 | Stability AI | MIT | 12-16 GB | Yes | models/stable-diffusion-2-1/ |
| waifu-diffusion-2-0 | Akihabara Labs | Artistic CC-BY-4.0 | 8-12 GB | Yes | models/waifu-diffusion-2-0/ |
| redshift-v3 | LocalLabs | Apache-2.0 | 16-24 GB | Yes | models/redshift-v3/ |
| dreamlike-diffusion | Dream-like/Community | CC-BY-4.0 | ~24 GB | Yes | models/dreamlike-diffusion/ |
| realism-distilled-1.0 | Distilled AI | MIT | 12-16 GB | Yes | models/realism-distilled-1.0/ |

> Note: Always ensure you have rights to use the models you download. See MODELS.md later for licensing notes and manual download steps for gated models.

## Manual download instructions
1) Create an account with the model provider if required.
2) Generate an access token if needed and download the weights (e.g., .ckpt, .safetensors).
3) Place downloaded weights into the corresponding folder, e.g., models/stable-diffusion-1-5/
4) Restart ComfyUI so it detects the new weights.

## Model recommendations for video workflows
- For lower VRAM GPUs: use lower-precision variants and LoRA adapters to speed up generation.
- For higher end GPUs (>16GB): combine stable diffusion models with video-specific models and upscalers for better results.
- Use model ensembles and sequential frame processing to maintain consistency across frames.

## Adding custom models
- Put custom models under the appropriate folder inside models/.
- Ensure the model files are named clearly and documented in an accompanying README inside the folder.
- Update any model lists or UI hints if your UI layout relies on manual config.

## Important note
Only download models you legally own or have rights to use. Respect licenses and usage terms.
