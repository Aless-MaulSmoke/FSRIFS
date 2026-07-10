# FSRIFS (FSR + IFS) Upscale and Frame Generator for Low-End PCs

## 1. The Root of the Project (The Need)
Running a heavy game and still recording in high resolution is a task that requires a robust PC, and even then, those powerful machines struggle with this dual task. Therefore, the process between playing and recording is segmented. First, the game is recorded at a smooth resolution so that the PC gamer can use ultra graphics settings, including ray tracing. After recording, the final video is submitted to the upscaling process (sharp resolution increase) and sometimes to the frame generation process. Some heavy games can be recorded at 30 or 48 FPS and then new frames are artificially created. All of this using the best of what AI has to offer on truly robust computers.

These solutions largely depend on heavy AI processing, require powerful CPUs and GPUs with dedicated AI cores, and also demand high VRAM resources that go far beyond what low-end cards can supply.

You have a low-end PC? Mine is an AMD FX-6300 and a 4GB Radeon RX 550 GPU. With a PC like this, it is impossible to run the most popular upscale and frame generation solutions. And of course, we drastically need these solutions because often the maximum that is possible to record with quality is at 720p at 30FPS, a low quality by current video publication standards.

---

## 2. The Turning Point: Finally I can expand the resolution and frames!
The inspiration for the project arose from practical experience with the Lossless Scaling software in a real-time gaming environment. Observing that my weak PC could run the tool to expand the resolution with FSR and generate frames with LSFG to transform a 720p/30FPS gameplay into a fluid 1080p/60FPS experience without killing the hardware, the following question was raised:

If the principle works in a lightweight way in a real-time game, then could it be applied to a previously recorded 720p/30FPS video file to expand it to 1080p/60FPS or more?

---

## 3. A Truly Lightweight Upscale and Frame Generator is Born
To materialize the concept of lightweight video post-processing focused on legacy hardware, the power of consolidated open-source tools was combined with the development of a mathematical logic running directly on the GPU. The magic is divided into four fundamental pillars:

FFmpeg + Vulkan + AMD FidelityFX FSR 1.0 + IFS (Intersection Fluid Sharpen)

Despite being 4 technologies, all are merged into the same process that you easily activate via command in your PowerShell, applying the same idea to your video that Lossless Scaling applies to games running in real time.

* FFmpeg: It is the program that generates the videos.
* Vulkan: It is a dependency; if your video card supports this technology, you are saved.
* AMD FidelityFX: It is a shader that runs directly on your GPU, doing the upscale process without using AI.
* IFS (Intersection Fluid Sharpen): It is a shader of my authorship that was born to generate frames without AI in a super fast way using the minimum of GPU processing. The idea for the shader comes from vector programs in object intersection processes.

### 3.1. Hardware Requirements and Dependencies
For the post-processing pipeline to function correctly on your computer, your system must comply with the following physical and software dependencies:

* Processor (CPU): Any basic 4 or 6-core older processor (such as the AMD FX line or past generations of Intel Core processors) is perfectly capable of running the pipeline. In the development and testing of this pipeline, the following was used: AMD FX-6300 with 8GB RAM (2012 Architecture).
* Graphics Card (GPU): Your video card must natively support Vulkan technology. It works on dedicated graphics cards (AMD RX, Nvidia GTX/RTX) and also on integrated chips (AMD Vega or newer Intel HD Graphics). In the development and testing of this pipeline, the following was used: AMD Radeon RX 550 with 4GB VRAM (Released in 2017).

Even under these severe physical limitations of the test/development computer, the ecosystem was able to deliver processing rates of up to 2.0x (in reduced time) for outputs in 1080p/60FPS and total stability in 4K renderings.

---

## 4. Conclusion and Efficiency Verdict
The concept proves that intelligent software optimization can bypass severe physical hardware limitations, replacing heavy AI calculations with direct and cheap mathematical instructions for the GPU architecture. It is everything that Lossless Scaling offers, but in video post-processing.

IMPORTANT AVISO: Since the entire upscale process of this ecosystem is done via AMD FSR, the ideal is that the videos are strictly gameplays of games. The algorithm was developed to treat digital graphical elements, polygon edges, and the polishing of real rendering textures. Trying to use videos of real footage, such as movies or cell phone recordings, will break the logic of the process and may not bring the expected result.

If you also have a low-end PC, come be happy with me!

---

## 5. Credits and License Assignments
This ecosystem distributes a modular post-processing pipeline composed of open-source tools integrated with a proprietary logic. Below are detailed the copyrights and licenses of each component:

* Core Component (FFmpeg): Version N-125258-gdf94900c98-20260624. Applicable license: GNU Lesser General Public License (LGPL v2.1 or later) or GNU General Public License (GPL v2.0 or later).
* Rendering Library (libplacebo): Compilation natively integrated into the FFmpeg core binary above. Applicable license: GNU Lesser General Public License (LGPL v2.1 or later).
* Spatial Scaling Algorithm (FidelityFX FSR): Version v1.0.2. Developed by AMD (Advanced Micro Devices, Inc.). Applicable license: MIT License (Open-Source, permissive).
* Frame Generator Algorithm (Intersection Fluid Sharpen - IFS): Version v0.1. Developed by Aless (MaulSmoke). Applicable license: MIT License (Open-Source, permissive).

### CREDITS AND TECHNICAL SUPPORT
* Conception, Authorship of the IFS Shader (MIT) and Pipeline Integration: by Aless (MaulSmoke).
* Third-Party Technologies Used: FFmpeg (GPL), libplacebo (LGPL), AMD FidelityFX FSR (MIT).
* Official Project Channel:** Watch tutorials and performance showcases on:
[YouTube (@toplayaless)](https://www.youtube.com/playlist?list=PLae7RZ7VAOWk)

