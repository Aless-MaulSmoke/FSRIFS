@echo off
title PIPELINE FSR + IFS - by Aless(MaulSmoke)
cd /d "%~dp0"

:: Check if the user dragged a file
if "%~1"=="" (
    echo [ERROR] No video file detected!
    echo To use, drag and drop a video file onto this icon.
    echo.
    pause
    exit
)

:: Check if config file exists
if not exist drag_config.txt (
    echo [ERROR] DRAG_CONFIG.txt not found in bin folder!
    pause
    exit
)

:: Read drag_config.txt line by line and map variables
for /f "tokens=1,2 delims==" %%A in (drag_config.txt) do (
    if "%%A"=="SCALE" set "SCALE=%%B"
    if "%%A"=="SHARPNESS" set "SHARPNESS=%%B"
    if "%%A"=="FPS" set "FPS=%%B"
    if "%%A"=="QUALITY" set "QUALITY=%%B"
    if "%%A"=="VERBOSE" set "VERBOSE=%%B"
)

:: Handle verbose parameter mapping
set "V_PARAM="
if /i "%VERBOSE%"=="true" set "V_PARAM=-v"

echo =======================================================
echo            LAUNCHING UPSCALE PIPELINE (FSR)
echo =======================================================
echo.
echo Input File   : %~nx1
echo Scale        : %SCALE%
echo Sharpness    : %SHARPNESS%
echo FPS          : %FPS%
echo Quality      : %QUALITY%
echo Verbose Mode : %VERBOSE%
echo =======================================================
echo.

powershell -ExecutionPolicy Bypass -Command ".\process.ps1 -file '%~1' -scale '%SCALE%' -sharpness %SHARPNESS% -fps %FPS% -quality %QUALITY% %V_PARAM%"

echo.
echo =======================================================
echo             PROCESS COMPLETED SUCCESSFULLY!
echo =======================================================
pause
