#!/usr/bin/env bash
# setup.sh — pós-instalação: usuário + zsh + oh-my-zsh + powerlevel10k + dotfiles do repo Minhas-Paradas.
# Suporta: Termux (pkg), Debian/Ubuntu (apt), Fedora (dnf), Arch/CachyOS (pacman + paru)
# e Arch Linux ARM dentro de proot (pacman, como root, sem paru/Kitty/fontes).
#
# Distros de desktop: rode como root (ou com sudo). O script
#   1. instala os pacotes do sistema;
#   2. cria o usuário "gustavo" (home /home/gustavo, shell zsh, grupos wheel/audio/video);
#   3. dá sudo a ele e pede a senha dele;
#   4. executa o setup tradicional (paru, oh-my-zsh, p10k, dotfiles, Kitty, fontes) COMO esse usuário.
# Termux e Arch Linux ARM em proot: não criam usuário; rodam o setup tradicional direto
# (Termux como usuário normal; proot como root, onde o script detecta o ambiente).
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

# Usuário criado nas distros de desktop.
NEW_USER="${NEW_USER:-gustavo}"
NEW_HOME="/home/$NEW_USER"
NEW_GROUPS=(wheel audio video)

# Pacotes (o nome é igual nos 4 gerenciadores). Adicione os outros aqui.
PACKAGES=(zsh git curl fastfetch micro fzf zoxide)

# Pacotes só para distros de desktop (ignorados no Termux).
# fontconfig garante o fc-cache/fc-list usados na instalação das fontes.
DESKTOP_PACKAGES=(kitty fontconfig)

# Estrutura do repo: cada ambiente tem a sua subpasta com os próprios dotfiles.
DIR_TERMUX="Termux"
DIR_DISTRO="Distro Normal"
DIR_KITTY="Kitty"

# Arquivos de cada subpasta que serão copiados para o $HOME.
DOTFILES_TERMUX=(.zshrc .p10k.zsh)
DOTFILES_DISTRO=(.zshrc .p10k.zsh .p10k-ascii.zsh)

# Caminhos que podem ser sobrescritos por variável de ambiente (útil para testar).
OS_RELEASE_FILE="${OS_RELEASE_FILE:-}"
ARCH_RELEASE_FILE="${ARCH_RELEASE_FILE:-/etc/arch-release}"
PROC_STATUS_FILE="${PROC_STATUS_FILE:-/proc/self/status}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"

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

PM=""
SUDO="sudo"
FAILED=()
ALARM_PROOT=0   # 1 = Arch Linux ARM rodando dentro de um proot (ex.: proot-distro no Termux)
USER_PHASE=0    # 1 = chamado pelo próprio script, já como o novo usuário (interno)
SCRIPT_PATH=$(readlink -f -- "${BASH_SOURCE[0]:-$0}" 2>/dev/null || true)

CLEANUP_FILES=()
cleanup() {
  local f
  for f in ${CLEANUP_FILES[@]+"${CLEANUP_FILES[@]}"}; do rm -f -- "$f"; done
  CLEANUP_FILES=()
}
trap cleanup EXIT

usage() {
  cat <<EOF
Uso: bash setup.sh [--dry-run]

  --dry-run, -n   mostra o que seria feito (linhas [dry] e [sim]) sem alterar nada
  --help, -h      mostra esta ajuda

Variáveis úteis: NEW_USER (padrão: gustavo), REPO_URL, REPO_DIR, FORCE_ALARM_PROOT=1.
EOF
}

parse_args() {
  local a
  for a in "$@"; do
    case $a in
      --dry-run|-n) DRY_RUN=1 ;;
      --user-phase) USER_PHASE=1 ;;   # interno
      -h|--help)    usage; exit 0 ;;
      *)            die "Opção desconhecida: $a (veja: bash setup.sh --help)" ;;
    esac
  done
}

# Arch Linux ARM dentro de proot: é o único caso em que rodar como root é permitido
# sem criar usuário. FORCE_ALARM_PROOT=1 força o modo caso a detecção falhe.
detect_env() {
  if [[ ${FORCE_ALARM_PROOT:-0} == 1 ]]; then ALARM_PROOT=1; return 0; fi

  local is_alarm=0 tracer arch f
  # Algumas imagens (ex.: proot-distro do ALARM) não têm /etc/os-release; o arquivo
  # canônico é /usr/lib/os-release, então tentamos os dois.
  if [[ -z $OS_RELEASE_FILE ]]; then
    for f in /etc/os-release /usr/lib/os-release; do
      if [[ -r $f ]]; then OS_RELEASE_FILE=$f; break; fi
    done
  fi
  if [[ -n $OS_RELEASE_FILE ]] \
     && grep -qiE '^(ID="?archarm"?|NAME="?Arch Linux ARM)' "$OS_RELEASE_FILE" 2>/dev/null; then
    is_alarm=1
  fi
  # Segundo critério: Arch (tem /etc/arch-release) em CPU ARM só pode ser o ALARM,
  # já que o Arch oficial não tem build aarch64.
  arch=${UNAME_M:-$(uname -m 2>/dev/null || true)}
  if ((! is_alarm)) && [[ -e $ARCH_RELEASE_FILE ]] && [[ $arch == aarch64 || $arch == arm* ]]; then
    is_alarm=1
  fi
  # No proot cada processo é rastreado (ptrace) pelo próprio proot: TracerPid != 0.
  tracer=$(awk '/^TracerPid:/ {print $2}' "$PROC_STATUS_FILE" 2>/dev/null || true)
  if ((is_alarm)) && [[ -n $tracer && $tracer != 0 ]]; then
    ALARM_PROOT=1
  fi
}

# Ambiente gráfico de verdade? (distro de desktop; não Termux e não proot)
is_desktop() { [[ $PM != pkg && $ALARM_PROOT != 1 ]]; }

detect_pm() {
  # O ALARM/proot vem antes de tudo: variáveis do Termux podem vazar para dentro do proot.
  if ((ALARM_PROOT)); then
    PM=pacman
    log "Modo Arch Linux ARM (proot) detectado"
  # Termux precisa ser checado antes do apt: ele também tem apt-get.
  elif [[ -n "${TERMUX_VERSION:-}" || "${PREFIX:-}" == *com.termux* ]]; then
    PM=pkg; SUDO=""
  elif command -v apt-get >/dev/null; then PM=apt
  elif command -v dnf >/dev/null;     then PM=dnf
  elif command -v pacman >/dev/null;  then PM=pacman
  else die "Gerenciador de pacotes não suportado (emerge não está incluído)."
  fi

  # Root não precisa de sudo.
  if [[ $EUID -eq 0 ]]; then SUDO=""; fi
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

# ─── Arch Linux ARM em proot ──────────────────────────────────────────────────
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
  log "Inicializando o chaveiro do pacman (pode demorar no proot)..."
  run $SUDO pacman-key --init || warn "pacman-key --init falhou"
  run $SUDO pacman-key --populate archlinuxarm || warn "pacman-key --populate falhou"
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

prepare_alarm_proot() {
  ((ALARM_PROOT)) || return 0
  patch_pacman_conf
  init_keyring
  # Rootfs de ARM costuma ser antigo: -Sy sem -u causaria atualização parcial.
  log "Atualizando o sistema (pacman -Syu)..."
  run $SUDO pacman -Syu --noconfirm || warn "pacman -Syu falhou; os pacotes abaixo podem falhar"
  # O -Syu pode ter trazido um pacman mais novo, com outras opções de sandbox.
  patch_pacman_conf
  gen_locales
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
  if ! zsh_bin=$(command -v zsh); then
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
    run usermod -aG "$csv" "$NEW_USER"
    run usermod -s "$zsh_bin" "$NEW_USER"
    local cur_home; cur_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
    [[ $cur_home == "$NEW_HOME" ]] || warn "home atual de $NEW_USER é $cur_home (esperado $NEW_HOME); não movi nada"
  else
    run useradd -m -d "$NEW_HOME" -s "$zsh_bin" -G "$csv" "$NEW_USER"
    log "usuário criado: $NEW_USER (home $NEW_HOME, shell $zsh_bin, grupos $csv)"
  fi
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
  pm_update
  install_packages
  install_desktop_packages
  ensure_sudo
  create_user
  configure_sudo
  set_password
  run_user_phase
}

# ─── Setup tradicional (roda como o próprio usuário, ou como root no proot) ───
install_paru() {
  if ((ALARM_PROOT)); then log "ALARM/proot: paru não é necessário, pulando"; return 0; fi
  [[ $PM == pacman ]] || return 0
  if command -v paru >/dev/null; then log "paru já instalado"; return 0; fi

  if ((DRY_RUN)); then
    run $SUDO pacman -S --needed --noconfirm paru
    log "(se o repositório não tiver o paru, compilaria o paru-bin do AUR com makepkg)"
    return 0
  fi

  # CachyOS e alguns repos já trazem o paru pronto.
  if $SUDO pacman -S --needed --noconfirm paru 2>/dev/null; then
    log "paru instalado via repositório"; return 0
  fi

  log "Compilando paru-bin a partir do AUR..."
  $SUDO pacman -S --needed --noconfirm base-devel git
  local tmp; tmp=$(mktemp -d)
  git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
  (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
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

  # Termux e distro normal têm dotfiles diferentes, cada um na sua subpasta.
  local sub f
  local -a files
  if [[ $PM == pkg ]]; then
    sub=$DIR_TERMUX;  files=("${DOTFILES_TERMUX[@]}")
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
  # Distros de desktop: o root já definiu o shell do novo usuário com usermod.
  is_desktop && return 0
  local zsh_bin
  zsh_bin=$(command -v zsh) || { warn "zsh não encontrado, pulando chsh"; return 0; }
  if [[ ${SHELL:-} == "$zsh_bin" ]]; then return 0; fi
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

# ─── Execução ─────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  ((DRY_RUN)) && log "MODO SIMULAÇÃO: nada será alterado no sistema"

  [[ $NEW_USER =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Nome de usuário inválido: $NEW_USER"

  detect_env
  detect_pm

  # Termux e Arch Linux ARM em proot: usuário único, sem criar conta.
  if ! is_desktop; then
    if [[ $EUID -eq 0 && $ALARM_PROOT -ne 1 ]]; then
      die "Rode como usuário normal; o script usa sudo quando precisa. (Root só é aceito no Arch Linux ARM dentro de proot.)"
    fi
    prepare_alarm_proot
    pm_update
    install_packages
    install_desktop_packages
    run_user_steps
    echo
    print_failed
    log "Pronto. Abra um novo terminal ou rode: exec zsh"
    hint_p10k
    return 0
  fi

  # Distros de desktop, fase 2: chamada pelo próprio script, já como o novo usuário.
  if ((USER_PHASE)); then
    [[ $EUID -ne 0 ]] || die "A fase do usuário não pode rodar como root."
    run_user_steps
    hint_p10k
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
      exec sudo env "REPO_URL=$REPO_URL" "NEW_USER=$NEW_USER" bash "$SCRIPT_PATH" "$@"
    fi
  fi
  if ((! DRY_RUN)); then
    [[ -f $SCRIPT_PATH ]] || die "Salve o script em disco e rode: bash setup.sh"
  fi

  system_phase

  echo
  print_failed
  if ((DRY_RUN)); then
    log "Simulação concluída: nada foi alterado."
  else
    log "Pronto. Entre como $NEW_USER (faça login ou rode: su - $NEW_USER)."
  fi
}

main "$@"
