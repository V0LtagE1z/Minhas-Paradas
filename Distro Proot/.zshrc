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
  [[ -r /etc/os-release ]] && source /etc/os-release

  read -q "REPLY?Deseja atualizar o sistema agora? [y/N] "
  echo
  if [[ "$REPLY" == [Yy] ]]; then
    case "$ID" in
      arch|archarm|archlinux32|manjaro|manjaro-arm|endeavouros)
        pacman -Syu
        ;;
      ubuntu|debian)
        apt update && apt upgrade -y
        apt autoclean
        apt autoremove -y
        ;;
      fedora)
        dnf upgrade --refresh -y
        dnf autoremove -y
        ;;
      opensuse*|sles)
        zypper refresh
        zypper update -y
        zypper clean
        ;;
      alpine)
        apk update
        apk upgrade
        ;;
      *)
        # $ID não bateu com nada acima — tenta pelo $ID_LIKE, que toda
        # distro derivada declara apontando pra "família" dela (ex.:
        # Parabola, Artix etc. têm ID_LIKE=arch mesmo com um ID= próprio
        # que a gente não previu aqui).
        case " $ID_LIKE " in
          *" arch "*)
            pacman -Syu
            ;;
          *" debian "*|*" ubuntu "*)
            apt update && apt upgrade -y
            apt autoclean
            apt autoremove -y
            ;;
          *" fedora "*|*" rhel "*)
            dnf upgrade --refresh -y
            dnf autoremove -y
            ;;
          *" suse "*|*" opensuse "*)
            zypper refresh
            zypper update -y
            zypper clean
            ;;
          *" alpine "*)
            apk update
            apk upgrade
            ;;
          *)
            echo "Distribuição não reconhecida ($ID) — pulando atualização."
            ;;
        esac
        ;;
    esac
  fi

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
