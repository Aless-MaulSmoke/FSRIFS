param(
    [string]$file,
    [string]$scale,
    [int]$fps,
	[switch]$v,
    [string]$quality = "MED",
	[int]$sharpness
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ==========================================================================
# SETUP PIPELINE
# ==========================================================================
$ffmpeg  = ".\ffmpeg\bin\ffmpeg.exe"
$ffprobe = ".\ffmpeg\bin\ffprobe.exe"

# Single merged shader file containing both FSR and IFS code blocks
$shader = ".\shaders\fsr_ifs.glsl"

# Replaces backslashes with forward slashes (format accepted by libplacebo)
$shaderFFmpeg = $shader.Replace("\", "/").Replace(":", "\:")

# Metadata extraction of the source input video file
$probeJson = & $ffprobe -v quiet -print_format json -show_streams -show_format "$file" | ConvertFrom-Json
$video     = $probeJson.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1

# Extract structural integers to prevent string truncation during syntax parsing
$wOriginal = [int]$video.width
$hOriginal = [int]$video.height

# ==========================================================================
# SETUP VALIDATIONS
# ==========================================================================

# Validação estruturada do arquivo de entrada
if (-not $file) {
    Write-Warning "No file information. Use the '-file' parameter to process the video."
    exit
} else {
    if (-not (Test-Path -Path $file -PathType Leaf)) {
        Write-Warning "The specified file does not exist: '$file'"
        exit
    }
    $AllowedExtensions = @(".mp4", ".mkv")
    $FileExtension = [System.IO.Path]::GetExtension($file).ToLower()

    if ($FileExtension -notin $AllowedExtensions) {
        Write-Warning "The file '$FileExtension' is not a supported video format. Valid extensions: $($AllowedExtensions -join ', ')"
        exit
    }
}
if (-not $scale -and -not $fps) {
    Write-Warning "No modifications requested. Use the '-scale' and/or '-fps' parameters to process the video."
    exit
}
if ($quality -notin @("LOW", "MED", "BIG")) {
    Write-Warning "quality needs only one of the valid options: low | med | big"
    exit
}
if (-not $scale -and $PSBoundParameters.ContainsKey('sharpness')) {
    Write-Warning "The '-sharpness' parameter can only be used when spatial upscaling ('-scale') is active."
    exit
}

# ==========================================================================
# SETUP PARAMETERS
# ==========================================================================

# Setup scale: resolution based on scale multiplier value mapping
if ($scale) {
    # Padroniza a string removendo espaços e jogando para maiúsculo
    $scaleClean = $scale.Replace(" ", "").ToUpper()

    if ($scaleClean -match "(\d+)X(\d+)") {
        # Formato 1: Resolução literal ex: "1920x1080"
        $wTarget = [int]$Matches[1]
        $hTarget = [int]$Matches[2]
    }
    else {
        # Formato 2: Multiplicador tradicional ex: "2" ou "1.5"
        # Substitui vírgula por ponto caso digitado no padrão PT-BR
        $numScale = [double]($scaleClean.Replace(",", "."))
        $wTarget = $wOriginal * $numScale
        $hTarget = $hOriginal * $numScale
    }

    # Força teto par superior para corrigir inconsistências do OBS ou do cálculo proporcional
    $widthOut  = [int]([math]::Ceiling($wTarget / 2) * 2)
    $heightOut = [int]([math]::Ceiling($hTarget / 2) * 2)
} else {
    $widthOut  = $wOriginal
    $heightOut = $hOriginal
}

# Setup quality: Retrieves values ​​based on the user's choice.
$quality = $quality.ToUpper()
$cqpProfiles = @{
    "LOW" = @(24, 27)
    "MED" = @(19, 22)
    "BIG" = @(15, 18)
}
$qp_i = $cqpProfiles[$quality][0]
$qp_p = $cqpProfiles[$quality][1]

# Setup verbose: output string based on user switch input
if ($v) {
    $verboseArgs = @("-v", "verbose")
} else {
    $verboseArgs = @()
}

# Set up sharpness: (Direct and robust string replacement): 0.0 (maximum) to 2.0 (minimum)
if (-not $sharpness) {
    $sharpness = 5
}
$clampedUserSharpness = [math]::Max(0, [math]::Min(10, $sharpness)) / 10.0
$fsrSharpness = 2.0 * (1.0 - $clampedUserSharpness)
if (Test-Path $shader) {
    # Reads the file as an array of independent lines
    $linhasShader = Get-Content $shader
 	# Injects the new line formatted with an invariant decimal point
	$novaLinhaSharpness = "#define SHARPNESS $($fsrSharpness.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture))"
    # Finds any line starting with '#define SHARPNESS' and replaces it entirely
    for ($i = 0; $i -lt $linhasShader.Count; $i++) {
        if ($linhasShader[$i] -like "#define SHARPNESS*") {
            $linhasShader[$i] = $novaLinhaSharpness
            break # Found and modified; the loop can stop.
        }
    }
    # Saves the array back to the file while maintaining clean encoding
    Set-Content $shader -Value $linhasShader -Encoding UTF8
	# Replaces backslashes with forward slashes (format accepted by libplacebo)
	$shaderFFmpeg = $shader.Replace("\", "/").Replace(":", "\:")
}

# ==========================================================================
# FILTER PIPELINE ASSEMBLY CONFIGURATION - THREE ISOLATED LOGICAL STATES
# ==========================================================================
$vfFilters = @()
$sufixo = "_QUALITY_$quality"

# STATE 1: Dual Optimized Pipeline (Both parameters active - Temporal libplacebo then Hardware sr_amf)
if ($scale -and $fps) {
    # 1. Native low-res temporal frame generation using the merged shader file
    $vfFilters += "libplacebo=w=${wOriginal}:h=${hOriginal}:fps=${fps}:frame_mixer=linear:custom_shader_path='${shaderFFmpeg}'"
    # 2. Native hardware-accelerated AMD FSR upscale block to achieve maximum execution speed
    $vfFilters += "sr_amf=w=${widthOut}:h=${heightOut}"
    $sufixo += "_IFS_${fps}fps_FSR_${widthOut}x${heightOut}"
}
# STATE 2: Spatial Upscale Only (Scale parameter active, FPS inactive)
# Uses hardware sr_amf directly for optimized standalone upscaling performance
elseif ($scale -and -not $fps) {
    $vfFilters += "libplacebo=w=${widthOut}:h=${heightOut}:custom_shader_path='${shaderFFmpeg}'"
    $sufixo += "_FSR_${widthOut}x${heightOut}"
}
# STATE 3: Temporal Frame Generation Only (FPS parameter active, Scale inactive)
elseif ($fps -and -not $scale) {
    $vfFilters += "libplacebo=w=${wOriginal}:h=${hOriginal}:fps=${fps}:frame_mixer=linear:custom_shader_path='${shaderFFmpeg}'"
    $sufixo += "_IFS_${fps}fps"
}

# add sharness information 
if ($sharpness -ne 5) {
	$sufixo += "_SHARPNESS_$sharpness"
}

# Bind individual processing stages with proper filter graph separator characters
$vfString = $vfFilters -join ","

$outDir  = [System.IO.Path]::GetDirectoryName($file)
$outName = [System.IO.Path]::GetFileNameWithoutExtension($file)

if (-not $outDir) { $outDir = "." }
$outFile = Join-Path $outDir "${outName}${sufixo}.mp4"

Write-Host "============================================================"
Write-Host " RUNNING UNIFIED MANAGEMENT SCRIPT VIA VULKAN & AMF PIPELINE"
Write-Host "============================================================"

# Execution pipeline binding passthrough timings alongside hardware accelerated AMF encoding
& $ffmpeg $verboseArgs -i "$file" `
    -vf "$vfString" `
    -fps_mode passthrough `
    -c:v hevc_amf -rc cqp -qp_i $qp_i -qp_p $qp_p `
    -tag:v hvc1 `
    -c:a copy -y `
    "$outFile"

if ($LASTEXITCODE -eq 0) {
    Write-Host "============================================================"
    Write-Host " [SUCCESS] Pipeline execution finished successfully!"
    Write-Host " Output file generated: $outFile"
    Write-Host "============================================================"
} else {
    Write-Host "============================================================"
    Write-Host " [ERROR] The FFmpeg processing pipeline failed."
    Write-Host "============================================================"
}
