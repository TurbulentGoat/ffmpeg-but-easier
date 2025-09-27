# Video Processing Script (conv.sh)

A comprehensive bash script for video processing using ffmpeg with hardware acceleration support.

## Features

- **Trim Video**: Cut video segments while preserving original quality
- **Transcode Video**: Change video quality and codec with customisable bitrate
- **Format Conversion**: Convert between video formats without re-encoding
- **GIF Creation**: Convert videos to optimized GIFs with palette generation
- **Instagram Padding**: Add black bars to fit Instagram's aspect ratios

## Requirements

- ffmpeg installed and available in PATH
- Optional: CUDA support for hardware acceleration (NVIDIA GPUs)

## Usage

Run the script and follow the interactive prompts:

```bash
./conv.sh
```

The script will guide you through:
1. Selecting processing mode (1-5)
2. Choosing input file (supports drag-and-drop paths)
3. Configuring output settings
4. Confirming operation before execution

## Processing Modes

### 1. Trim Video
- Preserves original quality using stream copy
- Requires start and end times (hh:mm:ss format)
- Fast processing with no quality loss

### 2. Transcode Video
- Adjustable bitrate for quality control
- Hardware acceleration when available (h264_nvenc)
- Constant bitrate encoding for consistent quality

### 3. Format Conversion
- Fast format changes without re-encoding
- No quality loss, minimal processing time
- Supports all ffmpeg-compatible formats

### 4. GIF Conversion
- High-quality palette optimization
- Configurable frame rate and dimensions
- Two-pass encoding for better compression

### 5. Instagram Padding
- Preset aspect ratios for different Instagram formats
- Square (1080x1080), Portrait (1080x1350), Landscape (1080x566)
- Story/Reel (1080x1920) and custom dimensions
- Output as video (MP4) or GIF

## File Handling

- Automatic output filename validation
- Collision detection with rename suggestions
- Preserves input directory structure
- Comprehensive video information display

## Hardware Acceleration

The script automatically detects and uses:
- CUDA acceleration for compatible NVIDIA GPUs
- Fallback to CPU processing when hardware acceleration unavailable
- Optimized encoding profiles for different use cases
