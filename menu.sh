#!/usr/bin/env bash
# menu.sh — menu de linha de comando do Minhas-Paradas: você escolhe o que rodar, ele executa o
# script certo e volta para esta tela. Também reinicia, desliga e fecha o terminal.
# Uso: bash menu.sh   (como usuário normal: os scripts pedem sudo sozinhos; o nvidia.sh recusa root)
# shortcut: só funciona a partir do clone (acha os scripts ao lado dele). Para rodar via curl o menu
# terá de clonar o repo antes e entrar nele; veja "Planejado" no README.

# Checagem do bash. POSIX puro de propósito: o ash do Alpine lê um comando por vez, então chega aqui
# antes de ver a sintaxe de bash lá embaixo. Com bash instalado, só reexecuta; sem ele, avisa e sai.
if [ -z "${BASH_VERSION:-}" ]; then
  if command -v bash >/dev/null 2>&1; then exec bash "$0" "$@"; fi
  if   command -v apk     >/dev/null 2>&1; then _cmd="apk add bash"
  elif command -v apt-get >/dev/null 2>&1; then _cmd="apt-get install -y bash"
  elif command -v dnf     >/dev/null 2>&1; then _cmd="dnf install -y bash"
  elif command -v zypper  >/dev/null 2>&1; then _cmd="zypper install -y bash"
  elif command -v pacman  >/dev/null 2>&1; then _cmd="pacman -S --noconfirm bash"
  else _cmd="(instale o pacote bash com o gerenciador de pacotes da sua distro)"
  fi
  printf '[erro] o menu precisa do bash, e ele não está instalado.\n  Instale como root (ou com sudo/doas na frente):\n    %s\n  Depois rode: bash %s\n' "$_cmd" "$0" >&2
  exit 1
fi

DIR="${MENU_DIR:-$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")}"
# Lê do terminal (e não do stdin) para continuar funcionando no futuro "curl ... | bash".
# MENU_TTY existe só para o teste (tests/menu.test.sh) alimentar as respostas.
{ exec 3<"${MENU_TTY:-/dev/tty}"; } 2>/dev/null || { echo "[erro] o menu precisa de um terminal" >&2; exit 1; }

ask() { local a=""; printf '%s' "$1"; read -r -u 3 a || exit 0; REPLY=$a; }   # fim da entrada = sair
yes_no() { ask "$1 [s/N] "; [[ ${REPLY,,} == s || ${REPLY,,} == sim ]]; }

run_script() {  # script [args...] — roda como filho: um die/exit do script não derruba o menu
  local s=$1 rc; shift
  [[ -f $DIR/$s ]] || { echo "[erro] não achei $DIR/$s"; return; }
  bash "$DIR/$s" "$@"; rc=$?
  echo; echo "[menu] $s terminou (código $rc)."
}

power() {  # reboot|poweroff  verbo-no-infinitivo
  if [[ ${PREFIX:-} == *com.termux* ]]; then echo "[!!] O Termux não consegue $2 o aparelho."; return; fi
  local k=${KERNEL_RELEASE:-$(uname -r)}   # mesma detecção do setup.sh; KERNEL_RELEASE existe para o teste
  if [[ ${k,,} == *microsoft* || ${k,,} == *wsl* ]]; then   # reboot/poweroff aqui não fazem nada: quem manda na distro é o Windows
    echo "[!!] No WSL não dá para $2 por aqui. No Windows (PowerShell ou CMD) rode: wsl --shutdown"
    echo "     (isso para todas as distros WSL; depois é só abrir a distro de novo)"
    return
  fi
  yes_no "Confirma $2 agora?" || return 0
  local su=""
  ((EUID)) && su=$(command -v sudo || command -v doas)   # doas: Alpine sem sudo
  $su "$1" || echo "[!!] não consegui $2 (em proot/container isso não existe)."
}

close_terminal() {
  # "exit" aqui só encerraria o menu; fechar o terminal é mandar SIGHUP ao shell que o chamou.
  case $(cat "/proc/$PPID/comm" 2>/dev/null) in
    bash|zsh|sh|ash|dash|ksh|fish) kill -HUP "$PPID"; exit 0 ;;
    *) echo "[!!] não achei com segurança o shell que chamou o menu (sudo?); digite 'exit' ou feche o terminal." ;;
  esac
}

while :; do
  clear 2>/dev/null
  cat <<'EOF'
 Minhas-Paradas

  1) Setup completo (usuário, zsh, p10k, dotfiles)
  2) Setup — só simular (--dry-run, não altera nada)
  3) Ranquear os mirrors (no Arch e derivadas, atualiza o sistema)
  4) Reverter os temas Minecraft (GRUB + Plymouth)
  5) NVIDIA — detectar GPU e ambiente (só leitura)
  6) NVIDIA — instalar o driver
  7) NVIDIA — simular a instalação (--dry-run)
  8) OXWM — instalar a configuração

  r) Reiniciar     d) Desligar
  e) Fechar este terminal     q) Sair do menu

EOF
  ask 'Escolha: '
  case ${REPLY,,} in
    1) run_script setup.sh --sem-encerrar ;;
    2) run_script setup.sh --dry-run --sem-encerrar ;;
    3) run_script mirrors.sh ;;
    4) run_script setup.sh --reverter-temas ;;
    5) run_script nvidia.sh ;;
    6) run_script nvidia.sh install ;;
    7) run_script nvidia.sh install --dry-run ;;
    8) run_script oxwm-setup.sh ;;
    r) power reboot reiniciar ;;
    d) power poweroff desligar ;;
    e) close_terminal ;;
    q|0) exit 0 ;;
    *) echo "Opção inválida: $REPLY" ;;
  esac
  ask $'\nEnter para voltar ao menu... '
done
