#!/usr/bin/env bash
# Teste do menu.sh: scripts de mentira num diretório temporário, teclas lidas de um arquivo, sem tocar no sistema.
# Uso: bash tests/menu.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/fake" "$tmp/bin"
for s in setup.sh mirrors.sh nvidia.sh oxwm-setup.sh caelestia-setup.sh; do
  # cada script de mentira mostra os argumentos e as variáveis que as opções do menu podem ligar
  printf '#!/usr/bin/env bash\necho "FAKE %s $*"\necho "ENV SKIP_MIRRORS=${SKIP_MIRRORS:-} SKIP_LOCALES=${SKIP_LOCALES:-} SKIP_TERMUX_UPGRADE=${SKIP_TERMUX_UPGRADE:-} WSL_INSTALL_GUI=${WSL_INSTALL_GUI:-}"\n' "$s" > "$tmp/$s"
done
sed -i '$a exit 3' "$tmp/setup.sh"   # falha: o menu não pode cair junto
# reboot, poweroff e sudo de mentira na frente do PATH: o teste nunca reinicia a máquina de verdade
for c in reboot poweroff; do printf '#!/bin/sh\necho "FAKE %s"\n' "$c" > "$tmp/fake/$c"; done
printf '#!/bin/sh\nexec "$@"\n' > "$tmp/fake/sudo"
chmod +x "$tmp/fake/"*
# os-release de mentira (o menu lê OS_RELEASE_FILE, o mesmo gancho do setup.sh): o padrão do teste é um Arch x86_64
printf 'ID=arch\n'                                          > "$tmp/os-arch"
printf 'ID=endeavouros\nID_LIKE=arch\n'                     > "$tmp/os-endeavour"
printf 'ID=cachyos\nID_LIKE=arch\n'                         > "$tmp/os-cachy"
printf 'ID=ubuntu\nID_LIKE=debian\n'                        > "$tmp/os-ubuntu"
printf 'ID=fedora\n'                                        > "$tmp/os-fedora"
printf 'ID=alpine\n'                                        > "$tmp/os-alpine"
printf 'ID="opensuse-tumbleweed"\nID_LIKE="opensuse suse"\n' > "$tmp/os-suse"
printf 'ID=void\n'                                          > "$tmp/os-void"
: > "$tmp/os-empty"   # os-release vazio: o menu não cai no /usr/lib/os-release do computador que roda o teste

TERMUX=PREFIX=/data/data/com.termux/files/usr
fail=0
run() {  # teclas [VAR=valor ...] — \n = Enter, \033[B = seta para baixo; a saída fica em $out
  printf '%b' "$1" > "$tmp/in"; shift
  out=$(env TERM=dumb KERNEL_RELEASE=6.0.0-generic PREFIX= FORCE_PROOT=0 COLUMNS= LINES= OS_RELEASE_FILE="$tmp/os-arch" UNAME_M=x86_64 \
        ARCH_RELEASE_FILE="$tmp/none" "$@" MENU_DIR="$tmp" MENU_TTY="$tmp/in" PATH="$tmp/fake:$PATH" bash "$here/../menu.sh" 2>&1); rc=$?
  [[ $rc == 0 ]] || { echo "FALHOU: o menu saiu com $rc"; fail=1; }
}
has()   { grep -qF -- "$1" <<<"$out" || { echo "FALHOU: faltou \"$1\""; fail=1; }; }
hasnt() { ! grep -qF -- "$1" <<<"$out" || { echo "FALHOU: não devia ter \"$1\""; fail=1; }; }

# Itens num Arch x86_64 de desktop: 0 Setup (submenu) | 1 Dotfiles | 2 mirrors | 3 reverter temas | 4 NVIDIA detectar | 5 NVIDIA instalar (submenu)
#   | 6 OXWM (submenu) | 7 Caelestia (submenu)
#   | 8 Mostrar todas as opções | 9 Reiniciar | 10 Desligar | 11 Fechar | 12 Sair
# Num submenu: Enter ou ←/→ mudam a opção, r roda, q volta; a primeira opção (a simulação) é a que começa selecionada.

# Setup real: abre o submenu, r pede "Tem certeza" (s = sim); um filho que falha (código 3) não derruba o menu.
run '\nrs\nq'
has 'Tem certeza que deseja'; has 'rodar o setup completo'
has 'FAKE setup.sh --sem-encerrar'; has 'setup.sh terminou (código 3)'
# Cada comando vem entre um título (com o comando exato) e uma linha de fim com o resultado: ✖ se falhou.
[[ $out == *'━━ ▶ Setup completo ━'*'$ bash setup.sh --sem-encerrar'*'FAKE setup.sh --sem-encerrar'*'━━ ✖ setup.sh terminou (código 3) ━'* ]] \
  || { echo "FALHOU: faltou o título, o comando ou a linha de fim em volta do setup.sh"; fail=1; }
# Sem nenhuma opção marcada nenhuma variável vai para o script.
has 'ENV SKIP_MIRRORS= SKIP_LOCALES= '
# Todas as linhas de caixa têm a mesma largura (60 sem terminal), mesmo com acentos nos rótulos: menu, submenu e "Tem certeza".
if command -v python3 >/dev/null; then
  bad=$(python3 -c 'import sys
for l in sys.stdin:
    l = l.rstrip("\n")
    if l and l[0] in "╭│╰" and len(l) != 60: print(len(l), l)' <<<"$out")
  [[ -z $bad ]] || { echo "FALHOU: caixa desalinhada:"; echo "$bad"; fail=1; }
fi
# Simular: o primeiro Enter do submenu liga o dry-run; r roda sem perguntar nada.
run '\n\nr\nq'; has 'FAKE setup.sh --sem-encerrar --dry-run'; hasnt 'Tem certeza'
# ← no primeiro valor dá a volta (não → sim); o comando mostrado embaixo já traz a opção antes de rodar.
run '\n\033[D\nq'; has 'bash setup.sh --sem-encerrar --dry-run'; hasnt 'FAKE setup.sh'
# Dotfiles e mirrors: pedem "Tem certeza" direto; Reiniciar também, e n cancela sem reiniciar.
run 'j\ns\nq'; has 'aplicar só os dotfiles'; has 'FAKE setup.sh --dotfiles'
run 'jjjjjjjjj\nnq'; has 'reiniciar o computador'; hasnt 'FAKE reboot'

# Centralizado: sem tty o menu lê COLUMNS/LINES. Terminal 100x40: a caixa (72 colunas) começa na coluna 14 (também a do submenu e a de
# "Tem certeza"), as teclas ficam alinhadas com ela, e o menu (12 itens + 9 = 21 linhas) tem (40-21)/2 = 9 linhas em branco em cima.
run '\nnqq' COLUMNS=100 LINES=40
bad=$(grep -F -e '╭' -e '│' -e '╰' <<<"$out" | grep -vE '^ {14}[^ ]')
[[ -z $bad ]] || { echo "FALHOU: caixa fora do centro (esperava 14 colunas de margem):"; echo "$bad" | head -3; fail=1; }
grep -qE '^ {15}↑↓ mover' <<<"$out" || { echo "FALHOU: a linha de teclas não está alinhada com a caixa"; fail=1; }
[[ -z $(head -n 9 <<<"$out" | tr -d ' ') && $(sed -n 10p <<<"$out") == "$(printf '%14s' '')╭"* ]] \
  || { echo "FALHOU: o menu devia começar na linha 10 (9 em branco em cima)"; fail=1; }
# Terminal estreito e baixo: sem margem nenhuma (largura mínima 36, começa no topo), no menu e no submenu.
run '\nqq' COLUMNS=30 LINES=10
bad=$(grep -F -e '╭' -e '│' -e '╰' <<<"$out" | grep -vE '^[^ ]')
[[ -z $bad && $(sed -n 1p <<<"$out") == '╭'* ]] || { echo "FALHOU: terminal pequeno não devia ter margem"; fail=1; }

# O padrão do botão é Não: Enter direto cancela (o submenu continua aberto). Esc também cancela.
run 'j\n\nq';  has 'Tem certeza'; hasnt 'FAKE setup.sh'
run 'j\n\033'; has 'Tem certeza'; hasnt 'FAKE setup.sh'
run '\nr\n';   has 'Tem certeza'; hasnt 'FAKE setup.sh'

# Setas: 3 para baixo e 1 para cima = item 2 (mirrors); → troca para Sim; Enter confirma.
run '\033[B\033[B\033[B\033[A\n\033[C\n\nq'; has 'FAKE mirrors.sh'

# ─── Opções do submenu do Setup (Arch x86_64): cada valor vira argumento ou variável ─────────────────────────────────────────────
# Linhas: 0 dry-run | 1 Mirrors | 2 core/extra/multilib | 3 Repos do CachyOS | 4 Temas Minecraft | 5 Locales | 6 Dotfiles | 7 Executar
run '\nqq'; has 'Repos do CachyOS'; has 'core/extra/multilib'; has 'Locales'; hasnt 'Kernel do CachyOS'; hasnt 'Mirrors do Termux'
run '\njjj\nrs\nq';  has 'FAKE setup.sh --sem-encerrar --sem-cachyos-repo'   # "instalação sem repo CachyOS"
run '\nj\nrs\nq';    has 'ENV SKIP_MIRRORS=1 '; has '$ SKIP_MIRRORS=1 bash setup.sh --sem-encerrar'   # variável na frente do comando
run '\njjjj\n\nrs\nq'; has 'FAKE setup.sh --sem-encerrar --sem-temas-minecraft'   # perguntar → instalar → pular (duas voltas)
run '\njjjjjj\nrs\nq'; has 'FAKE setup.sh --sem-encerrar --clonar-repo'
run '\njjjjj\n\nr\nq'; has 'SKIP_LOCALES=1'   # com o Locales em "pular" a variável vai; sem dry-run, mesmo assim
# Várias opções juntas, dry-run no meio (não pede "Tem certeza"): cada uma entra uma vez, as variáveis na frente.
run '\n\nj\njj\nr\nq'; has '$ SKIP_MIRRORS=1 bash setup.sh --sem-encerrar --dry-run --sem-cachyos-repo'; hasnt 'Tem certeza'
# Cada vez que o submenu abre, as opções voltam ao padrão.
run '\n\nr\n\nrs\nq'; has 'FAKE setup.sh --sem-encerrar --dry-run'; [[ $(grep -c 'FAKE setup.sh --sem-encerrar$' <<<"$out") == 1 ]] || { echo "FALHOU: o submenu devia voltar ao padrão ao reabrir"; fail=1; }

# ─── O que aparece em cada sistema ─────────────────────────────────────────────────────────────────────────────────────────────────
# Arch com derivada que tem os repos do CachyOS (EndeavourOS) mostra a opção; CachyOS (já é), Arch ARM e Ubuntu não.
run '\nqq' OS_RELEASE_FILE="$tmp/os-endeavour"; has 'Repos do CachyOS'
run '\nqq' OS_RELEASE_FILE="$tmp/os-cachy";     hasnt 'Repos do CachyOS'; has 'core/extra/multilib'
run '\nqq' UNAME_M=aarch64;                     hasnt 'Repos do CachyOS'
# Ubuntu: nada de pacman nem de mirrors (e o item "Ranquear os mirrors" some); o resto continua.
run '\nqq' OS_RELEASE_FILE="$tmp/os-ubuntu"
hasnt 'Repos do CachyOS'; hasnt 'core/extra/multilib'; hasnt 'Mirrors'; hasnt 'Ranquear os mirrors'; hasnt 'Kernel do CachyOS'
has 'Temas Minecraft'; has 'Locales'; has 'NVIDIA: instalar driver'; has 'Reverter temas Minecraft'
# Fedora x86_64: o kernel do CachyOS (COPR) aparece, os repos do CachyOS (pacman) não; os mirrors sim (dnf).
run '\nqq' OS_RELEASE_FILE="$tmp/os-fedora"; has 'Kernel do CachyOS'; hasnt 'Repos do CachyOS'; has 'Mirrors'; has 'Ranquear os mirrors'
run '\njj\nrs\nq'  OS_RELEASE_FILE="$tmp/os-fedora"; has 'FAKE setup.sh --sem-encerrar --kernel-cachyos'        # perguntar → instalar
run '\njj\n\nrs\nq' OS_RELEASE_FILE="$tmp/os-fedora"; has 'FAKE setup.sh --sem-encerrar --sem-kernel-cachyos'    # → pular
# Alpine e openSUSE: sem temas, sem NVIDIA para instalar (o nvidia.sh só sabe Arch, Debian/Ubuntu e Fedora); o Alpine ganha o community.
run '\nqq' OS_RELEASE_FILE="$tmp/os-alpine"; hasnt 'Temas Minecraft'; has 'Repositório community'; hasnt 'NVIDIA: instalar driver'; has 'NVIDIA: detectar GPU'; hasnt 'Ranquear os mirrors'
run '\nqq' OS_RELEASE_FILE="$tmp/os-suse";   has 'Temas Minecraft'; hasnt 'Repositório community'; hasnt 'NVIDIA: instalar driver'
# Distro desconhecida: só as opções gerais (dry-run, locales, temas, dotfiles).
run '\nqq' OS_RELEASE_FILE="$tmp/os-void"; has 'Locales'; hasnt 'Mirrors'; hasnt 'CachyOS'
# Imagem de proot do Arch Linux ARM, sem os-release: o /etc/arch-release (mesma dica do setup.sh) basta para ser Arch → mirrors.
: > "$tmp/arch-release"
run 'jj\nq' OS_RELEASE_FILE="$tmp/os-empty" ARCH_RELEASE_FILE="$tmp/arch-release" FORCE_PROOT=1 UNAME_M=aarch64; has 'Ranquear os mirrors'

# ─── Submenu da NVIDIA ─────────────────────────────────────────────────────────────────────────────────────────────────────────
# Arch: --proprietary não existe (o nvidia.sh recusa no driver 590): o Driver só gira entre auto e open, e não há "Fora do Arch".
run 'jjjjj\nqq'; hasnt 'Fora do Arch'; has 'Bootloader'; has 'PRIME'; has 'Snapshot'
run 'jjjjj\nj\nrs\nq'; has 'FAKE nvidia.sh install --open'; has 'instalar o driver NVIDIA'
run 'jjjjj\nrnqq';    has 'instalar o driver NVIDIA'; hasnt 'FAKE nvidia.sh'   # n cancela; o submenu segue
# Ubuntu: Driver tem proprietary, e o plano real só roda com "Fora do Arch → permitir"; o dry-run não precisa.
run 'jjjj\n\nj\n\nr\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'FAKE nvidia.sh install --dry-run --proprietary'
run 'jjjj\nqq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'Fora do Arch'
run 'jjjj\njjjjjj\nrs\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'FAKE nvidia.sh install --allow-untested'
# Bootloader, PRIME e snapshot viram os argumentos certos.
run 'jjjjj\n\njj\nr\nq'; has 'FAKE nvidia.sh install --dry-run --dkms'
run 'jjjjj\n\njjj\nr\nq'; has 'FAKE nvidia.sh install --dry-run --bootloader=grub'

# ─── Submenus do OXWM e do Caelestia ───────────────────────────────────────────────────────────────────────────────────────────
run 'jjjjjj\njj\nrs\nq'; has 'FAKE oxwm-setup.sh --dm=sddm'; has 'instalar a config. do OXWM'
run 'jjjjjj\n\nj\nr\nq'; has 'FAKE oxwm-setup.sh --dry-run --startx'
# Distro sem instalação de pacotes (void): o OXWM só copia a config do usuário, e a opção já vem fixa.
run 'jjjj\nqq' OS_RELEASE_FILE="$tmp/os-void"; has 'bash oxwm-setup.sh --sem-sistema'
run 'jjjjjjj\nrs\nq'; has 'FAKE caelestia-setup.sh'; has 'configurar o Caelestia'
run 'jjjjjjj\nj\nrs\nq'; has 'FAKE caelestia-setup.sh --so-atalhos'    # Arch: instalar + config → só config
# Fora do Arch o caelestia-setup.sh só sabe aplicar a config: --so-atalhos já vem fixo e a opção não gira.
run 'jjjjjj\nqq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'bash caelestia-setup.sh --so-atalhos'; hasnt 'instalar tudo'

# Terminal estreito (40 colunas, o Termux em pé): nenhum rótulo, valor ou descrição pode sair cortado ("…"), em nenhum sistema.
# 12 teclas "j" passam por todas as linhas de cada tela (a seleção dá a volta), então todas as descrições são desenhadas.
walk=jjjjjjjjjjjj
for os in arch endeavour ubuntu fedora alpine suse void; do
  run "${walk}q" COLUMNS=40 OS_RELEASE_FILE="$tmp/os-$os"; hasnt '…'
  for item in '' j jj jjj jjjj jjjjj jjjjjj jjjjjjj; do   # cada item do menu: abre (Enter, se for submenu), passa por todas as linhas e volta
    run "${item}\n${walk}qq" COLUMNS=40 OS_RELEASE_FILE="$tmp/os-$os"; hasnt '…'
  done
done
for env in "$TERMUX" KERNEL_RELEASE=5.15.153.1-microsoft-standard-WSL2 FORCE_PROOT=1; do
  run "${walk}q" COLUMNS=40 "$env" OS_RELEASE_FILE="$tmp/os-arch"; hasnt '…'
  for item in '' j jj jjj jjjj; do run "${item}\n${walk}qq" COLUMNS=40 "$env" OS_RELEASE_FILE="$tmp/os-arch"; hasnt '…'; done
done

# Mostrar todas as opções: o que não funciona neste sistema fica escondido; ligado (tecla a, ou Enter no item) aparece sem rodar.
# No Ubuntu o menu tem 7 itens antes de "Mostrar todas" (índice 7); ligado, "Ranquear os mirrors" entra na posição 2.
run 'q' OS_RELEASE_FILE="$tmp/os-ubuntu"; hasnt 'Ranquear os mirrors'; has 'Mostrar todas as opções: não'
run 'aq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'Ranquear os mirrors'; has 'Mostrar todas as opções: sim'
run 'jjjjjjj\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'Mostrar todas as opções: sim'; has 'Ranquear os mirrors'   # Enter no item faz o mesmo que a
# Alternar de novo volta ao menu curto, e a seleção continua no item "Mostrar todas" (o segundo Enter desliga).
run 'jjjjjjj\n\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"
[[ $(grep -o 'Mostrar todas as opções: [a-zãs]*' <<<"$out" | tail -1) == *': não' ]] || { echo "FALHOU: o segundo Enter devia desligar o mostrar-tudo"; fail=1; }
# Sem cor (dumb) o item indisponível leva ✗; os que funcionam, não.
run 'aq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has '✗ Ranquear os mirrors'; hasnt '✗ Setup completo'
# Com cor: vermelho fraco só nos indisponíveis (os disponíveis não têm essa cor), e nada de ✗.
run 'aq' TERM=xterm OS_RELEASE_FILE="$tmp/os-ubuntu"; has $'\e[38;5;131mRanquear os mirrors'; hasnt '✗'; hasnt $'\e[38;5;131mSetup completo'
# Enter num item indisponível explica o motivo e não roda nada nem pede confirmação.
run 'ajj\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'Não funciona neste sistema'; hasnt 'Tem certeza'; hasnt 'FAKE'
# Submenu: a opção indisponível aparece, não gira com Enter e não entra no comando (Repos do CachyOS é a 8ª linha no Ubuntu).
run 'a\n\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'Repos do CachyOS'; has '✗ Repos do CachyOS'
run 'a\njjjjjjj\n\nrs\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"; has 'FAKE setup.sh --sem-encerrar'; hasnt '--sem-cachyos-repo'
run 'a\njjjjjjj\n\n\033[C\nq' OS_RELEASE_FILE="$tmp/os-ubuntu"; hasnt 'pular'   # Enter e → nela não giram o valor
# Desligado, o submenu não mostra a opção.
run '\nqq' OS_RELEASE_FILE="$tmp/os-ubuntu"; hasnt 'Repos do CachyOS'
# Terminal estreito com tudo ligado: nada cortado ("…"), nem nos motivos, nem nos submenus.
for os in arch ubuntu fedora alpine; do
  run "a${walk:-jjjjjjjjjjjjjjj}q" COLUMNS=40 OS_RELEASE_FILE="$tmp/os-$os"; hasnt '…'
  for item in '' j jj jjj jjjj jjjjj jjjjjj; do run "a${item}\njjjjjjjjjjjjjjjj\nqq" COLUMNS=40 OS_RELEASE_FILE="$tmp/os-$os"; hasnt '…'; done
done
for env in "$TERMUX" KERNEL_RELEASE=5.15.153.1-microsoft-standard-WSL2 FORCE_PROOT=1; do
  run "ajjjjjjjjjjjjjjjjq" COLUMNS=40 "$env" OS_RELEASE_FILE="$tmp/os-arch"; hasnt '…'
  for item in '' j jj jjj jjjj; do run "a${item}\njjjjjjjjjjjjjjjj\nqq" COLUMNS=40 "$env" OS_RELEASE_FILE="$tmp/os-arch"; hasnt '…'; done
done

# Tela alternativa, como o nmtui/alsamixer (TERM=xterm; com TERM=dumb não há escape nenhum): o menu entra uma vez e sai
# uma vez, nunca limpa a tela inteira (o 2J era o que piscava) e o terminal sai da tela alternativa por último.
on=$'\e[?1049h' off=$'\e[?1049l'
count() { local t=${out//"$1"/}; echo $(((${#out} - ${#t}) / ${#1})); }
run 'jjq' TERM=xterm
[[ $out == "$on"* && $out == *"$off" ]] || { echo "FALHOU: o menu devia abrir com 1049h e terminar com 1049l"; fail=1; }
[[ $(count "$on") == 1 && $(count "$off") == 1 ]] || { echo "FALHOU: devia entrar e sair da tela alternativa uma vez só"; fail=1; }
hasnt $'\e[2J'; hasnt $'\e[H\e[J'
has $'\e[K'; has $'\e[?25h'   # apaga só até o fim de cada linha; o cursor volta ao sair
# O submenu fica na tela alternativa (abrir e voltar não sai dela); só rodar o script sai.
run '\nqq' TERM=xterm; [[ $(count "$on") == 1 && $(count "$off") == 1 ]] || { echo "FALHOU: o submenu devia ficar na tela alternativa"; fail=1; }
# Escolher um item: o script roda na tela normal (sai da alternativa antes, volta depois) e o menu continua.
run 'j\ns\nq' TERM=xterm
[[ $out == *"$off"*'FAKE setup.sh --dotfiles'*"$on"* ]] || { echo "FALHOU: o script devia rodar fora da tela alternativa"; fail=1; }
[[ $(count "$on") == 2 && $(count "$off") == 2 ]] || { echo "FALHOU: devia sair e voltar à tela alternativa em volta do script (h=$(count "$on") l=$(count "$off"))"; fail=1; }
# Ctrl+C no meio do menu, num terminal de verdade (pty): o terminal não pode ficar preso na tela alternativa.
if command -v python3 >/dev/null; then
  res=$(python3 - "$here/../menu.sh" "$tmp" <<'EOF'
import os, pty, select, sys, time
menu, tmp = sys.argv[1:3]
pid, fd = pty.fork()
if pid == 0:
    os.execvpe("bash", ["bash", menu], dict(os.environ, TERM="xterm", MENU_DIR=tmp, KERNEL_RELEASE="6.0.0-generic", PREFIX="", FORCE_PROOT="0"))
buf, sent, end = b"", False, time.time() + 10
while time.time() < end:
    if not select.select([fd], [], [], 0.2)[0]: continue
    try: d = os.read(fd, 4096)
    except OSError: break
    if not d: break
    buf += d
    if not sent and b"mover" in buf: os.write(fd, b"\x03"); sent = True
print("ok" if sent and buf.startswith(b"\x1b[?1049h") and buf.endswith(b"\x1b[?1049l") else "sent=%s fim=%r" % (sent, buf[-30:]))
EOF
  )
  [[ $res == ok ]] || { echo "FALHOU: Ctrl+C devia sair da tela alternativa ($res)"; fail=1; }
fi

# Script que dá certo: ✔ no fim. Título de Reiniciar (depois do "Sim") também aparece.
run 'jjjj\n\nq'; has '▶ NVIDIA: detectar GPU'; has '$ bash nvidia.sh'; has '✔ nvidia.sh terminou (código 0)'; hasnt '✖'
run 'jjjjjjjjj\ns\nq'; has '▶ Reiniciar'
# Sair do menu não deixa título nenhum para trás.
run 'jjjjjjjjjjjj\n'; hasnt '▶'

# "Sim" em Reiniciar chama o reboot (o de mentira).
run 'jjjjjjjjj\ns\nq'; has 'FAKE reboot'

# Termux e proot: Reiniciar e Desligar somem do menu; Fechar e Sair ficam. NVIDIA, OXWM e Caelestia também somem (não rodam lá).
for env in PREFIX=/data/data/com.termux/files/usr KERNEL_RELEASE=6.17.0-PRoot-Distro FORCE_PROOT=1; do
  run 'q' "$env"; hasnt 'Reiniciar'; hasnt 'Desligar'; has 'Fechar este terminal'
  hasnt 'NVIDIA'; hasnt 'OXWM'; hasnt 'Caelestia'; hasnt 'Reverter temas'; has 'Setup completo'; has 'Dotfiles'
done
# Termux: o submenu do Setup só traz o que é do Termux (e os mirrors do Termux entram no item de mirrors).
run '\nqq' "$TERMUX" OS_RELEASE_FILE="$tmp/os-empty"
has 'Mirrors do Termux'; has 'pkg update + upgrade'; has 'Repositórios extras'; has 'Arch no proot-distro'
hasnt 'Locales'; hasnt 'Temas Minecraft'; hasnt 'CachyOS'; hasnt 'core/extra'
has 'Ranquear os mirrors'
run '\njj\nrs\nq' "$TERMUX" OS_RELEASE_FILE="$tmp/os-empty"; has 'ENV SKIP_MIRRORS= SKIP_LOCALES= SKIP_TERMUX_UPGRADE=1'   # a terceira linha (pkg update + upgrade) → só o índice
# Proot de Arch: sem locales/temas (o setup.sh não faz isso lá), só mirrors e dotfiles.
run '\nqq' FORCE_PROOT=1; has 'Mirrors'; hasnt 'Locales'; hasnt 'Temas Minecraft'; hasnt 'CachyOS'; hasnt 'core/extra'

# WSL: Reiniciar não pergunta nada nem chama o reboot; mostra o wsl --shutdown. Sem GRUB (temas) e sem NVIDIA; o Setup ganha as opções do WSL.
run 'jjjjjj\n\nq' KERNEL_RELEASE=5.15.153.1-microsoft-standard-WSL2
has 'wsl --shutdown'; hasnt 'Tem certeza'; hasnt 'FAKE reboot'; hasnt 'NVIDIA'; hasnt 'Reverter temas'
run '\nqq' KERNEL_RELEASE=5.15.153.1-microsoft-standard-WSL2; has 'Kitty e fonte no Linux'; has 'Usuário padrão do WSL'; hasnt 'Temas Minecraft'; has 'Locales'
run '\njjjjj\nrs\nq' KERNEL_RELEASE=5.15.153.1-microsoft-standard-WSL2; has 'WSL_INSTALL_GUI=1'
# Fora do WSL essas opções não aparecem.
run '\nqq'; hasnt 'Kitty e fonte no Linux'; hasnt 'Usuário padrão do WSL'

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
  out=$(cd "$tmp/empty" && cat "$here/../menu.sh" | env KERNEL_RELEASE=6.0.0-generic PREFIX= FORCE_PROOT=0 OS_RELEASE_FILE="$tmp/os-arch" UNAME_M=x86_64 \
        ARCH_RELEASE_FILE="$tmp/none" "$@" MENU_TTY="$tmp/in" TERM=dumb TMPDIR="$tmp/t" FAKE_LOG="$tmp/curl.log" PATH="$tmp/fake:$PATH" bash 2>&1); rc=$?
}
fetched() { grep -o '[^/]*$' "$tmp/curl.log" | sort | tr '\n' ' '; }   # nomes dos arquivos baixados
raw=https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas
# Abrir o menu e sair não baixa nada; escolher a simulação do setup baixa só o setup.sh (do ref certo), sem tarball.
remote 'q' MENU_REF=v1
[[ $rc == 0 && ! -s $tmp/curl.log ]] || { echo "FALHOU: o menu remoto baixou algo antes de escolher: $(fetched)"; fail=1; }
remote '\n\nr\nq' MENU_REF=v1
[[ $rc == 0 ]] || { echo "FALHOU: o menu remoto saiu com $rc"; fail=1; }
has 'REMOTE setup.sh --sem-encerrar --dry-run'; has "STDIN=$tmp/in"; has 'DOTFILES_REF=v1'
[[ $(cat "$tmp/curl.log") == "$raw/v1/setup.sh" ]] || { echo "FALHOU: devia baixar só o setup.sh de v1, baixou: $(cat "$tmp/curl.log")"; fail=1; }
[[ -z $(ls -A "$tmp/t") ]] || { echo "FALHOU: a pasta temporária não foi apagada"; fail=1; }
# Abrir o submenu e voltar sem rodar também não baixa nada.
remote '\nqq'; [[ ! -s $tmp/curl.log ]] || { echo "FALHOU: só abrir o submenu baixou algo: $(fetched)"; fail=1; }
# O mesmo script duas vezes: baixa uma só.
remote '\n\nr\n\n\nr\n\nq'
[[ $(grep -c 'REMOTE setup.sh' <<<"$out") == 2 && $(grep -c . "$tmp/curl.log") == 1 ]] || { echo "FALHOU: o setup.sh devia rodar 2 vezes e ser baixado 1 (baixou: $(fetched))"; fail=1; }
# mirrors.sh usa o setup.sh ao lado, e o OXWM usa o config.lua: vêm junto; nada além disso.
remote 'jj\ns\nq';        [[ $(fetched) == "mirrors.sh setup.sh " ]]    || { echo "FALHOU: mirrors devia baixar mirrors.sh e setup.sh, baixou: $(fetched)"; fail=1; }
remote 'jjjjjj\nrs\nq';   [[ $(fetched) == "config.lua oxwm-setup.sh " ]] || { echo "FALHOU: OXWM devia baixar oxwm-setup.sh e config.lua, baixou: $(fetched)"; fail=1; }
grep -qx "$raw/main/.config/oxwm/config.lua" "$tmp/curl.log" || { echo "FALHOU: o config.lua do OXWM devia vir de .config/oxwm/ (baixou: $(cat "$tmp/curl.log" | tr '\n' ' '))"; fail=1; }
# O Caelestia usa os três arquivos de .config/caelestia/ (2 .lua e o shell.json): vêm junto; nada além disso.
remote 'jjjjjjj\nrs\nq'; [[ $(fetched) == "caelestia-setup.sh hypr-user.lua hypr-vars.lua shell.json " ]] || { echo "FALHOU: Caelestia devia baixar o script e os 3 arquivos, baixou: $(fetched)"; fail=1; }
grep -qx "$raw/main/.config/caelestia/hypr-vars.lua" "$tmp/curl.log" || { echo "FALHOU: hypr-vars.lua devia vir de .config/caelestia/ (baixou: $(tr '\n' ' ' < "$tmp/curl.log"))"; fail=1; }
# Download que falha: erro claro, o menu continua (não cai), nada roda e nada sobra em disco.
remote '\n\nr\nq' FAKE_FAIL=1
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
