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
  --dry-run, -n   mostra o que seria feito (linhas [dry]) sem alterar nada

Sem opções, o script pergunta como você quer iniciar o OXWM.
EOF_USAGE
}

SKIP_SYS=0
DRY_RUN=0
want_startx=0
dm=""
flags_given=0

for arg in "$@"; do
    case "$arg" in
        --sem-sistema) SKIP_SYS=1 ;;
        --dry-run | -n) DRY_RUN=1 ;;
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

# ------------------------------------------------------------------ distro
# shortcut: só Arch, Debian/Ubuntu e Fedora (e derivadas); outras usam --sem-sistema.
family=other
if [ -r /etc/os-release ]; then
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
        *" arch "*) family=arch ;;
        *" debian "* | *" ubuntu "*) family=debian ;;
        *" fedora "* | *" rhel "*) family=fedora ;;
        *" suse "* | *" opensuse "*) family=suse ;;
        *" alpine "*) family=alpine ;;
    esac
fi
if [ "$SKIP_SYS" -eq 0 ] && [ "$family" = other ]; then
    echo "Erro: distro sem suporte para instalar pacotes (só Arch, Debian/Ubuntu, Fedora, openSUSE e Alpine)." >&2
    echo "Instale o oxwm e as dependências à mão e rode: bash oxwm-setup.sh --sem-sistema" >&2
    exit 1
fi

# Alpine/containers costumam não ter sudo: usa doas, ou roda direto como root.
if ! command -v sudo >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
        sudo() { "$@"; }
    elif command -v doas >/dev/null 2>&1; then
        sudo() { doas "$@"; }
    fi
fi

# --dry-run: run() só imprime o comando e escrever() só informa o arquivo (formato [dry] do setup.sh).
# Imprime em stderr: alguns comandos rodam com ">/dev/null" e o [dry] sumiria.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        local a
        printf '\033[1;36m[dry]\033[0m' >&2
        for a in "$@"; do
            # argumentos simples saem como estão; os demais entre aspas simples (como no setup.sh)
            if [[ $a =~ ^[A-Za-z0-9_@%+=:,./-]+$ ]]; then printf ' %s' "$a" >&2
            elif [[ $a != *\'* ]]; then printf " '%s'" "$a" >&2
            else printf ' %q' "$a" >&2; fi
        done
        echo >&2
        return 0
    fi
    "$@"
}
escrever() {
    if [ "$DRY_RUN" -eq 1 ]; then printf '\033[1;36m[dry]\033[0m escrever %s\n' "$1" >&2; return 0; fi
    cat > "$1"
}

# Os nomes em PKGS são os do Arch; aqui viram os da distro. Sem tradução = mesmo nome.
native_name() {
    case "$family:$1" in
        debian:xorg-server) echo xserver-xorg ;;
        debian:xorg-setxkbmap) echo x11-xkb-utils ;;
        debian:xorg-xinit) echo xinit ;;
        debian:libnotify) echo libnotify-bin ;;
        debian:network-manager-applet) echo network-manager-gnome ;;
        fedora:xorg-server) echo xorg-x11-server-Xorg ;;
        fedora:xorg-setxkbmap) echo setxkbmap ;;
        fedora:xorg-xinit) echo xorg-x11-xinit ;;
        fedora:thunar) echo Thunar ;;
        fedora:lightdm-gtk-greeter) echo lightdm-gtk ;;
        suse:xorg-server) echo xorg-x11-server ;;
        suse:xorg-setxkbmap) echo setxkbmap ;;
        suse:xorg-xinit) echo xinit ;;
        suse:thunar) echo Thunar ;;
        suse:micro) echo micro-editor ;;
        suse:libnotify) echo libnotify-tools ;;
        suse:network-manager-applet) echo NetworkManager-applet ;;
        alpine:xorg-setxkbmap) echo setxkbmap ;;
        alpine:xorg-xinit) echo xinit ;;
        alpine:ttf-jetbrains-mono-nerd) echo font-jetbrains-mono-nerd ;;
        *) echo "$1" ;;
    esac
}

pm_has() {
    case "$family" in
        arch) "$helper" -Si "$1" ;;
        debian) apt-cache show "$1" ;;
        fedora) dnf -q info "$1" ;;
        suse) zypper -n info "$1" ;;
        alpine) [ -n "$(apk search -e "$1")" ] ;;
    esac >/dev/null 2>&1
}

pm_install() {
    local rc=0
    case "$family" in
        arch) run "$helper" -S --needed "$@" ;;
        debian) run sudo apt-get install -y "$@" ;;
        fedora) run sudo dnf install -y "$@" ;;
        suse) # 102/103/106 = instalou, com pendência (reiniciar, etc.); mesmo critério do setup.sh
            run sudo zypper --non-interactive install "$@" || rc=$?
            case "$rc" in 0 | 102 | 103 | 106) ;; *) return "$rc" ;; esac ;;
        alpine) run sudo apk add "$@" ;;
    esac
}

# Fora do Arch não há AUR: compila o oxwm (zig) num prefixo temporário e copia para /usr/local.
build_oxwm() {
    local deps=() src
    case "$family" in
        debian) deps=(git pkg-config libx11-dev libxft-dev libfreetype-dev libfontconfig-dev libxinerama-dev) ;;
        fedora) deps=(git pkgconf-pkg-config libX11-devel libXft-devel freetype-devel fontconfig-devel libXinerama-devel) ;;
        suse) deps=(git pkg-config libX11-devel libXft-devel freetype2-devel fontconfig-devel libXinerama-devel) ;;
        alpine) deps=(git pkgconf libx11-dev libxft-dev freetype-dev fontconfig-dev libxinerama-dev) ;;
    esac
    pm_install "${deps[@]}"
    if [ "$DRY_RUN" -eq 0 ] && ! command -v zig >/dev/null 2>&1; then
        echo "Erro: o zig não está nos repositórios da distro. Instale por https://ziglang.org/download e rode de novo." >&2
        exit 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then src=/tmp/oxwm-build; else src="$(mktemp -d)"; fi
    run git clone --depth 1 https://github.com/tonybanters/oxwm "$src/oxwm"
    run bash -c 'cd "$1" && zig build -Doptimize=ReleaseSmall --prefix "$2"' _ "$src/oxwm" "$src/out"
    run sudo cp -a "$src/out/." /usr/local/
    run rm -rf "$src"
    if [ "$DRY_RUN" -eq 0 ] && [ ! -x /usr/local/bin/oxwm ]; then
        echo "Erro: a compilação não gerou /usr/local/bin/oxwm." >&2
        exit 1
    fi
}

PKGS=(
    xorg-server xorg-setxkbmap xcape xdotool xclip feh
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
if [ "$family" = arch ]; then PKGS+=(oxwm-git); fi

# ------------------------------------------------------------------ sistema
if [ "$SKIP_SYS" -eq 0 ]; then
    helper=""
    if [ "$family" = arch ]; then
        for h in paru yay; do
            if command -v "$h" >/dev/null 2>&1; then helper="$h"; break; fi
        done
        if [ -z "$helper" ]; then
            echo "Erro: preciso de paru ou yay (o oxwm-git vem do AUR)." >&2
            exit 1
        fi
    elif ! command -v zig >/dev/null 2>&1; then
        PKGS+=(zig)
    fi

    echo
    echo "Vou fazer o seguinte:"
    echo "  - instalar (com ${helper:-o gerenciador de pacotes da distro}) os pacotes que ainda faltam"
    if [ "$family" != arch ]; then echo "  - compilar o oxwm com zig e instalar em /usr/local"; fi
    echo "  - criar /etc/X11/xorg.conf.d/40-flat-accel.conf (mouse sem aceleração)"
    if [ "$want_startx" -eq 1 ]; then echo "  - criar ~/.xinitrc (iniciar com startx)"; fi
    if [ -n "$dm" ]; then echo "  - instalar e habilitar o $dm (vale a partir do próximo boot)"; fi
    echo "  - copiar a config para $dest"
    if [ "$DRY_RUN" -eq 0 ]; then
        read -r -p "Continuar? [s/N] " ans || ans=""
        [[ "$ans" =~ ^[sS]$ ]] || exit 0
    fi

    # índice atualizado, senão o pm_has acha que pacotes existentes não existem
    # shortcut: no --dry-run o índice não é atualizado, então a lista de "não encontrados" pode vir desatualizada
    case "$family" in
        debian) run sudo apt-get update ;;
        suse) run sudo zypper --non-interactive refresh ;;
        alpine) run sudo apk update ;;
    esac
    ok=()
    faltando=()
    for p in "${PKGS[@]}"; do
        n="$(native_name "$p")"
        if pm_has "$n"; then ok+=("$n"); else faltando+=("$p"); fi
    done
    if [ "${#faltando[@]}" -gt 0 ]; then
        echo "Pacotes não encontrados (instale à mão se precisar): ${faltando[*]}"
    fi
    pm_install "${ok[@]}"
    if [ "$family" != arch ]; then build_oxwm; fi

    run sudo mkdir -p /etc/X11/xorg.conf.d
    run sudo tee /etc/X11/xorg.conf.d/40-flat-accel.conf >/dev/null <<'EOF_XORG'
Section "InputClass"
    Identifier "flat accel"
    MatchIsPointer "yes"
    MatchDriver "libinput"
    Option "AccelProfile" "flat"
EndSection
EOF_XORG
fi

# ------------------------------------------------------------------ arquivos
run mkdir -p "$dest/scripts"

# ---------------------------------------------------------------- screenshot
escrever "$dest/scripts/screenshot.sh" <<'EOF_SHOT'
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
escrever "$dest/scripts/record.sh" <<'EOF_REC'
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
escrever "$dest/scripts/powermenu.sh" <<'EOF_PWR'
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

run chmod +x "$dest/scripts/"*.sh

if [ -f "$dest/config.lua" ]; then
    bak="$dest/config.lua.bak-$(date +%F_%H-%M-%S)"
    run cp "$dest/config.lua" "$bak"
    echo "Config antiga salva em $bak"
fi
run cp "$here/config.lua" "$dest/config.lua"

# ------------------------------------------------------------------ startx
setup_startx() {
    local rc="$HOME/.xinitrc"
    if [ -f "$rc" ]; then
        local bak="$rc.bak-$(date +%F_%H-%M-%S)"
        run cp "$rc" "$bak"
        echo "~/.xinitrc antigo salvo em $bak"
    fi
    escrever "$rc" <<'EOF_XINIT'
#!/bin/sh
# Gerado por oxwm-setup.sh
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd DISPLAY XAUTHORITY
fi
exec oxwm
EOF_XINIT
    run chmod +x "$rc"
}

# ------------------------------------------------- gerenciador de login (DM)
setup_dm() {
    local name="$1" svc="$1.service"
    if [ -L /etc/systemd/system/display-manager.service ]; then
        DM_PREV="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
    fi

    # O oxwm-git normalmente já instala a sessão; só cria se estiver faltando.
    if [ ! -f /usr/share/xsessions/oxwm.desktop ]; then
        run sudo mkdir -p /usr/share/xsessions
        run sudo tee /usr/share/xsessions/oxwm.desktop >/dev/null <<'EOF_DESK'
[Desktop Entry]
Name=OXWM
Comment=OXWM window manager
Exec=oxwm
Type=Application
EOF_DESK
    fi

    if [ "$name" = lightdm ] && [ -f /etc/lightdm/lightdm.conf ]; then
        run sudo sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
    fi

    # --force troca o gerenciador atual. Não inicia agora para não derrubar
    # a sessão aberta; vale a partir do próximo boot.
    if command -v systemctl >/dev/null 2>&1; then
        run sudo systemctl enable --force "$svc"
    else
        # shortcut: OpenRC (Alpine) só liga o DM; não desliga outro já ligado e elogind/dbus/seatd ficam por sua conta
        run sudo rc-update add "$name" default
    fi
}

if [ "$want_startx" -eq 1 ]; then setup_startx; fi
if [ -n "$dm" ]; then setup_dm "$dm"; fi

# --------------------------------------------------------------------- fim
if [ "$DRY_RUN" -eq 1 ]; then
    echo
    echo "Dry-run: nada foi alterado."
    exit 0
fi
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
