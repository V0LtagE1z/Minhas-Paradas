# ── Detecção de ambiente: Termux, ou root em Ubuntu/Arch/Fedora/openSUSE (inclui proot) ──
# Diagnóstico: abra um shell com `ZSHRC_DEBUG=1 zsh` para ver o que foi detectado e por quê.
#
# ORDEM IMPORTA: dentro do proot (proot-distro) as variáveis do Termux ($TERMUX_VERSION,
# $PREFIX) podem vazar para o guest. Se o teste de Termux olhasse só para elas, o ALARM
# seria tratado como Termux (rodaria `pkg`, que não existe lá) e nunca atualizaria.
# Por isso o proot sempre vence, e o Termux só é confirmado por sinais que não vazam.

_zshrc_dbg() { [[ -n $ZSHRC_DEBUG ]] && print -u2 -- "[zshrc] $*"; return 0 }

# Existe QUALQUER sinal de uma distro Linux "de verdade"? O Termux (Android) não tem nenhum.
_zshrc_has_distro_files() {
  local f
  for f in /etc/os-release /usr/lib/os-release /etc/arch-release /etc/debian_version \
           /etc/fedora-release /etc/redhat-release /etc/SuSE-release /etc/SUSE-brand \
           /etc/alpine-release; do
    [[ -e $f ]] && return 0
  done
  return 1
}

# Estamos no Termux de verdade? (0 = sim, 1 = não)
_zshrc_is_termux() {
  # Sem nenhuma variável do Termux não há o que decidir (e não gasta fork nenhum).
  [[ -n $TERMUX_VERSION || $PREFIX == *com.termux* ]] || return 1

  # Daqui em diante as variáveis podem ser reais ou ter vazado para dentro de um proot.
  local kernel os
  kernel=${(L)$(uname -r 2>/dev/null)}
  os=$(uname -o 2>/dev/null)
  _zshrc_dbg "variáveis do Termux presentes: uname -r=$kernel | uname -o=$os"

  [[ $kernel == *proot* ]] && { _zshrc_dbg "kernel de proot → é distro, variáveis do Termux vazaram"; return 1 }
  [[ $os == Android ]]     && { _zshrc_dbg "uname -o = Android → Termux"; return 0 }
  _zshrc_has_distro_files  && { _zshrc_dbg "há os-release/marcadores de distro → variáveis do Termux vazaram"; return 1 }
  (( $+commands[pkg] ))    && { _zshrc_dbg "sem sinais de distro e com 'pkg' no PATH → Termux"; return 0 }
  _zshrc_dbg "variáveis do Termux, mas sem 'pkg' → tratando como distro"
  return 1
}

if [[ -n $ZSHRC_DEBUG ]]; then
  _zshrc_dbg "EUID=$EUID | interativo=$([[ -o interactive ]] && print sim || print não) | TERMUX_VERSION=${TERMUX_VERSION:-<vazia>} | PREFIX=${PREFIX:-<vazia>}"
fi

if _zshrc_is_termux; then
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
  # com variáveis como NAME/VERSION/ID. Preenche _UPDATE_FAMILY e _UPDATE_FAMILY_SRC
  # (globais, de propósito: nada de $(...), que roda em subshell); retorna 1 se não achar.
  # O setup.sh tem uma cópia em bash (detect_zshrc_family, usada no --dry-run):
  # se mudar a lógica aqui, mude lá também.
  _detect_update_family() {
    local f key val id="" id_like="" src="" w m pm
    _UPDATE_FAMILY=""
    _UPDATE_FAMILY_SRC=""

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
      [[ -n $id || -n $id_like ]] && { src=$f; break }
    done

    id=${(L)id}
    id_like=${(L)id_like}
    for w in ${=id} ${=id_like}; do
      case $w in
        arch|archarm|archlinux32|manjaro|manjaro-arm|endeavouros|artix|parabola) _UPDATE_FAMILY=pacman ;;
        ubuntu|debian|raspbian|kali|linuxmint)                                   _UPDATE_FAMILY=apt ;;
        fedora|rhel|centos|rocky|almalinux)                                      _UPDATE_FAMILY=dnf ;;
        opensuse*|suse|sles)                                                     _UPDATE_FAMILY=zypper ;;
        alpine)                                                                  _UPDATE_FAMILY=apk ;;
        *) continue ;;
      esac
      _UPDATE_FAMILY_SRC="ID/ID_LIKE \"$w\" em $src"
      return 0
    done

    for m in arch-release:pacman debian_version:apt fedora-release:dnf redhat-release:dnf \
             SuSE-release:zypper SUSE-brand:zypper alpine-release:apk; do
      if [[ -e /etc/${m%%:*} ]]; then
        _UPDATE_FAMILY=${m##*:}
        _UPDATE_FAMILY_SRC="arquivo /etc/${m%%:*} (sem ID reconhecível no os-release)"
        return 0
      fi
    done

    for pm in pacman:pacman apt-get:apt dnf:dnf zypper:zypper apk:apk; do
      if (( $+commands[${pm%%:*}] )); then
        _UPDATE_FAMILY=${pm##*:}
        _UPDATE_FAMILY_SRC="comando ${pm%%:*} no PATH (sem os-release nem marcadores)"
        return 0
      fi
    done

    return 1
  }

  _detect_update_family
  _zshrc_dbg "família de atualização: ${_UPDATE_FAMILY:-<não reconhecida>} (${_UPDATE_FAMILY_SRC:-sem fonte})"

  read -q "REPLY?Deseja atualizar o sistema agora? [y/N] "
  echo
  if [[ "$REPLY" == [Yy] ]]; then
    case "$_UPDATE_FAMILY" in
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
        echo "Para ver o que foi detectado: ZSHRC_DEBUG=1 zsh"
        ;;
    esac
  fi
  unfunction _detect_update_family
  unset _UPDATE_FAMILY _UPDATE_FAMILY_SRC

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
unfunction _zshrc_is_termux _zshrc_has_distro_files _zshrc_dbg 2>/dev/null

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
