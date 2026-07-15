@echo off
chcp 65001 >nul
title FSRIFS PIPELINE - by Aless(MaulSmoke)
cd /d "%~dp0"

:: Validação segura de entrada
if "%~1" == "" (
    echo [ERROR] No video file or folder detected!
    echo To use, drag and drop a video file OR a folder onto this icon.
    echo.
    pause
    exit
)

:: Armazena o caminho arrastado em uma variável de ambiente protegida
set "DRAG_PATH=%~1"

:: Detecta se o item arrastado é um diretório (pasta) ou um arquivo
if exist "%~1\" (
    echo [INFO] Folder detected. Starting batch mode...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { .\process.ps1 -folder $env:DRAG_PATH -DRAG_CONFIG }"
) else (
    echo [INFO] Single video file detected. Starting single mode...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { .\process.ps1 -file $env:DRAG_PATH -DRAG_CONFIG }"
)
pause
