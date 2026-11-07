#!/usr/bin/env bash
# caelestia-setup.sh — instala o Caelestia (shell + Hyprland) e aplica a sua config. Só Arch e derivadas.
#   1. instala o caelestia-cli (AUR) com paru ou yay;
#   2. roda `caelestia install`, o instalador oficial: ele instala o shell e coloca a config do Hyprland em ~/.config/hypr;
#   3. copia .config/caelestia/ (hypr-vars.lua, hypr-user.lua e shell.json: só os seus overrides) para ~/.config/caelestia/.
# Esses arquivos ficam ao lado deste script, em .config/caelestia/ (como no repo). Uso: bash caelestia-setup.sh [opções]
# shortcut: o `caelestia install` é interativo e não tem opção documentada para rodar sem perguntas; ele pergunta
#   o que instalar (Spotify, Discord, zen...). Upgrade: passar as respostas quando o instalador ganhar flags.
set -euo pipefail

usage() {
    cat <<'EOF_USAGE'
Uso: bash caelestia-setup.sh [opções]

  --so-atalhos    não instala nada: só copia a config (hypr-vars.lua, hypr-user.lua e shell.json) para ~/.config/caelestia/
                  (para reaplicar depois de editar, ou numa máquina que já tem o Caelestia)
  --dry-run, -n   mostra o que seria feito (linhas [dry]) sem alterar nada
EOF_USAGE
}

ONLY_KEYS=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --so-atalhos) ONLY_KEYS=1 ;;
        --dry-run | -n) DRY_RUN=1 ;;
        -h | --help) usage; exit 0 ;;
        *) echo "Opção desconhecida: $arg" >&2; usage >&2; exit 1 ;;
    esac
done

here="$(cd "$(dirname "$0")" && pwd)"
dest="$HOME/.config/caelestia"
FILES=(hypr-vars.lua hypr-user.lua shell.json)

# Confere os arquivos antes de instalar qualquer coisa: faltando um, não adianta instalar o resto.
for f in "${FILES[@]}"; do
    if [ ! -f "$here/.config/caelestia/$f" ]; then
        echo "Erro: não achei $here/.config/caelestia/$f (a pasta .config/caelestia tem de ficar ao lado deste script)." >&2
        exit 1
    fi
done

# --dry-run: run() só imprime o comando (formato [dry] do setup.sh), em stderr.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '\033[1;36m[dry]\033[0m %s\n' "$*" >&2
        return 0
    fi
    "$@"
}

if [ "$ONLY_KEYS" -eq 0 ]; then
    if ! command -v pacman >/dev/null 2>&1; then
        echo "Erro: o Caelestia só tem instalador para Arch e derivadas (o caelestia-cli vem do AUR)." >&2
        echo "Em outra distro, siga https://github.com/caelestia-dots/caelestia e depois rode: bash caelestia-setup.sh --so-atalhos" >&2
        exit 1
    fi
    if ! command -v caelestia >/dev/null 2>&1; then
        helper=""
        for h in paru yay; do
            if command -v "$h" >/dev/null 2>&1; then helper="$h"; break; fi
        done
        if [ -z "$helper" ]; then
            echo "Erro: preciso de paru ou yay (o caelestia-cli vem do AUR). O 'Setup completo' do menu instala o paru." >&2
            exit 1
        fi
        run "$helper" -S --needed caelestia-cli
    fi
    run caelestia install
fi

# Os arquivos entram depois do instalador, que pode mexer em ~/.config/caelestia. O arquivo que já existe e difere
# vira <nome>.bak-<data>_<hora>; igual ao do repo, fica como está.
run mkdir -p "$dest"
for f in "${FILES[@]}"; do
    src="$here/.config/caelestia/$f"
    if [ -f "$dest/$f" ] && ! cmp -s "$src" "$dest/$f"; then run cp -- "$dest/$f" "$dest/$f.bak-$(date +%F_%H%M%S)"; fi
    run cp -- "$src" "$dest/$f"
done

if [ "$DRY_RUN" -eq 1 ]; then
    echo
    echo "Dry-run: nada foi alterado."
    exit 0
fi
echo
echo "Pronto. Config em $dest. Saia do Hyprland e entre de novo para valer."
