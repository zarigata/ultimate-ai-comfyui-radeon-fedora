```markdown
# AI Video Shot List Template

## Project: [Your Project Name]
## Date: [Date]
## Target Resolution: [e.g., 512x512, 768x512, 1024x576]
## FPS: [8, 12, 16, 24]

| Shot # | Description | Camera | Duration | Style | Models Needed | Notes |
|--------|-------------|--------|----------|-------|---------------|-------|
| 1 | [Scene description] | [Camera move] | [Seconds] | [Style] | [Model name] | [Notes] |
| 2 | | | | | | |

## Pre-Production Checklist
- [ ] Storyboard complete
- [ ] Reference images collected
- [ ] Models downloaded
- [ ] Test renders at low resolution
- [ ] Audio/music sourced

## Post-Production
- [ ] Assemble shots in sequence
- [ ] Add transitions
- [ ] Add audio/music
- [ ] Color grading
- [ ] Final export

## FFmpeg Commands

### Extract audio from video
ffmpeg -i input.mp4 -vn -acodec copy audio.aac

### Combine frames to video
ffmpeg -framerate 12 -i frame_%04d.png -c:v libx264 -pix_fmt yuv420p output.mp4

### Add audio to video
ffmpeg -i video.mp4 -i audio.aac -c copy output_with_audio.mp4

### Resize video
ffmpeg -i input.mp4 -vf scale=1280:720 output.mp4

### Concatenate videos
ffmpeg -f concat -safe 0 -i filelist.txt -c copy output.mp4
```
