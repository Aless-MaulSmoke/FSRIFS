# PRACTICAL USER MANUAL
**Upscaling + Frame Generator (FSR + IFS)**

## HARDWARE REQUIREMENTS AND DEPENDENCIES
For the post-processing pipeline to function correctly on your computer, your system must meet the following physical and software dependencies:

* **Vulkan API Compatibility (REQUIRED):** Your graphics card must have native support for Vulkan technology. The IFS authoring shader runs the temporal calculations directly on the GPU silicon through this API. It works on dedicated graphics cards (AMD RX, Nvidia GTX/RTX) and also on integrated chips (AMD Vega or newer Intel HD Graphics). If your GPU does not support Vulkan, the process will not start.
* **Processor (CPU):** Any basic 4 or 6-core older processor (such as the AMD FX line or past generations of Intel Core processors) is perfectly capable of running the pipeline. Average CPU usage is around 45%, keeping Windows completely free of crashes or overheating during rendering.
* **Video Memory (VRAM):** Legacy graphics cards with 2GB of VRAM can handle the task more than adequately if the user operates intelligently. It is recommended to close internet browsers, Discord, and background games before starting the process at high resolutions (such as 2K or 4K) to avoid overloading the card's memory.
* **Operating System:** Windows 10 or Windows 11 64-bit with the PowerShell terminal enabled and allowed to run scripts.

---

## INSTALLATION
Start by downloading the zip file containing the contents. Unzip it wherever you want. You will see the entire FSRIFS folder structure.

The entire process unfolds within a PowerShell prompt (knowing basic command-line folder navigation is important). 

Let's start by opening PowerShell; it doesn't need to be in administrator mode, as the script won't require any privileges to run.

If this is your first time running scripts on your computer, type the command below to allow script execution:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

Answer **YES** to apply the execution policy.

Now we are ready to run the processes, and you can do this in two ways:
* **Drag & Drop:** Dragging and dropping your video file onto an automated bot that performs the entire process for you (aimed at users without command prompt knowledge).
* **PowerShell Prompt:** Running the scripts to execute the pipeline via the command prompt (knowledge of command prompt required).

---

## Drag & Drop
This is the easiest way to run the pipeline. Using File Explorer, go to the folder where you extracted FSRIFS. You will see a file called `DRAG_VIDEO_HERE.bat`. Now open another File Explorer window and go to the folder where the video you want to process is located. Drag and drop your video onto the file we mentioned.

You can configure the process by editing the file `DRAG_CONFIG.txt`:

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
This is the original method for processing your videos. We need to access the location where you extracted FSRIFS (for example: `D:\FSRIFS`):

```powershell
cd "D:\FSRIFS"
```

You will then be in the pipeline folder and will be able to run two scripts:

### 1. process.ps1
*(Our main script allows us to upscale and/or generate frames)*

The script operates in a modular way; you can access these modules through command-line parameters. Let's explore them:

* `-file "filename.mp4"`: The full path to the video file you want to process. It must be enclosed in quotation marks (e.g., `-file "C:\folder\video.mp4"`).
* `-scale factor|resolution`: Final video dimensions. If omitted, upscaling does not occur and the original size is maintained. The value can be entered in the following formats:
  * **Multiplier factor** for resolution gain. Use decimal numbers (e.g., the dimension factor for a 720p video to 1080p is `1.5`).
  * **Literal resolution** where you can specify, for example: `"1920x1080"`.
* `-fps number`: The desired frame rate for smoothness (e.g., `60`). If omitted, frame generation does not occur and the original FPS is maintained.
* `-quality "low|med|big"`: The weight, compression, and final file size profile. If you omit this parameter, the system will automatically assume the balanced "med" profile. The available options are:
  * **low:** Focus on drastic space savings. Reduces the final file size and eases VRAM usage. Generates a small final file.
  * **med:** The ideal balance point. Maintains edge sharpness and visual fidelity without overloading the hard drive. Generates a medium-sized final file.
  * **big:** Maximum visual fidelity and high bitrate, designed for high-quality archiving or uploading. Generates a huge final file.
* `-sharpness number`: Quality applied by FSR ranging from `0` (maximum) to `10` (minimum).
* `-v`: Verbose mode, where detailed information about the process is listed in the terminal.

**Security Note:** The script requires you to use at least the `-scale` or `-fps` option.

#### Examples:
* **To perform ONLY the Upscale:** Let's say from 720p to 1080p, with medium sharpness, then we apply a 1.5x scale and sharpness of 5.
  ```powershell
  .\process.ps1 -file "C:\folder\video.mp4" -scale 1.5 -sharpness 5
  ```

* **Perform ONLY Frame Generation:** Let's say your original video is at 30fps and you want 60fps.
  ```powershell
  .\process.ps1 -file "C:\folder\video.mp4" -fps 60
  ```

* **Complete Pipeline:** Upscale to 1080p + 60 FPS frame generation + checking a detailed log in the prompt.
  ```powershell
  .\process.ps1 -file "C:\folder\video.mp4" -scale "1920x1080" -fps 60 -v
  ```

The script will identify the source of your file and save the final result **exactly in the same folder as the original video**. The new file name is intelligently generated with suffixes based on what you chose to do:
* **If you only used upscaling:** `video_FSR_1080x720.mp4`
* **If only the frames were used:** `video_60fps.mp4`
* **If you used the complete pipeline:** `video_FSR_1080x720_60fps.mp4`

---

### 2. extract.ps1
*(Script to extract some frames from the processed video so you can evaluate frame by frame if the result is good)*

You can extract all frames from X seconds starting at a specific time in the video. It is the ideal tool for visually assessing the quality of the final result.

#### Command-line parameters:
* `-file "file"`: The full path to the video file you want to process. It must be enclosed in quotation marks (e.g., `-file "C:\folder\video.mp4"`).
* `-time "hh:mm:ss"`: The extraction start point in HH:MM:SS format. If not filled in, it will automatically start at 3 seconds (`00:00:03`).
* `-secs number`: How many seconds of video do you want to convert into photos? If not specified, it will only extract 1 second (if the video is at 60fps, then 60 frames will be extracted).
* `-output "destination folder"`: (In double quotes) Folder where to save the photos. If not filled in, the script will extract the frames into the `output` folder in the FSRIFS root directory.

---

## KNOWN PROBLEMS / TECHNICAL LIMITATIONS

* **Blur or Smoothing on Pause (Freeze Frame Artifacts):**
  * **Symptom:** When pausing the final video during fast-moving scenes, the image may appear soft, blurry, or exhibit a "ghosting" effect.
  * **Cause:** The video player froze the playback clock exactly on top of an intermediate (interpolated) frame generated by the IFS shader's temporal mathematics.
  * **Solution:** There is nothing to fix. This behavior is the necessary mechanics to guarantee the illusion of fluidity in frame generation with moving video, without requiring heavy AI or hardware with Tensor Cores. It is the price you pay for a solution aimed at low-end PCs.

---

## CREDITS AND TECHNICAL SUPPORT

* **Conception, Authorship of the IFS Shader (MIT) and Pipeline Integration:** by Aless (MaulSmoke).
* **Third-Party Technologies Used:** FFmpeg (GPL), libplacebo (LGPL), AMD FidelityFX FSR (MIT).
* **Official Project Channel (YouTube):** Watch tutorials, news, performance showcases, and get your questions answered directly in the channel's community: https://youtube.com
