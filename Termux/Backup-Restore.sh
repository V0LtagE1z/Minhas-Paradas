#!/data/data/com.termux/files/usr/bin/env zsh
#
# termux_restore.sh
# Restaura backup compactado (tar + zstd) das pastas "home" e "usr" do Termux.
# Sem argumento, usa o backup mais recente em ~/storage/shared/Documents.
#
# Uso:
#   ./termux_restore.sh
#   ./termux_restore.sh /caminho/especifico.tar.zst

set -o pipefail

TERMUX_FILES="/data/data/com.termux/files"
BACKUP_DIR="$HOME/storage/shared/Documents"

if [[ -n "$1" ]]; then
  BACKUP_FILE="$1"
else
  BACKUP_FILE=$BACKUP_DIR/Termux-Backup.tar.zst
fi

if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
  echo "❌ Nenhum Backup Encontrado Em $BACKUP_DIR"
  exit 1
fi

echo "📁 Backup Selecionado: $BACKUP_FILE"
echo "⚠️  Isto Vai Sobrescrever Arquivos Em $TERMUX_FILES/home E $TERMUX_FILES/usr"
read "confirm?Continuar? (s/N) "
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
  echo "Cancelado."
  exit 0
fi

echo "📦 Restauração Em Curso"
TOTAL_SIZE=$(stat -c %s "$BACKUP_FILE")

pv -s "$TOTAL_SIZE" "$BACKUP_FILE" \
  | zstd -dc \
  | tar -xp --keep-directory-symlink -C "$TERMUX_FILES"

if [[ $? -eq 0 ]]; then
  echo "✅ Restauração Concluída"
  echo "🔄 Reinicie o Termux (force stop + abrir de novo) para garantir que tudo carregue corretamente."
else
  echo "❌ Falha Ao Restaurar O Backup."
  exit 1
fi
