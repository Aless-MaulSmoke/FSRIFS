# MANUAL DE UTILIZAÇÃO PRÁTICA
**Upscale + Frame Generator (FSR + IFS)**

## REQUISITOS E DEPENDÊNCIAS DE HARDWARE
Para que a pipeline de pós-processamento funcione corretamente no seu computador, o seu sistema precisa cumprir as seguintes dependências físicas e de software:

* **Compatibilidade com API Vulkan (OBRIGATÓRIO):** A sua placa de vídeo precisa ter suporte nativo à tecnologia Vulkan. O shader autoral IFS roda os cálculos temporais diretamente no silício da GPU através dessa API. Funciona em placas de vídeo dedicadas (AMD RX, Nvidia GTX/RTX) e também em chips integrados (AMD Vega ou Intel HD Graphics mais recentes). Se a sua GPU não tiver suporte a Vulkan, o processo não iniciará.
* **Processador (CPU):** Qualquer processador básico de 4 ou 6 núcleos antigos (como a linha AMD FX ou Intel Core de gerações passadas) é perfeitamente capaz de rodar a pipeline. O uso médio de CPU fica na casa dos 45%, mantendo o Windows totalmente livre de travamentos ou superaquecimento durante a renderização.
* **Memória de Vídeo (VRAM):** Placas de vídeo legadas com 2GB de VRAM dão conta do recado tranquilamente se o usuário operar com inteligência. Recomenda-se fechar navegadores de internet, Discord e jogos em segundo plano antes de iniciar o processo em resoluções altas (como 2K ou 4K) para evitar estouro de memória da placa.
* **Sistema Operacional:** Windows 10 ou Windows 11 de 64-bits com o terminal PowerShell ativo e liberado para execução de scripts.

---

## INSTALAÇÃO
Inicie baixando o arquivo zip com o conteúdo. Descompacte onde desejar. Você verá toda a estrutura de pastas do FSRIFS.

O processo todo se desenrola dentro de um prompt do PowerShell (conhecer comandos básicos de navegação nas pastas via comando é importante).

Vamos iniciar abrindo o PowerShell; não precisa ser em modo administrador, pois o script não vai precisar de privilégios para rodar.

Se for a sua primeira vez rodando scripts no computador, digite o comando abaixo para permitir a execução de scripts:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

Responda **SIM** para aplicar a política de execução.

Agora estamos prontos para rodar os processos, e você pode fazer isso de duas maneiras:
* **Drag & Drop:** Arrastando e soltando o seu arquivo de vídeo sobre um bot automatizado que realiza para você todo o processo (voltado para usuários sem conhecimento em prompt).
* **Prompt do PowerShell:** Executando via prompt os scripts para rodar a pipeline (necessário conhecimento de prompt).

---

## Drag & Drop
Esta é a forma mais fácil de executar a pipeline. Usando o explorador de arquivos, acesse a pasta onde descompactou o FSRIFS. Você verá um arquivo chamado `DRAG_VIDEO_HERE.bat`. Agora abra outra janela de explorador de arquivos e vá até a pasta onde está o vídeo que você deseja processar. Arraste o seu vídeo e solte sobre o arquivo que mencionamos.

Você pode configurar o processo editando o arquivo `DRAG_CONFIG.txt`:

```ini
[DRAG_SETTINGS]
SCALE=1920x1080
SHARPNESS=5
FPS=60
QUALITY=med
VERBOSE=false
```

---

## PowerShell
Este é o método original para você processar seus vídeos. Precisamos acessar o local onde você descompactou o FSRIFS (por exemplo: `D:\FSRIFS`):

```powershell
cd "D:\FSRIFS"
```

Você estará assim na pasta da pipeline e poderá executar dois scripts:

### 1. process.ps1
*(Nosso script principal; com ele podemos fazer upscale e/ou gerar fps)*

O script atua de forma modular; você pode acessar esses módulos através de parâmetros na linha de comando. Vamos conhecê-los:

* `-file "nome_do_arquivo.mp4"`: O caminho completo do arquivo de vídeo que você deseja processar. Deve ser colocado entre aspas (e.g., `-file "C:\pasta\video.mp4"`).
* `-scale fator|resolução`: Dimensão final do vídeo. Se omitido, o upscale não acontece e o tamanho original é mantido. O valor pode ser informado nos formatos:
  * **Fator multiplicador** para o ganho de resolução. Use números decimais (e.g., o fator de dimensão de um vídeo de 720p para 1080p é `1.5`).
  * **Resolução literal** onde você pode informar, por exemplo: `"1920x1080"`.
* `-fps número`: A taxa de quadros desejada para a fluidez (e.g., `60`). Se omitido, a geração de quadros não acontece e os FPS originais são mantidos.
* `-quality "low|med|big"`: O perfil de peso, compressão e tamanho do arquivo final. Se você omitir este parâmetro, o sistema assumirá automaticamente o perfil equilibrado “med”. As opções disponíveis são:
  * **low:** Foco em economia drástica de espaço. Reduz o peso do arquivo final e alivia o uso de VRAM. Gera um arquivo final pequeno.
  * **med:** O ponto de equilíbrio ideal. Mantém a nitidez das bordas e a fidelidade visual sem estourar o HD. Gera um arquivo final de tamanho mediano.
  * **big:** Máxima fidelidade visual e alta taxa de bits, voltado para arquivamento ou upload em alta qualidade. Gera um arquivo final enorme.
* `-sharpness número`: Qualidade aplicada pelo FSR indo de `0` (máximo) até `10` (mínimo).
* `-v`: Modo verbose, onde informações detalhadas sobre o processo são listadas no terminal.

**Nota de Segurança:** O script exige que você use pelo menos o parâmetro `-scale` ou o `-fps`.

#### Exemplos:
* **Fazer APENAS o Upscale:** Digamos que de 720p para 1080p, com nitidez mediana; aplicamos uma escala de 1.5x e nitidez 5.
  ```powershell
  .\process.ps1 -file "C:\pasta\video.mp4" -scale 1.5 -sharpness 5
  ```

* **Fazer APENAS a Geração de Frames:** Digamos que seu vídeo original tem 30fps e você deseja 60fps.
  ```powershell
  .\process.ps1 -file "C:\pasta\video.mp4" -fps 60
  ```

* **Pipeline Completa:** Upscale 1080p + geração de frames 60 FPS + verificando um log detalhado no prompt.
  ```powershell
  .\process.ps1 -file "C:\pasta\video.mp4" -scale "1920x1080" -fps 60 -v
  ```

O script irá identificar a origem do seu arquivo e salva o resultado final **exatamente na mesma pasta do vídeo original**. O nome do novo arquivo é gerado de forma inteligente com sufixos baseados no que você escolheu fazer:
* **Se usou apenas o upscale:** `video_FSR_1080x720.mp4`
* **Se usou apenas os frames:** `video_60fps.mp4`
* **Se usou a pipeline completa:** `video_FSR_1080x720_60fps.mp4`

---

### 2. extract.ps1
*(Script para extrair alguns frames do vídeo processado para você poder avaliar se o resultado está bom)*

Você pode extrair todos os frames de X segundos iniciando em um determinado tempo do vídeo. É a ferramenta ideal para você avaliar visualmente a qualidade do resultado final, permitindo conferir frame por frame.

#### Parâmetros na linha de comando:
* `-file "arquivo"`: O caminho completo do arquivo de vídeo que você deseja processar. Deve ser colocado entre aspas (e.g., `-file "C:\pasta\video.mp4"`).
* `-time "hh:mm:ss"`: O ponto de início da extração no formato HH:MM:SS. Se não for preenchido, começará automaticamente aos 3 segundos (`00:00:03`).
* `-secs número`: Quantos segundos de vídeo você quer transformar em fotos. Se não for preenchido, extrairá apenas 1 segundo (se o vídeo estiver em 60fps, serão extraídos 60 frames).
* `-output "pasta destino"`: (Entre aspas duplas) Pasta onde salvar as fotos. Se não for preenchido, o script irá extrair os frames dentro da pasta `output` na raiz da FSRIFS.

---

## PROBLEMAS CONHECIDOS / LIMITAÇÕES TÉCNICAS

* **Borrão ou Suavização ao Pausar (Freeze Frame Artifacts):**
  * **Symptom:** Ao pausar o vídeo final durante cenas de movimentação rápida, a imagem pode parecer suave, borrada ou apresentar um efeito de "fantasma".
  * **Causa:** O player de vídeo congelou o relógio de reprodução exatamente em cima de um quadro intermediário (interpolated frame) gerado pela matemática temporal do shader IFS.
  * **Solução:** Não há o que corrigir. Esse comportamento é a mecânica necessária para garantir a ilusão de fluidez na geração de frames com o vídeo em movimento, sem exigir IA pesada ou hardware com Tensor Cores. É o preço que se paga para uma solução voltada a computadores de baixo custo (low-end PC).

---

## CRÉDITOS E SUPORTE TÉCNICO

* **Idealização, Autoria do Shader IFS (MIT) e Integração da Pipeline:** por Aless (MaulSmoke).
* **Tecnologias de Terceiros Utilizadas:** FFmpeg (GPL), libplacebo (LGPL), AMD FidelityFX FSR (MIT).
* **Canal Oficial do Projeto (YouTube): Assista aos tutoriais, showcase de performance: [YouTube (@toplayaless)](https://www.youtube.com/playlist?list=PLae7RZ7VAOWk)