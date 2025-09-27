#!/bin/bash

# Video Processing Script using ffmpeg with hardware acceleration
# Options: Trim, Transcode, Convert format, GIF conversion, Instagram padding

# Function to validate and suggest output filename
validate_output_path() {
    local output_path="$1"
    local counter=1
    local base_path="${output_path%.*}"
    local extension="${output_path##*.}"
    
    while [ -f "$output_path" ]; do
        read -p "File '$output_path' already exists. Overwrite? (y/N): " overwrite
        if [[ $overwrite =~ ^[Yy]$ ]]; then
            break
        else
            output_path="${base_path}_${counter}.${extension}"
            echo "Suggested filename: $(basename "$output_path")"
            read -p "Use this filename? (y/N): " use_suggested
            if [[ $use_suggested =~ ^[Yy]$ ]]; then
                break
            else
                read -p "Enter new filename: " new_filename
                output_path="$(dirname "$output_path")/$new_filename"
            fi
        fi
        ((counter++))
    done
    echo "$output_path"
}

# Check for ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed or not in PATH"
    echo "Please install ffmpeg first: https://ffmpeg.org/download.html"
    exit 1
fi

echo "=== Video Processing Tool ==="
echo
echo "Choose an option:"
echo "1. Trim video (keep original quality)"
echo "2. Transcode video (change quality/codec)"
echo "3. Convert format only (no quality change)"
echo "4. Convert to GIF"
echo "5. Add black bars for Instagram (post/reel/story)"
echo

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        mode="trim"
        ;;
    2)
        mode="transcode"
        ;;
    3)
        mode="convert"
        ;;
    4)
        mode="gif"
        ;;
    5)
        mode="pad"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo
echo "=== $mode Mode ==="
echo

# Get input file with drag-and-drop support
echo "Enter input file path (you can drag and drop the file here):"
read -p "File: " input_file

# Remove quotes and handle spaces in paths
input_file=$(echo "$input_file" | sed "s/^['\"]//;s/['\"]$//")

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' does not exist!"
    exit 1
fi

# Check if it's a valid video/media file
if ! ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$input_file" 2>/dev/null | grep -q video; then
    echo "Warning: File may not contain video streams or may not be a valid media file"
    read -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Extract directory from input file path
input_dir=$(dirname "$input_file")

# Get video information
echo
echo "=== Video Information ==="
duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input_file" 2>/dev/null)
if [ -n "$duration" ]; then
    # Convert seconds to hh:mm:ss
    hours=$(echo "$duration" | awk '{print int($1/3600)}')
    minutes=$(echo "$duration" | awk '{print int(($1%3600)/60)}')
    seconds=$(echo "$duration" | awk '{print int($1%60)}')
    duration_formatted=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)
    echo "Duration: $duration_formatted"
else
    echo "Duration: Unable to detect"
fi

# Get resolution
resolution=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$input_file" 2>/dev/null)
if [ -n "$resolution" ]; then
    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)
    echo "Resolution: ${width}x${height}"
    # Common resolution names
    case "$height" in
        2160) echo "Quality: 4K (2160p)" ;;
        1440) echo "Quality: 1440p (2K)" ;;
        1080) echo "Quality: 1080p (Full HD)" ;;
        720) echo "Quality: 720p (HD)" ;;
        480) echo "Quality: 480p (SD)" ;;
        360) echo "Quality: 360p" ;;
        240) echo "Quality: 240p" ;;
        *) echo "Quality: ${height}p" ;;
    esac
else
    echo "Resolution: Unable to detect"
fi

# Get bitrate
bitrate=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$input_file" 2>/dev/null)
if [ -n "$bitrate" ] && [ "$bitrate" != "N/A" ]; then
    bitrate_kbps=$(echo "$bitrate" | awk '{print int($1/1000)}')
    echo "Video bitrate: ${bitrate_kbps} kbps"
else
    # Try to get overall bitrate if video bitrate isn't available
    overall_bitrate=$(ffprobe -v quiet -show_entries format=bit_rate -of csv=p=0 "$input_file" 2>/dev/null)
    if [ -n "$overall_bitrate" ] && [ "$overall_bitrate" != "N/A" ]; then
        overall_bitrate_kbps=$(echo "$overall_bitrate" | awk '{print int($1/1000)}')
        echo "Overall bitrate: ${overall_bitrate_kbps} kbps"
    else
        echo "Bitrate: Unable to detect"
    fi
fi

# Get file size
file_size=$(ls -lh "$input_file" | awk '{print $5}')
echo "File size: $file_size"

# Get frame rate
fps=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$input_file" 2>/dev/null)
if [ -n "$fps" ] && [ "$fps" != "N/A" ]; then
    # Convert fraction to decimal
    fps_decimal=$(echo "$fps" | awk -F'/' '{if($2) print $1/$2; else print $1}' | awk '{printf "%.2f", $1}')
    echo "Frame rate: ${fps_decimal} fps"
else
    echo "Frame rate: Unable to detect"
fi

echo

if [ "$mode" = "trim" ]; then
    # Get start time
    echo "Enter start time (format: hh:mm:ss or mm:ss or ss):"
    read -p "Start time: " start_time
    
    # Get end time
    echo "Enter end time (format: hh:mm:ss or mm:ss or ss):"
    read -p "End time: " end_time
    
    # Get output filename
    read -p "Enter output filename (with extension): " output_filename
    
    # Create full output path and validate
    output_path="$input_dir/$output_filename"
    output_path=$(validate_output_path "$output_path")
    
    # Display summary
    echo
    echo "=== Trim Summary ==="
    echo "Input file: $input_file"
    echo "Start time: $start_time"
    echo "End time: $end_time"
    echo "Output file: $output_path"
    echo
    
    # Confirm before proceeding
    read -p "Proceed with trimming? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Trimming video..."
        # Check for CUDA support, fallback to CPU if not available
        if ffmpeg -hwaccels 2>/dev/null | grep -q cuda; then
            ffmpeg -hwaccel cuda -ss "$start_time" -i "$input_file" -to "$end_time" -c copy "$output_path"
        else
            echo "Note: CUDA not available, using CPU processing"
            ffmpeg -ss "$start_time" -i "$input_file" -to "$end_time" -c copy "$output_path"
        fi
    else
        echo "Operation cancelled."
        exit 0
    fi

elif [ "$mode" = "transcode" ]; then
    # Get bitrate setting
    echo "Enter target video bitrate in kbps:"
    echo "Examples: 500 (low quality), 1000 (medium), 2000 (good), 3000+ (high quality)"
    read -p "Video bitrate (kbps): " bitrate
    
    # Validate bitrate is a number
    if ! [[ "$bitrate" =~ ^[0-9]+$ ]]; then
        echo "Error: Please enter a valid number for bitrate."
        exit 1
    fi
    
    # Get output filename
    read -p "Enter output filename (with extension): " output_filename
    
    # Create full output path and validate
    output_path="$input_dir/$output_filename"
    output_path=$(validate_output_path "$output_path")
    
    # Display summary
    echo
    echo "=== Transcode Summary ==="
    echo "Input file: $input_file"
    echo "Target bitrate: ${bitrate} kbps (constant bitrate)"
    echo "Output file: $output_path"
    echo
    
    # Confirm before proceeding
    read -p "Proceed with transcoding? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Transcoding video with constant bitrate..."
        # Check for NVIDIA GPU and CUDA support
        if ffmpeg -hwaccels 2>/dev/null | grep -q cuda && ffmpeg -encoders 2>/dev/null | grep -q h264_nvenc; then
            echo "Using NVIDIA GPU acceleration (h264_nvenc)"
            ffmpeg -hwaccel cuda -hwaccel_output_format cuda -i "$input_file" -c:v h264_nvenc -b:v "${bitrate}k" -minrate "${bitrate}k" -maxrate "${bitrate}k" -bufsize "$((bitrate * 2))k" -c:a aac "$output_path"
        else
            echo "Using CPU encoding (libx264)"
            ffmpeg -i "$input_file" -c:v libx264 -b:v "${bitrate}k" -minrate "${bitrate}k" -maxrate "${bitrate}k" -bufsize "$((bitrate * 2))k" -c:a aac "$output_path"
        fi
    else
        echo "Operation cancelled."
        exit 0
    fi

elif [ "$mode" = "convert" ]; then
    # Get output filename
    read -p "Enter output filename (with extension): " output_filename
    
    # Create full output path and validate
    output_path="$input_dir/$output_filename"
    output_path=$(validate_output_path "$output_path")
    
    # Display summary
    echo
    echo "=== Format Conversion Summary ==="
    echo "Input file: $input_file"
    echo "Output file: $output_path"
    echo "Note: This will copy streams without re-encoding (fast, no quality loss)"
    echo
    
    # Confirm before proceeding
    read -p "Proceed with format conversion? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Converting format..."
        ffmpeg -i "$input_file" -c copy "$output_path"
    else
        echo "Operation cancelled."
        exit 0
    fi

elif [ "$mode" = "gif" ]; then
    # Ask if they want to trim first
    echo "Do you want to convert the entire video or a specific time range?"
    echo "1. Entire video"
    echo "2. Specific time range (trim first)"
    read -p "Choice (1-2): " trim_choice
    
    start_time=""
    end_time=""
    duration_option=""
    
    if [ "$trim_choice" = "2" ]; then
        echo "Enter start time (format: hh:mm:ss or mm:ss or ss):"
        read -p "Start time: " start_time
        
        echo "Enter duration in seconds (how long the GIF should be):"
        read -p "Duration (seconds): " duration_seconds
        
        duration_option="-t $duration_seconds"
    fi
    
    # Get GIF settings
    echo
    echo "GIF Quality Settings:"
    echo "Width (0 = keep original width, or specify pixels like 480, 720, 1080):"
    read -p "Width: " gif_width
    
    if [ "$gif_width" = "0" ] || [ -z "$gif_width" ]; then
        gif_width=-1
        scale_filter="scale=-1:-1"
    else
        scale_filter="scale=${gif_width}:-1"
    fi
    
    echo "Frame rate (fps) - lower = smaller file size:"
    echo "Examples: 10 (smooth), 5 (medium), 2 (choppy but small)"
    read -p "Frame rate: " gif_fps
    
    # Validate fps
    if ! [[ "$gif_fps" =~ ^[0-9]+$ ]] || [ "$gif_fps" -lt 1 ] || [ "$gif_fps" -gt 60 ]; then
        echo "Invalid frame rate. Using default of 10 fps."
        gif_fps=10
    fi
    
    # Get output filename
    read -p "Enter output filename (with .gif extension): " output_filename
    
    # Ensure .gif extension
    if [[ "$output_filename" != *.gif ]]; then
        output_filename="${output_filename}.gif"
    fi
    
    # Create full output path and validate
    output_path="$input_dir/$output_filename"
    output_path=$(validate_output_path "$output_path")
    
    # Display summary
    echo
    echo "=== GIF Conversion Summary ==="
    echo "Input file: $input_file"
    if [ -n "$start_time" ]; then
        echo "Start time: $start_time"
        echo "Duration: ${duration_seconds} seconds"
    else
        echo "Range: Entire video"
    fi
    echo "Width: $([ "$gif_width" = "-1" ] && echo "Original" || echo "${gif_width}px")"
    echo "Frame rate: ${gif_fps} fps"
    echo "Output file: $output_path"
    echo "Note: This creates an optimized GIF with high quality palette"
    echo
    
    # Confirm before proceeding
    read -p "Proceed with GIF conversion? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Converting to GIF..."
        
        # Build ffmpeg command with proper GIF optimization
        cmd="ffmpeg"
        
        if [ -n "$start_time" ]; then
            cmd="$cmd -ss '$start_time'"
        fi
        
        cmd="$cmd -i '$input_file'"
        
        if [ -n "$duration_option" ]; then
            cmd="$cmd $duration_option"
        fi
        
        # Use high-quality GIF conversion with palette optimization
        cmd="$cmd -vf \"fps=${gif_fps},${scale_filter}:flags=lanczos,palettegen=stats_mode=diff\" -y /tmp/palette.png"
        
        # Execute palette generation
        eval $cmd
        
        if [ $? -eq 0 ]; then
            # Generate final GIF using the palette
            cmd="ffmpeg"
            
            if [ -n "$start_time" ]; then
                cmd="$cmd -ss '$start_time'"
            fi
            
            cmd="$cmd -i '$input_file' -i /tmp/palette.png"
            
            if [ -n "$duration_option" ]; then
                cmd="$cmd $duration_option"
            fi
            
            cmd="$cmd -lavfi \"fps=${gif_fps},${scale_filter}:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle\" '$output_path'"
            
            eval $cmd
            
            # Clean up temporary palette
            rm -f /tmp/palette.png
        else
            echo "Error generating palette for GIF conversion."
            exit 1
        fi
    else
        echo "Operation cancelled."
        exit 0
    fi

    elif [ "$mode" = "pad" ]; then
        echo
        echo "Instagram Padding Presets:"
        echo "1) Square (1080x1080)"
        echo "2) Portrait (1080x1350)"
        echo "3) Landscape (1080x566)"
        echo "4) Story/Reel (1080x1920)"
        echo "5) Custom size"
        read -p "Choose a preset (1-5): " preset_choice

        case "$preset_choice" in
            1)
                out_w=1080; out_h=1080
                ;;
            2)
                out_w=1080; out_h=1350
                ;;
            3)
                out_w=1080; out_h=566
                ;;
            4)
                out_w=1080; out_h=1920
                ;;
            5)
                read -p "Enter output width (pixels): " out_w
                read -p "Enter output height (pixels): " out_h
                # basic validation
                if ! [[ "$out_w" =~ ^[0-9]+$ ]] || ! [[ "$out_h" =~ ^[0-9]+$ ]]; then
                    echo "Invalid dimensions. Exiting."
                    exit 1
                fi
                ;;
            *)
                echo "Invalid choice. Exiting."
                exit 1
                ;;
        esac

        echo
        echo "Choose output type:"
        echo "1) Video (mp4, keep audio)"
        echo "2) GIF (no audio)"
        read -p "Choice (1-2): " out_type

        # Get output filename
        read -p "Enter output filename (with extension): " output_filename
        output_path="$input_dir/$output_filename"
        output_path=$(validate_output_path "$output_path")

        echo
        echo "=== Padding Summary ==="
        echo "Input file: $input_file"
        echo "Output resolution: ${out_w}x${out_h}"
        echo "Output file: $output_path"
        echo
        read -p "Proceed with padding? (y/N): " confirm

        if ! [[ $confirm =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 0
        fi

        # Build scale+pad filter: scale output while preserving aspect ratio then pad with black
        vf="scale=${out_w}:${out_h}:force_original_aspect_ratio=decrease,pad=${out_w}:${out_h}:(ow-iw)/2:(oh-ih)/2:black"

    if [ "$out_type" = "1" ]; then
        echo "Applying padding to video..."
        # Ensure compatible output with Instagram (h264 + aac)
        if [[ "$output_path" == *.mp4 ]]; then
            ffmpeg -i "$input_file" -vf "$vf" -c:v libx264 -c:a aac -movflags +faststart "$output_path"
        else
            ffmpeg -i "$input_file" -vf "$vf" -c:a copy "$output_path"
        fi
    else
        # GIF flow: ask for frame rate
        echo "GIF frame rate (fps) - lower = smaller file size:"
        echo "Examples: 15 (smooth), 10 (good), 5 (medium), 2 (small)"
        read -p "Frame rate: " gif_fps
        
        # Validate fps
        if ! [[ "$gif_fps" =~ ^[0-9]+$ ]] || [ "$gif_fps" -lt 1 ] || [ "$gif_fps" -gt 30 ]; then
            echo "Invalid frame rate. Using default of 10 fps."
            gif_fps=10
        fi
        
        # Ensure .gif extension
        if [[ "$output_filename" != *.gif ]]; then
            output_filename="${output_filename}.gif"
            output_path="$input_dir/$output_filename"
        fi
        
        echo "Converting padded GIF at ${gif_fps} fps..."
        tmp_palette="/tmp/palette_$$.png"

        # First generate palette from padded frames
        ffmpeg -i "$input_file" -vf "$vf,fps=${gif_fps},palettegen=stats_mode=diff" -y "$tmp_palette"
        if [ $? -ne 0 ]; then
            echo "Error generating GIF palette."
            rm -f "$tmp_palette"; exit 1
        fi

        # Then create GIF using the palette
        ffmpeg -i "$input_file" -i "$tmp_palette" -lavfi "$vf,fps=${gif_fps}[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" -y "$output_path"
        rc=$?
        rm -f "$tmp_palette"
        if [ $rc -ne 0 ]; then
            echo "Error creating GIF."; exit 1
        fi
    fi

fi

# Check if ffmpeg succeeded
if [ $? -eq 0 ]; then
    echo
    echo "✓ Operation completed successfully!"
    echo "Output saved to: $output_path"
    
    # Show output file info
    if [ -f "$output_path" ]; then
        output_size=$(ls -lh "$output_path" | awk '{print $5}')
        echo "Output file size: $output_size"
        
        # Show duration if it's a video/gif
        if [[ "$output_path" == *.mp4 ]] || [[ "$output_path" == *.gif ]] || [[ "$output_path" == *.mov ]]; then
            output_duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$output_path" 2>/dev/null)
            if [ -n "$output_duration" ]; then
                output_hours=$(echo "$output_duration" | awk '{print int($1/3600)}')
                output_minutes=$(echo "$output_duration" | awk '{print int(($1%3600)/60)}')
                output_seconds=$(echo "$output_duration" | awk '{print int($1%60)}')
                output_duration_formatted=$(printf "%02d:%02d:%02d" $output_hours $output_minutes $output_seconds)
                echo "Output duration: $output_duration_formatted"
            fi
        fi
    fi
else
    echo
    echo "✗ Error occurred during processing."
    echo "Check the input file and try again."
    exit 1
fi
