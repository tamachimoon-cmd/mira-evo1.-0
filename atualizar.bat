@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set "AUTO_ARG="
if /I "%~1"=="--auto" set "AUTO_ARG=-Auto"

where powershell >nul 2>&1
if errorlevel 1 (
  echo [ERRO] PowerShell nao encontrado. O atualizador do Mira-Evo precisa do PowerShell.
  if not defined AUTO_ARG pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0atualizar.ps1" %AUTO_ARG%
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo [ERRO] Atualizacao encerrada com codigo %RC%.
  if not defined AUTO_ARG pause
)
exit /b %RC%
