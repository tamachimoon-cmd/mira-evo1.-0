#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

AUTO=0
[ "${1:-}" = "--auto" ] && AUTO=1
ENV_FILE=".env"
VERSION_FILE="VERSION"

get_env() {
  local name="$1"
  [ -f "$ENV_FILE" ] || return 0
  grep -E "^${name}=" "$ENV_FILE" | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

warn() { printf '[AVISO] %s\n' "$*"; }
info() { printf '[MIRA] %s\n' "$*"; }

[ -f "$ENV_FILE" ] || { warn '.env nao encontrado. Execute instalar.sh primeiro.'; exit 0; }
UPDATE_PATH="$(get_env MIRA_UPDATE_PATH)"

if [ -z "$UPDATE_PATH" ] || printf '%s' "$UPDATE_PATH" | grep -Eq 'SERVIDOR\\PASTA_ETL|COLE_AQUI|TROQUE_AQUI'; then
  warn 'MIRA_UPDATE_PATH ainda nao foi configurado no .env. Nenhuma atualizacao foi aplicada.'
  exit 0
fi
[ -d "$UPDATE_PATH" ] || { warn "Pasta de atualizacao inacessivel: $UPDATE_PATH"; exit 0; }

MANIFEST="$UPDATE_PATH/update-manifest.json"
[ -f "$MANIFEST" ] || { warn "Manifesto nao encontrado: $MANIFEST"; exit 0; }

readarray -t META < <(python3 - "$MANIFEST" <<'PY'
import json, sys
m=json.load(open(sys.argv[1], encoding='utf-8'))
for key in ('version','package','sha256'):
    if not m.get(key):
        raise SystemExit(f'manifesto invalido: campo {key} ausente')
print(m['version'])
print(m['package'])
print(m['sha256'])
PY
)
REMOTE_VERSION="${META[0]}"
PACKAGE_NAME="${META[1]}"
EXPECTED_SHA="${META[2],,}"
LOCAL_VERSION="0.0.0.0"
[ -f "$VERSION_FILE" ] && LOCAL_VERSION="$(tr -d '\r\n ' < "$VERSION_FILE")"

is_newer="$(python3 - "$LOCAL_VERSION" "$REMOTE_VERSION" <<'PY'
import re, sys

def v(s):
    p=[int(x) for x in re.findall(r'\d+', s)[:4]]
    return tuple((p+[0,0,0,0])[:4])
print('1' if v(sys.argv[2]) > v(sys.argv[1]) else '0')
PY
)"
[ "$is_newer" = "1" ] || { info "Versao local $LOCAL_VERSION ja esta atualizada."; exit 0; }

PACKAGE="$UPDATE_PATH/$PACKAGE_NAME"
[ -f "$PACKAGE" ] || { echo "[ERRO] Pacote nao encontrado: $PACKAGE" >&2; exit 1; }

TMP="$(mktemp -d -t miraevo-update-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
cp "$PACKAGE" "$TMP/update.zip"
ACTUAL_SHA="$(sha256sum "$TMP/update.zip" | awk '{print tolower($1)}')"
[ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || { echo '[ERRO] Checksum SHA-256 invalido. Atualizacao cancelada.' >&2; exit 1; }
info 'Checksum SHA-256 validado.'

mkdir -p "$TMP/extract"
unzip -q "$TMP/update.zip" -d "$TMP/extract"
[ -d "$TMP/extract/nextjs_space" ] || { echo '[ERRO] Pacote invalido: nextjs_space ausente.' >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="backups/nextjs_space-$STAMP"
mkdir -p "$BACKUP"
rsync -a --delete --exclude node_modules --exclude .next --exclude .yarn --exclude .env --exclude .env.local --exclude tsconfig.tsbuildinfo nextjs_space/ "$BACKUP/"

rollback() {
  warn 'Restaurando backup do codigo...'
  rsync -a --delete --exclude node_modules --exclude .next --exclude .yarn --exclude .env --exclude .env.local --exclude tsconfig.tsbuildinfo "$BACKUP/" nextjs_space/
  cp -f .env nextjs_space/.env
}
trap 'rc=$?; if [ $rc -ne 0 ]; then rollback; fi; rm -rf "$TMP"; exit $rc' EXIT

info "Aplicando $LOCAL_VERSION -> $REMOTE_VERSION"
rsync -a --delete --exclude node_modules --exclude .next --exclude .yarn --exclude .env --exclude .env.local --exclude tsconfig.tsbuildinfo "$TMP/extract/nextjs_space/" nextjs_space/
cp -f .env nextjs_space/.env

pushd nextjs_space >/dev/null
if [ -f yarn.lock ]; then yarn install --frozen-lockfile || yarn install; else yarn install; fi
yarn prisma generate
yarn build
popd >/dev/null

printf '%s\n' "$REMOTE_VERSION" > "$VERSION_FILE"
info "Atualizacao concluida. Versao atual: $REMOTE_VERSION"
trap - EXIT
rm -rf "$TMP"

if [ "$AUTO" -eq 0 ]; then
  printf '\nPressione Enter para sair.'
  read -r _
fi
