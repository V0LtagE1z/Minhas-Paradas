#!/usr/bin/env bash
# Teste do menu.sh: scripts de mentira num diretório temporário, teclas lidas de um arquivo, sem tocar no sistema.
# Uso: bash tests/menu.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/fake" "$tmp/bin"
for s in setup.sh mirrors.sh nvidia.sh oxwm-setup.sh; do
  printf '#!/usr/bin/env bash\necho "FAKE %s $*"\n' "$s" > "$tmp/$s"
done
printf '#!/usr/bin/env bash\necho "FAKE setup.sh $*"; exit 3\n' > "$tmp/setup.sh"   # falha: o menu não pode cair junto
# reboot, poweroff e sudo de mentira na frente do PATH: o teste nunca reinicia a máquina de verdade
for c in reboot poweroff; do printf '#!/bin/sh\necho "FAKE %s"\n' "$c" > "$tmp/fake/$c"; done
printf '#!/bin/sh\nexec "$@"\n' > "$tmp/fake/sudo"
chmod +x "$tmp/fake/"*

fail=0
run() {  # teclas [VAR=valor ...] — \n = Enter, \033[B = seta para baixo; a saída fica em $out
  printf '%b' "$1" > "$tmp/in"; shift
  out=$(env KERNEL_RELEASE=6.0.0-generic PREFIX= FORCE_PROOT=0 "$@" MENU_DIR="$tmp" MENU_TTY="$tmp/in" \
        TERM=dumb PATH="$tmp/fake:$PATH" bash "$here/../menu.sh" 2>&1); rc=$?
  [[ $rc == 0 ]] || { echo "FALHOU: o menu saiu com $rc"; fail=1; }
}
has()   { grep -qF -- "$1" <<<"$out" || { echo "FALHOU: faltou \"$1\""; fail=1; }; }
hasnt() { ! grep -qF -- "$1" <<<"$out" || { echo "FALHOU: não devia ter \"$1\""; fail=1; }; }

# Itens: 0 setup | 1 simular | 2 mirrors | 3 reverter | 4 NVIDIA detectar | 5 instalar | 6 simular | 7 OXWM | 8 Reiniciar | 9 Desligar | 10 Fechar | 11 Sair

# Setup pede "Tem certeza" (s = sim); simular não pede; um filho que falha (código 3) não derruba o menu;
# Reiniciar pede "Tem certeza" e n cancela sem reiniciar.
run '\ns\nj\n\njjjjj\n\njj\nnq'
has 'Tem certeza que deseja'; has 'rodar o setup completo'
has 'FAKE setup.sh --sem-encerrar'; has '[menu] setup.sh terminou (código 3)'
has 'FAKE setup.sh --dry-run --sem-encerrar'; has 'FAKE nvidia.sh install --dry-run'
has 'reiniciar o computador'; hasnt 'FAKE reboot'
# Todas as linhas de caixa têm a mesma largura (60 sem terminal), mesmo com acentos nos rótulos.
if command -v python3 >/dev/null; then
  bad=$(python3 -c 'import sys
for l in sys.stdin:
    l = l.rstrip("\n")
    if l and l[0] in "╭│╰" and len(l) != 60: print(len(l), l)' <<<"$out")
  [[ -z $bad ]] || { echo "FALHOU: caixa desalinhada:"; echo "$bad"; fail=1; }
fi

# O padrão do botão é Não: Enter direto cancela. Esc também cancela.
run '\n\nq';  has 'Tem certeza'; hasnt 'FAKE setup.sh'
run '\n\033'; has 'Tem certeza'; hasnt 'FAKE setup.sh'

# Setas: 3 para baixo e 1 para cima = item 2 (mirrors); → troca para Sim; Enter confirma.
run '\033[B\033[B\033[B\033[A\n\033[C\n\nq'; has 'FAKE mirrors.sh'

# "Sim" em Reiniciar chama o reboot (o de mentira).
run 'jjjjjjjj\ns\nq'; has 'FAKE reboot'

# Termux e proot: Reiniciar e Desligar somem do menu; Fechar e Sair ficam.
for env in PREFIX=/data/data/com.termux/files/usr KERNEL_RELEASE=6.17.0-PRoot-Distro FORCE_PROOT=1; do
  run 'q' "$env"; hasnt 'Reiniciar'; hasnt 'Desligar'; has 'Fechar este terminal'
done

# WSL: Reiniciar não pergunta nada nem chama o reboot; mostra o wsl --shutdown.
run 'jjjjjjjj\n\nq' KERNEL_RELEASE=5.15.153.1-microsoft-standard-WSL2
has 'wsl --shutdown'; hasnt 'Tem certeza'; hasnt 'FAKE reboot'

# Sem bash: um shell POSIX (dash/ash) com um PATH que só tem um "apk" de mentira avisa e mostra o comando.
posix=$(command -v dash || command -v ash || true)
if [[ -z $posix ]]; then echo "pulado: nenhum dash/ash para testar a checagem do bash"
else
  printf '#!/bin/sh\n' > "$tmp/bin/apk"; chmod +x "$tmp/bin/apk"
  out=$(PATH="$tmp/bin" "$posix" "$here/../menu.sh" 2>&1); rc=$?
  has 'apk add bash'
  [[ $rc == 1 ]] || { echo "FALHOU: sem bash o menu devia sair com 1, saiu com $rc"; fail=1; }
fi

((fail)) && exit 1
echo "menu.test.sh: ok"
