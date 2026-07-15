# ==========================================================================
# ------------------------------
#
#   FSRIFS Core Processing Engine (v1.1.0)
#   Automated pipeline for video upscaling (FSR) and frame interpolation (IFS).
#
#   process.ps1 (Powershell script)
#   07/15/2026
#   by Aless (MaulSmoke)
#
#   A modular script designed to orchestrate lightweight, hardware-accelerated 
#   Vulkan workflows for video post-processing without heavy AI dependencies.
#
#  -file "string"
#   The absolute or relative path to the single input video file.
#
#  -folder "string"
#   The path to a target directory containing multiple videos for batch processing.
#
#  -scale "string"
#   The target resolution (e.g., "1920x1080") or decimal multiplier factor (e.g., 1.5).
#
#  -fps number
#   The target frame rate for the final output video smoothness (e.g., 60).
#
#  -interpolate "string"
#   The frame mixing algorithm: "none", "oversample", "mitchell_clamp", or "linear".
#
#  -quality "string"
#   The compression profile and file size weight: "LOW", "MED", or "BIG".
#
#  -sharpness number
#   The edge crispness applied by FSR, ranging from 0 to 10 (Default is 5).
#
#  -v
#   Switch flag to toggle detailed real-time rendering logs (Verbose mode).
#
#  -shutdown
#   Switch flag to trigger a safe 30-second system power-off countdown after execution.
#
#  -DRAG_CONFIG
#   Switch flag to automatically read and load parameters directly from DRAG_CONFIG.txt.
# ------------------------------

param(
    [string]$file,
    [string]$folder,
    [string]$scale,
    [int]$fps,
	[string]$interpolate = "none",
    [string]$quality = "MED",
	[System.Nullable[int]]$sharpness,
	[switch]$v,
	[switch]$shutdown,
	[switch]$DRAG_CONFIG
)

# ==========================================================================
# 1. FUNÇÃO DE CONFIGURAÇÃO E TRATAMENTO DE PARÂMETROS
# ==========================================================================
function Get-ScriptConfig {
    param (
        [System.Collections.IDictionary]$BoundParameters
    )

    $config = [PSCustomObject]@{
        file        = if ($file) { $file } else { $BoundParameters['file'] }
        folder      = if ($folder) { $folder } else { $BoundParameters['folder'] }
        scale       = if ($scale) { [string]$scale } else { [string]$BoundParameters['scale'] } 
        fps         = if ($fps) { $fps } else { $BoundParameters['fps'] }
		interpolate = if ($interpolate) { $interpolate.ToLower() } else { "none" }
        quality     = if ($quality) { $quality.ToUpper() } else { "MED" }
        sharpness   = if ($sharpness) { $sharpness } else { $BoundParameters['sharpness'] }
        v           = $v -eq $true -or $BoundParameters['v'] -eq $true
        shutdown    = $shutdown -eq $true -or $BoundParameters['shutdown'] -eq $true
        drag_config = $DRAG_CONFIG -eq $true -or $BoundParameters['DRAG_CONFIG'] -eq $true
		widthOut    = $null
        heightOut   = $null
    }

    # Se o switch DRAG_CONFIG for usado, carrega as configurações do arquivo TXT
    if ($config.drag_config) {
        $configFile = "$PSScriptRoot\DRAG_CONFIG.txt"
        if (Test-Path $configFile) {
            Get-Content $configFile | Where-Object { $_ -match '=' -and $_ -notmatch '^[#;]' } | ForEach-Object {
                $chave, $valor = $_ -split '=', 2
                $chave = $chave.Trim().ToUpper()
                $valor = $valor.Trim()

                switch ($chave) {
                    "QUALITY"     { $config.quality = $valor.ToUpper() }
                    "FPS"         { $config.fps = $valor }
					"INTERPOLATE" { $config.interpolate = $valor.ToLower() }
					"SCALE"       { $config.scale = [string]$valor }
                    "SHARPNESS"   { $config.sharpness = [int]$valor }
                    "VERBOSE"     { if ($valor -eq "true") { $config.v = $true } }
                    "SHUTDOWN"    { if ($valor -eq "true") { $config.shutdown = $true } }
                }
            }
        } else {
            Write-Warning "Falha ao abrir o arquivo DRAG_CONFIG.txt."
            exit
        }
    }

    # Validações globais básicas de presença de entrada
    if ($config.file -and $config.folder) {
        Write-Warning "Ambiguity Error: Use ONLY '-file' OR '-folder', not both at the same time."
        exit
    }
    if (-not $config.file -and -not $config.folder) {
        Write-Warning "No input specified. Use '-file' for a single video or '-folder' for batch processing."
        exit
    }
    if ($config.quality.ToUpper() -notin @("LOW", "MED", "BIG")) {
        Write-Warning "The 'quality' parameter only accepts one of these valid options: LOW | MED | BIG"
        exit
    }

	$interpolacoesValidas = @("none", "oversample", "mitchell_clamp", "linear")
	if ($config.interpolate -notin $interpolacoesValidas) {
        Write-Warning "The 'interpolate' parameter only accepts one of these valid options: none | oversample | mitchell_clamp | linear"
        exit
	}

    return $config

}

# ==========================================================================
# 2. FUNÇÃO DE INICIALIZAÇÃO DO AMBIENTE E SHADER (GLOBAL)
# ==========================================================================
function Initialize-GlobalPipeline {
    param (
        [PSCustomObject]$Config
    )

    # Define os caminhos das ferramentas e estruturas do ambiente
    $pipeline = [PSCustomObject]@{
        ffmpeg       = "$PSScriptRoot\ffmpeg\bin\ffmpeg.exe"
        ffprobe      = "$PSScriptRoot\ffmpeg\bin\ffprobe.exe"
        logpath      = "$PSScriptRoot\log"
        shader       = "$PSScriptRoot\shaders\fsr.glsl"
        shaderFFmpeg = ""
		gpuName      = ""
        qp_i         = 0
        qp_p         = 0
        verboseArgs  = @()
		interpolate  = $Config.interpolate
    }

	# Faz a consulta de hardware apenas uma vez (Garante velocidade)
	$pipeline.gpuName = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
	$gpuVendor = $pipeline.gpuName.ToUpper()

	# Define o codec correto e os perfis de qualidade CRF universais
	$crfProfiles = @{ "LOW" = 26; "MED" = 22; "BIG" = 18 }
	$qualidadeAlvo = $Config.quality.ToUpper()
	$pipeline.qp_i = $crfProfiles[$qualidadeAlvo] # Reutilizando a variável qp_i para guardar o CRF

	if ($gpuVendor -match "AMD" -or $gpuVendor -match "RADEON") {
		$Global:SelectedCodec = "hevc_amf"
		$Global:CodecArgs = @("-rc", "cqp", "-qp_i", $pipeline.qp_i, "-qp_p", ($pipeline.qp_i + 3))
	} 
	elseif ($gpuVendor -match "NVIDIA" -or $gpuVendor -match "GEFORCE") {
		$Global:SelectedCodec = "hevc_nvenc"
		$Global:CodecArgs = @("-rc", "constqp", "-qp", $pipeline.qp_i)
	} 
	elseif ($gpuVendor -match "INTEL") {
		$Global:SelectedCodec = "hevc_qsv"
		$Global:CodecArgs = @("-global_quality", $pipeline.qp_i)
	} 
	else {
		# Contingência universal via processador (Super Leve)
		$Global:SelectedCodec = "libx265"
		$Global:CodecArgs = @("-crf", $pipeline.qp_i, "-preset", "ultrafast")
	}

    # Define argumentos verbose
    if ($Config.v) { $pipeline.verboseArgs = @("-v", "verbose") }

    # Aplicação GLOBAL da Nitidez (Sharpness) diretamente no arquivo de shader
    if ($Config.scale) {
        # Se omitido no CLI/TXT, assume o valor padrão 5 conforme o script original
        $sharpnessValor = if ($null -ne $Config.sharpness) { $Config.sharpness } else { 5 }
        $clampedUserSharpness = [math]::Max(0, [math]::Min(10, $sharpnessValor)) / 10.0
        $fsrSharpness = 2.0 * (1.0 - $clampedUserSharpness)

        if (Test-Path $pipeline.shader) {
            $linhasShader = Get-Content $pipeline.shader
            $novaLinhaSharpness = "#define SHARPNESS $($fsrSharpness.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture))"
            
            for ($i = 0; $i -lt $linhasShader.Count; $i++) {
                if ($linhasShader[$i] -like "#define SHARPNESS*") {
                    $linhasShader[$i] = $novaLinhaSharpness
                    break
                }
            }
            Set-Content $pipeline.shader -Value $linhasShader -Encoding UTF8
        }
    }

    # Prepara o caminho do shader formatado para o libplacebo
    $pipeline.shaderFFmpeg = $pipeline.shader.Replace("\", "/").Replace(":", "\:")
	
	# Cria a lista que vai guardar o histórico de todos os vídeos processados na sessão
	$Global:SessionHistory = @()

    return $pipeline
}

# ==========================================================================
# 3. FUNÇÃO DE CRIAÇÃO DO SPOOL DE PROCESSAMENTO (ARRAY)
# ==========================================================================
function Get-VideoQueue {
    param (
        [PSCustomObject]$Config
    )

    # Inicializa o array vazio que conterá todos os arquivos válidos
    $listaArquivos = @()
    
    # Definição das extensões de vídeo suportadas pelo seu pipeline original
    $extensoesSuportadas = @(".mp4", ".mkv")

    # CENÁRIO A: Processamento de Arquivo Único
    if ($Config.file) {
        # Resolve o caminho absoluto (caso o usuário tenha passado um caminho relativo)
        $caminhoAbsoluto = Resolve-Path -Path $Config.file -ErrorAction SilentlyContinue

        if (-not $caminhoAbsoluto -or -not (Test-Path $caminhoAbsoluto.Path)) {
            Write-Host "[ERRO CLÍTICO] O arquivo especificado não existe ou o caminho é inválido:`n -> $($Config.file)" -ForegroundColor Red
            exit
        }

        # Extrai a extensão do arquivo para validação
        $extensao = [System.IO.Path]::GetExtension($caminhoAbsoluto.Path).ToLower()
        if ($extensao -notin $extensoesSuportadas) {
            Write-Host "[ERRO] Extensão '$extensao' não suportada. O script aceita apenas: $($extensoesSuportadas -join ', ')." -ForegroundColor Yellow
            exit
        }

        # Adiciona o arquivo único ao array de forma uniforme
        $listaArquivos += $caminhoAbsoluto.Path
    }
    
    # CENÁRIO B: Processamento em Lote (Pasta)
    elseif ($Config.folder) {
        # Resolve e valida o caminho absoluto da pasta
        $pastaAbsoluta = Resolve-Path -Path $Config.folder -ErrorAction SilentlyContinue

        if (-not $pastaAbsoluta -or -not (Test-Path $pastaAbsoluta.Path -PathType Container)) {
            Write-Host "[ERRO CLÍTICO] A pasta especificada não existe ou não é um diretório válido:`n -> $($Config.folder)" -ForegroundColor Red
            exit
        }

        Write-Host "Varrendo a pasta em busca de vídeos válidos..." -ForegroundColor Cyan
        
        # Busca recursiva por arquivos que possuam as extensões permitidas
        $arquivosEncontrados = Get-ChildItem -Path $pastaAbsoluta.Path -File -Recurse | 
                               Where-Object { $_.Extension.ToLower() -in $extensoesSuportadas }

        foreach ($arquivo in $arquivosEncontrados) {
            $listaArquivos += $arquivo.FullName
        }

        # Se a pasta estiver vazia ou sem vídeos compatíveis, aborta antes de iniciar o loop
        if ($listaArquivos.Count -eq 0) {
            Write-Host "[AVISO] Nenhum arquivo de vídeo compatível ($($extensoesSuportadas -join ', ')) foi encontrado na pasta especificada." -ForegroundColor Yellow
            exit
        }

        Write-Host "Fila de processamento criada com sucesso! ($($listaArquivos.Count) arquivo(s) encontrado(s))." -ForegroundColor Green
    }

    # Retorna o array pronto (seja com 1 elemento ou com vários)
    return $listaArquivos
}

# ==========================================================================
# 4. CONFIGURAÇÃO DE METADADOS INDIVIDUAL E VALIDAÇÃO DE REDUNDÂNCIA
# ==========================================================================
function Get-VideoMetadataAndValidate {
param (
    [string]$VideoPath,
    [PSCustomObject]$Config,
    [PSCustomObject]$Pipeline
)

    # 1. Extração de Metadados via FFprobe (Adicionado r_frame_rate e duration)
    $ffprobeArgs = @(
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height,r_frame_rate:format=duration",
        "-of", "csv=p=0",
        $VideoPath
    )

    try {
        $probeOutput = & $Pipeline.ffprobe $ffprobeArgs 2>$null
        if ($null -eq $probeOutput -or $probeOutput.Trim() -eq "") {
            throw "Não foi possível ler as propriedades de vídeo."
        }

        # Trata o retorno do CSV
        $metadataParts = $probeOutput.Trim() -split ','
        $wOriginal   = [int]$metadataParts[0]
        $hOriginal   = [int]$metadataParts[1]
        
        # Trata a fração do FPS
        $fpsParts    = $metadataParts[2] -split '/'
        $fpsOriginal = [math]::Round(([double]$fpsParts[0] / [double]$fpsParts[1]), 2)
        
        # Extrai a duração em segundos (Sempre a última parte do output devido ao formato do FFprobe)
        $duracaoSegundos = [double]$metadataParts[-1]
    }
    catch {
        return [PSCustomObject]@{
            Success      = $false
            SkipVideo    = $true
            ErrorMessage = "Falha ao extrair metadados via FFprobe. Arquivo corrompido ou incompatível."
            NomeArquivo  = [System.IO.Path]::GetFileName($VideoPath)
        }
    }

    $nomeArquivo = [System.IO.Path]::GetFileName($VideoPath)
    $widthOut    = $wOriginal
    $heightOut   = $hOriginal
    $fpsOut      = $fpsOriginal

    if ($Config.scale) {
		# Converte para string para garantir que métodos de texto funcionem se o terminal passar número puro
		$scaleStr = [string]$Config.scale

		# Regex corrigida: Aceita inteiros ou decimais (com ponto/vírgula) e o 'x' opcional no final
		if ($scaleStr -match '^(\d+[\.,]?\d*)x?$') {
			# Limpa o 'x' se houver e padroniza o ponto decimal para o cálculo numérico [1.1]
			$fatorLimpo    = $Matches[1].Replace(',', '.')
			$multiplicador = [double]$fatorLimpo
			
			$widthOut      = [int]($wOriginal * $multiplicador)
			$heightOut     = [int]($hOriginal * $multiplicador)
		} elseif ($scaleStr -match '^\d+x\d+$') {
            $resParts  = $scaleStr -split 'x'
            $widthOut  = [int]$resParts[0]
            $heightOut = [int]$resParts[1]
        }
    }

    if ($Config.fps) {
        $fpsOut = [double]$Config.fps
    }

    # Validação de Redundância Individual
    $isResolutionRedundant = ($widthOut -eq $wOriginal -and $heightOut -eq $hOriginal)
    $isFpsRedundant        = ([math]::Abs($fpsOut - $fpsOriginal) -lt 0.01)

    if ($isResolutionRedundant -and $isFpsRedundant) {
        return [PSCustomObject]@{
            Success     = $true
            SkipVideo   = $true
            NomeArquivo = $nomeArquivo
            Reason      = "Resolução ($wOriginal`x$hOriginal) e FPS ($fpsOriginal) originais já são idênticos aos alvos solicitados."
        }
    }
	
    return [PSCustomObject]@{
        Success         = $true
        SkipVideo       = $false
        NomeArquivo     = $nomeArquivo
        wOriginal       = $wOriginal
        hOriginal       = $hOriginal
        fpsOriginal     = $fpsOriginal
        widthOut        = $widthOut
        heightOut       = $heightOut
        fpsOut          = $fpsOut
        duracaoSegundos = $duracaoSegundos 
		skipFSR         = $isResolutionRedundant
		skipIFS         = $isFpsRedundant
    }
}

# ==========================================================================
# 5. FUNÇÃO DE EXECUÇÃO DE SPOOL DE VIDEOS DA PIPELINE
# ==========================================================================
function Invoke-VideoPipeline {
    param (
        [string]$VideoPath,
        [PSCustomObject]$Config,
        [PSCustomObject]$Pipeline,
        [PSCustomObject]$Metadata
    )

    # Gerenciamento de Logs (Subpasta apenas se for lote)
    $nomeSemExtensao = [System.IO.Path]::GetFileNameWithoutExtension($VideoPath)
    $diretorioLogAlvo = ""

    if ($Config.folder) {
        $nomePastaOrigem = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($VideoPath))
        if ([string]::IsNullOrEmpty($nomePastaOrigem)) { $nomePastaOrigem = "Lote_Processado" }
        
        $subpastaLog = Join-Path -Path $Pipeline.logpath -ChildPath $nomePastaOrigem
        if (-not (Test-Path $subpastaLog)) {
            New-Item -ItemType Directory -Path $subpastaLog -Force | Out-Null
        }
        $diretorioLogAlvo = $subpastaLog
    } 
    else {
        if (-not (Test-Path $Pipeline.logpath)) {
            New-Item -ItemType Directory -Path $Pipeline.logpath -Force | Out-Null
        }
        $diretorioLogAlvo = $Pipeline.logpath
    }
	
    # Resgate de Variáveis Locais para bater com a lógica do seu bloco original
    $scale         = $Config.scale
    $fps           = $Config.fps
    $quality       = $Config.quality
    $sharpness     = $Config.sharpness
    $shaderFFmpeg  = $Pipeline.shaderFFmpeg
    $wOriginal     = $Metadata.wOriginal
    $hOriginal     = $Metadata.hOriginal
    $widthOut      = $Metadata.widthOut
    $heightOut     = $Metadata.heightOut

    # Montagem Rígida dos Seus Filtros e Sufixos Originais
    $vfFilters = @()
    $sufixo = "_QUALITY_$quality"
	
	# Validações finais
	if ($Metadata.skipIFS) { $pipeline.interpolate = "none" }

    # STATE 1: Dual Optimized Pipeline (Both parameters active - FSR and IFS)
    if (-not $Metadata.skipFSR -and -not $Metadata.skipIFS) {
		$vfFilters += "libplacebo=w=${widthOut}:h=${heightOut}:fps=${fps}:frame_mixer=$($pipeline.interpolate):custom_shader_path='${shaderFFmpeg}'"
		$sufixo += "_IFS_${fps}fps$($pipeline.interpolate.ToUpper())_FSR_${widthOut}x${heightOut}"
	}
    # STATE 2: Spatial Upscale Only (FSR parameter active, IFS inactive)
    elseif (-not $Metadata.skipFSR -and $Metadata.skipIFS) {
        $vfFilters += "libplacebo=w=${widthOut}:h=${heightOut}:custom_shader_path='${shaderFFmpeg}'"
        $sufixo += "_FSR_${widthOut}x${heightOut}"
    }
    # STATE 3: Temporal Frame Generation Only (IFS parameter active, FSR inactive)
    elseif ($Metadata.skipFSR -and -not $Metadata.skipIFS) {
        $vfFilters += "libplacebo=w=${wOriginal}:h=${hOriginal}:fps=${fps}:frame_mixer=$($pipeline.interpolate):custom_shader_path='${shaderFFmpeg}'"
		$sufixo += "_IFS_${fps}fps$($pipeline.interpolate.ToUpper())"
    }

    if ($null -ne $sharpness) {
        $sufixo += "_SHARPNESS_$sharpness"
    }

    # Converte o array de filtros em uma string separada por vírgulas para o FFmpeg
    $vfString = $vfFilters -join ','

    # Definição do Arquivo de Saída com o seu Sufixo Especial
    $pastaSaida = [System.IO.Path]::GetDirectoryName($VideoPath)
    $extensaoOriginal = [System.IO.Path]::GetExtension($VideoPath)
    $videoSaida = Join-Path -Path $pastaSaida -ChildPath "${nomeSemExtensao}${sufixo}${extensaoOriginal}"

    # Preparação das variáveis exatas da sua assinatura de comando
    $ffmpeg      = $Pipeline.ffmpeg
    $verboseArgs = if ($Pipeline.verboseArgs.Count -gt 0) { $Pipeline.verboseArgs } else { @() }
    $file        = $VideoPath
    $qp_i        = $Pipeline.qp_i
    $qp_p        = $Pipeline.qp_p
    $outFile     = $videoSaida
	
	# Inicia escrita do FFmpeg no arquivo de log 
	$logIndividual = Join-Path -Path $diretorioLogAlvo -ChildPath ([System.IO.Path]::ChangeExtension([System.IO.Path]::GetFileName($outFile), ".txt"))
	$ffmpegLogPath = $logIndividual.Replace('\', '/')
	$env:FFREPORT = "file='$ffmpegLogPath':level=32"

	$Resultado = [PSCustomObject]@{
		Success         = $false
		SkipVideo       = $false
		NomeArquivo     = $Metadata.NomeArquivo
		OutputFile      = $outFile
		LogPath         = $logIndividual
		TempoDecorrido  = [TimeSpan]::Zero
		DuracaoVideo    = $Metadata.duracaoSegundos
		widthOut        = $widthOut
		heightOut       = $heightOut
		fpsOut          = $Metadata.fpsOut
		Speed           = 0.0
		Bitrate         = "N/A"
		ErrorMessage    = $null
	}
			
    # Cronometragem do laço de processamento
    $cronometro = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # Executa o FFmpeg
		& $ffmpeg $verboseArgs -i "$file" `
			-vf "$vfString" `
			-fps_mode passthrough `
			-c:v $Global:SelectedCodec @Global:CodecArgs `
			-tag:v hvc1 `
			-c:a copy -y `
			"$outFile"	
			
		$cronometro.Stop()
		$Resultado.TempoDecorrido = $cronometro.Elapsed

		if (Test-Path $outFile) {
			# Sucesso: Ativa a flag e calcula as métricas direto no objeto base
            $Resultado.Success = $true
            
            # Velocidade em linha única: Duração / Segundos Decorridos
            if ($cronometro.Elapsed.TotalSeconds -gt 0 -and $Metadata.duracaoSegundos -gt 0) {
                $Resultado.Speed = $Metadata.duracaoSegundos / $cronometro.Elapsed.TotalSeconds
            }

            # Busca o Bitrate de forma direta varrendo as últimas linhas do Log
            if (Test-Path $logIndividual) {
                $linhasLog = Get-Content $logIndividual -Tail 15 2>$null
                foreach ($linha in $linhasLog) {
                    if ($linha -match 'bitrate\s*=\s*([\d\.]+)\s*kb') {
                        $Resultado.Bitrate = $Matches[1] 
                        break
                    }
                }
            }
        } else {
            throw "O arquivo final não foi gerado em disco."
        }
    } catch {
        if ($cronometro.IsRunning) { $cronometro.Stop() }
        $Resultado.Success      = $false
        $Resultado.TempoDecorrido = $cronometro.Elapsed
        $Resultado.ErrorMessage = "Erro durante a execução da chamada nativa do FFmpeg."
	} finally {
        # Limpa o escopo do ambiente para blindar o próximo arquivo do loop
        Remove-Item Env:\FFREPORT -ErrorAction SilentlyContinue
    }
	
    return $Resultado
	
}

# ==========================================================================
# 6. FUNÇÃO DE PROCESSAMENTO DE STATUS E MÉTRICAS
# ==========================================================================
function Show-VideoStatus {
    param (
        [PSCustomObject]$Result,
        [ref]$StatusAcumulado
    )

    $nomeArquivo = $Result.NomeArquivo

    # Se o arquivo foi pulado por redundância
    if ($Result.SkipVideo) {
        Write-Host "[PULADO]  $nomeArquivo -> $($Result.Reason)" -ForegroundColor Yellow
        $StatusAcumulado.Value.TotalPulados++
        return
    }

    # Se o arquivo falhou no FFmpeg ou FFprobe
    if (-not $Result.Success) {
        Write-Host "[FALHA]   $nomeArquivo -> $($Result.ErrorMessage)" -ForegroundColor Red
        Write-Host "          Verifique o log em: $($Result.LogPath)" -ForegroundColor DarkGray
        $StatusAcumulado.Value.TotalFalhas++
        return
    }
	
	# Acumula os dados globais para o relatório final
	if ($Result.TempoDecorrido -and $Result.TempoDecorrido.TotalSeconds -gt 0) {
		$StatusAcumulado.Value.TempoTotalSegundos += $Result.TempoDecorrido.TotalSeconds
	}

    # Inicializa variáveis para extração do Log original
    $tamanhoFinalStr = "N/A"
    $bitrateStr = "N/A"
    $tamanhoBytes = 0

    # Extração de Métricas do Log (Lógica original do seu script)
    if (Test-Path $Result.LogPath) {
        $conteudoLog = Get-Content $Result.LogPath -Tail 30 2>$null
        foreach ($linha in $conteudoLog) {
            # Regex robusta para capturar o bitrate do sumário consolidado (ex: bitrate=17791.5kbits/s)
            if ($linha -match 'bitrate\s*=\s*([\d\.]+)\s*kb') {
                $bitrateStr = "$($Matches[1]) kb/s"
            }
            # Se encontrar o sumário final de frames processados, confirma o tamanho físico em disco
            if ($linha -match 'Lsize=' -and (Test-Path $Result.OutputFile)) {
                $item = Get-Item $Result.OutputFile
                $tamanhoBytes = $item.Length
                $tamanhoFinalStr = "$([math]::Round($tamanhoBytes / 1MB, 2)) MB"
            }
        }
    }

    # Caso a leitura do log falhe em pegar o tamanho, tenta ler direto do disco como contingência
    if ($tamanhoFinalStr -eq "N/A" -and (Test-Path $Result.OutputFile)) {
        $tamanhoBytes = (Get-Item $Result.OutputFile).Length
        $tamanhoFinalStr = "$([math]::Round($tamanhoBytes / 1MB, 2)) MB"
    }

    # Formata o tempo de renderização (mm:ss)
    $tempoRender = "{0:d2}:{1:d2}" -f $Result.TempoDecorrido.Minutes, $Result.TempoDecorrido.Seconds

    # Cálculo da velocidade comparada ao tempo real do vídeo (Speed Factor)
    $speedFactor = "N/A"
    if ($Result.DuracaoVideo -gt 0 -and $Result.TempoDecorrido.TotalSeconds -gt 0) {
        $speed = [math]::Round($Result.DuracaoVideo / $Result.TempoDecorrido.TotalSeconds, 2)
        $speedFactor = "$($speed.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture))x"
    }

    # EXIBIÇÃO EM LINHA ÚNICA (Exatamente como planejado)
    Write-Host "[SUCESSO] " -NoNewline -ForegroundColor Green
    Write-Host "$nomeArquivo " -NoNewline -ForegroundColor White
    Write-Host "| Tempo: $tempoRender | Vel: $speedFactor | Tam: $tamanhoFinalStr | Bitrate: $bitrateStr" -ForegroundColor Gray

    # Acumula os dados globais para o relatório final
	$StatusAcumulado.Value.TotalSucesso++
	$StatusAcumulado.Value.TempoTotalSegundos += $Result.TempoDecorrido.TotalSeconds
	$StatusAcumulado.Value.TamanhoTotalBytes += $tamanhoBytes
	$StatusAcumulado.Value.DuracaoTotalVideos += $Result.DuracaoVideo

}

# ==========================================================================
# 7. RELATÓRIO FINAL E AUTOMAÇÃO DE DESLIGAMENTO
# ==========================================================================
function Out-GlobalSummary {
    param (
        [PSCustomObject]$StatusAcumulado,
        [boolean]$ShutdownAtivo,
		[PSCustomObject]$Pipeline
    )
	
	# Converte os tempos acumulados para um formato legível (hh:mm:ss)
    $tsRender = [TimeSpan]::FromSeconds($StatusAcumulado.TempoTotalSegundos)
    $tempoRenderTotal = "{0:d2}:{1:d2}:{2:d2}" -f [int]$tsRender.TotalHours, $tsRender.Minutes, $tsRender.Seconds

    $tsVideos = [TimeSpan]::FromSeconds($StatusAcumulado.DuracaoTotalVideos)
    $tempoVideoTotal = "{0:d2}:{1:d2}:{2:d2}" -f [int]$tsVideos.TotalHours, $tsVideos.Minutes, $tsVideos.Seconds

    $tamanhoTotalMB = [math]::Round($StatusAcumulado.TamanhoTotalBytes / 1MB, 2)
	
	# Renderiza o Banner de Estatísticas Consolidadas
    # Tenta obter dados do último processo global para o cabeçalho descritivo
	$InfoBanner = if ($Global:LastProcessResult) { $Global:LastProcessResult } else { $Global:SessionHistory[0] }

    # MODO INDIVIDUAL: Caso apenas 1 vídeo tenha rodado na fila
	if ($StatusAcumulado.TotalSucesso -eq 1 -and $Global:LastProcessResult) {
		$Result = $Global:LastProcessResult
		$velocidadeStr = if ($Result.Speed) { "$([math]::Round($Result.Speed, 2))x" } else { "1.00x" }
		$bitrateStr    = if ($Result.Bitrate) { "$($Result.Bitrate) kbits/s" } else { "N/A" }

		Write-Host "`n"
		Write-Host "====================================================================================" -ForegroundColor Cyan
		Write-Host "  Total Render Time : " -NoNewline; Write-Host "$tempoRenderTotal" -ForegroundColor Yellow
		Write-Host "  Processing Speed  : " -NoNewline; Write-Host "$velocidadeStr" -ForegroundColor Yellow
		Write-Host "  Final File Size   : " -NoNewline; Write-Host "$tamanhoTotalMB MB" -ForegroundColor Yellow
		Write-Host "  Video Bitrate     : " -NoNewline; Write-Host "$bitrateStr" -ForegroundColor Yellow
		Write-Host "  Session Log Saved : " -NoNewline; Write-Host "OK" -ForegroundColor Yellow

	} else {
        # MODO LOTE: Cabeçalhos com as novas colunas perfeitamente espaçadas
		Write-Host "`n"
		Write-Host "====================================================================================" -ForegroundColor Cyan
        Write-Host " STATUS    | VELOCIDADE | TEMPO    | ARQUIVO" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------------------------------" -ForegroundColor DarkGray

		if ($Global:SessionHistory) {
			foreach ($Item in $Global:SessionHistory) {
				# Trunca e formata o nome do arquivo dando o espaço ideal restante (45 caracteres)
				$nomeCurto = if ($Item.NomeArquivo.Length -gt 45) { $Item.NomeArquivo.Substring(0, 42) + "..." } else { $Item.NomeArquivo.PadRight(45) }
				
				if ($Item.Success -and -not $Item.SkipVideo) {
					$velStr   = if ($Item.Speed) { "$([math]::Round($Item.Speed, 1))x".PadRight(10) } else { "1.0x      " }
					# Formata o cronômetro individual do vídeo para hh:mm:ss
					$tempoStr = [string]::Format("{0:d2}:{1:d2}:{2:d2}", $Item.TempoDecorrido.Hours, $Item.TempoDecorrido.Minutes, $Item.TempoDecorrido.Seconds).PadRight(8)

					Write-Host " [SUCCESS]" -ForegroundColor Green -NoNewline; Write-Host " | $velStr | $tempoStr | $nomeCurto" -ForegroundColor White
				} elseif ($Item.SkipVideo) {
					# Preenchimento visual limpo para itens pulados/redundantes
					Write-Host " [SKIPPED]" -ForegroundColor Yellow -NoNewline; Write-Host " | ----       | --:--:-- | $nomeCurto" -ForegroundColor White
				} else {
					Write-Host " [FAILED] " -ForegroundColor Red -NoNewline; Write-Host " | ----       | --:--:-- | $nomeCurto" -ForegroundColor White
				}
			}
		} else {
            Write-Host " Nenhum histórico de lote encontrado no spool." -ForegroundColor Gray
        }

		Write-Host "------------------------------------------------------------------------------------" -ForegroundColor DarkGray
		Write-Host "  Videos Processados com Sucesso : " -NoNewline; Write-Host "$($StatusAcumulado.TotalSucesso)" -ForegroundColor Green
		Write-Host "  Videos Ignorados (Redundantes) : " -NoNewline; Write-Host "$($StatusAcumulado.TotalPulados)" -ForegroundColor Yellow
		Write-Host "  Videos com Falha de Processo   : " -NoNewline; Write-Host "$($StatusAcumulado.TotalFalhas)" -ForegroundColor Red
		Write-Host "------------------------------------------------------------------------------------" -ForegroundColor DarkGray
		Write-Host "  Duração Total de Vídeo Tratada : $tempoVideoTotal" -ForegroundColor White
		Write-Host "  Tempo Total de Renderização    : $tempoRenderTotal" -ForegroundColor White
		Write-Host "  Espaço Total Ocupado em Disco  : $tamanhoTotalMB MB" -ForegroundColor White
		
	}

	Write-Host "====================================================================================" -ForegroundColor Cyan
	Write-Host "  vCard (GPU): $($Pipeline.gpuName) [Codec: $Global:SelectedCodec] " -ForegroundColor Cyan
	Write-Host "------------------------------------------------------------------------------------" -ForegroundColor DarkGray
	Write-Host "                    __          _  __               _   _   ___                     " -ForegroundColor Red
	Write-Host "                   / _|___ _ __(_)/ _|___    __   _/ | / | / _ \                    " -ForegroundColor Red
	Write-Host "                  | |_/ __| '__| | |_/ __|   \ \ / / | | || | | |                   " -ForegroundColor Red
	Write-Host "                  |  _\__ \ |  | |  _\__ \    \ V /| |_| || |_| |                   " -ForegroundColor Red
	Write-Host "                  |_| |___/_|  |_|_| |___/     \_/ |_(_)_(_)___/                    " -ForegroundColor White
	Write-Host "                                                                                    " -ForegroundColor White
	Write-Host "            Author: Aless (MaulSmoke) | Community: YouTube (@toplayaless)           " -ForegroundColor Gray
	Write-Host "                                                                                    " -ForegroundColor Gray
	Write-Host "------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Quality: $($Config.quality.ToUpper())  Resolution: $($InfoBanner.widthOut)x$($InfoBanner.heightOut)  Sharpness: $($Config.sharpness)  FPS: $($InfoBanner.fpsOut)  Interp: $($Config.interpolate)" -ForegroundColor White
	Write-Host "====================================================================================" -ForegroundColor Cyan

    # Lógica de Desligamento Automático
    if ($ShutdownAtivo -and $StatusAcumulado.TotalSucesso -gt 0) {
        Write-Host "O parâmetro -shutdown está ativo. O sistema será desligado." -ForegroundColor Yellow
        Write-Host "Pressione ESC para CANCELAR ou ENTER para DESLIGAR IMEDIATAMENTE." -ForegroundColor White
        
        $segundosRestantes = 30
        while ($segundosRestantes -gt 0) {
            Write-Host "`rDesligando em $segundosRestantes segundos... " -NoNewline -ForegroundColor Red
            Start-Sleep -Seconds 1
            
            if ($Host.UI.RawUI.KeyAvailable) {
				$tecla = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
                if ($tecla.VirtualKeyCode -eq 27) { 
                    Write-Host "`n[CANCELADO] Desligamento automático interrompido pelo usuário." -ForegroundColor Green
                    return
                }
                if ($tecla.VirtualKeyCode -eq 13) { 
                    break
                }
            }
            $segundosRestantes--
        }
        
        Write-Host "`nIniciando desligamento do sistema..." -ForegroundColor Red
        Stop-Computer -Force
    }
}

# ==========================================================================
# BLOCO PRINCIPAL DE EXECUÇÃO
# ==========================================================================

# 1. Captura e unifica as configurações gerais (CLI ou TXT)
$Config = Get-ScriptConfig -BoundParameters $PSBoundParameters

# 2. Inicializa o ambiente global e shaders (Uma única vez)
$Pipeline = Initialize-GlobalPipeline -Config $Config

# 3. Cria a fila uniforme de processamento (Array de trabalho)
$FilaTrabalho = Get-VideoQueue -Config $Config

# 4. Inicializa o objeto acumulador para as Estatísticas Gerais
$StatusGeral = [PSCustomObject]@{
    TotalSucesso         = 0
    TotalPulados         = 0
    TotalFalhas          = 0
    TempoTotalSegundos   = 0.0
    TamanhoTotalBytes    = [long]0
    DuracaoTotalVideos   = 0.0
}

Write-Host "`nIniciando o processamento da fila..." -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray

# 5. O Loop de Processamento (Processa cada arquivo de forma isolada)
foreach ($VideoAtual in $FilaTrabalho) {
    
    # Passo A: Extração de Metadados e Validação de Redundância por Arquivo
    $Metadata = Get-VideoMetadataAndValidate -VideoPath $VideoAtual -Config $Config -Pipeline $Pipeline
    
    # Se o arquivo foi pulado por redundância ou falha no FFprobe
	if ($Metadata.SkipVideo) {
		$Global:SessionHistory += $Metadata
		Show-VideoStatus -Result $Metadata -StatusAcumulado ([ref]$StatusGeral)
		continue 
	}

    # Passo B: Execução da Pipeline do FFmpeg para o vídeo atual
	$Global:LastProcessResult = Invoke-VideoPipeline -VideoPath $VideoAtual -Config $Config -Pipeline $Pipeline -Metadata $Metadata
	$ResultadoProcesso = $Global:LastProcessResult
	$Global:SessionHistory += $Global:LastProcessResult
    
    # Passo C: Exibição de Conclusão em Linha Única e Acumulação de Métricas
    Show-VideoStatus -Result $ResultadoProcesso -StatusAcumulado ([ref]$StatusGeral)
}

# 6. Exibição da Estatística Geral de todos os arquivos e Gatilho de Desligamento
Out-GlobalSummary -StatusAcumulado $StatusGeral -ShutdownAtivo $Config.shutdown -Pipeline $Pipeline


