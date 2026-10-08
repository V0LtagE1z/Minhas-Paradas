#!/usr/bin/env bash
# setup.sh — pós-instalação: usuário + zsh + oh-my-zsh + powerlevel10k + dotfiles do repo Minhas-Paradas.
# Suporta: Termux (pkg), Debian/Ubuntu (apt), Fedora (dnf), Arch/CachyOS (pacman + paru)
# e essas mesmas distros rodando dentro de proot (proot-distro): lá o script roda como root,
# sem sudo, paru, Kitty nem fontes (a fonte é a do próprio Termux).
#
# Distros de desktop: rode como root (ou com sudo). O script
#   0. só no Arch puro: ranqueia os mirrors com o rate-mirrors e atualiza o sistema (pacman -Syyu);
#   1. instala os pacotes do sistema;
#   2. cria o usuário "gustavo" (home /home/gustavo, shell zsh, grupos wheel/audio/video)
#      e troca o shell do root para zsh;
#   3. dá sudo a ele e pede a senha dele;
#   4. executa o setup tradicional (paru, oh-my-zsh, p10k, dotfiles, Kitty, fontes) COMO esse usuário.
# Distros em proot: rode como root. O script
#   1. ajusta o pacman (só se a distro usar pacman) e instala os pacotes do sistema;
#   2. cria o usuário "gustavo" (home /home/gustavo, shell zsh, grupos audio/video) SEM sudo
#      (o setuid não funciona no proot; a administração fica com o root) e troca o shell do root para zsh;
#   3. aplica os dotfiles de "Distro Proot" no root e executa o setup COMO esse usuário (via su).
# Termux: não cria usuário; roda o setup tradicional direto, como usuário normal.
#
# Distros de desktop, opcional: instala os temas Minecraft (GRUB: minegrub-world-sel-theme;
# Plymouth: minecraft-plymouth-theme). Pergunta no começo; --temas-minecraft / --sem-temas-minecraft
# respondem por você. Só funciona com GRUB; em Limine/systemd-boot só o Plymouth é instalado.
# No fim, em qualquer ambiente, pergunta se você quer encerrar a sessão (fecha o shell que chamou o script).
#
# Use --dry-run para ver o que seria feito sem alterar nada.
# Pode ser executado várias vezes sem quebrar nada.
set -euo pipefail

# No Debian, "su" sem "-" não traz /usr/sbin no PATH (useradd, usermod, visudo).
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"

# ─── Configuração ─────────────────────────────────────────────────────────────
REPO_DIR_USER="${REPO_DIR:-}"   # guarda se o REPO_DIR foi escolhido pelo usuário
REPO_URL="${REPO_URL:-https://github.com/V0LtagE1z/Minhas-Paradas.git}"
REPO_DIR="${REPO_DIR:-$HOME/Minhas-Paradas}"

# Usuário criado nas distros de desktop e nas distros em proot.
# ATENÇÃO: o "Distro Proot/.zshrc" tem "gustavo" fixo (o root repassa a sessão com "su - gustavo").
# Com NEW_USER diferente de gustavo esse repasse falha e o root continua no próprio shell.
# Se um dia quiser usar outro nome, troque o "su - gustavo" nesse .zshrc.
NEW_USER="${NEW_USER:-gustavo}"
NEW_HOME="/home/$NEW_USER"
NEW_GROUPS=(wheel audio video)   # no proot vira (audio video): sem sudo, o wheel não serve para nada

# Arch puro (desktop): ranqueia os mirrors com o rate-mirrors antes de instalar qualquer coisa.
# SKIP_MIRRORS=1 pula essa etapa; FORCE_MIRRORS=1 ranqueia de novo mesmo se já foi feito.
SKIP_MIRRORS="${SKIP_MIRRORS:-0}"
FORCE_MIRRORS="${FORCE_MIRRORS:-0}"
MIRRORLIST_FILE="${MIRRORLIST_FILE:-/etc/pacman.d/mirrorlist}"

# Pacotes (o nome é igual nos 4 gerenciadores). Adicione os outros aqui.
PACKAGES=(zsh git curl fastfetch micro fzf zoxide)

# Pacotes só para distros de desktop (ignorados no Termux).
# fontconfig garante o fc-cache/fc-list usados na instalação das fontes.
DESKTOP_PACKAGES=(kitty fontconfig)

# Estrutura do repo: cada ambiente tem a sua subpasta com os próprios dotfiles.
DIR_TERMUX="Termux"
DIR_DISTRO="Distro Normal"
DIR_PROOT="Distro Proot"
DIR_KITTY="Kitty"

# Arquivos de cada subpasta que serão copiados para o $HOME.
DOTFILES_TERMUX=(.zshrc .p10k.zsh)
DOTFILES_DISTRO=(.zshrc .p10k.zsh .p10k-ascii.zsh)
DOTFILES_PROOT=(.zshrc .p10k.zsh)

# Caminhos/valores que podem ser sobrescritos por variável de ambiente (útil para testar).
OS_RELEASE_FILE="${OS_RELEASE_FILE:-}"
KERNEL_RELEASE="${KERNEL_RELEASE:-}"
ARCH_RELEASE_FILE="${ARCH_RELEASE_FILE:-/etc/arch-release}"
PROC_STATUS_FILE="${PROC_STATUS_FILE:-/proc/self/status}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"
ROOT_PREFIX="${ROOT_PREFIX:-}"   # só para testes: prefixo dos /etc e /usr/lib lidos por detect_zshrc_family
UNAME_O="${UNAME_O:-}"           # só para testes: substitui "uname -o" em detect_zshrc_termux

# Temas Minecraft (só distros de desktop):
#   GRUB     -> Lxtharia/minegrub-world-sel-theme
#   Plymouth -> nikp123/minecraft-plymouth-theme
# MC_THEMES: ask (pergunta no começo; padrão), 1 (instala sem perguntar) ou 0 (pula).
# Também: --temas-minecraft e --sem-temas-minecraft.
MC_THEMES="${MC_THEMES:-ask}"
MC_GRUB_REPO="${MC_GRUB_REPO:-https://github.com/Lxtharia/minegrub-world-sel-theme.git}"
MC_PLYMOUTH_REPO="${MC_PLYMOUTH_REPO:-https://github.com/nikp123/minecraft-plymouth-theme.git}"
BOOT_DIR="${BOOT_DIR:-/boot}"
GRUB_DEFAULT_FILE="${GRUB_DEFAULT_FILE:-/etc/default/grub}"
GRUB_D_DIR="${GRUB_D_DIR:-/etc/grub.d}"
MKINITCPIO_CONF="${MKINITCPIO_CONF:-/etc/mkinitcpio.conf}"
MKINITCPIO_CONF_D="${MKINITCPIO_CONF_D:-/etc/mkinitcpio.conf.d}"
# Onde o install.sh do tema do Plymouth coloca as coisas (usado só pelo --reverter-temas).
PLYMOUTH_THEMES_DIR="${PLYMOUTH_THEMES_DIR:-/usr/share/plymouth/themes}"
MC_FONT_FILE="${MC_FONT_FILE:-/usr/share/fonts/OTF/Minecraft.otf}"
MC_FONTCONF_FILE="${MC_FONTCONF_FILE:-/etc/fonts/conf.d/00-minecraft.conf}"
DRACUT_CONF_D="${DRACUT_CONF_D:-/etc/dracut.conf.d}"
INITRAMFS_HOOKS_DIR="${INITRAMFS_HOOKS_DIR:-/usr/share/initramfs-tools/hooks}"
REVERT_MC=0   # 1 = --reverter-temas

# ─── Utilidades ───────────────────────────────────────────────────────────────
DRY_RUN="${DRY_RUN:-0}"   # 1 = só mostra o que seria feito (--dry-run)

# Em simulação o prefixo é [sim], para não parecer que algo foi feito de verdade.
log()  {
  if ((DRY_RUN)); then printf '\033[1;36m[sim]\033[0m %s\n' "$*"
  else printf '\033[1;32m[ok]\033[0m %s\n' "$*"; fi
}
warn() { printf '\033[1;33m[!!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

# Executa o comando; em --dry-run só imprime.
run() {
  if ((DRY_RUN)); then
    local a
    printf '\033[1;36m[dry]\033[0m'
    for a in "$@"; do
      # Argumentos simples saem como estão; os demais entre aspas simples (mais legível que %q).
      if [[ $a =~ ^[A-Za-z0-9_@%+=:,./-]+$ ]]; then printf ' %s' "$a"
      elif [[ $a != *\'* ]]; then printf " '%s'" "$a"
      else printf ' %q' "$a"; fi
    done
    printf '\n'
    return 0
  fi
  "$@"
}

append_line() {  # linha arquivo — acrescenta ao final, com sudo se preciso
  local line=$1 file=$2
  if ((DRY_RUN)); then
    printf '\033[1;36m[dry]\033[0m echo %q >> %q\n' "$line" "$file"
  else
    printf '%s\n' "$line" | $SUDO tee -a "$file" >/dev/null
  fi
}

# Caminho do zsh para usar como shell de login. O "command -v" pode devolver
# /usr/sbin/zsh (symlink para /usr/bin no Arch), que não está em /etc/shells e o
# chsh recusa. Prefere o caminho real e, se nenhum estiver listado, devolve o real.
zsh_shell_path() {
  local found real p
  found=$(command -v zsh) || return 1
  real=$(readlink -f -- "$found" 2>/dev/null || echo "$found")
  for p in "$real" "$found" /usr/bin/zsh /bin/zsh; do
    if [[ -x $p ]] && grep -qxF "$p" /etc/shells 2>/dev/null; then
      printf '%s\n' "$p"; return 0
    fi
  done
  printf '%s\n' "$real"
}

PM=""
SUDO="sudo"
FAILED=()
PROOT=0         # 1 = rodando dentro de um proot (ex.: proot-distro no Termux), qualquer distro
IS_ALARM=0      # 1 = Arch Linux ARM (só relevante junto com PROOT=1, para o keyring)
USER_PHASE=0    # 1 = chamado pelo próprio script, já como o novo usuário (interno)
SCRIPT_PATH=$(readlink -f -- "${BASH_SOURCE[0]:-$0}" 2>/dev/null || true)

CLEANUP_FILES=()
CLEANUP_DIRS=()   # diretórios temporários (clones dos temas etc.)
cleanup() {
  local f
  for f in ${CLEANUP_FILES[@]+"${CLEANUP_FILES[@]}"}; do rm -f -- "$f"; done
  for f in ${CLEANUP_DIRS[@]+"${CLEANUP_DIRS[@]}"}; do rm -rf -- "$f"; done
  CLEANUP_FILES=()
  CLEANUP_DIRS=()
}
trap cleanup EXIT

usage() {
  cat <<EOF
Uso: bash setup.sh [--dry-run]

  --dry-run, -n           mostra o que seria feito (linhas [dry] e [sim]) sem alterar nada
  --temas-minecraft       instala os temas Minecraft (GRUB + Plymouth) sem perguntar (só desktop)
  --sem-temas-minecraft   não instala e não pergunta pelos temas Minecraft
  --reverter-temas        desfaz os temas Minecraft (GRUB + Plymouth) e sai; não faz mais nada
  --help, -h              mostra esta ajuda

No fim o script pergunta se você quer encerrar a sessão (fecha o shell que chamou o script).

Variáveis úteis: NEW_USER (padrão: gustavo), REPO_URL, REPO_DIR,
                 FORCE_PROOT=1 (força o modo proot se a detecção falhar),
                 SKIP_MIRRORS=1 (não ranquear os mirrors no Arch),
                 FORCE_MIRRORS=1 (ranquear de novo mesmo se já foi feito),
                 MC_THEMES=1|0 (o mesmo que --temas-minecraft / --sem-temas-minecraft).
EOF
}

parse_args() {
  local a
  for a in "$@"; do
    case $a in
      --dry-run|-n) DRY_RUN=1 ;;
      --user-phase) USER_PHASE=1 ;;   # interno
      --temas-minecraft)      MC_THEMES=1 ;;
      --sem-temas-minecraft)  MC_THEMES=0 ;;
      --reverter-temas)       REVERT_MC=1 ;;
      -h|--help)    usage; exit 0 ;;
      *)            die "Opção desconhecida: $a (veja: bash setup.sh --help)" ;;
    esac
  done
}

# Detecta se está dentro de um proot (qualquer distro) e se a distro é o Arch Linux ARM.
# Critérios do proot, nesta ordem:
#   1. o nome do kernel traz "proot" (o proot-distro devolve algo como 6.17.0-PRoot-Distro
#      em "uname -r"; é o que aparece no fastfetch). Vale para qualquer distro;
#   2. Arch Linux ARM + processo rastreado por ptrace (TracerPid != 0). Só para o ALARM de
#      propósito: fora do proot um strace/gdb também dá TracerPid != 0.
# FORCE_PROOT=1 força o modo caso a detecção falhe (FORCE_ALARM_PROOT=1 também força, e marca ALARM).
detect_env() {
  local tracer arch f kernel

  # Algumas imagens (ex.: proot-distro do ALARM) não têm /etc/os-release; o arquivo
  # canônico é /usr/lib/os-release, então tentamos os dois.
  if [[ -z $OS_RELEASE_FILE ]]; then
    for f in /etc/os-release /usr/lib/os-release; do
      if [[ -r $f ]]; then OS_RELEASE_FILE=$f; break; fi
    done
  fi
  if [[ -n $OS_RELEASE_FILE ]] \
     && grep -qiE '^(ID="?archarm"?|NAME="?Arch Linux ARM)' "$OS_RELEASE_FILE" 2>/dev/null; then
    IS_ALARM=1
  fi
  # Segundo critério: Arch (tem /etc/arch-release) em CPU ARM só pode ser o ALARM,
  # já que o Arch oficial não tem build aarch64.
  arch=${UNAME_M:-$(uname -m 2>/dev/null || true)}
  if ((! IS_ALARM)) && [[ -e $ARCH_RELEASE_FILE ]] && [[ $arch == aarch64 || $arch == arm* ]]; then
    IS_ALARM=1
  fi

  if [[ ${FORCE_ALARM_PROOT:-0} == 1 ]]; then IS_ALARM=1; PROOT=1; return 0; fi
  if [[ ${FORCE_PROOT:-0} == 1 ]]; then PROOT=1; return 0; fi

  kernel=${KERNEL_RELEASE:-$(uname -r 2>/dev/null || true)}
  if [[ ${kernel,,} == *proot* ]]; then PROOT=1; return 0; fi

  # No proot cada processo é rastreado (ptrace) pelo próprio proot: TracerPid != 0.
  tracer=$(awk '/^TracerPid:/ {print $2}' "$PROC_STATUS_FILE" 2>/dev/null || true)
  if ((IS_ALARM)) && [[ -n $tracer && $tracer != 0 ]]; then
    PROOT=1
  fi
}

# Ambiente gráfico de verdade? (distro de desktop; não Termux e não proot)
is_desktop() { [[ $PM != pkg && $PROOT != 1 ]]; }

detect_pm() {
  # Dentro do proot as variáveis do Termux podem vazar: o proot decide antes do Termux.
  if ((PROOT)); then
    if ((IS_ALARM)); then log "Modo proot detectado (Arch Linux ARM)"
    else log "Modo proot detectado"; fi
  fi

  if ((PROOT && IS_ALARM)); then
    PM=pacman
  # Termux precisa ser checado antes do apt: ele também tem apt-get.
  elif ((! PROOT)) && [[ -n "${TERMUX_VERSION:-}" || "${PREFIX:-}" == *com.termux* ]]; then
    PM=pkg; SUDO=""
  elif command -v apt-get >/dev/null; then PM=apt
  elif command -v dnf >/dev/null;     then PM=dnf
  elif command -v pacman >/dev/null;  then PM=pacman
  else die "Gerenciador de pacotes não suportado (emerge não está incluído)."
  fi

  # Root não precisa de sudo; no proot o sudo não é usado (setuid não funciona lá).
  if [[ $EUID -eq 0 ]] || ((PROOT)); then SUDO=""; fi
  if [[ -n $SUDO ]] && ! command -v sudo >/dev/null; then
    if ((DRY_RUN)); then warn "sudo não encontrado (na simulação ele seria instalado)"
    else die "sudo não encontrado. Rode este script como root (su -)."
    fi
  fi
  log "Gerenciador detectado: $PM"
}

pm_update() {
  case $PM in
    pkg) run pkg update -y ;;
    apt) run $SUDO apt-get update ;;
    *)   : ;;  # dnf atualiza metadados sozinho; no pacman evitamos -Sy isolado
  esac
}

pm_install() {  # instala UM pacote
  case $PM in
    pkg)    run pkg install -y "$1" ;;
    apt)    run $SUDO apt-get install -y "$1" ;;
    dnf)    run $SUDO dnf install -y "$1" ;;
    pacman) run $SUDO pacman -S --needed --noconfirm "$1" ;;
  esac
}

install_packages() {
  local p
  for p in "${PACKAGES[@]}"; do
    if pm_install "$p"; then
      log "pacote: $p"
    else
      warn "falhou: $p"
      FAILED+=("$p")
    fi
  done
}

install_desktop_packages() {
  is_desktop || return 0   # Kitty e fontconfig não se aplicam ao Termux nem ao proot
  local p
  for p in "${DESKTOP_PACKAGES[@]}"; do
    if pm_install "$p"; then
      log "pacote (desktop): $p"
    else
      warn "falhou: $p"
      FAILED+=("$p")
    fi
  done
}

# ─── Mirrors no Arch puro (desktop) ───────────────────────────────────────────
# Só no Arch puro (ID=arch). CachyOS, EndeavourOS, Arch ARM etc. têm mirrorlists próprias
# e não devem ser sobrescritas com a lista do Arch. O rate-mirrors está no repo oficial [extra].
optimize_mirrors() {
  [[ $PM == pacman ]] && is_desktop || return 0
  if [[ $SKIP_MIRRORS == 1 ]]; then log "mirrors: etapa pulada (SKIP_MIRRORS=1)"; return 0; fi
  if ! grep -qE '^ID="?arch"?$' "${OS_RELEASE_FILE:-/etc/os-release}" 2>/dev/null; then
    log "mirrors: não é Arch puro, mantendo a mirrorlist atual"; return 0
  fi
  if [[ $FORCE_MIRRORS != 1 ]] && grep -q '^# ARGS: rate-mirrors' "$MIRRORLIST_FILE" 2>/dev/null; then
    log "mirrors: a mirrorlist já foi gerada pelo rate-mirrors (FORCE_MIRRORS=1 para refazer)"; return 0
  fi

  if ((DRY_RUN)); then
    log "Ranquearia os mirrors com o rate-mirrors e atualizaria o sistema:"
    run $SUDO pacman -S --needed --noconfirm rate-mirrors
    run rate-mirrors --allow-root --protocol https --save=/tmp/mirrorlist.novo arch --max-delay=21600
    run $SUDO cp -a "$MIRRORLIST_FILE" "$MIRRORLIST_FILE.bak"
    run $SUDO install -m 644 /tmp/mirrorlist.novo "$MIRRORLIST_FILE"
    # -yy só se justifica logo após trocar de mirror, e SEMPRE junto com -u (senão é update parcial).
    run $SUDO pacman -Syyu --noconfirm
    return 0
  fi

  if ! command -v rate-mirrors >/dev/null; then
    if ! $SUDO pacman -S --needed --noconfirm rate-mirrors; then
      # Banco de dados antigo (404): atualiza o sistema inteiro, nunca só o banco (-Sy isolado = update parcial).
      warn "falha ao instalar o rate-mirrors; tentando com atualização completa do sistema"
      $SUDO pacman -Syu --noconfirm rate-mirrors \
        || { warn "não consegui instalar o rate-mirrors; seguindo com os mirrors atuais"; return 0; }
    fi
  fi

  log "Ranqueando os mirrors (pode levar 1-2 minutos)..."
  local tmp; tmp=$(mktemp)
  CLEANUP_FILES+=("$tmp")
  # --allow-root: esta fase roda como root. Opções gerais vêm antes do "arch"; --max-delay é do subcomando.
  if ! rate-mirrors --allow-root --protocol https --save="$tmp" arch --max-delay=21600 \
     || ! grep -q '^Server' "$tmp"; then
    warn "o rate-mirrors falhou; seguindo com os mirrors atuais"
    return 0
  fi

  # Backup: .bak; se já existir, .bak.1, .bak.2... (nunca sobrescreve um backup antigo)
  local bak="$MIRRORLIST_FILE.bak" n=0
  while [[ -e $bak ]]; do n=$((n + 1)); bak="$MIRRORLIST_FILE.bak.$n"; done
  $SUDO cp -a "$MIRRORLIST_FILE" "$bak"
  $SUDO install -m 644 "$tmp" "$MIRRORLIST_FILE"
  log "mirrorlist atualizada (backup: $bak)"

  # Atualizar o banco sem atualizar os pacotes quebra o sistema; por isso -Syyu, nunca -Syy.
  # Também garante que o paru seja compilado depois, contra a libalpm já atualizada.
  log "Atualizando o sistema a partir dos novos mirrors (pacman -Syyu)..."
  $SUDO pacman -Syyu --noconfirm \
    || die "pacman -Syyu falhou. Rode 'pacman -Syu' manualmente até funcionar e execute o script de novo."
  log "sistema atualizado (se o kernel mudou, reinicie no fim)"
}

# ─── pacman em proot (Arch Linux ARM e afins) ─────────────────────────────────
# No proot o kernel do Android não oferece Landlock/seccomp nem troca de usuário
# real, então o sandbox de download do pacman 7+ falha, e o CheckSpace não
# consegue descobrir os pontos de montagem.

pacman_version() {  # imprime "7.1" a partir de "Pacman v7.1.0"
  pacman --version 2>/dev/null | sed -nE 's/.*[Vv]([0-9]+)\.([0-9]+).*/\1.\2/p' | head -1
}

conf_enable() {  # ativa uma diretiva sem valor em [options] (descomenta ou insere)
  local opt=$1 conf=$PACMAN_CONF
  if grep -qE "^[[:space:]]*$opt[[:space:]]*$" "$conf"; then return 0; fi
  if grep -qE "^[[:space:]]*#[[:space:]]*$opt[[:space:]]*$" "$conf"; then
    run sed -i -E "s/^[[:space:]]*#[[:space:]]*($opt)[[:space:]]*$/\1/" "$conf"
  else
    run sed -i "/^\[options\]/a $opt" "$conf"
  fi
  log "pacman.conf: $opt ativado"
}

conf_disable() {  # comenta uma diretiva (com ou sem valor)
  local opt=$1 conf=$PACMAN_CONF
  if grep -qE "^[[:space:]]*$opt([[:space:]=]|$)" "$conf"; then
    run sed -i -E "s/^([[:space:]]*$opt([[:space:]=]|$))/#\1/" "$conf"
    log "pacman.conf: $opt desativado"
  fi
}

patch_pacman_conf() {
  local conf=$PACMAN_CONF ver major minor
  [[ -f $conf ]] || { warn "$conf não encontrado"; return 0; }
  if [[ ! -e $conf.bak ]]; then run cp -a "$conf" "$conf.bak"; log "backup: $conf.bak"; fi

  conf_disable CheckSpace
  conf_disable DownloadUser

  # O nome da opção de sandbox depende da versão do pacman:
  #   7.0  -> DisableSandbox
  #   7.1+ -> DisableSandboxFilesystem e DisableSandboxSyscalls
  # Diretivas que o pacman.conf da distro já lista (comentadas) também são ativadas.
  local o
  for o in DisableSandbox DisableSandboxFilesystem DisableSandboxSyscalls; do
    if grep -qE "^[[:space:]]*#?[[:space:]]*$o[[:space:]]*$" "$conf"; then conf_enable "$o"; fi
  done

  ver=$(pacman_version || true)
  major=${ver%%.*}; minor=${ver##*.}
  if [[ -z $ver ]]; then
    warn "não consegui ler a versão do pacman; confira o sandbox em $conf"
  elif ((major > 7 || (major == 7 && minor >= 1))); then
    conf_enable DisableSandboxFilesystem
    conf_enable DisableSandboxSyscalls
  elif ((major == 7)); then
    conf_enable DisableSandbox
  fi
}

init_keyring() {
  if [[ -s /etc/pacman.d/gnupg/trustdb.gpg ]]; then return 0; fi
  local keyring=archlinux
  ((IS_ALARM)) && keyring=archlinuxarm
  log "Inicializando o chaveiro do pacman (pode demorar no proot)..."
  run $SUDO pacman-key --init || warn "pacman-key --init falhou"
  run $SUDO pacman-key --populate "$keyring" || warn "pacman-key --populate falhou"
}

gen_locales() {  # o .zshrc usa pt_BR.UTF-8 e en_US.UTF-8; rootfs mínimo costuma ter só uma
  command -v locale-gen >/dev/null || return 0
  local f=${LOCALE_GEN_FILE:-/etc/locale.gen} l changed=0
  [[ -f $f ]] || return 0
  for l in "pt_BR.UTF-8 UTF-8" "en_US.UTF-8 UTF-8"; do
    if grep -qE "^${l}\s*$" "$f"; then continue; fi
    if grep -qE "^#\s*${l}\s*$" "$f"; then
      run $SUDO sed -i -E "s/^#\s*(${l})\s*$/\1/" "$f"
    else
      append_line "$l" "$f"
    fi
    changed=1
  done
  if ((changed)); then run $SUDO locale-gen && log "locales pt_BR e en_US geradas" || warn "locale-gen falhou"; fi
}

prepare_proot_pacman() {
  # Só para distros com pacman dentro de proot (Arch Linux ARM e afins).
  ((PROOT)) && [[ $PM == pacman ]] || return 0
  patch_pacman_conf
  init_keyring
  # Rootfs de ARM costuma ser antigo: -Sy sem -u causaria atualização parcial.
  log "Atualizando o sistema (pacman -Syu)..."
  run $SUDO pacman -Syu --noconfirm || warn "pacman -Syu falhou; os pacotes abaixo podem falhar"
  # O -Syu pode ter trazido um pacman mais novo, com outras opções de sandbox.
  patch_pacman_conf
}

# ─── Fase 1 (root, só desktop): usuário, grupos, shell, sudo, senha ───────────
install_sudoers() {  # nome-do-arquivo conteúdo — valida com visudo antes de instalar
  local name=$1 content=$2 tmp
  if ((DRY_RUN)); then
    log "instalaria /etc/sudoers.d/$name com: $content"
    return 0
  fi
  mkdir -p /etc/sudoers.d
  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  if ! visudo -cf "$tmp" >/dev/null; then
    rm -f "$tmp"
    die "sudoers inválido para $name; nada foi instalado."
  fi
  install -m 440 -o root -g root "$tmp" "/etc/sudoers.d/$name"
  rm -f "$tmp"
}

ensure_sudo() {
  command -v sudo >/dev/null && return 0
  log "sudo não encontrado; instalando"
  pm_install sudo || die "não consegui instalar o sudo"
  if ((! DRY_RUN)); then
    command -v visudo >/dev/null || die "visudo não encontrado após instalar o sudo"
  fi
}

create_user() {
  local zsh_bin g groups=() csv
  if ! zsh_bin=$(zsh_shell_path); then
    if ((DRY_RUN)); then zsh_bin=/usr/bin/zsh
    else die "zsh não foi instalado; não dá para defini-lo como shell de $NEW_USER."
    fi
  fi

  # zsh precisa estar em /etc/shells para ser aceito como shell de login.
  grep -qxF "$zsh_bin" /etc/shells 2>/dev/null || append_line "$zsh_bin" /etc/shells

  # Só usa grupos que existem; "wheel" não existe no Debian, então é criado.
  for g in "${NEW_GROUPS[@]}"; do
    if ! getent group "$g" >/dev/null; then
      if [[ $g == wheel ]]; then
        run groupadd wheel
        log "grupo criado: wheel"
      else
        warn "grupo $g não existe, pulando"
        continue
      fi
    fi
    groups+=("$g")
  done
  csv=$(IFS=,; echo "${groups[*]}")

  if id -u "$NEW_USER" >/dev/null 2>&1; then
    log "usuário $NEW_USER já existe; ajustando grupos e shell"
    if [[ -n $csv ]]; then run usermod -aG "$csv" "$NEW_USER"; fi
    run usermod -s "$zsh_bin" "$NEW_USER"
    local cur_home; cur_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
    [[ $cur_home == "$NEW_HOME" ]] || warn "home atual de $NEW_USER é $cur_home (esperado $NEW_HOME); não movi nada"
  else
    local -a uargs=(-m -d "$NEW_HOME" -s "$zsh_bin")
    if [[ -n $csv ]]; then uargs+=(-G "$csv"); fi
    run useradd "${uargs[@]}" "$NEW_USER"
    log "usuário criado: $NEW_USER (home $NEW_HOME, shell $zsh_bin, grupos ${csv:-nenhum})"
  fi
}

set_root_shell() {
  # O root também passa a usar zsh (o $NEW_USER já recebe o zsh em create_user).
  local zsh_bin cur
  if ! zsh_bin=$(zsh_shell_path); then
    if ((DRY_RUN)); then zsh_bin=/usr/bin/zsh
    else warn "zsh não encontrado; shell do root não alterado"; return 0
    fi
  fi
  grep -qxF "$zsh_bin" /etc/shells 2>/dev/null || append_line "$zsh_bin" /etc/shells
  cur=$(getent passwd root | cut -d: -f7)
  if [[ $cur == "$zsh_bin" ]]; then log "shell do root já é $zsh_bin"; return 0; fi
  run usermod -s "$zsh_bin" root
  log "shell do root: $zsh_bin"
}

configure_sudo() {
  # Drop-in próprio: funciona igual em Arch, Fedora e Debian, sem editar /etc/sudoers.
  install_sudoers "10-$NEW_USER" "$NEW_USER ALL=(ALL:ALL) ALL"
  grep -Eq '^[#@]includedir[[:space:]]+/etc/sudoers\.d' /etc/sudoers 2>/dev/null \
    || warn "/etc/sudoers não inclui /etc/sudoers.d (ou não foi encontrado); confira com visudo"
  log "sudo liberado para $NEW_USER"
}

set_password() {
  local st i
  if ((DRY_RUN)); then
    log "pediria a senha de $NEW_USER (passwd $NEW_USER), se ainda não estiver definida"
    return 0
  fi
  st=$(passwd -S "$NEW_USER" 2>/dev/null | awk '{print $2}' || true)
  if [[ $st == P ]]; then log "senha de $NEW_USER já definida; mantendo"; return 0; fi
  if [[ ! -t 0 ]]; then
    warn "sem terminal interativo; defina a senha depois com: passwd $NEW_USER"
    return 0
  fi
  echo "Defina a senha de $NEW_USER:"
  for i in 1 2 3; do
    if passwd "$NEW_USER"; then log "senha definida"; return 0; fi
    warn "tentativa $i/3 falhou"
  done
  warn "senha NÃO definida; rode: passwd $NEW_USER"
}

run_user_phase() {
  # No Arch o paru precisa de sudo sem senha durante o makepkg; removido logo depois.
  local need_tmp_sudo=0
  [[ $PM == pacman ]] && need_tmp_sudo=1

  if ((DRY_RUN)); then
    log "Fase do usuário $NEW_USER (simulada, home $NEW_HOME):"
    if ((need_tmp_sudo)); then
      install_sudoers "99-setup-tmp" "$NEW_USER ALL=(ALL:ALL) NOPASSWD: ALL"
    fi
    (
      HOME=$NEW_HOME
      [[ -n $REPO_DIR_USER ]] || REPO_DIR="$HOME/Minhas-Paradas"
      SUDO="sudo"
      run_user_steps
    )
    ((need_tmp_sudo)) && log "removeria /etc/sudoers.d/99-setup-tmp"
    return 0
  fi

  [[ -f $SCRIPT_PATH ]] || die "Não achei o arquivo do script. Salve-o em disco e rode: bash setup.sh"
  # Cópia legível pelo novo usuário (o original pode estar em /root).
  local tmp; tmp=$(mktemp)
  CLEANUP_FILES+=("$tmp")
  cp -- "$SCRIPT_PATH" "$tmp"
  chmod 755 "$tmp"

  if ((need_tmp_sudo)); then
    install_sudoers "99-setup-tmp" "$NEW_USER ALL=(ALL:ALL) NOPASSWD: ALL"
    CLEANUP_FILES+=("/etc/sudoers.d/99-setup-tmp")
  fi

  log "Executando o setup tradicional como $NEW_USER"
  (cd /tmp && sudo -H -u "$NEW_USER" env "REPO_URL=$REPO_URL" bash "$tmp" --user-phase) \
    || warn "a fase do usuário terminou com erro; rode de novo para tentar completar"
  cleanup
}

system_phase() {
  optimize_mirrors   # Arch puro: rate-mirrors + atualização completa, antes de qualquer outro pacote
  pm_update
  install_packages
  install_desktop_packages
  ensure_sudo
  create_user
  set_root_shell
  configure_sudo
  set_password
  run_user_phase
  # Por último: mexe no bootloader/initramfs e uma falha aqui não pode atrapalhar o setup principal.
  minecraft_themes || warn "os temas Minecraft não foram concluídos"
}

# ─── Proot (qualquer distro): como root, sem sudo ─────────────────────────────
# O setuid não funciona no proot, então o NEW_USER não recebe sudo (a administração
# fica com o root) e o setup dele roda com "su", que o root pode usar sem senha.
run_user_phase_proot() {
  if ((DRY_RUN)); then
    log "Fase do usuário $NEW_USER (simulada, home $NEW_HOME, via su):"
    (
      HOME=$NEW_HOME
      [[ -n $REPO_DIR_USER ]] || REPO_DIR="$HOME/Minhas-Paradas"
      run_user_steps
    )
    return 0
  fi

  [[ -f $SCRIPT_PATH ]] || die "Não achei o arquivo do script. Salve-o em disco e rode: bash setup.sh"
  # Cópia legível pelo novo usuário (o original pode estar em /root).
  local tmp; tmp=$(mktemp)
  CLEANUP_FILES+=("$tmp")
  cp -- "$SCRIPT_PATH" "$tmp"
  chmod 755 "$tmp"

  log "Executando o setup como $NEW_USER (su)"
  # -s /bin/bash: o shell de login dele é o zsh, que interpretaria o comando de outro jeito.
  su -l -s /bin/bash "$NEW_USER" -c \
    "cd /tmp && env REPO_URL=$(printf '%q' "$REPO_URL") FORCE_PROOT=1 FORCE_ALARM_PROOT=${FORCE_ALARM_PROOT:-0} bash $(printf '%q' "$tmp") --user-phase" \
    || warn "a fase do usuário terminou com erro; rode de novo para tentar completar"
  cleanup
}

# Simula a detecção do "Distro Proot/.zshrc" (função _detect_update_family): qual
# gerenciador o .zshrc do root vai usar quando você aceitar "atualizar o sistema".
# MANTENHA EM SINCRONIA com aquele .zshrc (mesma ordem: os-release → marcadores → PATH).
# Preenche UPDATE_FAMILY e UPDATE_FAMILY_SRC; retorna 1 se não reconhecer a distro.
UPDATE_FAMILY=""
UPDATE_FAMILY_SRC=""
detect_zshrc_family() {
  local f key val id="" id_like="" src="" w m pm
  UPDATE_FAMILY=""; UPDATE_FAMILY_SRC=""

  # os-release: /etc é o usual; /usr/lib é o canônico (o ALARM de proot pode só ter este).
  for f in "$ROOT_PREFIX/etc/os-release" "$ROOT_PREFIX/usr/lib/os-release"; do
    [[ -r $f ]] || continue
    while IFS='=' read -r key val || [[ -n $key ]]; do
      val=${val//\"/}
      val=${val//\'/}
      case $key in
        ID)      id=$val ;;
        ID_LIKE) id_like=$val ;;
      esac
    done < "$f"
    if [[ -n $id || -n $id_like ]]; then src=$f; break; fi
  done

  # ${id,,}: minúsculas; sem aspas de propósito, para separar o ID_LIKE em palavras.
  for w in ${id,,} ${id_like,,}; do
    case $w in
      arch|archarm|archlinux32|manjaro|manjaro-arm|endeavouros|artix|parabola) UPDATE_FAMILY=pacman ;;
      ubuntu|debian|raspbian|kali|linuxmint)                                   UPDATE_FAMILY=apt ;;
      fedora|rhel|centos|rocky|almalinux)                                      UPDATE_FAMILY=dnf ;;
      opensuse*|suse|sles)                                                     UPDATE_FAMILY=zypper ;;
      alpine)                                                                  UPDATE_FAMILY=apk ;;
      *) continue ;;
    esac
    UPDATE_FAMILY_SRC="ID/ID_LIKE \"$w\" em ${src#"$ROOT_PREFIX"}"
    return 0
  done

  for m in arch-release:pacman debian_version:apt fedora-release:dnf redhat-release:dnf \
           SuSE-release:zypper SUSE-brand:zypper alpine-release:apk; do
    if [[ -e $ROOT_PREFIX/etc/${m%%:*} ]]; then
      UPDATE_FAMILY=${m##*:}
      UPDATE_FAMILY_SRC="arquivo /etc/${m%%:*} (sem ID reconhecível no os-release)"
      return 0
    fi
  done

  for pm in pacman:pacman apt-get:apt dnf:dnf zypper:zypper apk:apk; do
    if command -v "${pm%%:*}" >/dev/null 2>&1; then
      UPDATE_FAMILY=${pm##*:}
      UPDATE_FAMILY_SRC="comando ${pm%%:*} no PATH (sem os-release nem marcadores)"
      return 0
    fi
  done

  return 1
}

report_zshrc_family() {
  if detect_zshrc_family; then
    log "o .zshrc do root vai atualizar o sistema via '$UPDATE_FAMILY' (detectado por: $UPDATE_FAMILY_SRC)"
  else
    warn "o .zshrc do root NÃO reconheceria esta distro (sem os-release, marcadores nem gerenciador conhecido) e pularia a atualização"
  fi
}

# Simula o teste "isso é Termux?" do "Distro Proot/.zshrc" (função _zshrc_is_termux).
# As variáveis do Termux ($TERMUX_VERSION, $PREFIX) podem vazar para dentro do proot; se o
# .zshrc confiasse só nelas, o root cairia no ramo do Termux (pkg update) e nunca atualizaria.
# MANTENHA EM SINCRONIA com aquele .zshrc (mesma ordem de critérios).
# Retorna 0 se o .zshrc trataria o ambiente como Termux, 1 se como distro; o motivo
# fica em ZSHRC_TERMUX_SRC.
ZSHRC_TERMUX_SRC=""
detect_zshrc_termux() {
  local kernel os f
  ZSHRC_TERMUX_SRC=""

  if [[ -z ${TERMUX_VERSION:-} && ${PREFIX:-} != *com.termux* ]]; then
    ZSHRC_TERMUX_SRC="sem variáveis do Termux (TERMUX_VERSION/PREFIX)"
    return 1
  fi

  kernel=${KERNEL_RELEASE:-$(uname -r 2>/dev/null || true)}
  kernel=${kernel,,}
  os=${UNAME_O:-$(uname -o 2>/dev/null || true)}

  if [[ $kernel == *proot* ]]; then
    ZSHRC_TERMUX_SRC="kernel de proot (\"$kernel\"): as variáveis do Termux vazaram para dentro da distro"
    return 1
  fi
  if [[ $os == Android ]]; then
    ZSHRC_TERMUX_SRC="uname -o = Android"
    return 0
  fi
  for f in etc/os-release usr/lib/os-release etc/arch-release etc/debian_version \
           etc/fedora-release etc/redhat-release etc/SuSE-release etc/SUSE-brand \
           etc/alpine-release; do
    if [[ -e $ROOT_PREFIX/$f ]]; then
      ZSHRC_TERMUX_SRC="há /$f: as variáveis do Termux vazaram para dentro da distro"
      return 1
    fi
  done
  if command -v pkg >/dev/null 2>&1; then
    ZSHRC_TERMUX_SRC="sem sinais de distro e com 'pkg' no PATH"
    return 0
  fi
  ZSHRC_TERMUX_SRC="variáveis do Termux, mas sem 'pkg' no PATH"
  return 1
}

report_zshrc_termux() {
  if detect_zshrc_termux; then
    warn "o .zshrc do root trataria este proot como TERMUX (rodaria 'pkg update', que não existe aqui) e NÃO atualizaria o sistema; motivo: $ZSHRC_TERMUX_SRC"
  else
    log "o .zshrc do root trata este ambiente como distro Linux, não como Termux ($ZSHRC_TERMUX_SRC)"
  fi
}

proot_phase() {
  if ((DRY_RUN)); then report_zshrc_termux; report_zshrc_family; fi
  prepare_proot_pacman
  pm_update
  install_packages
  gen_locales
  create_user
  set_root_shell
  set_password
  # Root: dotfiles de "Distro Proot" (o .zshrc dele repassa a sessão para o NEW_USER).
  run_user_steps
  run_user_phase_proot
}

# ─── Setup tradicional (roda como o próprio usuário, ou como root no proot) ───
# O paru precisa não só existir, mas executar: um binário ligado a uma libalpm antiga
# existe no PATH e morre com "libalpm.so.15: cannot open shared object file".
paru_ok() { command -v paru >/dev/null && paru --version >/dev/null 2>&1; }

install_paru() {
  if ((PROOT)); then log "proot: paru não é necessário, pulando"; return 0; fi
  [[ $PM == pacman ]] || return 0
  if paru_ok; then log "paru já instalado e funcionando"; return 0; fi
  if command -v paru >/dev/null; then
    warn "paru instalado mas quebrado (provável libalpm diferente da do pacman); recompilando"
  fi

  if ((DRY_RUN)); then
    run $SUDO pacman -S --needed --noconfirm paru
    log "(se o repositório não tiver o paru: removeria o paru-bin, se houver, e compilaria o paru do AUR com makepkg)"
    return 0
  fi

  # CachyOS e alguns repos já trazem o paru pronto.
  if $SUDO pacman -S --needed --noconfirm paru 2>/dev/null && paru_ok; then
    log "paru instalado via repositório"; return 0
  fi

  # O paru-bin é pré-compilado e fica para trás quando o pacman muda a versão da libalpm.
  # Compilamos o paru do fonte e removemos o paru-bin antes (os dois conflitam).
  if pacman -Qq paru-bin >/dev/null 2>&1; then
    log "removendo o paru-bin (conflita com o paru e está quebrado)"
    $SUDO pacman -Rn --noconfirm paru-bin
  fi

  log "Compilando o paru a partir do AUR (leva alguns minutos)..."
  $SUDO pacman -S --needed --noconfirm base-devel git
  local tmp; tmp=$(mktemp -d)
  git clone --depth=1 https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  paru_ok || die "o paru foi compilado mas não executa; verifique com: ldd /usr/bin/paru"
  log "paru instalado"
}

clone_or_update() {  # url destino
  if [[ -d $2/.git ]]; then
    run git -C "$2" pull --ff-only --quiet || warn "não consegui atualizar $2"
  else
    run git clone --depth=1 "$1" "$2"
  fi
}

install_zsh_stack() {
  local zsh_dir="$HOME/.oh-my-zsh"
  local custom="${ZSH_CUSTOM:-$zsh_dir/custom}"
  # Clonamos direto em vez de usar o instalador oficial: ele sobrescreveria
  # o .zshrc e trocaria de shell no meio do script.
  clone_or_update https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"

  # O .zshrc do repo carrega o tema com: source ~/powerlevel10k/powerlevel10k.zsh-theme
  clone_or_update https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"

  # Plugins usados no plugins=(...) do .zshrc (git, fzf, history e dirhistory já vêm com o OMZ).
  clone_or_update https://github.com/zsh-users/zsh-autosuggestions.git            "$custom/plugins/zsh-autosuggestions"
  clone_or_update https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$custom/plugins/fast-syntax-highlighting"
  clone_or_update https://github.com/zsh-users/zsh-history-substring-search.git    "$custom/plugins/zsh-history-substring-search"
  log "oh-my-zsh, powerlevel10k e plugins prontos"
}

backup_and_copy() {  # origem destino
  local src=$1 dst=$2
  if [[ ! -f $src ]]; then
    if ((DRY_RUN)); then
      log "copiaria $src -> $dst (com backup se for diferente)"
      return 0
    fi
    warn "$src não existe no repo, pulando"; return 0
  fi

  if [[ -e $dst ]]; then
    if cmp -s "$src" "$dst"; then log "$dst já é igual ao do repo"; return 0; fi
    # .bak; se já existir, .bak.1, .bak.2... (nunca sobrescreve um backup antigo)
    local bak="$dst.bak" n=0
    while [[ -e $bak ]]; do n=$((n + 1)); bak="$dst.bak.$n"; done
    run cp -a "$dst" "$bak"
    log "backup: $bak"
  fi
  run cp "$src" "$dst"
  log "copiado: $dst"
}

deploy_dotfiles() {
  clone_or_update "$REPO_URL" "$REPO_DIR"

  # Termux, proot e distro normal têm dotfiles diferentes, cada um na sua subpasta.
  local sub f
  local -a files
  if [[ $PM == pkg ]]; then
    sub=$DIR_TERMUX;  files=("${DOTFILES_TERMUX[@]}")
  elif ((PROOT)); then
    sub=$DIR_PROOT;   files=("${DOTFILES_PROOT[@]}")
  else
    sub=$DIR_DISTRO;  files=("${DOTFILES_DISTRO[@]}")
  fi

  log "Aplicando dotfiles de: $sub/"
  for f in "${files[@]}"; do
    backup_and_copy "$REPO_DIR/$sub/$f" "$HOME/$f"
  done
}

deploy_kitty() {
  is_desktop || return 0   # Kitty só em distro de desktop (não Termux, não proot)
  run mkdir -p "$HOME/.config/kitty"
  backup_and_copy "$REPO_DIR/$DIR_KITTY/kitty.conf" "$HOME/.config/kitty/kitty.conf"
}

ensure_editor() {
  # Vai no ~/.zshenv (e não no .zshrc) para o .zshrc continuar idêntico ao do repo.
  # Se você preferir manter isso no repo, ponha o export no .zshrc e apague esta função.
  local f
  for f in "$HOME/.zshenv" "$HOME/.zshrc"; do
    if grep -qE '^[[:space:]]*(export[[:space:]]+)?(EDITOR|VISUAL)=' "$f" 2>/dev/null; then
      return 0
    fi
  done
  if ((DRY_RUN)); then log "definiria EDITOR/VISUAL=micro em ~/.zshenv"; return 0; fi
  printf '\n# adicionado por setup.sh\nexport EDITOR=micro\nexport VISUAL=micro\n' >> "$HOME/.zshenv"
  log "EDITOR/VISUAL=micro definido em ~/.zshenv"
}

set_default_shell() {
  # Distros de desktop e proot: o shell do novo usuário e o do root já foram definidos
  # com usermod (o chsh pede PAM/senha e não funciona bem no proot).
  if is_desktop || ((PROOT)); then return 0; fi
  local zsh_bin
  zsh_bin=$(zsh_shell_path) || { warn "zsh não encontrado, pulando chsh"; return 0; }
  if [[ ${SHELL:-} == "$zsh_bin" ]]; then return 0; fi
  if [[ $PM != pkg ]]; then
    # O chsh só aceita shells listados em /etc/shells.
    grep -qxF "$zsh_bin" /etc/shells 2>/dev/null || append_line "$zsh_bin" /etc/shells
  fi
  if [[ $PM == pkg ]]; then
    run chsh -s zsh || warn "falhou; rode: chsh -s zsh"
  else
    run chsh -s "$zsh_bin" || warn "falhou; rode: chsh -s $zsh_bin"
  fi
}

termux_font() {
  [[ $PM == pkg ]] || return 0
  local font="$HOME/.termux/font.ttf"
  if [[ -f $font ]]; then return 0; fi   # não sobrescreve fonte já escolhida
  if ((DRY_RUN)); then log "baixaria a fonte MesloLGS NF Regular para $font"; return 0; fi
  mkdir -p "$HOME/.termux"
  if curl -fsSL -o "$font" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"; then
    termux-reload-settings || true
    log "fonte MesloLGS NF instalada no Termux"
  else
    rm -f "$font"
    warn "não consegui baixar a fonte; o powerlevel10k vai mostrar glifos quebrados"
  fi
}

desktop_fonts() {
  is_desktop || return 0   # no Termux a fonte é tratada em termux_font; no proot vale a do Termux
  local dir="$HOME/.local/share/fonts/MesloLGS-NF"
  local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
  local style file tmp installed=0 failed=0

  if ((DRY_RUN)); then
    for style in "Regular" "Bold" "Italic" "Bold Italic"; do
      file="MesloLGS NF $style.ttf"
      if [[ -s $dir/$file ]]; then continue; fi
      log "baixaria: $file para $dir"
    done
    run fc-cache -f "$HOME/.local/share/fonts"
    return 0
  fi

  mkdir -p "$dir"
  for style in "Regular" "Bold" "Italic" "Bold Italic"; do
    file="MesloLGS NF $style.ttf"
    if [[ -s $dir/$file ]]; then continue; fi   # já instalada
    tmp=$(mktemp)
    if curl -fsSL -o "$tmp" "$base/${file// /%20}"; then
      chmod 644 "$tmp"
      mv "$tmp" "$dir/$file"
      installed=$((installed + 1))
    else
      rm -f "$tmp"
      failed=$((failed + 1))
      warn "não consegui baixar: $file"
    fi
  done
  if ((installed > 0)); then
    log "MesloLGS NF: $installed arquivo(s) novo(s) em $dir"
  elif ((failed == 0)); then
    log "MesloLGS NF já instalada"
  fi

  # Atualiza o cache mesmo quando nada foi baixado agora (ex.: rodada anterior interrompida).
  if command -v fc-cache >/dev/null; then
    fc-cache -f "$HOME/.local/share/fonts" || warn "fc-cache falhou"
    if fc-list | grep -qi "MesloLGS NF"; then
      log "fonte reconhecida pelo fontconfig"
    else
      warn "MesloLGS NF não apareceu no fc-list; reinicie a sessão ou rode: fc-cache -f"
    fi
  else
    warn "fc-cache não encontrado (instale o fontconfig); a fonte pode não aparecer até um novo login"
  fi
}

run_user_steps() {
  install_paru
  install_zsh_stack
  deploy_dotfiles
  deploy_kitty
  ensure_editor
  set_default_shell
  termux_font
  desktop_fonts
}

print_failed() {
  if ((${#FAILED[@]})); then
    warn "Pacotes que não foram instalados: ${FAILED[*]}"
  fi
  return 0
}

hint_p10k() {
  [[ -f $HOME/.p10k.zsh ]] || log "Sem .p10k.zsh no repo: rode 'p10k configure' na primeira abertura."
  return 0
}

# ─── Perguntas (s/N) ──────────────────────────────────────────────────────────
# Pergunta sim/não lendo do terminal (/dev/tty), mesmo com o stdin redirecionado.
# Resposta vazia = padrão ($2: s ou n). Sem terminal, devolve o padrão sem perguntar.
ask_yn() {  # pergunta [s|n]
  local q=$1 def=${2:-n} ans="" hint="[s/N]"
  [[ $def == s ]] && hint="[S/n]"
  { : </dev/tty; } 2>/dev/null || { [[ $def == s ]]; return; }
  printf '%s %s ' "$q" "$hint" >&2
  { read -r ans </dev/tty; } 2>/dev/null || ans=""
  case ${ans,,} in
    s|sim|y|yes)  return 0 ;;
    n|nao|não|no) return 1 ;;
    *)            [[ $def == s ]] ;;
  esac
}

# ─── Encerrar a sessão no fim ─────────────────────────────────────────────────
# Um "exit" dentro do script só encerraria o próprio script: o shell que o chamou
# continuaria aberto. Por isso a sessão é encerrada mandando SIGHUP para o shell
# interativo que está acima do script (pulando sudo/su/env no meio do caminho).
# Imprime o PID desse shell; retorna 1 se não achar um shell com segurança.
find_parent_shell() {
  local pid=$$ ppid comm args
  while :; do
    ppid=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status" 2>/dev/null) || return 1
    [[ $ppid =~ ^[0-9]+$ ]] && ((ppid > 1)) || return 1
    comm=$(cat "/proc/$ppid/comm" 2>/dev/null) || return 1
    case $comm in
      sudo|su|doas|env|timeout) ;;   # intermediários: continua subindo
      bash|zsh|sh|dash|ksh|fish)
        args=$(tr '\0' ' ' < "/proc/$ppid/cmdline" 2>/dev/null) || args=""
        # um shell que só está rodando este script (ex.: sh -c "bash setup.sh") não é a sessão
        if [[ -z $SCRIPT_PATH || $args != *"${SCRIPT_PATH##*/}"* ]]; then
          printf '%s\n' "$ppid"; return 0
        fi ;;
      *) return 1 ;;
    esac
    pid=$ppid
  done
}

# $1 = mensagem de aviso, mostrada quando a pessoa NÃO quer encerrar a sessão
# (ou quando não dá para perguntar/encerrar).
finish_session() {
  local msg=$1 target
  if ((DRY_RUN)); then
    log "perguntaria: \"Deseja encerrar a sessão?\" (sim = fecha o shell que chamou o script; não = mostra o aviso final)"
    return 0
  fi
  if ask_yn "Deseja encerrar a sessão? (sim = fecha este shell/terminal)" n; then
    if target=$(find_parent_shell); then
      log "Encerrando a sessão..."
      cleanup
      kill -HUP "$target" 2>/dev/null || true
      exit 0
    fi
    warn "não consegui identificar com segurança o shell que chamou o script; digite 'exit' ou feche o terminal."
  fi
  log "$msg"
}

# ─── Temas Minecraft (só desktop) ─────────────────────────────────────────────
# GRUB: minegrub-world-sel-theme (Lxtharia). Plymouth: minecraft-plymouth-theme (nikp123).
# Mexe no bootloader e no initramfs, por isso só roda se a pessoa aceitar (pergunta no
# começo ou --temas-minecraft). Antes disso tira um snapshot do snapper, se existir, e
# guarda a versão original de cada arquivo alterado em <arquivo>.mc.bak (só na primeira vez).
MC_NEED_MKCONFIG=0
GRUB_OK=0
GRUB_DIR=""; GRUB_CFG=""; GRUB_MKCONFIG=""

decide_minecraft_themes() {
  is_desktop || { MC_THEMES=0; return 0; }
  case $MC_THEMES in 1|0) return 0 ;; esac
  if ((DRY_RUN)); then
    log "perguntaria: \"Instalar os temas Minecraft (GRUB + Plymouth)?\" (simulando sim)"
    MC_THEMES=1; return 0
  fi
  if ask_yn "Instalar os temas Minecraft (GRUB + Plymouth)? Altera o bootloader e o initramfs." n; then
    MC_THEMES=1
  else
    MC_THEMES=0
  fi
}

mc_backup() {  # arquivo — guarda a versão original uma única vez (arquivo.mc.bak)
  local f=$1
  [[ -e $f && ! -e $f.mc.bak ]] || return 0
  run $SUDO cp -a "$f" "$f.mc.bak"
  # O grub-mkconfig executa tudo que for executável em /etc/grub.d, backup incluído, e isso
  # duplicaria as entradas do menu. O cp -a preserva o modo, então tira a permissão de execução.
  run $SUDO chmod a-x "$f.mc.bak"
}

# Versões antigas deste script deixavam os .mc.bak de /etc/grub.d executáveis (veja acima).
# Corrige os que já existem. Retorna 0 se mudou algo (aí o grub.cfg precisa ser regenerado).
mc_defuse_grub_d_backups() {
  local f fixed=1
  for f in "$GRUB_D_DIR"/*.mc.bak; do
    [[ -f $f && -x $f ]] || continue
    run $SUDO chmod a-x "$f"
    log "GRUB: $f deixou de ser executável (o grub-mkconfig o executaria e duplicaria entradas do menu)"
    fixed=0
  done
  return $fixed
}

mc_clone() {  # url destino
  run git clone --depth 1 --quiet "$1" "$2" && return 0
  warn "não consegui clonar $1"
  return 1
}

mc_snapshot() {
  command -v snapper >/dev/null || return 0
  snapper list-configs 2>/dev/null | grep -qE '^root[[:space:]]' || return 0
  log "snapper: snapshot antes de mexer no bootloader/initramfs"
  run $SUDO snapper -c root create -d "setup.sh: antes dos temas Minecraft" \
    || warn "o snapshot falhou; seguindo sem ele"
}

# Define CHAVE=VALOR em /etc/default/grub (troca a linha ativa ou acrescenta no fim).
grub_set() {  # chave valor
  local key=$1 val=$2 f=$GRUB_DEFAULT_FILE
  if grep -qxF "$key=$val" "$f" 2>/dev/null; then return 0; fi
  if grep -qE "^$key=" "$f" 2>/dev/null; then
    run $SUDO sed -i -E "s|^$key=.*|$key=$val|" "$f"
  else
    append_line "$key=$val" "$f"
  fi
}

# GRUB só é usado se existir /etc/default/grub, a pasta /boot/grub (ou grub2) e o grub-mkconfig.
# O tema não funciona em Limine/systemd-boot.
mc_detect_grub() {
  local pref
  GRUB_DIR=""; GRUB_CFG=""; GRUB_MKCONFIG=""
  [[ -f $GRUB_DEFAULT_FILE ]] || return 1
  if   [[ -d $BOOT_DIR/grub  ]]; then pref=grub     # Arch, Debian, Ubuntu
  elif [[ -d $BOOT_DIR/grub2 ]]; then pref=grub2    # Fedora
  else return 1; fi
  GRUB_DIR=$BOOT_DIR/$pref
  GRUB_CFG=$GRUB_DIR/grub.cfg
  GRUB_MKCONFIG=$pref-mkconfig
  command -v "$GRUB_MKCONFIG" >/dev/null
}

# Os dois patches opcionais do tema (ícone da entrada UEFI e do submenu "Advanced options").
# As expressões do sed são as do install_theme.sh do tema. Rodar de novo não duplica nada.
# Atualizações do pacote do GRUB podem desfazer isso: rode o script de novo para reaplicar.
mc_patch_grub_icons() {
  local f expr
  f=$GRUB_D_DIR/30_uefi-firmware
  if [[ -f $f ]] && ! grep -q -- '--class uefi' "$f"; then
    mc_backup "$f"
    expr='/--class uefi/!s#(menuentry '\''\$LABEL'\'')(.*)$#\1 --class uefi \2#'
    run $SUDO sed -i -E "$expr" "$f"
    log "GRUB: ícone da entrada UEFI (30_uefi-firmware)"
  fi
  f=$GRUB_D_DIR/10_linux
  if [[ -f $f ]] && ! grep -q -- '--class submenu' "$f"; then
    mc_backup "$f"
    expr='/--class submenu/!s#(gettext_printf "Advanced options for %s" "\$\{OS\}" \| grub_quote\)'\'' )\s*(.*)$#\1 --class submenu \2#'
    run $SUDO sed -i -E "$expr" "$f"
    log "GRUB: ícone do submenu Advanced options (10_linux)"
  fi
}

mc_grub_theme() {  # pasta do clone
  local src=$1 tdir=$GRUB_DIR/themes/minegrub-world-selection
  log "GRUB: instalando o tema minegrub-world-selection em $GRUB_DIR/themes"
  run $SUDO mkdir -p "$GRUB_DIR/themes"
  run $SUDO cp -ru "$src/minegrub-world-selection" "$GRUB_DIR/themes/"
  mc_backup "$GRUB_DEFAULT_FILE"
  grub_set GRUB_TERMINAL_OUTPUT gfxterm
  grub_set GRUB_TIMEOUT_STYLE menu      # o tema só aparece com o menu visível
  grub_set GRUB_THEME "$tdir/theme.txt"
  mc_patch_grub_icons
  MC_NEED_MKCONFIG=1
}

# mkinitcpio (Arch): o hook plymouth vem logo depois de udev (ou systemd).
mc_mkinitcpio_hook() {
  [[ -f $MKINITCPIO_CONF ]] || return 0   # apt usa initramfs-tools e dnf usa dracut: o install.sh do tema cuida deles
  if grep -qE '^[[:space:]]*HOOKS=\(.*\bplymouth\b' "$MKINITCPIO_CONF"; then return 0; fi
  if ! grep -qE '^[[:space:]]*HOOKS=\(.*\b(udev|systemd)\b' "$MKINITCPIO_CONF"; then
    warn "não achei 'udev' nem 'systemd' no HOOKS de $MKINITCPIO_CONF; adicione o hook 'plymouth' à mão, logo depois deles"
    return 0
  fi
  mc_backup "$MKINITCPIO_CONF"
  run $SUDO sed -i -E 's/^([[:space:]]*HOOKS=\(.*\b(udev|systemd)\b)/\1 plymouth/' "$MKINITCPIO_CONF"
  log "mkinitcpio: hook plymouth adicionado ao HOOKS"
  local d
  for d in "$MKINITCPIO_CONF_D"/*.conf; do
    if [[ -f $d ]] && grep -qE '^[[:space:]]*HOOKS=' "$d"; then
      warn "$d também define HOOKS e passa por cima do $MKINITCPIO_CONF; confira se 'plymouth' está lá"
    fi
  done
}

# O Plymouth só aparece com "splash" (e "quiet", para as mensagens do kernel não taparem a tela).
mc_splash_cmdline() {
  local f=$GRUB_DEFAULT_FILE w
  if [[ $PM == dnf ]]; then
    log "Fedora: o 'rhgb quiet' padrão já aciona o Plymouth; linha de comando do kernel mantida"
    return 0
  fi
  if ((! GRUB_OK)); then
    warn "bootloader sem GRUB: adicione 'quiet splash' à linha de comando do kernel no seu bootloader"
    return 0
  fi
  if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=' "$f"; then
    mc_backup "$f"
    append_line 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' "$f"
    log "GRUB: GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
    MC_NEED_MKCONFIG=1
    return 0
  fi
  for w in quiet splash; do
    if grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' "$f" | tail -1 | grep -qE "[\"' ]$w([\"' ]|\$)"; then continue; fi
    mc_backup "$f"
    run $SUDO sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=([\"']))(.*)\\2[[:space:]]*\$/\\1\\3 $w\\2/" "$f"
    log "GRUB: '$w' acrescentado a GRUB_CMDLINE_LINUX_DEFAULT"
    MC_NEED_MKCONFIG=1
  done
}

mc_plymouth_theme() {  # pasta do clone
  local src=$1 p shim="" pathenv=() pk=(plymouth imagemagick)
  [[ $PM == dnf ]] && pk=(plymouth plymouth-plugin-script ImageMagick)
  for p in "${pk[@]}"; do
    if ! pm_install "$p"; then
      warn "falhou: $p (tema do Plymouth pulado)"
      return 1
    fi
  done
  # Debian/Ubuntu: o plugin de texto fica num pacote à parte, quando existe.
  if [[ $PM == apt ]] && apt-cache show plymouth-label >/dev/null 2>&1; then
    pm_install plymouth-label || warn "não consegui instalar o plymouth-label (só afeta o texto da tela de senha)"
  fi
  # O install.sh do tema exige o comando "magick" (ImageMagick 7); o 6 só tem "convert".
  if ((! DRY_RUN)) && ! command -v magick >/dev/null && command -v convert >/dev/null; then
    shim=$(mktemp -d); CLEANUP_DIRS+=("$shim")
    printf '#!/bin/sh\nexec convert "$@"\n' > "$shim/magick"
    chmod 755 "$shim/magick"
    pathenv=("PATH=$shim:$PATH")
    log "ImageMagick sem 'magick': usando 'convert' no lugar"
  fi
  log "Plymouth: instalando o tema mc"
  if ! run $SUDO env ${pathenv[@]+"${pathenv[@]}"} bash -c 'cd "$1" && exec bash ./install.sh' _ "$src"; then
    warn "o install.sh do tema falhou; Plymouth não foi configurado"
    return 1
  fi
  mc_mkinitcpio_hook
  mc_splash_cmdline
  log "Plymouth: definindo o tema mc e regenerando o initramfs (pode demorar)"
  if [[ $PM == pacman ]] && command -v mkinitcpio >/dev/null; then
    # No Arch o initramfs é refeito direto pelo mkinitcpio (não dependemos do -R do plymouth).
    if ! run $SUDO plymouth-set-default-theme mc || ! run $SUDO mkinitcpio -P; then
      warn "falhou; rode: plymouth-set-default-theme mc && mkinitcpio -P"
      return 1
    fi
  elif ! run $SUDO plymouth-set-default-theme -R mc; then   # apt: update-initramfs; dnf: dracut
    warn "plymouth-set-default-theme falhou; rode: plymouth-set-default-theme -R mc"
    return 1
  fi
}

minecraft_themes() {
  [[ $MC_THEMES == 1 ]] && is_desktop || return 0
  if ((! DRY_RUN)); then
    command -v git >/dev/null || { warn "git não encontrado; temas Minecraft pulados"; return 1; }
  fi
  local tmp
  log "Temas Minecraft: GRUB (minegrub-world-selection) + Plymouth (mc)"
  GRUB_OK=0
  mc_detect_grub && GRUB_OK=1
  if ((GRUB_OK)) && mc_defuse_grub_d_backups; then MC_NEED_MKCONFIG=1; fi
  mc_snapshot
  tmp=$(mktemp -d); CLEANUP_DIRS+=("$tmp")

  if ((GRUB_OK)); then
    if mc_clone "$MC_GRUB_REPO" "$tmp/grub"; then mc_grub_theme "$tmp/grub"; fi
  else
    warn "GRUB não detectado (precisa de $GRUB_DEFAULT_FILE, $BOOT_DIR/grub ou grub2 e grub-mkconfig); tema do GRUB pulado. Ele não funciona em Limine/systemd-boot."
  fi

  if mc_clone "$MC_PLYMOUTH_REPO" "$tmp/plymouth"; then
    mc_plymouth_theme "$tmp/plymouth" || warn "o tema do Plymouth não foi concluído"
  fi

  if ((MC_NEED_MKCONFIG)); then
    log "GRUB: regenerando $GRUB_CFG"
    run $SUDO "$GRUB_MKCONFIG" -o "$GRUB_CFG" \
      || warn "falhou; rode: $GRUB_MKCONFIG -o $GRUB_CFG"
  fi
  cleanup
  log "Temas Minecraft concluídos. Para reverter, rode: bash setup.sh --reverter-temas"
}

# ─── Reverter os temas Minecraft (--reverter-temas) ───────────────────────────
# Só mexe no que os arquivos <arquivo>.mc.bak indicam que o script alterou:
#   - /etc/default/grub volta para a cópia original (.mc.bak);
#   - 30_uefi-firmware, 10_linux e mkinitcpio.conf têm só o trecho do tema removido (não voltam
#     para a cópia velha, para não desfazer uma atualização do pacote que veio depois);
#   - o tema do GRUB e os arquivos do tema do Plymouth são apagados e o tema padrão do Plymouth é resetado.
# No fim regenera o GRUB e o initramfs. Os pacotes plymouth e imagemagick continuam instalados.
mc_unpatch() {  # arquivo expressão-sed descrição — desfaz um patch do tema (só se houver .mc.bak)
  local f=$1 expr=$2 what=$3
  [[ -e $f.mc.bak ]] || return 1
  run $SUDO sed -i -E "$expr" "$f"
  run $SUDO rm -f "$f.mc.bak"
  log "revertido: $what ($f)"
}

revert_minecraft_themes() {
  local f d need_mkconfig=0 need_initramfs=0 found=0 current
  mc_detect_grub || true   # só para saber GRUB_DIR/GRUB_MKCONFIG; a falta do GRUB não impede o resto

  # O que existe para desfazer?
  for f in "$GRUB_DEFAULT_FILE" "$GRUB_D_DIR/30_uefi-firmware" "$GRUB_D_DIR/10_linux" "$MKINITCPIO_CONF"; do
    [[ -e $f.mc.bak ]] && found=1
  done
  for d in "$BOOT_DIR/grub/themes/minegrub-world-selection" "$BOOT_DIR/grub2/themes/minegrub-world-selection" \
           "$PLYMOUTH_THEMES_DIR/mc"; do
    [[ -d $d ]] && found=1
  done
  if ((! found)); then
    log "Nenhum vestígio dos temas Minecraft encontrado (sem .mc.bak nem pastas dos temas); nada a reverter."
    return 0
  fi

  log "Vai desfazer os temas Minecraft: restaura $GRUB_DEFAULT_FILE a partir de .mc.bak (edições feitas nele depois"
  log "da instalação dos temas voltam ao que era), remove os patches do GRUB/mkinitcpio, apaga os temas e regenera GRUB e initramfs."
  if ((! DRY_RUN)) && ! ask_yn "Reverter os temas Minecraft agora?" n; then
    log "Nada foi alterado."
    return 0
  fi
  mc_snapshot

  # 1. GRUB: arquivo de configuração original
  if [[ -e $GRUB_DEFAULT_FILE.mc.bak ]]; then
    run $SUDO cp -a "$GRUB_DEFAULT_FILE.mc.bak" "$GRUB_DEFAULT_FILE"
    run $SUDO rm -f "$GRUB_DEFAULT_FILE.mc.bak"
    log "revertido: $GRUB_DEFAULT_FILE"
    need_mkconfig=1
  fi
  # 2. GRUB: patches de ícone (o inverso exato do que o mc_patch_grub_icons faz)
  mc_unpatch "$GRUB_D_DIR/30_uefi-firmware" "s/(menuentry '\\\$LABEL') --class uefi /\\1/" "ícone da entrada UEFI" \
    && need_mkconfig=1
  mc_unpatch "$GRUB_D_DIR/10_linux" "s/ --class submenu //" "ícone do submenu Advanced options" \
    && need_mkconfig=1
  # 3. GRUB: o tema em si
  for d in "$BOOT_DIR/grub/themes/minegrub-world-selection" "$BOOT_DIR/grub2/themes/minegrub-world-selection"; do
    if [[ -d $d ]]; then
      run $SUDO rm -rf "$d"
      log "removido: $d"
      need_mkconfig=1
    fi
  done

  # 4. Plymouth: volta ao tema padrão antes de apagar o tema mc
  if command -v plymouth-set-default-theme >/dev/null; then
    current=$(plymouth-set-default-theme 2>/dev/null || true)
    if [[ $current == mc ]] || ((DRY_RUN)); then
      run $SUDO plymouth-set-default-theme --reset || warn "não consegui resetar o tema do Plymouth; rode: plymouth-set-default-theme --reset"
      need_initramfs=1
    fi
  fi
  # 5. mkinitcpio: tira o hook plymouth que o script colocou
  mc_unpatch "$MKINITCPIO_CONF" 's/^([[:space:]]*HOOKS=\(.*) plymouth\b/\1/' "hook plymouth do HOOKS" \
    && need_initramfs=1
  # 6. Plymouth: arquivos do tema, da fonte e dos hooks do initramfs
  for f in "$PLYMOUTH_THEMES_DIR/mc" "$MC_FONT_FILE" "$MC_FONTCONF_FILE" \
           "$DRACUT_CONF_D/99-minecraft-plymouth.conf" "$MKINITCPIO_CONF_D/99-minecraft-plymouth.conf" \
           "$INITRAMFS_HOOKS_DIR/minecraft-font-hook"; do
    if [[ -e $f ]]; then
      run $SUDO rm -rf "$f"
      log "removido: $f"
      need_initramfs=1
    fi
  done

  # 7. Regenerar
  if ((need_initramfs)); then
    log "Regenerando o initramfs (pode demorar)"
    if   [[ $PM == pacman ]] && command -v mkinitcpio >/dev/null; then run $SUDO mkinitcpio -P || warn "falhou; rode: mkinitcpio -P"
    elif [[ $PM == apt ]];    then run $SUDO update-initramfs -u -k all || warn "falhou; rode: update-initramfs -u -k all"
    elif [[ $PM == dnf ]];    then run $SUDO dracut -f --regenerate-all || warn "falhou; rode: dracut -f --regenerate-all"
    else warn "regenere o initramfs à mão"; fi
  fi
  if ((need_mkconfig)); then
    if [[ -n $GRUB_MKCONFIG ]] && command -v "$GRUB_MKCONFIG" >/dev/null; then
      log "GRUB: regenerando $GRUB_CFG"
      run $SUDO "$GRUB_MKCONFIG" -o "$GRUB_CFG" || warn "falhou; rode: $GRUB_MKCONFIG -o $GRUB_CFG"
    else
      warn "grub-mkconfig não encontrado; regenere o grub.cfg à mão"
    fi
  fi
  log "Temas Minecraft revertidos."
}

# ─── Execução ─────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  ((DRY_RUN)) && log "MODO SIMULAÇÃO: nada será alterado no sistema"

  [[ $NEW_USER =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Nome de usuário inválido: $NEW_USER"

  detect_env
  detect_pm

  if ((REVERT_MC)) && ! is_desktop; then die "--reverter-temas só vale para distros de desktop (os temas não são instalados no Termux nem no proot)."; fi

  # No proot o NEW_USER não tem sudo, então o grupo wheel não serve para nada.
  if ((PROOT)); then NEW_GROUPS=(audio video); fi

  # Fase 2 (interna): chamada pelo próprio script, já como o novo usuário (desktop ou proot).
  if ((USER_PHASE)); then
    [[ $EUID -ne 0 ]] || die "A fase do usuário não pode rodar como root."
    run_user_steps
    hint_p10k
    return 0
  fi

  # Termux: usuário único, sem criar conta.
  if [[ $PM == pkg ]]; then
    [[ $EUID -ne 0 ]] || die "Rode como usuário normal no Termux; root não é aceito."
    pm_update
    install_packages
    run_user_steps
    echo
    print_failed
    hint_p10k
    finish_session "Pronto. Abra um novo terminal ou rode: exec zsh"
    return 0
  fi

  # Proot (qualquer distro): roda como root, cria o NEW_USER sem sudo e aplica o setup nos dois.
  if ((PROOT)); then
    if ((! DRY_RUN)); then
      [[ $EUID -eq 0 ]] || die "No proot, rode como root (ex.: proot-distro login <distro>); o script cria o usuário $NEW_USER."
      [[ -f $SCRIPT_PATH ]] || die "Salve o script em disco e rode: bash setup.sh"
    fi
    proot_phase
    echo
    print_failed
    ((DRY_RUN)) && log "Simulação concluída: nada foi alterado."
    finish_session "Pronto. Abra um novo shell do root (ele pergunta se quer atualizar e entra como $NEW_USER) ou rode: su - $NEW_USER"
    return 0
  fi

  # Distros de desktop, fase 1: precisa de root.
  if [[ $EUID -ne 0 ]]; then
    if ((DRY_RUN)); then
      log "reexecutaria com sudo; simulando como root"
      SUDO=""
    else
      [[ -f $SCRIPT_PATH ]] || die "Salve o script em disco e rode: bash setup.sh"
      log "Reexecutando com sudo"
      exec sudo env "REPO_URL=$REPO_URL" "NEW_USER=$NEW_USER" "MC_THEMES=$MC_THEMES" bash "$SCRIPT_PATH" "$@"
    fi
  fi
  if ((! DRY_RUN)); then
    [[ -f $SCRIPT_PATH ]] || die "Salve o script em disco e rode: bash setup.sh"
  fi

  if ((REVERT_MC)); then
    revert_minecraft_themes
    ((DRY_RUN)) && log "Simulação concluída: nada foi alterado."
    return 0
  fi

  decide_minecraft_themes   # pergunta já no começo, para você não precisar ficar olhando o resto
  system_phase

  echo
  print_failed
  ((DRY_RUN)) && log "Simulação concluída: nada foi alterado."
  finish_session "Pronto. Entre como $NEW_USER (faça login ou rode: su - $NEW_USER)."
}

main "$@"
