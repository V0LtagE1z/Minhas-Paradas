#!/usr/bin/env bash
# menu.sh — TUI do Minhas-Paradas: ↑/↓ (ou j/k) escolhem, Enter roda o script certo como processo filho e
# volta para esta tela. Ações que alteram o sistema pedem "Tem certeza?". Também reinicia, desliga (não no
# Termux nem no proot: lá o item some) e fecha o terminal.
# Uso: bash menu.sh   (como usuário normal: os scripts pedem sudo sozinhos; o nvidia.sh recusa root)
# Sem clone: curl -fsSL https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/main/menu.sh | bash
#   Sem os outros scripts ao lado, o menu baixa o tarball do repo (curl ou wget + tar, sem git) para uma pasta
#   temporária, usa os scripts de lá e apaga a pasta ao sair. MENU_REF escolhe a tag/branch/commit (padrão: main).
# shortcut: o tarball não é conferido por checksum (só HTTPS do GitHub); fixe MENU_REF num commit para não rodar
#   o que a main tiver na hora. Upgrade: publicar um .sha256 por versão e conferir aqui.
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

# Cores (salmão/laranja). Terminal "dumb" ou NO_COLOR: sem cor e sem limpar a tela.
if [[ -n ${NO_COLOR:-} || ${TERM:-dumb} == dumb ]]; then CLS="" HIDE="" SHOW="" ACC="" REV="" OFF=""
else CLS=$'\e[H\e[2J' HIDE=$'\e[?25l' SHOW=$'\e[?25h' ACC=$'\e[38;5;209m' REV=$'\e[7m' OFF=$'\e[0m'; fi
TMP_REPO=""   # pasta do repo baixado (rota remota); apagada ao sair
trap 'printf "%s" "$SHOW"; [[ -z $TMP_REPO ]] || rm -rf -- "$TMP_REPO"' EXIT

# ─── De onde vêm os scripts ───────────────────────────────────────────────────
MENU_REF=${MENU_REF:-main}
fetch_repo() {  # sem clone: baixa o tarball do repo (sem git) numa pasta temporária e aponta DIR para ela
  local url="https://codeload.github.com/V0LtagE1z/Minhas-Paradas/tar.gz/$MENU_REF" dl
  if   command -v curl >/dev/null 2>&1; then dl=(curl -fsSL --retry 3 --connect-timeout 20 -o)
  elif command -v wget >/dev/null 2>&1; then dl=(wget -q -O)
  else echo "[erro] para rodar sem clone o menu precisa de curl ou wget (ou clone o repo e rode bash menu.sh)" >&2; return 1; fi
  command -v tar >/dev/null 2>&1 || { echo "[erro] para rodar sem clone o menu precisa do tar" >&2; return 1; }
  TMP_REPO=$(mktemp -d "${TMPDIR:-/tmp}/minhas-paradas.XXXXXX") || return 1   # TMPDIR: o Termux não tem /tmp
  echo "[menu] baixando o Minhas-Paradas ($MENU_REF)..." >&2
  "${dl[@]}" "$TMP_REPO/repo.tgz" "$url" && tar -xzf "$TMP_REPO/repo.tgz" --strip-components=1 -C "$TMP_REPO" \
    || { echo "[erro] não consegui baixar ou extrair $url" >&2; return 1; }
  rm -f -- "$TMP_REPO/repo.tgz"
  [[ -f $TMP_REPO/setup.sh ]] || { echo "[erro] o download não trouxe o setup.sh (MENU_REF=$MENU_REF existe?)" >&2; return 1; }
  DIR=$TMP_REPO
}
# Local: os scripts ficam ao lado do menu. Sem setup.sh ali (curl | bash, ou só o menu.sh baixado): rota remota.
# MENU_DIR existe só para o teste.
if [[ -n ${MENU_DIR:-} ]]; then DIR=$MENU_DIR
else
  DIR=""; [[ -f ${BASH_SOURCE[0]:-} ]] && DIR=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
  [[ -n $DIR && -f $DIR/setup.sh ]] || fetch_repo || exit 1
fi

# ─── Ambiente ─────────────────────────────────────────────────────────────────
# KERNEL_RELEASE e FORCE_PROOT são os mesmos nomes do setup.sh (aqui também servem ao teste).
is_wsl() { local k=${KERNEL_RELEASE:-$(uname -r)}; [[ ${k,,} == *microsoft* || ${k,,} == *wsl* ]]; }

no_power() {  # Termux e proot não têm o que reiniciar/desligar: os itens somem do menu
  local k=${KERNEL_RELEASE:-$(uname -r)}
  [[ ${PREFIX:-} == *com.termux* || ${FORCE_PROOT:-} == 1 || ${k,,} == *proot* ]] && return 0
  # no proot o processo é rastreado por ptrace; sob strace/gdb isto também dá "sim" (só esconde os itens)
  [[ ${FORCE_PROOT:-} != 0 ]] && grep -qs '^TracerPid:[[:space:]]*[1-9]' "/proc/$$/status"
}

# ─── Ações ────────────────────────────────────────────────────────────────────
run_script() {  # script [args...] — roda como filho: um die/exit do script não derruba o menu
  local s=$1 rc; shift
  [[ -f $DIR/$s ]] || { echo "[erro] não achei $DIR/$s"; return; }
  # stdin = terminal: no "curl | bash" o stdin é o pipe, e setup.sh/nvidia.sh recusam rodar sem terminal ([[ -t 0 ]])
  bash "$DIR/$s" "$@" <&3; rc=$?
  echo; echo "[menu] $s terminou (código $rc)."
}

power() {  # reboot|poweroff  verbo — o menu já perguntou "Tem certeza?"
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
    *) echo "[!!] não achei com segurança o shell que chamou o menu (sudo?); digite 'exit' ou feche o terminal." ;;
  esac
}

pause() { printf '\nEnter para voltar ao menu... '; read -r -u 3 _ || exit 0; }

# ─── Itens: rótulo | descrição (2 linhas separadas por "|") | "Tem certeza que deseja <isto>?" (vazio = sem pergunta) | comando
LBL=(); DESC=(); CONF=(); CMD=()
add() { LBL+=("$1"); DESC+=("$2"); CONF+=("$3"); CMD+=("$4"); }

add "Setup completo"           "Usuário, zsh, p10k e dotfiles|Pede sudo; altera o sistema"    "rodar o setup completo"       "run_script setup.sh --sem-encerrar"
add "Setup (só simular)"       "Mostra o que o setup faria|(--dry-run); nada é alterado"      ""                             "run_script setup.sh --dry-run --sem-encerrar"
add "Ranquear os mirrors"      "Ranqueia os mirrors; no Arch|também atualiza o sistema"       "ranquear os mirrors"          "run_script mirrors.sh"
add "Reverter temas Minecraft" "Desfaz os temas Minecraft|(GRUB + Plymouth)"                  "reverter os temas Minecraft"  "run_script setup.sh --reverter-temas"
add "NVIDIA: detectar GPU"     "Detecta a GPU e o ambiente|(só leitura)"                      ""                             "run_script nvidia.sh"
add "NVIDIA: instalar driver"  "Instala o driver NVIDIA|(Arch real; demais: dry-run)"         "instalar o driver NVIDIA"     "run_script nvidia.sh install"
add "NVIDIA: simular instalação" "Mostra o plano da instalação|sem alterar nada"              ""                             "run_script nvidia.sh install --dry-run"
add "OXWM: instalar configuração" "Instala a configuração do OXWM|(X11; Arch e derivadas)"    "instalar a config. do OXWM"   "run_script oxwm-setup.sh"
NINST=${#LBL[@]}
if ! no_power; then
  is_wsl && { c_reb=""; c_off=""; } || { c_reb="reiniciar o computador"; c_off="desligar o computador"; }   # no WSL só aparece o aviso
  add "Reiniciar" "Reinicia o computador|(pede sudo ou doas)" "$c_reb" "power reboot reiniciar"
  add "Desligar"  "Desliga o computador|(pede sudo ou doas)"  "$c_off" "power poweroff desligar"
fi
add "Fechar este terminal" "Fecha este terminal|(SIGHUP no shell que chamou)" "fechar este terminal" close_terminal
add "Sair do menu"         "Sai só do menu|o terminal continua aberto"        ""                      "exit 0"
N=${#LBL[@]}

# ─── Desenho ──────────────────────────────────────────────────────────────────
box_top() {  # título — W é a largura da caixa
  local t=" $1 " d; printf -v d '%*s' $((W - 3 - ${#t})) ''
  printf '%s╭─%s%s╮%s\n' "$ACC" "$t" "${d// /─}" "$OFF"
}
box_bottom() { local d; printf -v d '%*s' $((W - 2)) ''; printf '%s╰%s╯%s\n' "$ACC" "${d// /─}" "$OFF"; }
box_row() {  # texto [1 = selecionado]
  local t=$1 m="  " st="" en="" pad
  ((${#t} > W - 6)) && t="${t:0:W-7}…"
  if [[ ${2:-} == 1 ]]; then m="${ACC}❯${OFF} "; st=$REV; en=$OFF; fi
  printf -v pad '%*s' $((W - 6 - ${#t})) ''
  printf '%s│%s %s%s%s%s%s %s│%s\n' "$ACC" "$OFF" "$m" "$st" "$t" "$pad" "$en" "$ACC" "$OFF"
}

draw() {
  local i d1 d2
  read -r _ W < <(stty size <&3 2>/dev/null)   # largura do terminal; sem tty (teste) cai nos 60
  [[ $W =~ ^[0-9]+$ ]] || W=60
  ((W > 72)) && W=72; ((W < 36)) && W=36
  printf '%s%s' "$CLS" "$HIDE"
  box_top "Minhas-Paradas"
  for ((i = 0; i < NINST; i++)); do box_row "${LBL[i]}" $((i == sel)); done
  box_bottom
  box_top "Sistema"
  for ((i = NINST; i < N; i++)); do box_row "${LBL[i]}" $((i == sel)); done
  box_bottom
  d1=${DESC[sel]%%|*}; d2=${DESC[sel]#*|}
  box_top "Descrição"; box_row "$d1"; box_row "$d2"; box_bottom
  printf ' ↑↓ mover   Enter escolher   q sair\n'
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
    printf '%s%s' "$CLS" "$HIDE"
    if ((yes)); then a="[ Sim ]"; b="  Não  "; else a="  Sim  "; b="[ Não ]"; fi
    box_top "Confirmar"; box_row ""; box_row "Tem certeza que deseja"; box_row "$1?"; box_row ""
    box_row "$a    $b"; box_bottom
    printf ' ←→ escolher  Enter ok  Esc cancela\n'
    key
    case $KEY in
      left|right|h|l|$'\t') yes=$((1 - yes)) ;;
      s|S|y|Y) return 0 ;;
      n|N|q|esc) return 1 ;;
      enter) return $((1 - yes)) ;;
    esac
  done
}

# ─── Laço principal ───────────────────────────────────────────────────────────
sel=0
while :; do
  draw
  key
  case $KEY in
    up|k)   sel=$(((sel + N - 1) % N)) ;;
    down|j) sel=$(((sel + 1) % N)) ;;
    enter|' ')
      [[ -z ${CONF[sel]} ]] || confirm "${CONF[sel]}" || continue
      printf '%s%s' "$CLS" "$SHOW"
      ${CMD[sel]}
      pause ;;
    q) exit 0 ;;
  esac
done
