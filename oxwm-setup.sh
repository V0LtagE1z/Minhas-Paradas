#!/usr/bin/env bash
# Instalador da config OXWM (migrada do Caelestia).
# Coloque este arquivo na mesma pasta do config.lua e rode: bash oxwm-setup.sh
set -euo pipefail

usage() {
    cat <<'EOF_USAGE'
Uso: bash oxwm-setup.sh [opções]

  --startx        cria ~/.xinitrc para iniciar o OXWM com `startx`
  --dm=sddm       instala e habilita o SDDM como gerenciador de login
  --dm=lightdm    instala e habilita o LightDM (com o greeter gtk)
  --sem-sistema   só copia os arquivos do usuário: sem pacotes, sem /etc e
                  sem gerenciador de login (--startx continua valendo)

Sem opções, o script pergunta como você quer iniciar o OXWM.
EOF_USAGE
}

SKIP_SYS=0
want_startx=0
dm=""
flags_given=0

for arg in "$@"; do
    case "$arg" in
        --sem-sistema) SKIP_SYS=1 ;;
        --startx) want_startx=1; flags_given=1 ;;
        --dm=sddm | --dm=lightdm) dm="${arg#--dm=}"; flags_given=1 ;;
        --dm=*) echo "Gerenciador inválido: use --dm=sddm ou --dm=lightdm." >&2; exit 1 ;;
        -h | --help) usage; exit 0 ;;
        *) echo "Opção desconhecida: $arg" >&2; usage >&2; exit 1 ;;
    esac
done

here="$(cd "$(dirname "$0")" && pwd)"
dest="$HOME/.config/oxwm"
DM_PREV=""

if [ ! -f "$here/config.lua" ]; then
    echo "Erro: config.lua não está na mesma pasta que este script." >&2
    exit 1
fi

PKGS=(
    oxwm-git xorg-server xorg-setxkbmap xcape xdotool xclip feh
    maim slop flameshot xcolor ffmpeg
    i3lock xss-lock rofi rofi-emoji clipmenu dunst libnotify
    kitty micro thunar btop playerctl brightnessctl wireplumber
    pwvucontrol network-manager-applet ttf-jetbrains-mono-nerd
)

# ------------------------------------------------------------------ escolha
if [ "$SKIP_SYS" -eq 0 ] && [ "$flags_given" -eq 0 ]; then
    cat <<'EOF_MENU'

Como você quer iniciar o OXWM?
  1) startx  (cria ~/.xinitrc; você roda `startx` num TTY)
  2) SDDM    (gerenciador de login gráfico)
  3) LightDM (gerenciador de login gráfico)
  4) Nenhum  (continuo usando o login que já tenho)
Dá para combinar o 1 com o 2 ou o 3 (ex.: "1 2"). Só um gerenciador vale.
EOF_MENU
    read -r -p "Sua escolha [Enter = 4]: " sel || sel=""
    for tok in $sel; do
        case "$tok" in
            1) want_startx=1 ;;
            2) dm=sddm ;;
            3) dm=lightdm ;;
            4) ;;
            *) echo "Ignorando opção inválida: $tok" ;;
        esac
    done
fi

if [ "$SKIP_SYS" -eq 1 ] && [ -n "$dm" ]; then
    echo "Aviso: --sem-sistema ignora --dm=$dm (mexe em pacotes e em /etc)."
    dm=""
fi

if [ "$want_startx" -eq 1 ]; then PKGS+=(xorg-xinit); fi
case "$dm" in
    sddm) PKGS+=(sddm) ;;
    lightdm) PKGS+=(lightdm lightdm-gtk-greeter) ;;
esac

# ------------------------------------------------------------------ sistema
if [ "$SKIP_SYS" -eq 0 ]; then
    helper=""
    for h in paru yay; do
        if command -v "$h" >/dev/null 2>&1; then helper="$h"; break; fi
    done
    if [ -z "$helper" ]; then
        echo "Erro: preciso de paru ou yay (o oxwm-git vem do AUR)." >&2
        exit 1
    fi

    echo
    echo "Vou fazer o seguinte:"
    echo "  - instalar (com $helper) os pacotes que ainda faltam"
    echo "  - criar /etc/X11/xorg.conf.d/40-flat-accel.conf (mouse sem aceleração)"
    if [ "$want_startx" -eq 1 ]; then echo "  - criar ~/.xinitrc (iniciar com startx)"; fi
    if [ -n "$dm" ]; then echo "  - instalar e habilitar o $dm (vale a partir do próximo boot)"; fi
    echo "  - copiar a config para $dest"
    read -r -p "Continuar? [s/N] " ans || ans=""
    [[ "$ans" =~ ^[sS]$ ]] || exit 0

    ok=()
    faltando=()
    for p in "${PKGS[@]}"; do
        if "$helper" -Si "$p" >/dev/null 2>&1; then ok+=("$p"); else faltando+=("$p"); fi
    done
    if [ "${#faltando[@]}" -gt 0 ]; then
        echo "Pacotes não encontrados (instale à mão se precisar): ${faltando[*]}"
    fi
    case " ${faltando[*]} " in
        *" oxwm-git "*) echo "Erro: o oxwm-git não foi encontrado; sem ele não há o que configurar." >&2; exit 1 ;;
    esac
    "$helper" -S --needed "${ok[@]}"

    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/40-flat-accel.conf >/dev/null <<'EOF_XORG'
Section "InputClass"
    Identifier "flat accel"
    MatchIsPointer "yes"
    MatchDriver "libinput"
    Option "AccelProfile" "flat"
EndSection
EOF_XORG
fi

# ------------------------------------------------------------------ arquivos
mkdir -p "$dest/scripts"

# ---------------------------------------------------------------- screenshot
cat > "$dest/scripts/screenshot.sh" <<'EOF_SHOT'
#!/usr/bin/env bash
# uso: screenshot.sh full|region
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%F_%H-%M-%S).png"
case "${1:-full}" in
    region) maim -s -u "$file" || exit 0 ;;  # Esc cancela sem erro
    *)      maim -u "$file" || exit 1 ;;
esac
xclip -selection clipboard -t image/png "$file"
notify-send -i "$file" "Screenshot salva" "$file"
EOF_SHOT

# ---------------------------------------------------------------- gravação
cat > "$dest/scripts/record.sh" <<'EOF_REC'
#!/usr/bin/env bash
# uso: record.sh full|sound|region   (rode de novo para parar)
mode="${1:-full}"
pidfile="${XDG_RUNTIME_DIR:-/tmp}/oxwm-record.pid"
dir="$HOME/Videos/Recordings"

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    pid="$(cat "$pidfile")"
    kill -INT "$pid"
    for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    rm -f "$pidfile"
    notify-send "Gravação parada" "Arquivos em $dir"
    exit 0
fi

mkdir -p "$dir"
file="$dir/$(date +%F_%H-%M-%S).mp4"
input=(-f x11grab -framerate 30)
if [ "$mode" = region ]; then
    geom="$(slop -f '%x %y %w %h')" || exit 0
    read -r x y w h <<<"$geom"
    w=$((w / 2 * 2)); h=$((h / 2 * 2))
    { [ "$w" -gt 0 ] && [ "$h" -gt 0 ]; } || exit 0
    input+=(-video_size "${w}x${h}" -i "${DISPLAY:-:0}+${x},${y}")
else
    input+=(-i "${DISPLAY:-:0}")
fi

audio=()
# "sound" grava o áudio que sai do sistema. Se ficar mudo, veja os nomes com:
#   pactl list short sources
[ "$mode" = sound ] && audio=(-f pulse -i @DEFAULT_MONITOR@)

ffmpeg -nostdin -loglevel error "${input[@]}" "${audio[@]}" \
    -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p "$file" &
echo $! > "$pidfile"
notify-send "Gravação iniciada ($mode)" "Repita o atalho para parar."
EOF_REC

# ---------------------------------------------------------------- energia
cat > "$dest/scripts/powermenu.sh" <<'EOF_PWR'
#!/usr/bin/env bash
confirm() { [ "$(printf 'Não\nSim\n' | rofi -dmenu -i -p "$1?")" = "Sim" ]; }
choice="$(printf '%s\n' "Bloquear" "Suspender" "Sair da sessão" "Reiniciar" "Desligar" \
    | rofi -dmenu -i -p "Energia")"
case "$choice" in
    "Bloquear")       i3lock -c 1e1e2e ;;
    "Suspender")      systemctl suspend ;;
    "Sair da sessão") confirm "Sair" && loginctl terminate-session "${XDG_SESSION_ID:-self}" ;;
    "Reiniciar")      confirm "Reiniciar" && systemctl reboot ;;
    "Desligar")       confirm "Desligar" && systemctl poweroff ;;
esac
EOF_PWR

chmod +x "$dest/scripts/"*.sh

if [ -f "$dest/config.lua" ]; then
    bak="$dest/config.lua.bak-$(date +%F_%H-%M-%S)"
    cp "$dest/config.lua" "$bak"
    echo "Config antiga salva em $bak"
fi
cp "$here/config.lua" "$dest/config.lua"

# O config.lua aponta o feh para ~/Pictures/Wallpapers/Luna E Terra.png.
if [ -f "$here/Luna E Terra.png" ]; then
    mkdir -p "$HOME/Pictures/Wallpapers"
    cp -n "$here/Luna E Terra.png" "$HOME/Pictures/Wallpapers/"
fi

# ------------------------------------------------------------------ startx
setup_startx() {
    local rc="$HOME/.xinitrc"
    if [ -f "$rc" ]; then
        local bak="$rc.bak-$(date +%F_%H-%M-%S)"
        cp "$rc" "$bak"
        echo "~/.xinitrc antigo salvo em $bak"
    fi
    cat > "$rc" <<'EOF_XINIT'
#!/bin/sh
# Gerado por oxwm-setup.sh
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd DISPLAY XAUTHORITY
fi
exec oxwm
EOF_XINIT
    chmod +x "$rc"
}

# ------------------------------------------------- gerenciador de login (DM)
setup_dm() {
    local name="$1" svc="$1.service"
    if [ -L /etc/systemd/system/display-manager.service ]; then
        DM_PREV="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
    fi

    # O oxwm-git normalmente já instala a sessão; só cria se estiver faltando.
    if [ ! -f /usr/share/xsessions/oxwm.desktop ]; then
        sudo mkdir -p /usr/share/xsessions
        sudo tee /usr/share/xsessions/oxwm.desktop >/dev/null <<'EOF_DESK'
[Desktop Entry]
Name=OXWM
Comment=OXWM window manager
Exec=oxwm
Type=Application
EOF_DESK
    fi

    if [ "$name" = lightdm ] && [ -f /etc/lightdm/lightdm.conf ]; then
        sudo sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
    fi

    # --force troca o gerenciador atual. Não inicia agora para não derrubar
    # a sessão aberta; vale a partir do próximo boot.
    sudo systemctl enable --force "$svc"
}

if [ "$want_startx" -eq 1 ]; then setup_startx; fi
if [ -n "$dm" ]; then setup_dm "$dm"; fi

# --------------------------------------------------------------------- fim
echo
echo "Pronto. Configuração em $dest"
if [ "$want_startx" -eq 1 ]; then
    echo "startx: saia do Hyprland, abra um TTY (Ctrl+Alt+F3), faça login e rode: startx"
fi
if [ -n "$dm" ]; then
    echo "$dm habilitado para o próximo boot. Reinicie e escolha a sessão OXWM."
    if [ -n "$DM_PREV" ] && [ "$DM_PREV" != "$dm.service" ]; then
        echo "O gerenciador anterior era $DM_PREV. Para voltar:"
        echo "  sudo systemctl enable --force $DM_PREV"
    fi
fi
if [ "$want_startx" -eq 0 ] && [ -z "$dm" ]; then
    echo "Saia do Hyprland e escolha a sessão OXWM no login que você já usa."
fi
echo "Se algo der errado, a sessão do Hyprland continua intacta."
