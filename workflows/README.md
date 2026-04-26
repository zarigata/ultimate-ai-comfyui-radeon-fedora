# Video Workflows

Workflow documentation for AI video generation with ComfyUI on AMD Radeon.

## Getting Started with AI Video
- 2 Low VRAM Video Workflow: Step-by-step for GPUs with 8-12GB
  - Recommended models
  - Recommended custom nodes
  - Workflow JSON reference (link to community workflows)
  - Settings tips (resolution, frame count, etc.)
- 3 High VRAM Video Workflow: For 16GB+ GPUs
  - Full quality settings
  - AnimateDiff workflow
  - Frame interpolation
  - Upscaling
- 4 Video Editing with FFmpeg: 
  - Basic commands: extract frames, combine frames to video, add audio, resize
  - ./run.sh edit helper
- 5 Workflow JSONs: Note that exact workflows are community-maintained. Links to:
  - ComfyUI Examples: https://comfyui.github.io/ComfyUI_examples/
  - ComfyUI Community workflows
  - AnimateDiff-Evolved examples
- 6 Performance Tips: 
  - Resolution vs VRAM tradeoffs
  - Batch size recommendations
  - xformers/memory optimization notes for AMD
