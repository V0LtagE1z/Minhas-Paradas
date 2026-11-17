#!/usr/bin/env bash
# menu.sh — TUI do Minhas-Paradas: ↑/↓ (ou j/k) escolhem, Enter roda o script certo como processo filho e
# volta para esta tela. Ações que alteram o sistema pedem "Tem certeza?". Também reinicia, desliga (não no
# Termux nem no proot: lá o item some) e fecha o terminal. Como o nmtui e o alsamixer, o menu vive na tela
# alternativa do terminal: ao sair (ou com Ctrl+C) o terminal volta exatamente como estava, sem vestígios.
# Uso: bash menu.sh  (como usuário normal: os scripts pedem sudo sozinhos; o nvidia.sh recusa root)
# Sem clone: curl -fsSL https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/main/menu.sh | bash
#   Sem os outros scripts ao lado, o menu baixa (curl ou wget, sem git nem tar) só o script do item que você
#   escolher, para uma pasta temporária que some ao sair; os dotfiles o próprio setup.sh baixa, arquivo por arquivo,
#   quando precisa. MENU_REF escolhe a tag/branch/commit (padrão: main) e vale para scripts e dotfiles.
# shortcut: nada é conferido por checksum (só HTTPS do GitHub) e cada arquivo é baixado no momento em que é usado:
#   se a main andar no meio da sessão, scripts de commits diferentes se misturam. Fixe MENU_REF num commit para
#   não rodar o que a main tiver na hora. Upgrade: publicar um .sha256 por versão e conferir aqui.
# shortcut: assume terminal UTF-8 (bordas e ❯); o console do Linux sem fonte unicode mostra lixo. Upgrade: borda ASCII.

# Checagem do bash. POSIX puro de propósito: o ash do Alpine lê um comando por vez, então chega aqui
# antes de ver a sintaxe de bash lá embaixo. Com bash instalado, só reexecuta; sem ele, avisa e sai.
# Com "curl | sh" não há arquivo para reexecutar: $0 é "sh" ou o binário do shell (/bin/sh, que não começa com
# "#!"), então pede para rodar de novo com "| bash".
if [ -z "${BASH_VERSION:-}" ]; then
  if [ -f "$0" ] && [ "$(head -c 2 "$0" 2>/dev/null)" = '#!' ]; then _again="bash $0"
  else _again="curl -fsSL https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/${MENU_REF:-main}/menu.sh | bash"; fi
  if command -v bash >/dev/null 2>&1; then
    case $_again in "bash "*) exec bash "$0" "$@" ;; esac
    printf '[erro] o menu precisa rodar no bash, não no sh. Rode:\n  %s\n' "$_again" >&2
    exit 1
  fi
  if   command -v apk     >/dev/null 2>&1; then _cmd="apk add bash"
  elif command -v apt-get >/dev/null 2>&1; then _cmd="apt-get install -y bash"
  elif command -v dnf     >/dev/null 2>&1; then _cmd="dnf install -y bash"
  elif command -v zypper  >/dev/null 2>&1; then _cmd="zypper install -y bash"
  elif command -v pacman  >/dev/null 2>&1; then _cmd="pacman -S --noconfirm bash"
  else _cmd="(instale o pacote bash com o gerenciador de pacotes da sua distro)"
  fi
  printf '[erro] o menu precisa do bash, e ele não está instalado.\n  Instale como root (ou com sudo/doas na frente):\n    %s\n  Depois rode: %s\n' "$_cmd" "$_again" >&2
  exit 1
fi

# Lê as teclas do terminal (e não do stdin, que no "curl | bash" é o próprio script).
# MENU_TTY existe só para o teste (tests/menu.test.sh) alimentar as teclas.
{ exec 3<"${MENU_TTY:-/dev/tty}"; } 2>/dev/null || { echo "[erro] o menu precisa de um terminal" >&2; exit 1; }

# Sem locale UTF-8 (rootfs mínimo de proot) o bash conta bytes e as bordas desalinham com acentos.
case ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;; *) LC_ALL=C.UTF-8 ;; esac

# Terminal e cores (salmão/laranja). O menu vive na tela alternativa (1049, a do nmtui/alsamixer) e cada quadro é
# desenhado por cima do anterior: cursor no canto e "apagar até o fim da linha" em cada linha. Limpar a tela
# inteira a cada tecla era o que piscava. Terminal "dumb" ou NO_COLOR: sem cor, sem tela alternativa e sem
# apagar nada (cada quadro sai embaixo do anterior).
if [[ -n ${NO_COLOR:-} || ${TERM:-dumb} == dumb ]]; then
  ALT_ON="" ALT_OFF="" GOHOME="" EOL="" EOS="" NL=$'\n' HIDE="" SHOW="" ACC="" REV="" OFF="" RED=""
else
  ALT_ON=$'\e[?1049h' ALT_OFF=$'\e[?1049l' GOHOME=$'\e[H' EOL=$'\e[K' EOS=$'\e[J' NL="" HIDE=$'\e[?25l' SHOW=$'\e[?25h'
  ACC=$'\e[38;5;209m' REV=$'\e[7m' OFF=$'\e[0m'
  RED=$'\e[38;5;131m'   # vermelho apagado (legível em fundo claro e escuro): o que não funciona neste sistema
fi
INALT=0
alt_on()  { printf '%s%s' "$ALT_ON" "$HIDE"; INALT=1; }
alt_off() { ((INALT)) || return 0; printf '%s%s' "$SHOW" "$ALT_OFF"; INALT=0; }   # só sai se entrou: 1049l solto move o cursor
TMP_REPO=""   # pasta do repo baixado (rota remota); apagada ao sair
# EXIT também roda em Ctrl+C e kill (o bash executa o trap de EXIT ao morrer por sinal): o terminal nunca fica preso na tela alternativa.
trap 'alt_off; [[ -z $TMP_REPO ]] || rm -rf -- "$TMP_REPO"' EXIT

# ─── De onde vêm os scripts ───────────────────────────────────────────────────
MENU_REF=${MENU_REF:-main}
export DOTFILES_REF=${DOTFILES_REF:-$MENU_REF}   # o setup.sh baixa os dotfiles do mesmo ref dos scripts
RAW_URL="https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/$MENU_REF"
# Local: os scripts ficam ao lado do menu. Sem setup.sh ali (curl | bash, ou só o menu.sh baixado): rota remota,
# em que cada script só é baixado quando o item é escolhido (need). MENU_DIR existe só para o teste.
if [[ -n ${MENU_DIR:-} ]]; then DIR=$MENU_DIR
else
  DIR=""; [[ -f ${BASH_SOURCE[0]:-} ]] && DIR=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
  if [[ -z $DIR || ! -f $DIR/setup.sh ]]; then
    if   command -v curl >/dev/null 2>&1; then dl=(curl -fsSL --retry 3 --connect-timeout 20 -o)
    elif command -v wget >/dev/null 2>&1; then dl=(wget -q -O)
    else echo "[erro] para rodar sem clone o menu precisa de curl ou wget (ou clone o repo e rode bash menu.sh)" >&2; exit 1; fi
    TMP_REPO=$(mktemp -d "${TMPDIR:-/tmp}/minhas-paradas.XXXXXX") || exit 1   # TMPDIR: o Termux não tem /tmp
    DIR=$TMP_REPO
  fi
fi
need() {  # arquivos... — rota remota: baixa para $DIR o que ainda não está lá; localmente não faz nada
  local f
  [[ -n $TMP_REPO ]] || return 0
  for f in "$@"; do
    [[ -s $DIR/$f ]] && continue
    echo "[menu] baixando $f ($MENU_REF)..." >&2
    mkdir -p -- "$(dirname -- "$DIR/$f")"   # arquivos em subpasta (.config/oxwm/config.lua)
    "${dl[@]}" "$DIR/$f" "$RAW_URL/$f" && [[ -s $DIR/$f ]] \
      || { rm -f -- "$DIR/$f"; echo "[erro] não consegui baixar $RAW_URL/$f (MENU_REF=$MENU_REF existe?)" >&2; return 1; }
  done
}

# ─── Ambiente ─────────────────────────────────────────────────────────────────
# KERNEL_RELEASE e FORCE_PROOT são os mesmos nomes do setup.sh (aqui também servem ao teste).
is_wsl() { local k=${KERNEL_RELEASE:-$(uname -r)}; [[ ${k,,} == *microsoft* || ${k,,} == *wsl* ]]; }

is_proot() {
  local k=${KERNEL_RELEASE:-$(uname -r)}
  [[ ${FORCE_PROOT:-} == 1 || ${k,,} == *proot* ]] && return 0
  # no proot o processo é rastreado por ptrace; sob strace/gdb isto também dá "sim" (só esconde os itens)
  [[ ${FORCE_PROOT:-} != 0 ]] && grep -qs '^TracerPid:[[:space:]]*[1-9]' "/proc/$$/status"
}
is_termux() { [[ ${PREFIX:-} == *com.termux* ]]; }
no_power() { is_termux || is_proot; }   # Termux e proot não têm o que reiniciar/desligar: os itens somem do menu

# Qual sistema é este: decide que itens e opções aparecem (o que não funciona aqui só aparece em vermelho, com "mostrar todas").
# OS_RELEASE_FILE, ARCH_RELEASE_FILE e UNAME_M são os mesmos nomes do setup.sh (aqui também servem ao teste).
os_field() {  # CAMPO — valor do os-release em minúsculas, sem aspas (vazio se não achar)
  local f=${OS_RELEASE_FILE:-/etc/os-release}
  [[ -r $f ]] || f=/usr/lib/os-release
  [[ -r $f ]] || return 0
  sed -nE "s/^$1=\"?([^\"]*)\"?[[:space:]]*\$/\1/p" "$f" | head -1 | tr '[:upper:]' '[:lower:]'
}
SYS_ID=$(os_field ID); SYS_LIKE=$(os_field ID_LIKE); ARCH_M=${UNAME_M:-$(uname -m)}
IS_PROOT=0; is_proot && IS_PROOT=1
IS_TERMUX=0; ((IS_PROOT)) || { is_termux && IS_TERMUX=1; }   # no proot dentro do Termux o PREFIX vaza: o proot decide primeiro
DESKTOP=0; ((IS_PROOT || IS_TERMUX)) || DESKTOP=1             # distro de verdade (mesmo critério do is_desktop do setup.sh)
case " $SYS_ID $SYS_LIKE " in   # família: o ID_LIKE cobre as derivadas (EndeavourOS, Manjaro, Mint, Alma...)
  *" arch "*) FAM=arch ;;
  *" debian "*|*" ubuntu "*) FAM=debian ;;
  *" fedora "*|*" rhel "*) FAM=fedora ;;
  *" suse "*|*" opensuse "*) FAM=suse ;;
  *" alpine "*) FAM=alpine ;;
  *) FAM=other; [[ -e ${ARCH_RELEASE_FILE:-/etc/arch-release} ]] && FAM=arch ;;   # imagem sem os-release (ALARM no proot)
esac
((IS_TERMUX)) && FAM=termux

# O que cada item precisa (o que o script de trás recusaria ou não faria):
can_mirrors() { ((IS_TERMUX)) || [[ $FAM == arch ]] || { ((DESKTOP)) && [[ $FAM == fedora ]]; }; }   # Debian/Ubuntu/SUSE/Alpine: nada para ranquear
can_cachy()   { ((DESKTOP)) && [[ $SYS_ID == arch || $SYS_ID == endeavouros ]] && [[ $ARCH_M == x86_64 ]]; }   # os repos do CachyOS: só Arch puro (e EndeavourOS) x86_64
can_themes()  { ((DESKTOP)) && ! is_wsl && [[ $FAM != alpine ]]; }                                  # GRUB/Plymouth: sem bootloader no WSL, sem mkinitcpio/dracut no Alpine
can_nvidia()  { ((DESKTOP)) && ! is_wsl; }                                                            # o nvidia.sh recusa Termux, proot e WSL
can_nvidia_install() { can_nvidia && [[ $FAM == arch || $FAM == debian || $FAM == fedora ]]; }       # e só instala em Arch, Debian/Ubuntu e Fedora

# ─── Ações ────────────────────────────────────────────────────────────────────
rule() {  # texto — linha de título, larga como o menu: marca onde começa e termina a saída de cada comando (que sai na tela normal)
  local rows cols t=" $1 " d
  size; ((cols > 72)) && cols=72; ((cols < 36)) && cols=36
  ((${#t} > cols - 6)) && t="${t:0:cols-9}… "
  printf -v d '%*s' $((cols - 4 - ${#t})) ''
  printf '\n%s━━%s%s%s\n' "$ACC" "$t" "${d// /━}" "$OFF"
}

show_cmd() {  # script [VAR=valor | args...] — o comando como se digita: as variáveis na frente, depois "bash script args"
  local s=$1 a e="" r=""; shift
  for a; do if [[ $a =~ ^[A-Z][A-Z0-9_]*= ]]; then e+="$a "; else r+=" $a"; fi; done
  printf '%sbash %s%s' "$e" "$s" "$r"
}

run_script() {  # script [VAR=valor | args...] — roda como filho: um die/exit do script não derruba o menu
  local s=$1 rc a; shift
  local -a deps=("$s") envs=() args=()
  for a; do if [[ $a =~ ^[A-Z][A-Z0-9_]*= ]]; then envs+=("$a"); else args+=("$a"); fi; done
  rule "▶ $TITLE"; printf '$ %s\n\n' "$(show_cmd "$s" "$@")"   # o comando exato, para saber o que está rodando
  case $s in   # o que o script usa ao lado
    mirrors.sh) deps+=(setup.sh) ;;
    oxwm-setup.sh) deps+=(.config/oxwm/config.lua) ;;
    caelestia-setup.sh) deps+=(.config/caelestia/hypr-vars.lua .config/caelestia/hypr-user.lua .config/caelestia/shell.json) ;;
  esac
  need "${deps[@]}" || return 0
  [[ -f $DIR/$s ]] || { echo "[erro] não achei $DIR/$s"; return; }
  # stdin = terminal: no "curl | bash" o stdin é o pipe, e setup.sh/nvidia.sh recusam rodar sem terminal ([[ -t 0 ]])
  env "${envs[@]}" bash "$DIR/$s" "${args[@]}" <&3; rc=$?
  rule "$( ((rc)) && echo ✖ || echo ✔ ) $s terminou (código $rc)"
}

power() {  # reboot|poweroff  verbo — o menu já perguntou "Tem certeza?"
  rule "▶ $TITLE"
  if is_wsl; then   # reboot/poweroff aqui não fazem nada: quem manda na distro é o Windows
    echo "[!!] No WSL não dá para $2 por aqui. No Windows (PowerShell ou CMD) rode: wsl --shutdown"
    echo "     (isso para todas as distros WSL; depois é só abrir a distro de novo)"
    return
  fi
  local su=""
  ((EUID)) && su=$(command -v sudo || command -v doas)   # doas: Alpine sem sudo
  $su "$1" || echo "[!!] não consegui $2 (em container isso não existe)."
}

close_terminal() {
  # "exit" aqui só encerraria o menu; fechar o terminal é mandar SIGHUP ao shell que o chamou.
  case $(cat "/proc/$PPID/comm" 2>/dev/null) in
    bash|zsh|sh|ash|dash|ksh|fish) kill -HUP "$PPID"; exit 0 ;;
    *) rule "▶ $TITLE"; echo "[!!] não achei com segurança o shell que chamou o menu (sudo?); digite 'exit' ou feche o terminal." ;;
  esac
}

pause() { printf '\nEnter para voltar ao menu... '; read -r -u 3 _ || exit 0; }

# ─── Itens: condição | motivo | rótulo | descrição (2 linhas separadas por "|") | "Tem certeza que deseja <isto>?" (vazio = sem pergunta) | comando
# Comando "sub:nome" abre o submenu de opções (sub_nome monta as opções deste sistema); "toggle_all" liga/desliga o mostrar-tudo.
# O que não funciona neste sistema (a condição, avaliada com eval, falha) só entra no menu com "Mostrar todas as opções":
# em vermelho fraco, com o motivo na descrição, e sem rodar. AV é 1 se funciona aqui e 0 se não.
SHOWALL=0
LBL=(); DESC=(); CONF=(); CMD=(); AV=(); WHY=()
item() {
  local ok=1; eval "$1" || ok=0
  ((ok || SHOWALL)) || return 0
  LBL+=("$3"); DESC+=("$4"); CONF+=("$5"); CMD+=("$6"); AV+=("$ok"); WHY+=("$2")
}
build_menu() {
  local nv_why="WSL, Termux, proot" c_reb="reiniciar o computador" c_off="desligar o computador" all=não
  LBL=(); DESC=(); CONF=(); CMD=(); AV=(); WHY=()
  can_nvidia && nv_why="só Arch, Debian/Ubuntu, Fedora"
  item true "" "Setup completo" "Escolha as opções e rode o setup|(simular, repos, temas...)" "" "sub:setup"
  item true "" "Dotfiles: só aplicar" "Baixa e aplica .zshrc, p10k e|kitty.conf (backup .bak)" "aplicar só os dotfiles" "run_script setup.sh --dotfiles"
  item can_mirrors "Arch, Fedora e Termux" "Ranquear os mirrors" "Ranqueia os mirrors; no Arch|também atualiza o sistema" "ranquear os mirrors" "run_script mirrors.sh"
  item can_themes "WSL, Alpine, Termux, proot-distro" "Reverter temas Minecraft" "Desfaz os temas Minecraft|(GRUB + Plymouth)" "reverter os temas Minecraft" "run_script setup.sh --reverter-temas"
  item can_nvidia "WSL, Termux, proot" "NVIDIA: detectar GPU" "Detecta a GPU e o ambiente|(só leitura)" "" "run_script nvidia.sh"
  item can_nvidia_install "$nv_why" "NVIDIA: instalar driver" "Escolha as opções e instale o|driver NVIDIA (simular, PRIME...)" "" "sub:nvidia"
  item '((DESKTOP))' "não roda no Termux nem proot" "OXWM: instalar configuração" "Escolha as opções (startx, login)|e instale a config. do OXWM" "" "sub:oxwm"
  item '((DESKTOP))' "não roda no Termux nem proot" "Caelestia: instalar + atalhos" "Escolha as opções e instale o|Caelestia, ou só a config (Arch)" "" "sub:caelestia"
  NINST=${#LBL[@]}
  ((SHOWALL)) && all=sim
  is_wsl && { c_reb=""; c_off=""; }   # no WSL só aparece o aviso
  item true "" "Mostrar todas as opções: $all" "Inclui o que não funciona aqui|em vermelho fraco, sem rodar" "" toggle_all
  item '! no_power' "Termux e proot não têm isso" "Reiniciar" "Reinicia o computador|(pede sudo ou doas)" "$c_reb" "power reboot reiniciar"
  item '! no_power' "Termux e proot não têm isso" "Desligar"  "Desliga o computador|(pede sudo ou doas)"  "$c_off" "power poweroff desligar"
  item true "" "Fechar este terminal" "Fecha este terminal|(SIGHUP no shell que chamou)" "fechar este terminal" close_terminal
  item true "" "Sair do menu"         "Sai só do menu|o terminal continua aberto"        ""                      "exit 0"
  N=${#LBL[@]}
}
toggle_all() {  # liga/desliga o mostrar-tudo e refaz o menu, mantendo a seleção no mesmo item (se ele ainda existir)
  local c=${CMD[sel]} i
  SHOWALL=$((1 - SHOWALL)); build_menu; sel=0
  for ((i = 0; i < N; i++)); do [[ ${CMD[i]} == "$c" ]] && sel=$i; done
}
build_menu

# ─── Desenho ──────────────────────────────────────────────────────────────────
size() {  # define rows e cols (o chamador os declara local): o tamanho do terminal; sem tty (teste) vale COLUMNS/LINES, senão 60 e 0
  read -r rows cols < <(stty size <&3 2>/dev/null)
  [[ $cols =~ ^[0-9]+$ ]] || { cols=${COLUMNS:-60}; rows=${LINES:-0}; }
  [[ $cols =~ ^[0-9]+$ ]] || cols=60
  [[ $rows =~ ^[0-9]+$ ]] || rows=0
}
layout() {  # altura (em linhas) do que vai ser desenhado — define W (largura da caixa) e LP (margem esquerda) e imprime a margem de cima
  local rows cols m
  size
  W=$cols; ((W > 72)) && W=72; ((W < 36)) && W=36
  m=$(((cols - W) / 2)); ((m < 0)) && m=0
  printf -v LP '%*s' "$m" ''
  m=$(((rows - $1) / 2)); ((m > 0)) || return 0   # terminal baixo demais: começa no topo
  printf -v m '%*s' "$m" ''; printf '%s' "${m// /$'\n'}"
}
box_top() {  # título — W é a largura da caixa, LP a margem esquerda
  local t=" $1 " d; printf -v d '%*s' $((W - 3 - ${#t})) ''
  printf '%s%s╭─%s%s╮%s\n' "$LP" "$ACC" "$t" "${d// /─}" "$OFF"
}
box_bottom() { local d; printf -v d '%*s' $((W - 2)) ''; printf '%s%s╰%s╯%s\n' "$LP" "$ACC" "${d// /─}" "$OFF"; }
box_row() {  # texto [1 = selecionado] [1 = não funciona aqui: vermelho fraco]
  local t=$1 m="  " st="" en="" pad
  ((${#t} > W - 6)) && t="${t:0:W-7}…"
  if [[ ${2:-} == 1 ]]; then m="${ACC}❯${OFF} "; st=$REV; en=$OFF; fi
  if [[ ${3:-} == 1 ]]; then   # não funciona aqui: vermelho fraco; sem cor (dumb/NO_COLOR) um ✗ no lugar do ❯, que não custa largura
    st+=$RED; en=$OFF
    [[ -n $RED || ${2:-} == 1 ]] || m="✗ "
  fi
  printf -v pad '%*s' $((W - 6 - ${#t})) ''
  printf '%s%s│%s %s%s%s%s%s %s│%s\n' "$LP" "$ACC" "$OFF" "$m" "$st" "$t" "$pad" "$en" "$ACC" "$OFF"
}

paint() {  # quadro — o quadro todo sai de uma vez, por cima do anterior; $NL só no terminal "dumb" (sem cursor para voltar)
  printf '%s%s%s%s%s' "$GOHOME" "${1//$'\n'/$EOL$'\n'}" "$EOL" "$EOS" "$NL"
}

draw() {
  local i d1 d2
  if ((${AV[sel]})); then d1=${DESC[sel]%%|*}; d2=${DESC[sel]#*|}; else d1="Não funciona neste sistema:"; d2=${WHY[sel]}; fi
  paint "$(
    layout $((N + 9))   # 3 caixas (N itens + 2 bordas cada, +2 linhas de descrição) + a linha de teclas
    box_top "Minhas-Paradas"
    for ((i = 0; i < NINST; i++)); do box_row "${LBL[i]}" $((i == sel)) $((!${AV[i]})); done
    box_bottom
    box_top "Sistema"
    for ((i = NINST; i < N; i++)); do box_row "${LBL[i]}" $((i == sel)) $((!${AV[i]})); done
    box_bottom
    box_top "Descrição"; box_row "$d1"; box_row "$d2"; box_bottom
    printf '%s ↑↓ mover   Enter escolher   a todas   q sair\n' "$LP"
  )"
}

key() {  # lê uma tecla do terminal (fd 3) → KEY: up down left right enter esc, ou o próprio caractere
  local k r=""
  IFS= read -rsn1 -u 3 k || exit 0   # fim da entrada = sair
  case $k in
    $'\e')
      IFS= read -rsn2 -t 0.05 -u 3 r   # setas chegam como ESC [ A; um ESC sozinho não traz mais nada
      case $r in '[A'|OA) KEY=up ;; '[B'|OB) KEY=down ;; '[C'|OC) KEY=right ;; '[D'|OD) KEY=left ;; '') KEY=esc ;; *) KEY=other ;; esac ;;
    '') KEY=enter ;;
    *) KEY=$k ;;
  esac
}

confirm() {  # ação — "Tem certeza que deseja <ação>?"; o padrão é Não
  local yes=0 a b
  while :; do
    if ((yes)); then a="[ Sim ]"; b="  Não  "; else a="  Sim  "; b="[ Não ]"; fi
    paint "$(
      layout 8   # 7 linhas da caixa + a linha de teclas
      box_top "Confirmar"; box_row ""; box_row "Tem certeza que deseja"; box_row "$1?"; box_row ""
      box_row "$a    $b"; box_bottom
      printf '%s ←→ escolher  Enter ok  Esc cancela\n' "$LP"
    )"
    key
    case $KEY in
      left|right|h|l|$'\t') yes=$((1 - yes)) ;;
      s|S|y|Y) return 0 ;;
      n|N|q|esc) return 1 ;;
      enter) return $((1 - yes)) ;;
    esac
  done
}

# ─── Submenus ─────────────────────────────────────────────────────────────────
# Um submenu é uma lista de opções. Cada opção gira entre valores (←/→, Espaço ou Enter) e cada valor vira nada ("-"),
# um argumento (--dry-run) ou uma variável de ambiente (SKIP_LOCALES=1) na linha de comando que o menu monta, mostra
# embaixo e passa ao run_script. Só entra a opção que funciona neste sistema (quem monta decide); com "mostrar todas" as
# outras entram em vermelho fraco, sem girar e sem contar na linha de comando (SU guarda o motivo; vazio = funciona).
SL=() SD=() SN=() SA=() SV=() SU=() SUB_BASE=() RUN=()
SUB_SCRIPT="" SUB_CONF=""
sub_reset() { SL=() SD=() SN=() SA=() SV=() SU=() SUB_BASE=() RUN=() SUB_SCRIPT="" SUB_CONF=""; }
# rótulo | "linha 1|linha 2" da descrição | "valor|valor" (o primeiro é o padrão) | "argumento|argumento" ("-" = nada)
sopt() { SL+=("$1"); SD+=("$2"); SN+=("$3"); SA+=("$4"); SV+=(0); SU+=(""); }
# opção que só vale em certos sistemas: condição (eval) | motivo | e os mesmos quatro de cima
sopt_if() {
  local ok=1; eval "$1" || ok=0
  ((ok || SHOWALL)) || return 0
  sopt "${@:3}"; ((ok)) || SU[${#SU[@]} - 1]=$2
}
nth()  { local IFS='|' a; read -ra a <<<"$1"; printf '%s' "${a[$2]}"; }   # lista "a|b|c" e índice → o item
cnt()  { local IFS='|' a; read -ra a <<<"$1"; echo "${#a[@]}"; }          # lista → quantos itens

compose() {  # monta RUN (script, base e o valor atual de cada opção)
  local i a
  RUN=("$SUB_SCRIPT" "${SUB_BASE[@]}")
  for ((i = 0; i < ${#SL[@]}; i++)); do
    [[ -z ${SU[i]} ]] || continue   # não funciona aqui: não entra no comando
    a=$(nth "${SA[i]}" "${SV[i]}"); [[ $a == - ]] || RUN+=("$a")
  done
}

sub_setup() {
  sub_reset; SUB_SCRIPT=setup.sh; SUB_BASE=(--sem-encerrar); SUB_CONF="rodar o setup completo"
  sopt "Simular (dry-run)" "Mostra o que o setup faria|sem alterar nada no sistema" "não|sim" "-|--dry-run"
  sopt_if '((IS_TERMUX))' "só no Termux" "Mirrors do Termux" "Usa os mais rápidos; manter deixa|o que o termux-change-repo pôs" "ranquear|manter" "-|SKIP_TERMUX_MIRROR=1"
  sopt_if '((IS_TERMUX))' "só no Termux" "pkg update + upgrade" "Atualiza o Termux antes de tudo;|a outra só atualiza o índice" "completo|só o índice" "-|SKIP_TERMUX_UPGRADE=1"
  sopt_if '((IS_TERMUX))' "só no Termux" "Repositórios extras" "x11-repo, root-repo e tur-repo|(o tur-repo não é oficial)" "habilitar|pular" "-|SKIP_TERMUX_REPOS=1"
  sopt_if '((IS_TERMUX))' "só no Termux" "Arch no proot-distro" "Instala o Arch dentro do Termux|(o proot-distro vem sempre)" "instalar|pular" "-|SKIP_TERMUX_PROOT=1"
  sopt_if '((! IS_TERMUX)) && can_mirrors' "só em Arch e Fedora" "Mirrors" "Ranqueia antes de instalar|(no Arch, também atualiza tudo)" "ranquear|pular" "-|SKIP_MIRRORS=1"
  sopt_if '((DESKTOP)) && [[ $FAM == arch ]]' "só em distro Arch de verdade" "core/extra/multilib" "Garante os três repositórios|ativos no pacman.conf" "ajustar|não mexer" "-|SKIP_PACMAN_REPOS=1"
  sopt_if can_cachy "só Arch ou EndeavourOS x86_64" "Repos do CachyOS" "Instala os repositórios do CachyOS|(snapshot antes, se tiver snapper)" "instalar|pular" "-|--sem-cachyos-repo"
  sopt_if '((DESKTOP)) && [[ $SYS_ID == fedora && $ARCH_M == x86_64 ]] && ! is_wsl' "só Fedora x86_64 (fora do WSL)" "Kernel do CachyOS" "Kernel do CachyOS (COPR); o do|Fedora continua no menu do GRUB" "perguntar|instalar|pular" "-|--kernel-cachyos|--sem-kernel-cachyos"
  sopt_if can_themes "WSL, Alpine, Termux, proot-distro" "Temas Minecraft" "GRUB + Plymouth; mexe no|bootloader e no initramfs" "perguntar|instalar|pular" "-|--temas-minecraft|--sem-temas-minecraft"
  sopt_if '((DESKTOP))' "só em distro de verdade" "Locales" "Gera pt_BR e en_US (UTF-8) e grava|LANG e LC_MESSAGES" "gerar|pular" "-|SKIP_LOCALES=1"
  sopt_if '((DESKTOP)) && [[ $FAM == alpine ]]' "só no Alpine" "Repositório community" "Habilita o community em|/etc/apk/repositories" "habilitar|manter" "-|SKIP_APK_REPOS=1"
  sopt_if '((DESKTOP)) && is_wsl' "só no WSL" "Kitty e fonte no Linux" "No WSL o terminal e a fonte são|os do Windows; instalar é opcional" "não|instalar" "-|WSL_INSTALL_GUI=1"
  sopt_if '((DESKTOP)) && is_wsl' "só no WSL" "Usuário padrão do WSL" "Faz o WSL abrir direto no|novo usuário (wsl.conf)" "definir|não mexer" "-|WSL_SET_DEFAULT_USER=0"
  sopt "Dotfiles" "Baixa só os arquivos necessários|ou clona o repo (para editar)" "baixar|clonar o repo" "-|--clonar-repo"
}

sub_nvidia() {
  sub_reset; SUB_SCRIPT=nvidia.sh; SUB_BASE=(install); SUB_CONF="instalar o driver NVIDIA"
  sopt "Simular (dry-run)" "Mostra o plano da instalação|sem alterar nada" "não|sim" "-|--dry-run"
  if [[ $FAM == arch ]]; then   # no driver 590 o Arch só tem o nvidia-open: o nvidia.sh recusa --proprietary lá
    sopt "Driver" "auto escolhe pela GPU; open usa|os módulos abertos" "auto|open" "-|--open"
  else
    sopt "Driver" "auto: pela GPU; open: módulos|abertos; proprietary: o fechado" "auto|open|proprietary" "-|--open|--proprietary"
  fi
  sopt "Módulo do kernel" "Pacote da distro ou DKMS|(compila para cada kernel)" "pacote|DKMS" "-|--dkms"
  sopt "Bootloader" "Onde pôr o modeset; auto acha|o GRUB ou o Limine" "auto|GRUB|Limine|nenhum" "-|--bootloader=grub|--bootloader=limine|--bootloader=none"
  sopt "PRIME (notebook)" "Configura a GPU híbrida|(offload), se houver" "configurar|pular" "-|--no-prime"
  sopt "Snapshot (snapper)" "Snapshot antes de instalar,|se o snapper existir" "tirar|pular" "-|--no-snapshot"
  sopt_if '[[ $FAM != arch ]]' "só fora do Arch" "Fora do Arch" "Instalação real aqui ainda não foi|validada; sem isto o script recusa" "só simular|permitir" "-|--allow-untested"
}

sub_oxwm() {
  sub_reset; SUB_SCRIPT=oxwm-setup.sh; SUB_CONF="instalar a config. do OXWM"
  sopt "Simular (dry-run)" "Mostra o que seria feito|sem alterar nada" "não|sim" "-|--dry-run"
  sopt "Iniciar com startx" "Cria o ~/.xinitrc que|inicia o OXWM" "não|sim" "-|--startx"
  sopt "Gerenciador de login" "Instala e habilita; sem startx nem|login marcados, o script pergunta" "padrão|SDDM|LightDM" "-|--dm=sddm|--dm=lightdm"
  case $FAM in
    arch|debian|fedora|suse|alpine) sopt "Só arquivos do usuário" "Sem pacotes, sem /etc e|sem gerenciador de login" "não|sim" "-|--sem-sistema" ;;
    *) sopt "Só arquivos do usuário" "Sem instalação de pacotes aqui:|só a config do usuário" "sim" "--sem-sistema" ;;
  esac
}

sub_caelestia() {
  sub_reset; SUB_SCRIPT=caelestia-setup.sh; SUB_CONF="configurar o Caelestia"
  sopt "Simular (dry-run)" "Mostra o que seria feito|sem alterar nada" "não|sim" "-|--dry-run"
  if [[ $FAM == arch ]]; then
    sopt "O que fazer" "Tudo: caelestia-cli (AUR) + config|ou só aplica a config e os atalhos" "instalar tudo|só config" "-|--so-atalhos"
  else   # o caelestia-cli vem do AUR: fora do Arch o script só aplica a config e os atalhos
    sopt "O que fazer" "A instalação é só no Arch (AUR);|aqui: só a config e os atalhos" "só config" "--so-atalhos"
  fi
}

sub_go() {  # 0 = pode rodar (antes confirma, se vai alterar o sistema); 1 = não
  compose
  [[ -z $SUB_CONF || " ${RUN[*]} " == *" --dry-run "* ]] || confirm "$SUB_CONF"
}

sub_draw() {  # ssel (do submenu): 0..n-1 são as opções, n é "Executar" e n+1 é "Voltar"
  local n=${#SL[@]}
  compose
  paint "$(
    local i x lw=0 mv=0 arrows=0 v pad d1 d2 w cmd
    local -a vs
    cmd=$(show_cmd "${RUN[@]}")
    for ((i = 0; i < n; i++)); do
      ((${#SL[i]} > lw)) && lw=${#SL[i]}
      IFS='|' read -ra vs <<<"${SN[i]}"
      for x in "${vs[@]}"; do ((${#x} > mv)) && mv=${#x}; done
    done
    if ((ssel < n)) && [[ -n ${SU[ssel]} ]]; then d1="Não funciona neste sistema:"; d2=${SU[ssel]}
    elif ((ssel < n)); then d1=${SD[ssel]%%|*}; d2=""; [[ ${SD[ssel]} == *'|'* ]] && d2=${SD[ssel]#*|}
    elif ((ssel == n)); then d1="Roda o comando mostrado abaixo"; d2="Enter aqui ou r em qualquer linha"
    else d1="Volta ao menu sem rodar nada"; d2=""; fi
    layout $((n + 14))   # caixa das opções (n + 3 linhas + 2 bordas), descrição (4), comando (4) e a linha de teclas
    w=$((W - 6))
    ((lw + 3 + mv + 4 <= w)) && arrows=1   # as setas ‹ › só entram se o maior valor ainda couber (terminal estreito: valor puro, não cortado)
    box_top "$TITLE"
    for ((i = 0; i < n; i++)); do
      v=$(nth "${SN[i]}" "${SV[i]}")
      if ((arrows)); then (($(cnt "${SN[i]}") > 1)) && [[ -z ${SU[i]} ]] && v="‹ $v ›" || v="  $v"; fi   # sem setas no que não gira
      printf -v pad '%*s' $((lw - ${#SL[i]})) ''
      box_row "${SL[i]}$pad   $v" $((i == ssel)) $((${#SU[i]} > 0))
    done
    box_row ""; box_row "▶ Executar" $((ssel == n)); box_row "← Voltar" $((ssel == n + 1)); box_bottom
    box_top "Descrição"; box_row "$d1"; box_row "$d2"; box_bottom
    box_top "Comando"; box_row "${cmd:0:w}"; box_row "${cmd:w:w}"; box_bottom
    printf '%s ↑↓ mover  ←→ mudar  r rodar  q voltar\n' "$LP"
  )"
}

submenu() {  # 0 = rodar (RUN pronto), 1 = voltar ao menu; começa na primeira opção (a simulação)
  local n=${#SL[@]} ssel=0 c d
  while :; do
    sub_draw
    key
    case $KEY in
      up|k)   ssel=$(((ssel + n + 1) % (n + 2))) ;;
      down|j) ssel=$(((ssel + 1) % (n + 2))) ;;
      left|h|right|l|' '|enter)
        if ((ssel < n)); then
          [[ -z ${SU[ssel]} ]] || continue   # em vermelho: não funciona aqui, não gira
          d=1; [[ $KEY == left || $KEY == h ]] && d=-1
          c=$(cnt "${SN[ssel]}"); SV[ssel]=$(((SV[ssel] + c + d) % c))
        elif [[ $KEY == enter ]]; then
          ((ssel == n)) || return 1
          sub_go && return 0
        fi ;;
      r) sub_go && return 0 ;;
      q|esc) return 1 ;;
    esac
  done
}

# ─── Laço principal ───────────────────────────────────────────────────────────
sel=0
alt_on
while :; do
  draw
  key
  case $KEY in
    up|k)   sel=$(((sel + N - 1) % N)) ;;
    down|j) sel=$(((sel + 1) % N)) ;;
    a) toggle_all ;;
    enter|' ')
      ((${AV[sel]})) || continue   # em vermelho: não funciona aqui (a descrição diz por quê)
      if [[ ${CMD[sel]} == toggle_all ]]; then toggle_all; continue; fi
      if [[ ${CMD[sel]} == sub:* ]]; then   # submenu: as opções e o "Tem certeza" ficam lá dentro
        TITLE=${LBL[sel]}
        "sub_${CMD[sel]#sub:}"
        submenu || continue
        alt_off; run_script "${RUN[@]}"; pause; alt_on
        continue
      fi
      [[ -z ${CONF[sel]} ]] || confirm "${CONF[sel]}" || continue
      TITLE=${LBL[sel]}
      alt_off   # o script roda na tela normal: a saída dele fica no terminal (e no scrollback) em vez de sumir com o menu
      ${CMD[sel]}
      pause
      alt_on ;;
    q) exit 0 ;;
  esac
done
