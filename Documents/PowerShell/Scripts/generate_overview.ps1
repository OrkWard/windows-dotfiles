# generate_overview.ps1 (v2 - with compression)
#
# This script receives a video file path, generates a 4x4 grid of thumbnails,
# and saves it as a single compressed image in the same directory as the video.

# --- SCRIPT PARAMETERS ---
param(
    [Parameter(Mandatory=$true)]
    [string]$VideoPath
)

# --- USER CONFIGURATION ---
# Choose your output format: 'jpg' for small size, or 'png' for lossless quality.
$OutputImageFormat = 'jpg'

# JPEG quality setting (only used if format is 'jpg').
# A value between 2 and 5 is a good range for FFmpeg's -q:v flag.
# Lower value = Higher quality = Larger file size.
# 2 = Very High Quality
# 4 = Good Quality, Small Size (Recommended Default)
# 6 = Medium Quality, Very Small Size
$JpegQuality = 4

# Grid layout, e.g., 4 means a 4x4 grid.
$GridSize = 4
# ---------------------------

$TotalThumbs = $GridSize * $GridSize

# --- PRE-FLIGHT CHECKS ---
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue) -or -not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: 'ffmpeg' or 'ffprobe' not found." -ForegroundColor Red
    Write-Host "Please make sure FFmpeg is installed and its 'bin' directory is in your system's PATH."
    Read-Host "Press Enter to exit"
    exit 1
}
if (-not (Test-Path -Path $VideoPath -PathType Leaf)) {
    Write-Host "ERROR: The provided path is not a file or the file does not exist." -ForegroundColor Red
    Write-Host "Path: $VideoPath"
    Read-Host "Press Enter to exit"
    exit 1
}

# --- SETUP PATHS AND NAMES ---
$VideoFileInfo = Get-Item $VideoPath
$VideoDir = $VideoFileInfo.DirectoryName
$VideoBaseName = $VideoFileInfo.BaseName
$OutputImageName = "$($VideoBaseName)_overview.$($OutputImageFormat)"
$FinalOutputPath = Join-Path -Path $VideoDir -ChildPath $OutputImageName

Write-Host "=================================================" -ForegroundColor Green
Write-Host "Processing Video: $($VideoFileInfo.Name)"
Write-Host "Output Image:     $OutputImageName"
Write-Host "Output Format:    $OutputImageFormat"
if ($OutputImageFormat -eq 'jpg') {
    Write-Host "JPEG Quality:     $JpegQuality (Lower is better)"
}
Write-Host "================================================="

# --- SETUP TEMPORARY DIRECTORY ---
$TempDir = Join-Path -Path $PSScriptRoot -ChildPath "temp_thumbnails_$(Get-Random)"
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

try {
    # STEP 1: Get video duration
    Write-Host "[Step 1/4] Getting video duration..."
    $DurationString = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -i $VideoPath
    if (-not $DurationString) {
        throw "Could not get video duration. Please check if the video file is valid."
    }
    $DurationSeconds = [double]::Parse($DurationString, [System.Globalization.CultureInfo]::InvariantCulture)
    Write-Host "  -> Duration: $($DurationSeconds.ToString('F2')) seconds"

    # STEP 2: Generate individual thumbnails (always as PNG for intermediate quality)
    Write-Host "[Step 2/4] Generating $TotalThumbs individual thumbnails..."
    $Interval = $DurationSeconds / $TotalThumbs
    for ($i = 1; $i -le $TotalThumbs; $i++) {
        $Timestamp = $i * $Interval
        $ThumbName = "thumb_{0:D2}.png" -f $i
        $ThumbPath = Join-Path -Path $TempDir -ChildPath $ThumbName

        Write-Host "  -> Creating thumbnail $i of $TotalThumbs (at $($Timestamp.ToString('F2'))s)..."
        ffmpeg -hide_banner -loglevel error -ss $Timestamp -i $VideoPath -vframes 1 -q:v 2 -y $ThumbPath
    }

    # STEP 3: Stitch thumbnails into the final image with specified format and quality
    Write-Host "[Step 3/4] Assembling the final $($GridSize)x$($GridSize) image..."
    $InputPattern = Join-Path -Path $TempDir -ChildPath "thumb_%02d.png"

    # Construct the final ffmpeg command based on the chosen format
    $ffmpegCommand = "ffmpeg -hide_banner -loglevel error -i `"$InputPattern`" -filter_complex `"tile=${GridSize}x${GridSize}`""
    if ($OutputImageFormat -eq 'jpg') {
        $ffmpegCommand += " -q:v $JpegQuality"
    }
    $ffmpegCommand += " -y `"$FinalOutputPath`""

    # Execute the command
    Invoke-Expression $ffmpegCommand

    Write-Host "-------------------------------------------------" -ForegroundColor Green
    Write-Host "SUCCESS!"
    Write-Host "Overview image saved to: $FinalOutputPath"
    Write-Host "-------------------------------------------------"

}
catch {
    Write-Host "AN ERROR OCCURRED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    # STEP 4: Clean up temporary files
    Write-Host "[Step 4/4] Cleaning up temporary files..."
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}
