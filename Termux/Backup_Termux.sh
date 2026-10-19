#!/data/data/com.termux/files/usr/bin/env zsh
#
# termux_backup.sh
# Faz backup compactado (tar + zstd) das pastas "home" e "usr" do Termux,
# salvando em ~/storage/shared/Documents.
#
# Uso:
#   ./termux_backup.sh

set -o pipefail

TERMUX_FILES="/data/data/com.termux/files"
BACKUP_DIR="$HOME/storage/shared/Documents"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/termux_backup_${TIMESTAMP}.tar.zst"

mkdir -p "$BACKUP_DIR"

echo "📊 Calculando Tamanho Total"
TOTAL_SIZE=$(du -sb \
  --exclude="$TERMUX_FILES/home/storage" \
  --exclude="$TERMUX_FILES/home/.cache" \
  --exclude="*/cache/*" \
  "$TERMUX_FILES/home" "$TERMUX_FILES/usr" 2>/dev/null \
  | awk '{sum+=$1} END {print sum}')

echo "📦 Backup Em Curso"
tar -cp \
  --exclude="home/storage" \
  --exclude="home/.cache" \
  --exclude="*/cache/*" \
  -C "$TERMUX_FILES" home usr \
  | pv -s "$TOTAL_SIZE" \
  | zstd -19 -T0 > "$BACKUP_FILE"

if [[ $? -eq 0 ]]; then
  echo "✅ Backup Concluído"
  ls -lh "$BACKUP_FILE"
else
  echo "❌ Falha Ao Criar O Backup."
  exit 1
fi
