#!/usr/bin/env bash
# =============================================================================
# Mira-Evo — Inicia o servidor localmente (localhost, sem Docker)
# =============================================================================
set -e
cd "$(dirname "$0")"

[ -f .env ] || { echo "[ERRO] .env não encontrado. Execute: bash instalar.sh"; exit 1; }

PORT="${PORT:-3000}"

# Verifica atualizacao na pasta de rede antes de iniciar o servidor.
AUTO_UPDATE="$(grep -E '^MIRA_AUTO_UPDATE=' .env | tail -n1 | cut -d= -f2- | tr '[:upper:]' '[:lower:]' || true)"
if [ "$AUTO_UPDATE" = "true" ]; then
  bash ./atualizar.sh --auto
fi

echo "============================================================"
echo "  MIRA-EVO — SERVIDOR   | Uma solução Vivo"
echo "============================================================"
echo "  Acesse neste computador: http://localhost:$PORT"
echo
echo "  Para rodar em segundo plano:  bash iniciar.sh --daemon"
echo "  Para encerrar:                bash parar.sh"
echo "============================================================"

cp -f .env nextjs_space/.env
cd nextjs_space
export NODE_ENV=production

if [ "${1:-}" = "--daemon" ]; then
  mkdir -p ../logs
  nohup yarn start --port "$PORT" > ../logs/miraevo.log 2>&1 &
  echo $! > ../miraevo.pid
  echo "Servidor iniciado em segundo plano (PID $(cat ../miraevo.pid)). Log: logs/miraevo.log"
else
  exec yarn start --port "$PORT"
fi
