#!/usr/bin/env bash
# Teste do menu.sh: scripts de mentira num diretório temporário, teclas lidas de um arquivo, sem tocar no sistema.
# Uso: bash tests/menu.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/fake" "$tmp/bin"
for s in setup.sh mirrors.sh nvidia.sh oxwm-setup.sh caelestia-setup.sh; do
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
  out=$(env KERNEL_RELEASE=6.0.0-generic PREFIX= FORCE_PROOT=0 COLUMNS= LINES= "$@" MENU_DIR="$tmp" MENU_TTY="$tmp/in" \
        TERM=dumb PATH="$tmp/fake:$PATH" bash "$here/../menu.sh" 2>&1); rc=$?
  [[ $rc == 0 ]] || { echo "FALHOU: o menu saiu com $rc"; fail=1; }
}
has()   { grep -qF -- "$1" <<<"$out" || { echo "FALHOU: faltou \"$1\""; fail=1; }; }
hasnt() { ! grep -qF -- "$1" <<<"$out" || { echo "FALHOU: não devia ter \"$1\""; fail=1; }; }

# Itens: 0 setup | 1 simular | 2 dotfiles | 3 mirrors | 4 reverter | 5 NVIDIA detectar | 6 instalar | 7 simular | 8 OXWM | 9 Caelestia | 10 Reiniciar | 11 Desligar | 12 Fechar | 13 Sair

# Setup pede "Tem certeza" (s = sim); simular não pede; um filho que falha (código 3) não derruba o menu;
# Reiniciar pede "Tem certeza" e n cancela sem reiniciar.
run '\ns\nj\n\njjjjjj\n\njjj\nnq'
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

# Centralizado: sem tty o menu lê COLUMNS/LINES. Terminal 100x40: a caixa (72 colunas) começa na coluna 14 (também a de
# "Tem certeza"), as teclas ficam alinhadas com ela, e o menu (14 itens + 9 = 23 linhas) tem (40-23)/2 = 8 linhas em branco em cima.
run '\nn\nq' COLUMNS=100 LINES=40
bad=$(grep -F -e '╭' -e '│' -e '╰' <<<"$out" | grep -vE '^ {14}[^ ]')
[[ -z $bad ]] || { echo "FALHOU: caixa fora do centro (esperava 14 colunas de margem):"; echo "$bad" | head -3; fail=1; }
grep -qE '^ {15}↑↓ mover' <<<"$out" || { echo "FALHOU: a linha de teclas não está alinhada com a caixa"; fail=1; }
[[ -z $(head -n 8 <<<"$out" | tr -d ' ') && $(sed -n 9p <<<"$out") == "$(printf '%14s' '')╭"* ]] \
  || { echo "FALHOU: o menu devia começar na linha 9 (8 em branco em cima)"; fail=1; }
# Terminal estreito e baixo: sem margem nenhuma (largura mínima 36, começa no topo).
run '\nn\nq' COLUMNS=30 LINES=10
bad=$(grep -F -e '╭' -e '│' -e '╰' <<<"$out" | grep -vE '^[^ ]')
[[ -z $bad && $(sed -n 1p <<<"$out") == '╭'* ]] || { echo "FALHOU: terminal pequeno não devia ter margem"; fail=1; }

# O padrão do botão é Não: Enter direto cancela. Esc também cancela.
run '\n\nq';  has 'Tem certeza'; hasnt 'FAKE setup.sh'
run '\n\033'; has 'Tem certeza'; hasnt 'FAKE setup.sh'

# Setas: 4 para baixo e 1 para cima = item 3 (mirrors); → troca para Sim; Enter confirma.
run '\033[B\033[B\033[B\033[B\033[A\n\033[C\n\nq'; has 'FAKE mirrors.sh'

# Dotfiles: pede "Tem certeza" e roda o setup.sh só com --dotfiles.
run 'jj\ns\nq'; has 'aplicar só os dotfiles'; has 'FAKE setup.sh --dotfiles'

# Caelestia: pede "Tem certeza" e roda o caelestia-setup.sh.
run 'jjjjjjjjj\ns\nq'; has 'instalar o Caelestia'; has 'FAKE caelestia-setup.sh'

# "Sim" em Reiniciar chama o reboot (o de mentira).
run 'jjjjjjjjjj\ns\nq'; has 'FAKE reboot'

# Termux e proot: Reiniciar e Desligar somem do menu; Fechar e Sair ficam.
for env in PREFIX=/data/data/com.termux/files/usr KERNEL_RELEASE=6.17.0-PRoot-Distro FORCE_PROOT=1; do
  run 'q' "$env"; hasnt 'Reiniciar'; hasnt 'Desligar'; has 'Fechar este terminal'
done

# WSL: Reiniciar não pergunta nada nem chama o reboot; mostra o wsl --shutdown.
run 'jjjjjjjjjj\n\nq' KERNEL_RELEASE=5.15.153.1-microsoft-standard-WSL2
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

# Sem clone ("curl | bash"): sem setup.sh ao lado, o menu só baixa (curl de mentira) o script do item escolhido, roda-o
# com o terminal como stdin e apaga a pasta temporária ao sair. O script entra pelo pipe, como no uso real.
mkdir -p "$tmp/t" "$tmp/empty"
cat > "$tmp/fake/curl" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; *) u=$1 ;; esac; shift; done
echo "$u" >> "$FAKE_LOG"
[ -z "${FAKE_FAIL:-}" ] || exit 22
printf '#!/usr/bin/env bash\necho "REMOTE %s $*"; echo "STDIN=$(readlink /proc/self/fd/0)"; echo "DOTFILES_REF=${DOTFILES_REF:-}"\n' "${u##*/}" > "$o"
EOF
chmod +x "$tmp/fake/curl"
remote() {  # teclas [VAR=valor ...] — roda o menu a partir de uma pasta vazia, lido do pipe
  printf '%b' "$1" > "$tmp/in"; shift; : > "$tmp/curl.log"
  out=$(cd "$tmp/empty" && cat "$here/../menu.sh" | env KERNEL_RELEASE=6.0.0-generic PREFIX= FORCE_PROOT=0 "$@" \
        MENU_TTY="$tmp/in" TERM=dumb TMPDIR="$tmp/t" FAKE_LOG="$tmp/curl.log" PATH="$tmp/fake:$PATH" bash 2>&1); rc=$?
}
fetched() { grep -o '[^/]*$' "$tmp/curl.log" | sort | tr '\n' ' '; }   # nomes dos arquivos baixados
raw=https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas
# Abrir o menu e sair não baixa nada; escolher a simulação do setup baixa só o setup.sh (do ref certo), sem tarball.
remote 'q' MENU_REF=v1
[[ $rc == 0 && ! -s $tmp/curl.log ]] || { echo "FALHOU: o menu remoto baixou algo antes de escolher: $(fetched)"; fail=1; }
remote 'j\n\nq' MENU_REF=v1
[[ $rc == 0 ]] || { echo "FALHOU: o menu remoto saiu com $rc"; fail=1; }
has 'REMOTE setup.sh --dry-run --sem-encerrar'; has "STDIN=$tmp/in"; has 'DOTFILES_REF=v1'
[[ $(cat "$tmp/curl.log") == "$raw/v1/setup.sh" ]] || { echo "FALHOU: devia baixar só o setup.sh de v1, baixou: $(cat "$tmp/curl.log")"; fail=1; }
[[ -z $(ls -A "$tmp/t") ]] || { echo "FALHOU: a pasta temporária não foi apagada"; fail=1; }
# O mesmo script duas vezes: baixa uma só.
remote 'j\n\n\n\nq'
[[ $(grep -c 'REMOTE setup.sh' <<<"$out") == 2 && $(grep -c . "$tmp/curl.log") == 1 ]] || { echo "FALHOU: o setup.sh devia rodar 2 vezes e ser baixado 1 (baixou: $(fetched))"; fail=1; }
# mirrors.sh usa o setup.sh ao lado, e o OXWM usa o config.lua: vêm junto; nada além disso.
remote 'jjj\ns\nq';      [[ $(fetched) == "mirrors.sh setup.sh " ]]    || { echo "FALHOU: mirrors devia baixar mirrors.sh e setup.sh, baixou: $(fetched)"; fail=1; }
remote 'jjjjjjjj\ns\nq'; [[ $(fetched) == "config.lua oxwm-setup.sh " ]] || { echo "FALHOU: OXWM devia baixar oxwm-setup.sh e config.lua, baixou: $(fetched)"; fail=1; }
grep -qx "$raw/main/.config/oxwm/config.lua" "$tmp/curl.log" || { echo "FALHOU: o config.lua do OXWM devia vir de .config/oxwm/ (baixou: $(cat "$tmp/curl.log" | tr '\n' ' '))"; fail=1; }
# O Caelestia usa os três arquivos de .config/caelestia/ (2 .lua e o shell.json): vêm junto; nada além disso.
remote 'jjjjjjjjj\ns\nq'; [[ $(fetched) == "caelestia-setup.sh hypr-user.lua hypr-vars.lua shell.json " ]] || { echo "FALHOU: Caelestia devia baixar o script e os 3 arquivos, baixou: $(fetched)"; fail=1; }
grep -qx "$raw/main/.config/caelestia/hypr-vars.lua" "$tmp/curl.log" || { echo "FALHOU: hypr-vars.lua devia vir de .config/caelestia/ (baixou: $(tr '\n' ' ' < "$tmp/curl.log"))"; fail=1; }
# Download que falha: erro claro, o menu continua (não cai), nada roda e nada sobra em disco.
remote 'j\n\nq' FAKE_FAIL=1
[[ $rc == 0 ]] || { echo "FALHOU: download falho não devia derrubar o menu (saiu com $rc)"; fail=1; }
has 'não consegui baixar'; hasnt 'REMOTE'
[[ -z $(ls -A "$tmp/t") ]] || { echo "FALHOU: sobrou pasta temporária após o erro"; fail=1; }
# Sem curl nem wget (PATH só com bash, env e cat): erro claro e código 1, antes de abrir o menu.
mkdir -p "$tmp/min"; for c in bash env cat; do ln -sf "$(command -v $c)" "$tmp/min/$c"; done
printf 'q' > "$tmp/in"
out=$(cd "$tmp/empty" && cat "$here/../menu.sh" | env -i PATH="$tmp/min" MENU_TTY="$tmp/in" TERM=dumb "$tmp/min/bash" 2>&1); rc=$?
has 'precisa de curl ou wget'; [[ $rc == 1 ]] || { echo "FALHOU: sem curl nem wget devia sair com 1, saiu com $rc"; fail=1; }
# "curl | sh" (sem bash): não dá para reexecutar o stdin, então pede "| bash".
if [[ -n $posix ]]; then
  out=$(cat "$here/../menu.sh" | "$posix" 2>&1); rc=$?
  has '| bash'; [[ $rc == 1 ]] || { echo "FALHOU: curl | sh devia sair com 1, saiu com $rc"; fail=1; }
fi

((fail)) && exit 1
echo "menu.test.sh: ok"
