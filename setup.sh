#!/usr/bin/env bash
# setup.sh — pós-instalação: zsh + oh-my-zsh + powerlevel10k + dotfiles do repo Minhas-Paradas.
# Suporta: Termux (pkg), Debian/Ubuntu (apt), Fedora (dnf), Arch/CachyOS (pacman + paru).
# Pode ser executado várias vezes sem quebrar nada. Rode como usuário normal (não root).
set -euo pipefail

# ─── Configuração ─────────────────────────────────────────────────────────────
REPO_URL="${REPO_URL:-https://github.com/V0LtagE1z/Minhas-Paradas.git}"
REPO_DIR="${REPO_DIR:-$HOME/Minhas-Paradas}"

# Pacotes (o nome é igual nos 4 gerenciadores). Adicione os outros aqui.
PACKAGES=(zsh git curl fastfetch micro fzf zoxide wget)

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

# ─── Utilidades ───────────────────────────────────────────────────────────────
log()  { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

PM=""
SUDO="sudo"
FAILED=()

detect_pm() {
  # Termux precisa ser checado primeiro: ele também tem apt-get.
  if [[ -n "${TERMUX_VERSION:-}" || "${PREFIX:-}" == *com.termux* ]]; then
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
  [[ $PM != pkg ]] || return 0   # Kitty e fontconfig não se aplicam ao Termux
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

install_paru() {
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
  [[ $PM != pkg ]] || return 0   # Kitty não existe no Termux
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
  [[ $PM != pkg ]] || return 0   # no Termux a fonte é tratada em termux_font
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
  [[ $EUID -ne 0 ]] || die "Rode como usuário normal; o script usa sudo quando precisa."

  detect_pm
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
