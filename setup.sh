#!/usr/bin/env bash
# setup.sh — pós-instalação: zsh + oh-my-zsh + powerlevel10k + dotfiles do repo Minhas-Paradas.
# Suporta: Termux (pkg), Debian/Ubuntu (apt), Fedora (dnf), Arch/CachyOS (pacman + paru)
# e Arch Linux ARM dentro de proot (pacman, como root, sem paru/Kitty/fontes).
# Pode ser executado várias vezes sem quebrar nada. Rode como usuário normal (não root),
# exceto no Arch Linux ARM em proot, onde o script detecta o ambiente e aceita root.
set -euo pipefail

# ─── Configuração ─────────────────────────────────────────────────────────────
REPO_URL="${REPO_URL:-https://github.com/V0LtagE1z/Minhas-Paradas.git}"
REPO_DIR="${REPO_DIR:-$HOME/Minhas-Paradas}"

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
OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
PROC_STATUS_FILE="${PROC_STATUS_FILE:-/proc/self/status}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"

# ─── Utilidades ───────────────────────────────────────────────────────────────
log()  { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

PM=""
SUDO="sudo"
FAILED=()
ALARM_PROOT=0   # 1 = Arch Linux ARM rodando dentro de um proot (ex.: proot-distro no Termux)

# Arch Linux ARM dentro de proot: é o único caso em que rodar como root é permitido.
# FORCE_ALARM_PROOT=1 força o modo caso a detecção falhe.
detect_env() {
  if [[ ${FORCE_ALARM_PROOT:-0} == 1 ]]; then ALARM_PROOT=1; return 0; fi

  local is_alarm=0 tracer
  if grep -qiE '^(ID="?archarm"?|NAME="?Arch Linux ARM)' "$OS_RELEASE_FILE" 2>/dev/null; then
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
    if [[ $EUID -eq 0 ]]; then SUDO=""; fi
    log "Modo Arch Linux ARM (proot) detectado"
  # Termux precisa ser checado antes do apt: ele também tem apt-get.
  elif [[ -n "${TERMUX_VERSION:-}" || "${PREFIX:-}" == *com.termux* ]]; then
    PM=pkg; SUDO=""
  elif command -v apt-get >/dev/null; then PM=apt
  elif command -v dnf >/dev/null;     then PM=dnf
  elif command -v pacman >/dev/null;  then PM=pacman
  else die "Gerenciador de pacotes não suportado (emerge não está incluído)."
  fi
  if [[ -n $SUDO ]] && ! command -v sudo >/dev/null; then
    die "sudo não encontrado. Instale-o ou ajuste o script."
  fi
  log "Gerenciador detectado: $PM"
}

pm_update() {
  case $PM in
    pkg) pkg update -y ;;
    apt) $SUDO apt-get update ;;
    *)   : ;;  # dnf atualiza metadados sozinho; no pacman evitamos -Sy isolado
  esac
}

pm_install() {  # instala UM pacote
  case $PM in
    pkg)    pkg install -y "$1" ;;
    apt)    $SUDO apt-get install -y "$1" ;;
    dnf)    $SUDO dnf install -y "$1" ;;
    pacman) $SUDO pacman -S --needed --noconfirm "$1" ;;
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
    sed -i -E "s/^[[:space:]]*#[[:space:]]*($opt)[[:space:]]*$/\1/" "$conf"
  else
    sed -i "/^\[options\]/a $opt" "$conf"
  fi
  log "pacman.conf: $opt ativado"
}

conf_disable() {  # comenta uma diretiva (com ou sem valor)
  local opt=$1 conf=$PACMAN_CONF
  if grep -qE "^[[:space:]]*$opt([[:space:]=]|$)" "$conf"; then
    sed -i -E "s/^([[:space:]]*$opt([[:space:]=]|$))/#\1/" "$conf"
    log "pacman.conf: $opt desativado"
  fi
}

patch_pacman_conf() {
  local conf=$PACMAN_CONF ver major minor
  [[ -f $conf ]] || { warn "$conf não encontrado"; return 0; }
  if [[ ! -e $conf.bak ]]; then cp -a "$conf" "$conf.bak"; log "backup: $conf.bak"; fi

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
  $SUDO pacman-key --init || warn "pacman-key --init falhou"
  $SUDO pacman-key --populate archlinuxarm || warn "pacman-key --populate falhou"
}

gen_locales() {  # o .zshrc usa pt_BR.UTF-8 e en_US.UTF-8; rootfs mínimo costuma ter só uma
  command -v locale-gen >/dev/null || return 0
  local f=${LOCALE_GEN_FILE:-/etc/locale.gen} l changed=0
  [[ -f $f ]] || return 0
  for l in "pt_BR.UTF-8 UTF-8" "en_US.UTF-8 UTF-8"; do
    if grep -qE "^${l}\s*$" "$f"; then continue; fi
    if grep -qE "^#\s*${l}\s*$" "$f"; then
      $SUDO sed -i -E "s/^#\s*(${l})\s*$/\1/" "$f"
    else
      printf '%s\n' "$l" | $SUDO tee -a "$f" >/dev/null
    fi
    changed=1
  done
  if ((changed)); then $SUDO locale-gen && log "locales pt_BR e en_US geradas" || warn "locale-gen falhou"; fi
}

prepare_alarm_proot() {
  ((ALARM_PROOT)) || return 0
  patch_pacman_conf
  init_keyring
  # Rootfs de ARM costuma ser antigo: -Sy sem -u causaria atualização parcial.
  log "Atualizando o sistema (pacman -Syu)..."
  $SUDO pacman -Syu --noconfirm || warn "pacman -Syu falhou; os pacotes abaixo podem falhar"
  # O -Syu pode ter trazido um pacman mais novo, com outras opções de sandbox.
  patch_pacman_conf
  gen_locales
}

install_paru() {
  if ((ALARM_PROOT)); then log "ALARM/proot: paru não é necessário, pulando"; return 0; fi
  [[ $PM == pacman ]] || return 0
  if command -v paru >/dev/null; then log "paru já instalado"; return 0; fi

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
    git -C "$2" pull --ff-only --quiet || warn "não consegui atualizar $2"
  else
    git clone --depth=1 "$1" "$2"
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
  if [[ ! -f $src ]]; then warn "$src não existe no repo, pulando"; return 0; fi

  if [[ -e $dst ]]; then
    if cmp -s "$src" "$dst"; then log "$dst já é igual ao do repo"; return 0; fi
    # .bak; se já existir, .bak.1, .bak.2... (nunca sobrescreve um backup antigo)
    local bak="$dst.bak" n=0
    while [[ -e $bak ]]; do n=$((n + 1)); bak="$dst.bak.$n"; done
    cp -a "$dst" "$bak"
    log "backup: $bak"
  fi
  cp "$src" "$dst"
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
  mkdir -p "$HOME/.config/kitty"
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
  printf '\n# adicionado por setup.sh\nexport EDITOR=micro\nexport VISUAL=micro\n' >> "$HOME/.zshenv"
  log "EDITOR/VISUAL=micro definido em ~/.zshenv"
}

set_default_shell() {
  local zsh_bin
  zsh_bin=$(command -v zsh) || { warn "zsh não encontrado, pulando chsh"; return 0; }
  if [[ ${SHELL:-} == "$zsh_bin" ]]; then return 0; fi
  if [[ $PM == pkg ]]; then
    chsh -s zsh || warn "falhou; rode: chsh -s zsh"
  else
    chsh -s "$zsh_bin" || warn "falhou; rode: chsh -s $zsh_bin"
  fi
}

termux_font() {
  [[ $PM == pkg ]] || return 0
  local font="$HOME/.termux/font.ttf"
  if [[ -f $font ]]; then return 0; fi   # não sobrescreve fonte já escolhida
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

# ─── Execução ─────────────────────────────────────────────────────────────────
main() {
  detect_env
  if [[ $EUID -eq 0 && $ALARM_PROOT -ne 1 ]]; then
    die "Rode como usuário normal; o script usa sudo quando precisa. (Root só é aceito no Arch Linux ARM dentro de proot.)"
  fi

  detect_pm
  prepare_alarm_proot
  pm_update
  install_packages
  install_desktop_packages
  install_paru
  install_zsh_stack
  deploy_dotfiles
  deploy_kitty
  ensure_editor
  set_default_shell
  termux_font
  desktop_fonts

  echo
  if ((${#FAILED[@]})); then
    warn "Pacotes que não foram instalados: ${FAILED[*]}"
  fi
  log "Pronto. Abra um novo terminal ou rode: exec zsh"
  [[ -f $HOME/.p10k.zsh ]] || log "Sem .p10k.zsh no repo: rode 'p10k configure' na primeira abertura."
}

main "$@"
