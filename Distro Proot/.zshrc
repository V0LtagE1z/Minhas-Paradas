# ── Detecção de ambiente: Termux, ou root em Ubuntu/Arch/Fedora/openSUSE ────────
if [[ -n "$TERMUX_VERSION" || "$PREFIX" == *com.termux* ]]; then
  # Termux não tem conceito de root/múltiplos usuários — só pergunta e atualiza
  if [[ -o interactive ]]; then
    read -q "REPLY?Deseja atualizar o sistema agora? [y/N] "
    echo
    if [[ "$REPLY" == [Yy] ]]; then
      pkg update && pkg upgrade -y
      apt autoclean
      apt autoremove -y
    fi
    clear
    fastfetch
  fi

elif [[ "$EUID" -eq 0 && -o interactive ]]; then
  # Linux como root: pergunta, detecta a distro, atualiza, e passa a vez para o usuário "gustavo"

  # Descobre a "família" da distro (pacman/apt/dnf/zypper/apk) SEM depender só do
  # /etc/os-release: imagens proot como o Arch Linux ARM (ALARM) podem não ter esse
  # arquivo, só o canônico /usr/lib/os-release (ou nenhum dos dois). Ordem:
  #   1. ID e depois ID_LIKE do os-release (/etc, depois /usr/lib)
  #   2. arquivos-marcadores (/etc/arch-release, /etc/debian_version etc.)
  #   3. gerenciador de pacotes presente no PATH
  # Lê o arquivo linha a linha em vez de usar `source`, para não poluir o shell
  # com variáveis como NAME/VERSION/ID. Imprime a família; retorna 1 se não achar.
  # O setup.sh tem uma cópia em bash (detect_zshrc_family, usada no --dry-run):
  # se mudar a lógica aqui, mude lá também.
  _detect_update_family() {
    local f key val id="" id_like="" w pm

    for f in /etc/os-release /usr/lib/os-release; do
      [[ -r $f ]] || continue
      while IFS='=' read -r key val || [[ -n $key ]]; do
        val=${val//\"/}
        val=${val//\'/}
        case $key in
          ID)      id=$val ;;
          ID_LIKE) id_like=$val ;;
        esac
      done < "$f"
      [[ -n $id || -n $id_like ]] && break
    done

    id=${(L)id}
    id_like=${(L)id_like}
    for w in ${=id} ${=id_like}; do
      case $w in
        arch|archarm|archlinux32|manjaro|manjaro-arm|endeavouros|artix|parabola)
          print pacman; return 0 ;;
        ubuntu|debian|raspbian|kali|linuxmint)
          print apt; return 0 ;;
        fedora|rhel|centos|rocky|almalinux)
          print dnf; return 0 ;;
        opensuse*|suse|sles)
          print zypper; return 0 ;;
        alpine)
          print apk; return 0 ;;
      esac
    done

    [[ -e /etc/arch-release ]]                           && { print pacman; return 0 }
    [[ -e /etc/debian_version ]]                         && { print apt;    return 0 }
    [[ -e /etc/fedora-release || -e /etc/redhat-release ]] && { print dnf;   return 0 }
    [[ -e /etc/SuSE-release || -e /etc/SUSE-brand ]]     && { print zypper; return 0 }
    [[ -e /etc/alpine-release ]]                         && { print apk;    return 0 }

    for pm in pacman:pacman apt-get:apt dnf:dnf zypper:zypper apk:apk; do
      (( $+commands[${pm%%:*}] )) && { print ${pm##*:}; return 0 }
    done

    return 1
  }

  read -q "REPLY?Deseja atualizar o sistema agora? [y/N] "
  echo
  if [[ "$REPLY" == [Yy] ]]; then
    case "$(_detect_update_family)" in
      pacman)
        pacman -Syu
        ;;
      apt)
        apt update && apt upgrade -y
        apt autoclean
        apt autoremove -y
        ;;
      dnf)
        dnf upgrade --refresh -y
        dnf autoremove -y
        ;;
      zypper)
        zypper refresh
        zypper update -y
        zypper clean
        ;;
      apk)
        apk update
        apk upgrade
        ;;
      *)
        echo "Distribuição não reconhecida (sem os-release, marcadores ou gerenciador de pacotes conhecido) — pulando atualização."
        ;;
    esac
  fi
  unfunction _detect_update_family

  clear
  fastfetch
# neofetch
# macchina

  # Troca para o usuário "gustavo". Se falhar (senha errada, usuário
  # inexistente etc.), NÃO usamos `exec` — isso fecharia o terminal
  # inteiro no zsh em vez de voltar pro shell do root.
  if su - gustavo; then
    exit   # sessão do gustavo terminou normalmente: fecha o shell root também
  else
    echo "Não foi possível trocar para o usuário \"gustavo\" — continuando como root."
  fi
fi

# ── A partir daqui: roda no Termux, como "gustavo", ou como root (se o `exec` acima falhar) ──

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# P10k é carregado manualmente no final — não usar tema do OMZ
ZSH_THEME=""

# ── Autosugestões: configurar ANTES de carregar o OMZ ──────────────────────────
ZSH_AUTOSUGGEST_STRATEGY=(history completion)   # sugere do histórico e depois do completion
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"    # cor cinza da sugestão inline
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20              # não sugerir para comandos muito longos

# ── Plugins ────────────────────────────────────────────────────────────────────
plugins=(
  git
  zsh-autosuggestions
  fast-syntax-highlighting
  zsh-history-substring-search
  fzf
  history
  dirhistory
)

source $ZSH/oh-my-zsh.sh

# ── Keybindings de autosugestão ────────────────────────────────────────────────
bindkey '^ '  autosuggest-accept          # Ctrl+Space aceita sugestão inteira
bindkey '^F'  autosuggest-accept          # Ctrl+F também (estilo Fish)
# Seta direita já aceita por padrão

# ── Busca no histórico por substring (seta ↑↓ inteligente) ────────────────────
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ── Completion estilo Fish ──────────────────────────────────────────────────────
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive
zstyle ':completion:*' menu select                           # menu visual no Tab
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # cores nos completions

# ── Zoxide: cd inteligente por frecência (substitui o cd nativo) ───────────────
eval "$(zoxide init zsh --cmd cd)"

# ── Locale ─────────────────────────────────────────────────────────────────────
export LANG=pt_BR.UTF-8
export LC_MESSAGES=en_US.UTF-8

# ── Powerlevel10k ──────────────────────────────────────────────────────────────
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
