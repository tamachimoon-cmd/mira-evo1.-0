@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Mira-Evo - Servidor (localhost)

cd /d "%~dp0"

if not exist ".env" (
  echo [ERRO] Arquivo .env nao encontrado. Execute "instalar.bat" primeiro.
  pause & exit /b 1
)

if "%PORT%"=="" set PORT=3000

rem Verifica atualizacao na pasta de rede antes de iniciar o servidor.
findstr /B /I /C:"MIRA_AUTO_UPDATE=true" ".env" >nul 2>&1
if not errorlevel 1 (
  call "%~dp0atualizar.bat" --auto
  if errorlevel 1 (
    echo [AVISO] A atualizacao falhou. O Mira-Evo nao sera iniciado para evitar versao inconsistente.
    pause & exit /b 1
  )
)

echo ============================================================
echo   MIRA-EVO - SERVIDOR   ^| Uma solucao Vivo
echo ============================================================
echo   Acesse neste computador: http://localhost:%PORT%
echo.
echo   Deixe esta janela ABERTA. Feche-a (ou rode parar.bat) para
echo   encerrar o servidor.
echo ============================================================
echo.

copy /Y ".env" "nextjs_space\.env" >nul
cd nextjs_space
set NODE_ENV=production
call yarn start --port %PORT%
pause
