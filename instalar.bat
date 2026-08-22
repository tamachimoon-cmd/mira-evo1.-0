@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Mira-Evo - Instalacao (localhost / SQL Server)

echo ============================================================
echo   MIRA-EVO - INSTALACAO (Windows / SQL Server / localhost)
echo   Uma solucao Vivo
echo ============================================================
echo.

cd /d "%~dp0"

where node >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Node.js nao encontrado.
  echo Instale o Node.js 18 LTS ou superior: https://nodejs.org
  pause & exit /b 1
)
for /f "tokens=*" %%v in ('node -v') do echo [OK] Node.js %%v

where yarn >nul 2>&1
if errorlevel 1 (
  echo [..] Instalando o yarn...
  call npm install -g yarn || (echo [ERRO] Falha ao instalar o yarn & pause & exit /b 1)
)
echo [OK] yarn disponivel

if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo.
  echo [ATENCAO] Foi criado o arquivo .env a partir do modelo.
  echo Edite o arquivo .env e preencha DATABASE_URL (SQL Server),
  echo NEXTAUTH_SECRET, NEXTAUTH_URL e CRON_SECRET antes de continuar.
  echo Se usar atualizacao por pasta de rede, ajuste tambem MIRA_UPDATE_PATH.
  echo.
  notepad .env
)

copy /Y ".env" "nextjs_space\.env" >nul

echo.
echo [1/5] Instalando dependencias (pode levar alguns minutos)...
cd nextjs_space
call yarn install --frozen-lockfile || call yarn install || (echo [ERRO] Falha no yarn install & pause & exit /b 1)

echo.
echo [2/5] Gerando o cliente de banco de dados...
call yarn prisma generate || (echo [ERRO] Falha no prisma generate & pause & exit /b 1)

echo.
echo [3/5] Criando/atualizando as tabelas no SQL Server...
call yarn prisma db push || (echo [ERRO] Falha ao conectar no SQL Server. Confira o DATABASE_URL no .env & pause & exit /b 1)

echo.
echo [4/5] Importando a carga inicial de dados...
call yarn tsx scripts/importar_dados.ts || echo [AVISO] Nenhuma carga inicial foi importada. No repositorio publico, os fixtures devem permanecer vazios.

echo.
echo [5/5] Compilando a aplicacao...
call yarn build || (echo [ERRO] Falha no build & pause & exit /b 1)

cd ..
echo.
echo ============================================================
echo   INSTALACAO CONCLUIDA
echo   Execute "iniciar.bat" para subir o Mira-Evo.
echo ============================================================
pause
