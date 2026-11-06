#!/usr/bin/env bash
# Teste do setup.sh --dotfiles: um curl de mentira serve os arquivos desta própria pasta do repo no lugar de
# raw.githubusercontent.com. Confere as URLs (com %20), que só os arquivos necessários são baixados, o backup .bak,
# o ref escolhido e os erros. Roda num HOME temporário; não instala nada nem usa a rede.
# Uso: bash tests/dotfiles.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
repo=$(dirname "$here")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/fake" "$tmp/home"
cat > "$tmp/fake/curl" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; *) u=$1 ;; esac; shift; done
echo "$u" >> "$FAKE_LOG"
[ -z "${FAKE_FAIL:-}" ] || exit 22
p=${u#https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/}; p=${p#*/}   # tira o ref
p=$(printf '%s' "$p" | sed 's/%20/ /g')
cp "$FAKE_SRC/$p" "$o" 2>/dev/null || exit 22
EOF
chmod +x "$tmp/fake/curl"
raw=https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas

fail=0
run() {  # [VAR=valor ...] -- args do setup.sh; a saída fica em $out e os arquivos baixados em $tmp/curl.log
  local -a envs=(); while [[ $1 != -- ]]; do envs+=("$1"); shift; done; shift
  : > "$tmp/curl.log"
  out=$(env HOME="$tmp/home" FAKE_LOG="$tmp/curl.log" FAKE_SRC="$repo" PATH="$tmp/fake:$PATH" "${envs[@]}" \
        bash "$repo/setup.sh" "$@" 2>&1 </dev/null); rc=$?
}
has()   { grep -qF -- "$1" <<<"$out" || { echo "FALHOU: faltou \"$1\""; echo "$out" | tail -15; fail=1; }; }
hasnt() { ! grep -qF -- "$1" <<<"$out" || { echo "FALHOU: não devia ter \"$1\""; fail=1; }; }
fetched() { sed "s#^$raw/##" "$tmp/curl.log" | tr '\n' ' '; }   # o que foi baixado, sem o começo da URL
ok() { [[ $rc == 0 ]] || { echo "FALHOU: saiu com $rc"; echo "$out" | tail -15; fail=1; }; }

# Proot (FORCE_PROOT=1 também permite rodar como root): baixa só os 2 dotfiles de "Distro Proot", sem clonar nada.
run FORCE_PROOT=1 -- --dotfiles; ok
[[ $(fetched) == "main/Distro%20Proot/.zshrc main/Distro%20Proot/.p10k.zsh " ]] || { echo "FALHOU: URLs do proot: $(fetched)"; fail=1; }
cmp -s "$repo/Distro Proot/.zshrc" "$tmp/home/.zshrc" && cmp -s "$repo/Distro Proot/.p10k.zsh" "$tmp/home/.p10k.zsh" \
  || { echo "FALHOU: os dotfiles copiados não são os do repo"; fail=1; }
[[ ! -e $tmp/home/Minhas-Paradas ]] || { echo "FALHOU: o repo foi clonado"; fail=1; }

# De novo: nada muda, nada de backup.
run FORCE_PROOT=1 -- --dotfiles; ok; has 'já é igual'; hasnt '.bak'
[[ ! -e $tmp/home/.zshrc.bak ]] || { echo "FALHOU: criou backup de um arquivo igual"; fail=1; }

# Arquivo diferente: backup .bak e depois .bak.1 (nunca sobrescreve um backup antigo).
echo velho > "$tmp/home/.zshrc"
run FORCE_PROOT=1 -- --dotfiles; ok; has 'backup:'
[[ $(cat "$tmp/home/.zshrc.bak") == velho ]] || { echo "FALHOU: o backup não guardou o arquivo antigo"; fail=1; }
echo outro > "$tmp/home/.zshrc"
run FORCE_PROOT=1 -- --dotfiles; ok
[[ $(cat "$tmp/home/.zshrc.bak.1") == outro && $(cat "$tmp/home/.zshrc.bak") == velho ]] || { echo "FALHOU: .bak.1 errado"; fail=1; }

# DOTFILES_REF escolhe o ref da URL.
run FORCE_PROOT=1 DOTFILES_REF=v9 -- --dotfiles; ok
[[ $(fetched) == "v9/Distro%20Proot/.zshrc v9/Distro%20Proot/.p10k.zsh " ]] || { echo "FALHOU: ref v9: $(fetched)"; fail=1; }

# Download que falha: aviso com a URL, o arquivo é listado como não instalado e o que existia fica como está.
echo intacto > "$tmp/home/.zshrc"
run FORCE_PROOT=1 FAKE_FAIL=1 -- --dotfiles
has 'não consegui baixar'; has 'dotfile Distro Proot/.zshrc'
[[ $(cat "$tmp/home/.zshrc") == intacto ]] || { echo "FALHOU: um download falho mexeu no arquivo"; fail=1; }

# Simulação: não baixa nada, não escreve nada, mostra as URLs (distro normal + kitty; root é aceito só em --dry-run).
rm -f "$tmp/home"/.zshrc* "$tmp/home"/.p10k*
run -- --dotfiles --dry-run; ok
has "[sim]"; has "$raw/main/Distro%20Normal/.zshrc"; has "$raw/main/Distro%20Normal/.p10k-ascii.zsh"; has "$raw/main/Kitty/kitty.conf"
[[ ! -s $tmp/curl.log && -z $(ls -A "$tmp/home") ]] || { echo "FALHOU: a simulação baixou ou escreveu algo"; fail=1; }

# Distro normal de verdade não roda como root (aqui o teste roda como root, então cai na recusa).
if [[ $EUID -eq 0 ]]; then run -- --dotfiles; has 'rode como usuário normal'; [[ $rc != 0 ]] || { echo "FALHOU: root fora do proot devia recusar"; fail=1; }; fi

# --clonar-repo e REPO_URL fora do GitHub não usam o raw: caem no clone (em simulação só mostra o git clone).
run FORCE_PROOT=1 -- --dotfiles --clonar-repo --dry-run; ok; has 'git clone'; hasnt "$raw"
run FORCE_PROOT=1 REPO_URL=https://example.org/x.git -- --dotfiles --dry-run; ok; has 'não é do GitHub'; has 'git clone'

((fail)) && exit 1
echo "dotfiles.test.sh: ok"
