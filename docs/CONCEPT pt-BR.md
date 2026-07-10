# FSRIFS (FSR + IFS) Upscale e Frame Generator para PCs Fracos

## 1. A Raiz do Projeto (A Necessidade)
Rodar um jogo pesado e ainda gravar em alta resolução é uma tarefa que exige um PC robusto, e mesmo assim esses parrudões sofrem para essa tarefa dupla. Então o processo entre jogar e gravar é segmentado. Primeiro o jogo é gravado em uma resolução tranquila para que o PC gamer possa usar configuração gráfica no ultra com direito a ray tracing. Depois de gravado, o vídeo final é submetido ao processo de upscaling (aumento nítido de resolução) e às vezes ao processo de geração de frames. Alguns jogos pesados podem ser gravados em 30 ou 48 FPS e depois novos frames são criados artificialmente. Tudo isso usando o melhor do que a IA tem a nos oferecer em computadores realmente robustos.

Essas soluções em grande parte dependem de processamentos pesados com IA, exigem CPU e GPU poderosas com núcleos dedicados a IA e ainda exigem altos recursos de VRAM que vão muito além do que plaquinhas low-end conseguem suprir.

Você tem um low-end PC? O meu é um AMD FX-6300 e GPU Radeon RX 550 de 4GB. Com um PC como esse é impossível poder rodar as soluções mais conhecidas de upscale e geração de frames. E claro, precisamos demais dessas soluções porque muitas vezes o máximo que é possível gravar com qualidade é em 720p a 30FPS, qualidade essa baixa para os padrões atuais de publicação de vídeos.

---

## 2. A Virada de Chave: Finalmente posso ampliar a resolução e os frames!
A inspiração para o projeto surgiu da experiência prática com o software Lossless Scaling no ambiente de jogo em tempo real. Ao observar que meu PC fraco conseguia rodar a ferramenta para ampliar a resolução com FSR e gerar frames com LSFG para transformar uma jogatina de 720p/30FPS em uma experiência fluida de 1080p/60FPS sem matar o hardware, gerou-se o seguinte questionamento:

Se o princípio funciona de forma leve em um jogo em tempo real, então ele poderia ser aplicado em um arquivo de vídeo 720p/30FPS anteriormente gravado para ampliar a 1080p/60FPS ou mais?

---

## 3. Nasce um Upscale e Frame Generator verdadeiramente leve
Para materializar o conceito de pós-processamento de vídeo leve e focada em hardware legado, uniu-se o poder de ferramentas open-source consolidadas ao desenvolvimento de uma lógica matemática rodando diretamente na GPU. A magia divide-se em quatro pilares fundamentais:

FFmpeg + Vulkan + AMD FidelityFX FSR 1.0 + IFS (Intersection Fluid Sharpen)

Apesar de serem 4 tecnologias, todas estão fundidas no mesmo processo que você activa facilmente via comando no seu PowerShell, aplicando no seu vídeo a mesma ideia que o Lossless Scaling aplica em jogos rodando em tempo real.

* FFmpeg: É o programa que gera os vídeos.
* Vulkan: É dependência; se sua placa de vídeo suporta essa tecnologia, você está salvo.
* AMD FidelityFX: É um shader que roda diretamente na sua GPU fazendo o processo de upscale sem usar IA.
* IFS (Intersection Fluid Sharpen): É um shader de minha autoria que nasceu para gerar frames sem IA de forma super veloz usando o mínimo de processamento da GPU. A ideia para o shader vem dos programas de vetores em processos de interseção de objetos.

### 3.1. Requisitos e Dependências de Hardware
Para que a pipeline de pós-processamento funcione corretamente no seu computador, o seu sistema precisa cumprir as seguintes dependências físicas e de software:

* Processador (CPU): Qualquer processador básico de 4 ou 6 núcleos antigos (como a linha AMD FX ou Intel Core de gerações passadas) é perfeitamente capaz de rodar a pipeline. No desenvolvimento e testes dessa pipeline foi usado: AMD FX-6300 com 8GB RAM (Arquitetura de 2012).
* Placa de Vídeo (GPU): A sua placa de vídeo obrigatoriamente precisa ter suporte nativo à tecnologia Vulkan. Funciona em placas de vídeo dedicadas (AMD RX, Nvidia GTX/RTX) e também em chips integrados (AMD Vega ou Intel HD Graphics mais recentes). No desenvolvimento e testes dessa pipeline foi usado: AMD Radeon RX 550 com 4GB VRAM (Lançada em 2017).

Mesmo sob essas limitações físicas severas do computador de teste/desenvolvimento, o ecossistema foi capaz de entregar taxas de processamento de até 2.0x (em tempo reduzido) para saídas em 1080p/60FPS e estabilidade total em renderizações 4K.

---

## 4. Conclusão e Veredito da Eficiência
O conceito prova que a otimização de software inteligente consegue contornar limitações físicas severas de hardware, substituindo cálculos pesados de IA por instruções matemáticas diretas e baratas para a arquitetura da GPU. É tudo que o Lossless Scaling oferece, porém em pós-processamento de vídeo.

AVISO IMPORTANTE: Como todo o processo de upscale deste ecossistema é feito via AMD FSR, o ideal é que os vídeos sejam estritamente de gameplays de jogos. O algoritmo foi desenvolvido para tratar elementos gráficos digitais, bordas de polígonos e polimento de texturas de renderização real. Tentar usar vídeos de filmagens reais, como filmes ou gravações de celular, vai quebrar a lógica do processo e poderá não trazer o resultado esperado.

Se você também tem um low-end PC, vem ser feliz comigo!

---

## 5. Créditos e Atribuições de Licença
Este ecossistema distribui uma pipeline de pós-processamento modular composta por ferramentas de código aberto integradas a uma lógica proprietária. Abaixo estão detalhados os direitos autorais e as licenças de cada componente:

* Componente Core (FFmpeg): Versão N-125258-gdf94900c98-20260624. Licença aplicável: GNU Lesser General Public License (LGPL v2.1 ou posterior) ou GNU General Public License (GPL v2.0 ou posterior).
* Biblioteca de Renderização (libplacebo): Compilação integrada nativamente no binário FFmpeg core acima. Licença aplicável: GNU Lesser General Public License (LGPL v2.1 ou posterior).
* Algoritmo de Escala Espacial (FidelityFX FSR): Versão v1.0.2. Desenvolvido por AMD (Advanced Micro Devices, Inc.). Licença aplicável: Licença MIT (Open-Source, permissiva).
* Algoritmo de Gerador de Frames (Intersection Fluid Sharpen - IFS): Versão v0.1. Desenvolvido por Aless (MaulSmoke). Licença aplicável: Licença MIT (Open-Source, permissiva).

### CRÉDITOS E SUPORTE TÉCNICO
* Idealização, Autoria do Shader IFS (MIT) e Integração da Pipeline: por Aless (MaulSmoke).
* Tecnologias de Terceiros Utilizadas: FFmpeg (GPL), libplacebo (LGPL), AMD FidelityFX FSR (MIT).
* Canal Oficial do Projeto (YouTube): Assista aos tutoriais, showcase de performance: 
[YouTube (@toplayaless)](https://www.youtube.com/playlist?list=PLae7RZ7VAOWk)