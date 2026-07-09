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

# extrack width and height of original video
$wOriginal = [int]$video.width
$hOriginal = [int]$video.height
# extrack fps of original video
if ($video.avg_frame_rate -match "/") {
    $partesFps = $video.avg_frame_rate -split "/"
    if ([double]$partesFps[1] -gt 0) {
        $fpsOriginal = [int][math]::Round([double]$partesFps[0] / [double]$partesFps[1])
    } else {
        $fpsOriginal = 0
    }
} else {
    $fpsOriginal = [int][math]::Round([double]$video.avg_frame_rate)
}

# ==========================================================================
# SETUP VALIDATIONS
# ==========================================================================

# validation: file
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
# prepare validation: scale
$isScaleSame = $false
if ($scale) {
    $scaleClean = $scale.Replace(" ", "").ToUpper()
    if ($scaleClean -match "(\d+)X(\d+)") {
        # Força ambos os lados a serem inteiros puros para evitar erros de texto
        if ([int]$Matches[1] -eq [int]$wOriginal -and [int]$Matches[2] -eq [int]$hOriginal) { 
            $isScaleSame = $true 
        }
    } elseif ([double]($scaleClean.Replace(",", ".")) -eq 1.0) {
        $isScaleSame = $true
    }
}
# prepare validation: fps
$isFpsSame = $false
if ($PSBoundParameters.ContainsKey('fps') -and [int]$fps -eq [int]$fpsOriginal) {
    $isFpsSame = $true
}
#  validation: scale and fps
if ( (-not $scale -and -not $fps) -or 
     ($isScaleSame -and $isFpsSame) -or 
     ($isScaleSame -and -not $fps) -or 
     ($isFpsSame -and -not $scale) ) {
    Write-Warning "No modifications requested. The video already matches the specified resolution and/or FPS."
    exit
}
#  validation: qualityfps
if ($quality -notin @("LOW", "MED", "BIG")) {
    Write-Warning "quality needs only one of the valid options: low | med | big"
    exit
}
#  validation: sharpness
if ($PSBoundParameters.ContainsKey('sharpness') -and (-not $scale -or $isScaleSame)) {
    Write-Warning "The '-sharpness' parameter can only be used when spatial upscaling ('-scale') is active and changing the resolution."
    exit
}

# ==========================================================================
# SETUP PARAMETERS
# ==========================================================================

# Setup scale: resolution based on scale multiplier value mapping
if ($scale -and -not $isScaleSame) {
    # Padroniza a string removendo espaços e jogando para maiúsculo
    $scaleClean = $scale.Replace(" ", "").ToUpper()

    if ($scaleClean -match "(\d+)X(\d+)") {
        # Formato 1: Resolução literal ex: "1920x1080"
        $wTarget = [int]$Matches[1]
        $hTarget = [int]$Matches[2]
    }
    else {
        # Format 2: Traditional multiplier, e.g., "2" or "1.5"
        # Replaces comma with period if entered in the PT-BR format
        $numScale = [double]($scaleClean.Replace(",", "."))
        $wTarget = $wOriginal * $numScale
        $hTarget = $hOriginal * $numScale
    }

    # Force upper ceiling to correct inconsistencies from OBS or proportional calculation
    $widthOut  = [int]([math]::Ceiling($wTarget / 2) * 2)
    $heightOut = [int]([math]::Ceiling($hTarget / 2) * 2)
} else {
    $widthOut  = $wOriginal
    $heightOut = $hOriginal
	$scale     = $null
}

# Setup fps (Intercepts if the requested FPS matches the video's original FPS)
if ($isFpsSame) {
    $null = $PSBoundParameters.Remove('fps')
    $fps = $null
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
if ($scale -and -not $isScaleSame) {
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
    }
} else {
    # Se a escala for inexistente ou igual, o sharpness é totalmente anulado
    $sharpness = $null
}

# Mantém a conversão do caminho do shader para o libplacebo sempre ativa e segura
$shaderFFmpeg = $shader.Replace("\", "/").Replace(":", "\:")

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
if ($null -ne $sharpness -and $sharpness -ne 0 -and $sharpness -ne 5) {
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
