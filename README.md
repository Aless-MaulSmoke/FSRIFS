# FSRIFS: Video Upscale & Frame Generator for Weak PCs

An ultra-lightweight video post-processing pipeline tailored for legacy hardware, combining open-source tools with pure mathematical logic executed directly on the GPU silicon via Vulkan.

## Built for Low-End Hardware
Validated and optimized under severe hardware limitations:
* **CPU:** Tested on AMD FX-6300 (2012 architecture) with only ~45% usage.
* **GPU:** Tested on AMD Radeon RX 550 4GB (Works on any 2GB+ VRAM card with native Vulkan support).

## How It Works
The project uses a custom PowerShell pipeline that integrates **FFmpeg**, **libplacebo**, **AMD FidelityFX FSR 1.0** (spatial upscale), and the **IFS (Intersection Fluid Sharpen)** temporal shader authored by Aless (MaulSmoke) to generate frames without relying on heavy AI or Tensor Cores.

## Complete Documentation & Manual
Inside the `docs` folder, you will find the **Practical User Manual** containing:
* Full system dependencies and configuration rules.
* **Drag & Drop Method:** How to use the automated `DRAG_VIDEO_HERE.bat` and edit `DRAG_CONFIG.txt`.
* **PowerShell Method:** Advanced parameters for `process.ps1` and frame extraction testing with `extract.ps1`.

## Important: Required FFmpeg Executable
To prevent command syntax errors due to constant FFmpeg build updates, **do not use generic FFmpeg versions**. 
* Go to the **Releases** section on the right side of this repository.
* Download our **v1.0.0 Stable Build** zip file.

---
**Official Project Channel:** Watch tutorials and performance showcases on [YouTube (@toplayaless)]
https://www.youtube.com/playlist?list=PLae7RZ7VAOWk
