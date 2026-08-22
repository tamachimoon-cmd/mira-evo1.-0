#!/usr/bin/env bash
# =============================================================================
# Mira-Evo — Instalação (Linux/macOS) — SQL Server / localhost — sem Docker
# =============================================================================
set -e
cd "$(dirname "$0")"

echo "============================================================"
echo "  MIRA-EVO — INSTALAÇÃO (SQL Server / localhost)"
echo "  Uma solução Vivo"
echo "============================================================"

command -v node >/dev/null 2>&1 || { echo "[ERRO] Node.js não encontrado. Instale o Node.js 18 LTS ou superior."; exit 1; }
echo "[OK] Node.js $(node -v)"

if ! command -v yarn >/dev/null 2>&1; then
  echo "[..] Instalando o yarn..."
  npm install -g yarn
fi
echo "[OK] yarn $(yarn -v)"

if [ ! -f .env ]; then
  cp .env.example .env
  echo
  echo "[ATENÇÃO] Arquivo .env criado a partir do modelo."
  echo "Edite o .env e preencha DATABASE_URL (SQL Server), NEXTAUTH_SECRET, NEXTAUTH_URL e CRON_SECRET."
  echo "Se usar atualizacao por pasta de rede, ajuste tambem MIRA_UPDATE_PATH."
  echo "Depois execute novamente: bash instalar.sh"
  exit 0
fi

cp -f .env nextjs_space/.env

echo
echo "[1/5] Instalando dependências..."
cd nextjs_space
yarn install --frozen-lockfile || yarn install

echo
echo "[2/5] Gerando o cliente de banco de dados..."
yarn prisma generate

echo
echo "[3/5] Criando/atualizando as tabelas no SQL Server..."
yarn prisma db push

echo
echo "[4/5] Importando a carga inicial de dados..."
yarn tsx scripts/importar_dados.ts || echo "[AVISO] Nenhuma carga inicial foi importada. No repositorio publico, os fixtures devem permanecer vazios."

echo
echo "[5/5] Compilando a aplicação..."
yarn build

cd ..
echo
echo "============================================================"
echo "  INSTALAÇÃO CONCLUÍDA"
echo "  Execute: bash iniciar.sh"
echo "============================================================"
