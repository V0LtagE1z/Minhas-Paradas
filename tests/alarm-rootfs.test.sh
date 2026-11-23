#!/usr/bin/env bash
# Teste da instalação do Arch no proot-distro (Termux): termux_proot_distro, fetch_alarm_rootfs e verify_alarm_rootfs
# do setup.sh. As funções são extraídas do script e rodam com um GnuPG de verdade (chaves de teste num chaveiro
# temporário); só o keyserver, o curl e o proot-distro são de mentira. Confere que o rootfs do Arch Linux ARM só é
# instalado com assinatura PGP válida da chave fixada: arquivo adulterado, assinatura de outra chave, chave expirada,
# .sig ausente e keyserver fora do ar devem recusar a instalação. Confere também a escolha de mirrors (o mais rápido
# primeiro, o oficial sempre de reserva, mirror que falha ou serve arquivo adulterado é descartado). Não usa a rede nem
# instala nada.
# Uso: bash tests/alarm-rootfs.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
repo=$(dirname "$here")
command -v gpg >/dev/null 2>&1 || { echo "pulado: o teste precisa do gpg"; exit 0; }
tmp=$(mktemp -d); trap 'gpgconf --homedir "$tmp/gk" --kill all >/dev/null 2>&1; gpgconf --homedir "$tmp/gv" --kill all >/dev/null 2>&1; rm -rf "$tmp"' EXIT
mkdir -m 700 "$tmp/gk" "$tmp/bin" "$tmp/fx"
real_gpg=$(command -v gpg)

# ── Rootfs de teste (o nome do arquivo é o mesmo do servidor oficial) ──
tarname=ArchLinuxARM-aarch64-latest.tar.gz
head -c 4096 /dev/urandom > "$tmp/fx/$tarname"
cp "$tmp/fx/$tarname" "$tmp/fx/tampered.tar.gz"; printf 'x' >> "$tmp/fx/tampered.tar.gz"

# ── Chaves de teste: a "oficial" (que o script fixa), uma impostora e uma que expira em 2 s ──
mkkey() {  # nome [expiração]
  gpg --homedir "$tmp/gk" --batch --passphrase '' --quick-gen-key "$1 <$1@teste>" default default "${2:-never}" >/dev/null 2>&1
  gpg --homedir "$tmp/gk" --batch --with-colons --fingerprint "$1@teste" | awk -F: '/^fpr/{print $10; exit}'
}
sign() { gpg --homedir "$tmp/gk" --batch --yes --local-user "$1@teste" --detach-sign -o "$2" "$tmp/fx/$tarname" >/dev/null 2>&1; }
FPR_EXP=$(mkkey expirada seconds=2); sign expirada "$tmp/fx/exp.sig"   # assinada logo, enquanto ainda vale
FPR_OK=$(mkkey oficial); FPR_BAD=$(mkkey impostor)
[[ -n $FPR_OK && -n $FPR_BAD && -n $FPR_EXP && -s $tmp/fx/exp.sig ]] || { echo "FALHOU: não consegui gerar as chaves de teste (o gpg aceita expiração seconds=N?)"; exit 1; }
sign oficial  "$tmp/fx/ok.sig"
sign impostor "$tmp/fx/bad.sig"
for k in oficial impostor expirada; do gpg --homedir "$tmp/gk" --batch --armor --export "$k@teste" > "$tmp/fx/$k.asc"; done
sleep 3   # a chave "expirada" passa a ter expirado

# ── Binários de mentira ──
# gpg: --recv-keys "baixa" a chave de $FAKE_KEYFILE (ou falha se FAKE_NOKEYSERVER); o resto é o gpg de verdade.
# --recv-keys leva keyserver e fingerprint; como "--import" lê o arquivo, tiro esses dois argumentos antes.
cat > "$tmp/bin/gpg" <<EOF
#!/bin/bash
out=()
recv=0
skip=0
for a in "\$@"; do
  if [ \$skip = 1 ]; then skip=0; continue; fi
  case \$a in
    --keyserver) skip=1 ;;
    --recv-keys) recv=1; skip=1 ;;
    *) out+=("\$a") ;;
  esac
done
if [ \$recv = 1 ]; then
  [ -z "\${FAKE_NOKEYSERVER:-}" ] || exit 2
  echo keyserver >> "\$FAKE_LOG"
  exec "$real_gpg" "\${out[@]}" --import "\$FAKE_KEYFILE"
fi
exec "$real_gpg" "\$@"
EOF
# curl: copia do $FAKE_TAR/$FAKE_SIG; FAKE_NOSIG faz o .sig dar 404.
#   Sondagem (-w, a dos mirrors): responde "206 <tempo>" só para a URL que contém um trecho de $FAKE_PROBE
#   ("trecho:tempo trecho:tempo"); as demais falham como um mirror sem o arquivo.
#   $FAKE_BADHOST: download de URL com esse trecho entrega o arquivo adulterado; $FAKE_DOWNFAIL: o download falha.
cat > "$tmp/bin/curl" <<'EOF'
#!/bin/bash
while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; -w) w=$2; shift ;; -*) ;; *) u=$1 ;; esac; shift; done
if [ -n "${w:-}" ]; then
  echo "probe $u" >> "$FAKE_LOG"
  for p in ${FAKE_PROBE:-}; do case $u in *"${p%%:*}"*) printf '206 %s' "${p#*:}"; exit 0 ;; esac; done
  exit 22
fi
echo "curl $u" >> "$FAKE_LOG"
[ -z "${FAKE_DOWNFAIL:-}" ] || case $u in *"$FAKE_DOWNFAIL"*) exit 22 ;; esac
case $u in
  *.sig) [ -z "${FAKE_NOSIG:-}" ] || exit 22; cp "$FAKE_SIG" "$o" ;;
  *)     if [ -n "${FAKE_BADHOST:-}" ] && case $u in *"$FAKE_BADHOST"*) true ;; *) false ;; esac; then
           cp "$FAKE_TAMPERED" "$o"
         else cp "$FAKE_TAR" "$o"; fi ;;
esac
EOF
# proot-distro: "list" mostra $FAKE_LISTED; "install" registra os argumentos e o tamanho do arquivo local, se for um.
cat > "$tmp/bin/proot-distro" <<'EOF'
#!/bin/bash
case $1 in
  list) printf '%s\n' ${FAKE_LISTED:-} ;;
  install) echo "install $*" >> "$FAKE_LOG"
           for a in "$@"; do [ -f "$a" ] && echo "arquivo-existia $a" >> "$FAKE_LOG"; done
           exit "${FAKE_INSTALL_RC:-0}" ;;
esac
EOF
printf '#!/bin/sh\necho "pkg $*" >> "$FAKE_LOG"\n' > "$tmp/bin/pkg"
chmod +x "$tmp/bin/"*

# ── Funções do setup.sh ──
fn() {  # imprime a função $1 do setup.sh (uma linha, ou até o "}" na coluna 1)
  awk -v n="$1" 'index($0, n "()")==1 { print; if ($0 ~ /\}[[:space:]]*$/ && $0 !~ /\{[[:space:]]*$/) exit; p=1; next } p { print; if ($0 ~ /^\}/) exit }' "$repo/setup.sh"
}
{
  echo 'set -euo pipefail'
  echo 'DRY_RUN=${DRY_RUN:-0}; PM=pkg; SKIP_TERMUX_PROOT=${SKIP_TERMUX_PROOT:-0}; CLEANUP_DIRS=(); FAILED=()'
  # as variáveis de configuração do ALARM, como estão no script (menos o fingerprint, que o teste troca)
  grep -E '^(ALARM_ROOTFS_URL|ALARM_KEYSERVERS|ALARM_MIRRORS|SKIP_ALARM_MIRRORS|ALARM_TAR)=' "$repo/setup.sh"
  echo 'ALARM_KEY_FPR=$TEST_FPR'
  awk '/^case \$\{UNAME_M:-/,/^unset _proot_img/' "$repo/setup.sh"
  for f in log warn run pm_install verify_alarm_rootfs rank_mirrors fetch_alarm_rootfs termux_proot_distro; do fn "$f"; done
} > "$tmp/funcs.sh"
bash -n "$tmp/funcs.sh" || { echo "FALHOU: as funções extraídas não passam no bash -n"; exit 1; }
grep -q 'termux_proot_distro()' "$tmp/funcs.sh" && grep -q 'verify_alarm_rootfs()' "$tmp/funcs.sh" || { echo "FALHOU: extração incompleta"; exit 1; }

fail=0
# t [VAR=valor ...] -- : roda termux_proot_distro; $out = saída, $log = o que os binários de mentira registraram, $failed = FAILED
t() {
  local -a envs=(); while [[ ${1:-} != -- && $# -gt 0 ]]; do envs+=("$1"); shift; done; shift
  : > "$tmp/log"; rm -rf "$tmp/tmpdir"; mkdir "$tmp/tmpdir"
  out=$(env PATH="$tmp/bin:$PATH" TMPDIR="$tmp/tmpdir" PREFIX="$tmp/prefix" FAKE_LOG="$tmp/log" FAKE_TAR="$tmp/fx/$tarname" FAKE_TAMPERED="$tmp/fx/tampered.tar.gz" \
        FAKE_SIG="$tmp/fx/ok.sig" FAKE_KEYFILE="$tmp/fx/oficial.asc" TEST_FPR="$FPR_OK" UNAME_M=aarch64 "${envs[@]}" \
        bash -c 'source "$0"; termux_proot_distro; echo "FAILED=(${FAILED[*]:-})"' "$tmp/funcs.sh" 2>&1 </dev/null | sed 's/\x1b\[[0-9;]*m//g')
  log=$(cat "$tmp/log")
}
has()   { grep -qF -- "$1" <<<"$2" || { echo "FALHOU: faltou \"$1\""; echo "--- saída:"; echo "$out" | tail -8; echo "--- log:"; echo "$log" | tail -8; fail=1; }; }
hasnt() { ! grep -qF -- "$1" <<<"$2" || { echo "FALHOU: não devia ter \"$1\""; echo "$out" | tail -6; fail=1; }; }
installed() { grep -q '^install ' <<<"$log"; }
leftover()  { [[ -z $(ls -A "$tmp/tmpdir") ]]; }   # o download temporário foi apagado

# 1) Assinatura boa: baixa tar + .sig, confere, e instala o ARQUIVO LOCAL (caminho absoluto) com o nome certo.
t --; has 'Assinatura do rootfs confirmada' "$out"; has 'FAILED=()' "$out"
has "curl http://os.archlinuxarm.org/os/$tarname" "$log"; has "curl http://os.archlinuxarm.org/os/$tarname.sig" "$log"
has 'install install --name archlinuxarm /' "$log"; has 'arquivo-existia' "$log"
leftover || { echo "FALHOU: o download não foi apagado: $(ls "$tmp/tmpdir")"; fail=1; }

# 2) Arquivo adulterado depois de assinado: recusa, não instala, registra a falha e apaga o download.
t FAKE_TAR="$tmp/fx/tampered.tar.gz" --
has 'NÃO foi confirmada' "$out"; has 'FAILED=(proot-distro:Arch Linux ARM (rootfs oficial))' "$out"
installed && { echo "FALHOU: instalou um rootfs adulterado"; fail=1; }
leftover || { echo "FALHOU: o download rejeitado ficou no disco"; fail=1; }

# 3) Assinatura feita por outra chave (a chave fixada é a "oficial"; o keyserver devolve a dela, mas o .sig é do impostor).
t FAKE_SIG="$tmp/fx/bad.sig" --; has 'NÃO foi confirmada' "$out"; installed && { echo "FALHOU: aceitou assinatura de outra chave"; fail=1; }

# 4) O keyserver entrega a chave do impostor no lugar da fixada: a chave fixada não aparece no chaveiro, então recusa.
t FAKE_KEYFILE="$tmp/fx/impostor.asc" FAKE_SIG="$tmp/fx/bad.sig" --; has 'NÃO foi confirmada' "$out"
installed && { echo "FALHOU: aceitou a chave errada do keyserver"; fail=1; }

# 5) Chave fixada expirada (assinatura feita quando valia): recusa (EXPKEYSIG).
t TEST_FPR="$FPR_EXP" FAKE_KEYFILE="$tmp/fx/expirada.asc" FAKE_SIG="$tmp/fx/exp.sig" --
has 'NÃO foi confirmada' "$out"; installed && { echo "FALHOU: aceitou chave expirada"; fail=1; }

# 6) Sem o .sig no servidor: não instala sem verificar.
t FAKE_NOSIG=1 --; has 'falhou; nada foi instalado' "$out"; installed && { echo "FALHOU: instalou sem .sig"; fail=1; }
has 'FAILED=(proot-distro:' "$out"

# 7) Keyserver fora do ar: recusa.
t FAKE_NOKEYSERVER=1 --; has 'NÃO foi confirmada' "$out"; installed && { echo "FALHOU: instalou sem conseguir a chave"; fail=1; }

# 8) Já instalado (pasta do container existe): não baixa nada.
mkdir -p "$tmp/prefix/var/lib/proot-distro/containers/archlinuxarm"
t --; has 'já instalado' "$out"; hasnt 'curl' "$log"
rm -rf "$tmp/prefix"
t FAKE_LISTED=archlinuxarm --; has 'já instalado' "$out"; hasnt 'curl' "$log"

# 9) x86_64: imagem oficial archlinux:latest pelo proot-distro, sem baixar rootfs nem usar gpg.
t UNAME_M=x86_64 --; has 'install install --name archlinux archlinux:latest' "$log"; hasnt 'curl' "$log"; hasnt 'keyserver' "$log"

# 10) TERMUX_PROOT_IMAGE próprio em aarch64: instala a imagem, sem rootfs do ALARM.
t TERMUX_PROOT_IMAGE=meu/arch:1 --; has 'install install --name archlinuxarm meu/arch:1' "$log"; hasnt 'curl' "$log"

# 11) Arquitetura sem distro (armv7l): avisa e pula, sem instalar.
t UNAME_M=armv7l --; has 'sem distro para a arquitetura armv7l' "$out"; installed && { echo "FALHOU: instalou em armv7l"; fail=1; }

# 12) SKIP_TERMUX_PROOT=1.
t SKIP_TERMUX_PROOT=1 --; has 'pulada (SKIP_TERMUX_PROOT=1)' "$out"; [[ -z $log ]] || { echo "FALHOU: fez algo com SKIP_TERMUX_PROOT=1: $log"; fail=1; }

# 13) --dry-run: mostra os comandos, não baixa, não confere e não instala nada.
t DRY_RUN=1 --; has '[dry] curl -fL --retry 3' "$out"; has '[dry] proot-distro install --name archlinuxarm' "$out"
has 'conferiria a assinatura PGP' "$out"; has 'mediria os mirrors do Arch Linux ARM' "$out"; [[ -z $log ]] || { echo "FALHOU: o dry-run executou algo: $log"; fail=1; }

# 14) install falhando: avisa, registra e apaga o download.
t FAKE_INSTALL_RC=1 --; has 'falhou: proot-distro install' "$out"; has 'FAILED=(proot-distro:' "$out"; leftover || { echo "FALHOU: o download ficou no disco"; fail=1; }

# 15) Mirrors: o mais rápido que tem o rootfs é o primeiro (e o único) a ser baixado; o oficial não é usado.
first_curl() { grep '^curl ' <<<"$log" | head -1; }
t FAKE_PROBE="fl.us:0.30 de.mirror:0.10 dk:0.20" --
has 'mirrors com o rootfs: 3; o mais rápido: http://de.mirror.archlinuxarm.org' "$out"; has 'FAILED=()' "$out"
[[ $(first_curl) == "curl http://de.mirror.archlinuxarm.org/os/$tarname" ]] || { echo "FALHOU: o primeiro download não foi do mirror mais rápido: $(first_curl)"; fail=1; }
has "curl http://de.mirror.archlinuxarm.org/os/$tarname.sig" "$log"; hasnt 'curl http://os.archlinuxarm.org' "$log"
has 'Assinatura do rootfs confirmada (http://de.mirror.archlinuxarm.org)' "$out"; has 'install install --name archlinuxarm /' "$log"
leftover || { echo "FALHOU: o download não foi apagado"; fail=1; }

# 16) Sem nenhum mirror com o rootfs (todos falham na sondagem): os mirrors são sondados e vale o oficial.
t --; has 'nenhum mirror tem o rootfs' "$out"; has 'probe http://fl.us.mirror.archlinuxarm.org/os/' "$log"
has "curl http://os.archlinuxarm.org/os/$tarname" "$log"; hasnt 'curl http://fl.us' "$log"

# 17) O download do mirror mais rápido falha: cai no seguinte, sem tocar no oficial.
t FAKE_PROBE="de.mirror:0.10 fl.us:0.30" FAKE_DOWNFAIL=de.mirror --
has 'o download de http://de.mirror.archlinuxarm.org falhou; tento o próximo' "$out"
has "curl http://fl.us.mirror.archlinuxarm.org/os/$tarname" "$log"; hasnt 'curl http://os.archlinuxarm.org' "$log"
has 'Assinatura do rootfs confirmada (http://fl.us.mirror.archlinuxarm.org)' "$out"; has 'FAILED=()' "$out"; installed || { echo "FALHOU: não instalou"; fail=1; }

# 18) O mirror entrega arquivo adulterado: a assinatura não confere, ele é descartado e o próximo (aqui o oficial) é usado.
t FAKE_PROBE="de.mirror:0.10" FAKE_BADHOST=de.mirror --
has 'rootfs de http://de.mirror.archlinuxarm.org NÃO foi confirmada; tento o próximo' "$out"
has 'Assinatura do rootfs confirmada (http://os.archlinuxarm.org)' "$out"; has 'FAILED=()' "$out"
installed || { echo "FALHOU: não instalou do oficial depois do mirror ruim"; fail=1; }
leftover || { echo "FALHOU: o download do mirror ruim ficou no disco"; fail=1; }

# 19) Arquivo adulterado em TODAS as origens, inclusive no oficial: nada é instalado.
t FAKE_PROBE="de.mirror:0.10" FAKE_BADHOST=archlinuxarm.org --
has 'a assinatura do rootfs NÃO foi confirmada (sem a chave' "$out"; has 'FAILED=(proot-distro:' "$out"
installed && { echo "FALHOU: instalou um rootfs adulterado vindo de todas as origens"; fail=1; }
leftover || { echo "FALHOU: os downloads rejeitados ficaram no disco"; fail=1; }

# 20) SKIP_ALARM_MIRRORS=1: nenhuma sondagem, só o oficial.
t SKIP_ALARM_MIRRORS=1 FAKE_PROBE="de.mirror:0.10" --
hasnt 'probe' "$log"; hasnt 'de.mirror' "$log"; has "curl http://os.archlinuxarm.org/os/$tarname" "$log"; installed || { echo "FALHOU: não instalou"; fail=1; }

# 21) Sem referência ao danhunsaker no código (só em comentários explicando a remoção).
if grep -nE 'danhunsaker' "$repo/setup.sh" | grep -vE '^[0-9]+:[[:space:]]*#'; then echo "FALHOU: o setup.sh ainda usa o danhunsaker fora de comentários"; fail=1; fi

((fail)) && { echo "FALHARAM testes"; exit 1; }
echo "ok: tests/alarm-rootfs.test.sh"
