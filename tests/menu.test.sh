#!/usr/bin/env bash
# Teste do menu.sh: scripts de mentira num diretório temporário, respostas por arquivo, sem tocar no sistema.
# Uso: bash tests/menu.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for s in setup.sh mirrors.sh nvidia.sh oxwm-setup.sh; do
  printf '#!/usr/bin/env bash\necho "FAKE %s $*"\n' "$s" > "$tmp/$s"
done
printf '#!/usr/bin/env bash\necho "FAKE setup.sh $*"; exit 3\n' > "$tmp/setup.sh"   # falha: o menu não pode cair junto

# 1 (setup, sai com 3) | Enter | 7 | Enter | 8 | Enter | x (inválida) | Enter | r + n (recusa reiniciar) | Enter | q
printf '1\n\n7\n\n8\n\nx\n\nr\nn\n\nq\n' > "$tmp/in"
out=$(MENU_DIR="$tmp" MENU_TTY="$tmp/in" TERM=dumb bash "$here/../menu.sh" 2>&1); rc=$?

fail=0
check() { grep -qF -- "$1" <<<"$out" || { echo "FALHOU: faltou \"$1\""; fail=1; }; }
check 'FAKE setup.sh --sem-encerrar'          # a opção 1 passa a flag que impede o setup de fechar o menu
check '[menu] setup.sh terminou (código 3)'   # o código do filho aparece e o menu continua
check 'FAKE nvidia.sh install --dry-run'
check 'FAKE oxwm-setup.sh'
check 'Opção inválida: x'
[[ $rc == 0 ]] || { echo "FALHOU: o menu saiu com $rc"; fail=1; }
((fail)) && exit 1
echo "menu.test.sh: ok"
