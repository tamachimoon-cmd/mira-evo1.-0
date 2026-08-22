#!/usr/bin/env bash
# Gera pacote de atualizacao para a instalacao LOCALHOST/SQL Server.
# Uso:
#   bash gerar_update_localhost.sh [versao] [pasta_publicacao]
# Exemplo:
#   bash gerar_update_localhost.sh 1.1.0.0 "//servidor/pasta_etl/MIRA-EVO/releases"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-$(date +%Y.%m.%d.%H%M)}"
PUBLISH_PATH="${2:-${MIRA_PUBLISH_PATH:-}}"
TMP="$ROOT/update_localhost_temp"
ZIP="$ROOT/miraevo_update.zip"
MANIFEST="$ROOT/update-manifest.json"

rm -rf "$TMP"
mkdir -p "$TMP/nextjs_space"

rsync -a \
  --exclude 'node_modules' \
  --exclude '.next' \
  --exclude '.build' \
  --exclude '.deploy' \
  --exclude '.yarn' \
  --exclude '.env' \
  --exclude '.env.local' \
  --exclude '*.log' \
  --exclude 'tsconfig.tsbuildinfo' \
  "$ROOT/nextjs_space/" "$TMP/nextjs_space/"

cp -L "$ROOT/nextjs_space/package.json" "$TMP/nextjs_space/package.json"
[ -f "$ROOT/nextjs_space/yarn.lock" ] && cp -L "$ROOT/nextjs_space/yarn.lock" "$TMP/nextjs_space/yarn.lock"

SCHEMA="$TMP/nextjs_space/prisma/schema.prisma"
sed -i '/output *= *"\/home\//d' "$SCHEMA"
sed -i '/binaryTargets/d' "$SCHEMA"
python3 "$ROOT/pacote_localhost/converter_schema_sqlserver.py" "$SCHEMA"

rm -f "$ZIP"
(
  cd "$TMP"
  zip -rq "$ZIP" nextjs_space
)
SHA="$(sha256sum "$ZIP" | awk '{print $1}')"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$MANIFEST" <<EOF
{
  "version": "$VERSION",
  "package": "miraevo_update.zip",
  "sha256": "$SHA",
  "createdAt": "$CREATED_AT",
  "target": "localhost-sqlserver"
}
EOF

if [ -n "$PUBLISH_PATH" ]; then
  mkdir -p "$PUBLISH_PATH"
  cp -f "$ZIP" "$MANIFEST" "$PUBLISH_PATH/"
  echo "Publicado em: $PUBLISH_PATH"
fi

rm -rf "$TMP"
echo "Pacote: $ZIP"
echo "Manifesto: $MANIFEST"
echo "Versao: $VERSION"
echo "SHA-256: $SHA"
