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
case $u in https://api.github.com/repos/V0LtagE1z/Minhas-Paradas/contents/*)   # listagem de uma pasta, no formato da API
  d=${u#*/contents/}; d=${d%%\?*}
  { echo '['; for f in "$FAKE_SRC/$d"/*; do printf '  {\n    "name": "%s",\n    "path": "%s/%s",\n    "type": "file"\n  },\n' "${f##*/}" "$d" "${f##*/}"; done; echo ']'; } > "$o"
  exit 0 ;;
esac
p=${u#https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/}; p=${p#*/}   # tira o ref
p=$(printf '%s' "$p" | sed 's/%20/ /g')
cp "$FAKE_SRC/$p" "$o" 2>/dev/null || exit 22
EOF
chmod +x "$tmp/fake/curl"
raw=https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas

fail=0
U=()   # prefixo para rodar como outro usuário (veja a parte dos wallpapers); vazio = como quem roda o teste
run() {  # [VAR=valor ...] -- args do setup.sh; a saída fica em $out e os arquivos baixados em $tmp/curl.log
  local -a envs=(); while [[ $1 != -- ]]; do envs+=("$1"); shift; done; shift
  : > "$tmp/curl.log"; chmod 666 "$tmp/curl.log"
  out=$(${U[@]+"${U[@]}"} env HOME="$tmp/home" FAKE_LOG="$tmp/curl.log" FAKE_SRC="$repo" PATH="$tmp/fake:$PATH" "${envs[@]}" \
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
has "[sim]"; has "$raw/main/Distro%20Normal/.zshrc"; has "$raw/main/Distro%20Normal/.p10k-ascii.zsh"; has "$raw/main/.config/kitty/kitty.conf"
[[ ! -s $tmp/curl.log && -z $(ls -A "$tmp/home") ]] || { echo "FALHOU: a simulação baixou ou escreveu algo"; fail=1; }

# Distro normal de verdade não roda como root (aqui o teste roda como root, então cai na recusa).
if [[ $EUID -eq 0 ]]; then run -- --dotfiles; has 'rode como usuário normal'; [[ $rc != 0 ]] || { echo "FALHOU: root fora do proot devia recusar"; fail=1; }; fi

# --clonar-repo e REPO_URL fora do GitHub não usam o raw: caem no clone (em simulação só mostra o git clone).
run FORCE_PROOT=1 -- --dotfiles --clonar-repo --dry-run; ok; has 'git clone'; hasnt "$raw"
run FORCE_PROOT=1 REPO_URL=https://example.org/x.git -- --dotfiles --dry-run; ok; has 'não é do GitHub'; has 'git clone'

# ─── --wallpapers: Wallpapers/ do repo → Imagens/Wallpapers ou Pictures/Wallpapers ───────────────────────────────
# O de verdade recusa root fora do proot, então roda como usuário comum: o próprio, ou "nobody" (setpriv) se o teste roda como root.
if [[ $EUID -eq 0 ]]; then
  if command -v setpriv >/dev/null; then
    U=(setpriv --reuid=65534 --regid=65534 --clear-groups); chmod 755 "$tmp" "$tmp/fake"
  else echo "pulado: wallpapers de verdade como root precisam do setpriv"; U=(skip); fi
fi
if [[ ${U[0]:-} != skip ]]; then
  # Repo de mentira: duas imagens (uma com extensão maiúscula e espaço), um texto e uma subpasta, que não são wallpapers.
  mkdir -p "$tmp/wp/Wallpapers/sub"; echo texto > "$tmp/wp/Wallpapers/notas.txt"
  cp "$repo/Wallpapers/"* "$tmp/wp/Wallpapers/"; cp "$repo/Wallpapers/"* "$tmp/wp/Wallpapers/Foto Grande.PNG"; chmod -R a+rX "$tmp/wp"
  # shellcheck disable=SC2016  # o $HOME é para o script de mentira expandir, não para este
  printf '#!/bin/sh\necho "${FAKE_XDG:-$HOME}"\n' > "$tmp/fake/xdg-user-dir"; chmod +x "$tmp/fake/xdg-user-dir"
  noloc=(LOCALE_CONF_FILE="$tmp/nada" LOCALE_DEFAULT_FILE="$tmp/nada" PROFILE_LOCALE_FILE="$tmp/nada")
  wp() {  # [VAR=valor ...] -- args; casa limpa (nobody-gravável) a cada chamada; imagens: $tmp/uhome/<pasta>/Wallpapers
    rm -rf "$tmp/uhome"; mkdir "$tmp/uhome"; chmod 777 "$tmp/uhome"
    local -a e=(); while [[ $1 != -- ]]; do e+=("$1"); shift; done; shift
    run HOME="$tmp/uhome" FAKE_SRC="$tmp/wp" LC_ALL= LANG=en_US.UTF-8 "${noloc[@]}" "${e[@]}" -- "$@"
  }
  want="$tmp/wp/Wallpapers/Luna E Terra.jpg"
  apiurl="https://api.github.com/repos/V0LtagE1z/Minhas-Paradas/contents/Wallpapers?ref=main"

  # Sistema em inglês, sem pasta nenhuma: cria Pictures/Wallpapers e copia só as imagens (nada de .txt nem subpasta).
  wp -- --wallpapers; ok
  grep -qxF "$apiurl" "$tmp/curl.log" || { echo "FALHOU: não consultou a API: $(cat "$tmp/curl.log" | tr '\n' ' ')"; fail=1; }
  [[ $(ls "$tmp/uhome/Pictures/Wallpapers" 2>&1) == $'Foto Grande.PNG\nLuna E Terra.jpg' ]] \
    || { echo "FALHOU: esperava só as 2 imagens em Pictures/Wallpapers: $(ls -R "$tmp/uhome" 2>&1 | tr '\n' ' ')"; fail=1; }
  cmp -s "$want" "$tmp/uhome/Pictures/Wallpapers/Luna E Terra.jpg" || { echo "FALHOU: a imagem copiada não é a do repo"; fail=1; }
  grep -qxF "$raw/main/Wallpapers/Foto%20Grande.PNG" "$tmp/curl.log" || { echo "FALHOU: URL da imagem sem %20: $(cat "$tmp/curl.log" | tr '\n' ' ')"; fail=1; }
  [[ ! -e $tmp/uhome/Imagens && ! -e $tmp/uhome/.zshrc ]] || { echo "FALHOU: criou pasta ou dotfile a mais"; fail=1; }
  ! grep -qE 'notas\.txt|/sub$' "$tmp/curl.log" || { echo "FALHOU: pediu o .txt ou a subpasta (não são imagens): $(cat "$tmp/curl.log" | tr '\n' ' ')"; fail=1; }

  # Sistema em português: Imagens (por LANG, e também só pelo locale.conf, que é o que o setup.sh grava).
  wp LANG=pt_BR.UTF-8 -- --wallpapers; ok
  [[ -f $tmp/uhome/Imagens/Wallpapers/Luna\ E\ Terra.jpg && ! -e $tmp/uhome/Pictures ]] || { echo "FALHOU: pt_BR devia usar Imagens"; fail=1; }
  printf 'LANG="pt_BR.UTF-8"\nLC_MESSAGES=en_US.UTF-8\n' > "$tmp/locale.conf"; chmod a+r "$tmp/locale.conf"
  wp LOCALE_CONF_FILE="$tmp/locale.conf" -- --wallpapers; ok
  [[ -f $tmp/uhome/Imagens/Wallpapers/Luna\ E\ Terra.jpg ]] || { echo "FALHOU: locale.conf pt_BR devia dar Imagens"; fail=1; }

  # Quem já tem a pasta manda: Imagens existente vence o LANG em inglês; a do XDG vence tudo; $HOME (XDG sem config) é ignorado.
  rm -rf "$tmp/uhome"; mkdir "$tmp/uhome" "$tmp/uhome/Imagens"; chmod -R 777 "$tmp/uhome"
  run HOME="$tmp/uhome" FAKE_SRC="$tmp/wp" LC_ALL= LANG=en_US.UTF-8 "${noloc[@]}" -- --wallpapers; ok
  [[ -f $tmp/uhome/Imagens/Wallpapers/Luna\ E\ Terra.jpg && ! -e $tmp/uhome/Pictures ]] || { echo "FALHOU: Imagens existente devia ser usada"; fail=1; }
  wp FAKE_XDG="$tmp/uhome/MinhasFotos" -- --wallpapers; ok
  [[ -f $tmp/uhome/MinhasFotos/Wallpapers/Luna\ E\ Terra.jpg ]] || { echo "FALHOU: a pasta do XDG devia ser usada"; fail=1; }
  wp FAKE_XDG="$tmp/uhome" -- --wallpapers; ok
  [[ -f $tmp/uhome/Pictures/Wallpapers/Luna\ E\ Terra.jpg && ! -e $tmp/uhome/Wallpapers ]] || { echo "FALHOU: XDG = HOME (sem config) devia cair em Pictures"; fail=1; }

  # Não sobrescreve o que já existe (o arquivo do usuário com o mesmo nome fica como está).
  wp -- --wallpapers; ok
  echo meu > "$tmp/uhome/Pictures/Wallpapers/Luna E Terra.jpg"
  run HOME="$tmp/uhome" FAKE_SRC="$tmp/wp" LC_ALL= LANG=en_US.UTF-8 "${noloc[@]}" -- --wallpapers; ok; has 'já existe'
  [[ $(cat "$tmp/uhome/Pictures/Wallpapers/Luna E Terra.jpg") == meu ]] || { echo "FALHOU: sobrescreveu uma imagem existente"; fail=1; }

  # API fora do ar: aviso claro, entra na lista de falhas e não cria a pasta.
  wp FAKE_FAIL=1 -- --wallpapers; has 'não consegui listar'; has 'wallpapers'
  [[ ! -e $tmp/uhome/Pictures ]] || { echo "FALHOU: criou a pasta sem ter imagem"; fail=1; }

  # DOTFILES_REF vai na consulta da API; --dry-run não baixa nem cria nada e mostra o destino.
  wp DOTFILES_REF=v9 -- --wallpapers; ok
  grep -qxF "${apiurl%main}v9" "$tmp/curl.log" || { echo "FALHOU: o ref v9 não foi para a API: $(cat "$tmp/curl.log" | tr '\n' ' ')"; fail=1; }
  wp -- --wallpapers --dry-run; ok; has 'baixaria as imagens'; has "$tmp/uhome/Pictures/Wallpapers"
  [[ ! -s $tmp/curl.log && -z $(ls -A "$tmp/uhome") ]] || { echo "FALHOU: a simulação baixou ou criou algo"; fail=1; }

  # Com o repo clonado (--clonar-repo ou REPO_URL fora do GitHub) lê a pasta do clone, sem API nem raw. O clone de mentira é um
  # repo git local; uma subpasta "x.png" e um .txt não contam como imagem.
  git init -q "$tmp/clone-src" && cp -r "$tmp/wp/Wallpapers" "$tmp/clone-src/" && mkdir "$tmp/clone-src/Wallpapers/falsa.png"
  git -C "$tmp/clone-src" add -A && git -C "$tmp/clone-src" -c user.name=t -c user.email=t@t commit -q -m t --allow-empty
  [[ $EUID -ne 0 ]] || chown -R 65534:65534 "$tmp/clone-src"
  wp REPO_URL="$tmp/clone-src" REPO_DIR="$tmp/uhome/clone" -- --wallpapers; ok
  [[ $(ls "$tmp/uhome/Pictures/Wallpapers" 2>&1) == $'Foto Grande.PNG\nLuna E Terra.jpg' ]] \
    || { echo "FALHOU: clone: esperava só as 2 imagens: $(ls -R "$tmp/uhome" 2>&1 | tr '\n' ' ')"; fail=1; }
  [[ ! -s $tmp/curl.log ]] || { echo "FALHOU: com o clone não devia usar curl: $(cat "$tmp/curl.log" | tr '\n' ' ')"; fail=1; }

  # --dotfiles sozinho não mexe nos wallpapers.
  wp -- --dotfiles; ok
  [[ ! -e $tmp/uhome/Pictures ]] || { echo "FALHOU: --dotfiles criou a pasta de wallpapers"; fail=1; }
fi
U=()
# Sem interface gráfica (proot, Termux, WSL) --wallpapers diz que não faz nada e não baixa nada.
run FORCE_PROOT=1 -- --wallpapers; ok; has 'só em distro de desktop'
[[ ! -s $tmp/curl.log ]] || { echo "FALHOU: o proot baixou algo: $(fetched)"; fail=1; }

((fail)) && exit 1
echo "dotfiles.test.sh: ok"
