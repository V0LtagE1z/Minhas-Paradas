# Inicia o fastfetch antes de tudo
fastfetch
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ "$TERM" == "linux" ]]; then
  [[ -f ~/.p10k-ascii.zsh ]] && source ~/.p10k-ascii.zsh
else
  [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
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

# ── Alias Kitty ──────────────────────────────────────────────────────────────
# alias kitty='GTK_THEME=Adwaita-dark kitty'
# ── Powerlevel10k ──────────────────────────────────────────────────────────────
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.

# Certifica que os plugins estão clonados (se ainda não fez)
# git clone https://github.com/zsh-users/zsh-autosuggestions \
# ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
#
# git clone https://github.com/zdharma-continuum/fast-syntax-highlighting \
# ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
#
# git clone https://github.com/zsh-users/zsh-history-substring-search \
# ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
#
# Instalar com o gerenciador de pacotes (fzf zoxide)
#
# Aplica
# source ~/.zshrc
