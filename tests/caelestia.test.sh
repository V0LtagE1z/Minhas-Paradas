#!/usr/bin/env bash
# Teste do caelestia-setup.sh e dos arquivos de .config/caelestia/: pacman, paru e caelestia de mentira, HOME numa pasta temporária,
# nada é instalado de verdade. A parte do Lua precisa de python3 com o módulo lupa (pip install lupa); sem ele, é pulada.
# Uso: bash tests/caelestia.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
repo=$here/..
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
bad()  { echo "FALHOU: $1"; fail=1; }

# PATH mínimo (o que o script usa, mais chmod para o paru de mentira) + as mentiras; sem paru ele não existe de verdade, mesmo que a máquina tenha um.
mkdir "$tmp/min"
for c in bash env cmp cp mkdir date dirname cat chmod rm; do ln -s "$(command -v $c)" "$tmp/min/$c"; done
fake() {  # nome [conteúdo extra] — comando de mentira que registra a chamada em $FAKE_LOG
  printf '#!/bin/sh\necho "%s $*" >> "$FAKE_LOG"\n%s\n' "$1" "${2:-}" > "$tmp/min/$1"; chmod +x "$tmp/min/$1"
}
# O paru de mentira "instala" o caelestia; este, ao rodar o install, deixa um hypr-vars.lua do instalador no HOME
# (para provar que os atalhos entram depois e que o arquivo do instalador vira backup).
fake pacman
fake paru "printf '#!/bin/sh\necho \"caelestia \$*\" >> \"\$FAKE_LOG\"\necho instalador > \"\$HOME/.config/caelestia/hypr-vars.lua\"\n' > '$tmp/min/caelestia'; chmod +x '$tmp/min/caelestia'"
log=$tmp/log

run() {  # [VAR=valor ...] -- opções — roda o script com HOME em $tmp/home; saída em $out, código em $rc
  local envs=()
  while [[ ${1:-} != -- ]]; do envs+=("$1"); shift; done; shift
  out=$(env -i HOME="$tmp/home" PATH="$tmp/min" FAKE_LOG="$log" "${envs[@]}" "$tmp/min/bash" "$repo/caelestia-setup.sh" "$@" 2>&1); rc=$?
}
reset() { rm -rf "${tmp:?}/home" "$log" "$tmp/min/caelestia"; mkdir -p "$tmp/home/.config/caelestia"; : > "$log"; }
has()   { grep -qF -- "$1" <<<"$out" || bad "faltou \"$1\" na saída"; }

# --dry-run: mostra paru e install, não instala nem escreve nada.
reset; run -- --dry-run
[[ $rc == 0 ]] || bad "dry-run saiu com $rc"
has 'paru -S --needed caelestia-cli'; has 'caelestia install'; has 'Dry-run'
[[ ! -s $log && -z $(ls -A "$tmp/home/.config/caelestia") ]] || bad "dry-run não devia chamar nada nem escrever arquivos"

# Instalação: paru, depois o install do caelestia, depois os atalhos; o hypr-vars.lua do instalador vira backup.
reset; run --
[[ $rc == 0 ]] || bad "instalação saiu com $rc: $out"
[[ $(cat "$log") == $'paru -S --needed caelestia-cli\ncaelestia install' ]] || bad "ordem/chamadas erradas: $(tr '\n' '|' < "$log")"
for f in hypr-vars.lua hypr-user.lua shell.json; do cmp -s "$repo/.config/caelestia/$f" "$tmp/home/.config/caelestia/$f" || bad "$f não foi copiado igual ao do repo"; done
bak=$(ls "$tmp/home/.config/caelestia"/hypr-vars.lua.bak-* 2>/dev/null | head -1)
[[ -n $bak && $(cat "$bak") == instalador ]] || bad "o hypr-vars.lua do instalador devia virar backup"

# Reaplicar com --so-atalhos: não chama paru nem caelestia; arquivo igual ao do repo não ganha backup novo.
: > "$log"; n=$(ls "$tmp/home/.config/caelestia" | wc -l)
run -- --so-atalhos
[[ $rc == 0 && ! -s $log ]] || bad "--so-atalhos não devia chamar paru nem caelestia"
[[ $(ls "$tmp/home/.config/caelestia" | wc -l) == "$n" ]] || bad "arquivo igual ao do repo não devia gerar backup"

# Caelestia já instalado: não roda o paru, mas roda o install (o --so-atalhos existe para pular isso).
reset; fake caelestia; run --
[[ $(cat "$log") == "caelestia install" ]] || bad "com o caelestia instalado devia rodar só o install: $(tr '\n' '|' < "$log")"
rm -f "$tmp/min/caelestia"

# Sem paru nem yay: erro claro e nada rodou. Sem pacman: não é Arch.
reset; rm "$tmp/min/paru"; run --
[[ $rc == 1 ]] && has 'paru ou yay' || bad "sem helper devia sair com 1 e avisar (saiu com $rc)"
[[ ! -s $log ]] || bad "sem helper nada devia rodar"
rm "$tmp/min/pacman"; run --; [[ $rc == 1 ]] && has 'Arch' || bad "sem pacman devia sair com 1 e avisar (saiu com $rc)"
run -- --so-atalhos; [[ $rc == 0 ]] || bad "--so-atalhos devia funcionar fora do Arch (saiu com $rc)"
fake pacman; fake paru

# arquivo faltando: erro antes de instalar qualquer coisa.
reset; mkdir "$tmp/semlua"; cp "$repo/caelestia-setup.sh" "$tmp/semlua/"
out=$(env -i HOME="$tmp/home" PATH="$tmp/min" FAKE_LOG="$log" "$tmp/min/bash" "$tmp/semlua/caelestia-setup.sh" 2>&1); rc=$?
[[ $rc == 1 && ! -s $log ]] && has 'não achei' || bad "arquivo faltando devia sair com 1 antes de instalar (saiu com $rc)"
run -- --foo; [[ $rc == 1 ]] || bad "opção desconhecida devia sair com 1"

# Logo do shell.json: baixado para ~/Pictures/CachyOS.svg uma vez só; se o download falha, só avisa e a config fica aplicada.
url=https://cdn.jsdelivr.net/gh/glincker/thesvg@main/public/icons/cachyos/default.svg
fake curl 'while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; esac; shift; done; echo "<svg/>" > "$o"'
reset; run -- --so-atalhos
[[ $rc == 0 && -s $tmp/home/Pictures/CachyOS.svg ]] || bad "o logo devia ser baixado para ~/Pictures/CachyOS.svg (rc=$rc)"
grep -qF -- "-o $tmp/home/Pictures/CachyOS.svg $url" "$log" || bad "o curl devia pedir $url (log: $(tr '\n' '|' < "$log"))"
: > "$log"; run -- --so-atalhos
[[ ! -s $log ]] || bad "com o logo já baixado o curl não devia rodar de novo"
reset; run -- --dry-run
has "curl -fsSL"; [[ ! -e $tmp/home/Pictures ]] || bad "dry-run não devia criar ~/Pictures"
fake curl 'while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; esac; shift; done; echo parcial > "$o"; exit 22'
reset; run -- --so-atalhos
[[ $rc == 0 ]] && has 'Aviso: não consegui baixar o logo' || bad "download falho devia só avisar e sair com 0 (saiu com $rc)"
[[ ! -e $tmp/home/Pictures/CachyOS.svg ]] || bad "o arquivo parcial do logo devia ser apagado"
cmp -s "$repo/.config/caelestia/shell.json" "$tmp/home/.config/caelestia/shell.json" || bad "com o download falho a config devia ficar aplicada"
rm "$tmp/min/curl"

# shell.json tem de ser um JSON válido (o shell do Caelestia lê esse arquivo).
if command -v python3 >/dev/null; then
  python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$repo/.config/caelestia/shell.json" 2>/dev/null || bad "shell.json não é um JSON válido"
fi

# Os dois .lua: sintaxe e valores. Com um "hl" de mentira no lugar da API do Hyprland.
if python3 -c 'import lupa' 2>/dev/null; then
  erros=$(python3 - "$repo/.config/caelestia" <<'EOF'
import sys
from lupa import LuaRuntime
d = sys.argv[1]; lua = LuaRuntime()
v = lua.execute(open(d + "/hypr-vars.lua", encoding="utf-8").read())
exp = {"browser": "flock -n /tmp/zen.lock zen-browser || true", "kbTerminal": "SUPER + RETURN"}
for k, x in exp.items():
    if v[k] != x: print("ERRO hypr-vars.lua:", k, "=", v[k], "esperado", x)
lua.execute('''calls = {binds = {}}
hl = {config = function(t) calls.config = t end,
      monitor = function(t) calls.monitor = t end,
      bind = function(k, a) calls.binds[k] = a end,
      dsp = {exec_cmd = function(c) return "exec:" .. c end}}''')
lua.execute(open(d + "/hypr-user.lua", encoding="utf-8").read())
c = lua.globals()["calls"]
i = c["config"]["input"]
if (i["kb_layout"], i["accel_profile"]) != ("br", "flat"): print("ERRO hypr-user.lua: teclado/mouse")
if c["monitor"]["output"] != "eDP-1": print("ERRO hypr-user.lua: faltou o monitor eDP-1")
if c["binds"]["SUPER + I"] != "exec:claude-desktop": print("ERRO hypr-user.lua: Super+I devia abrir o claude-desktop")
EOF
  ) || bad "o python falhou ao carregar os .lua"
  [[ -z $erros ]] || { while read -r l; do echo "FALHOU: $l"; done <<<"$erros"; fail=1; }
else echo "pulado: sem python3 com lupa (pip install lupa) não dá para conferir os .lua"; fi

((fail)) && exit 1
echo "caelestia.test.sh: ok"
