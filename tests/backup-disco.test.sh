#!/usr/bin/env bash
# Teste do backup-disco.sh: lsblk, findmnt, ddrescue, zstd, dd, snapper... de mentira que só registram as chamadas num log.
# Nenhum disco é lido ou escrito de verdade. Uso: bash tests/backup-disco.test.sh
set -u
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
chmod 755 "$tmp"; mkdir "$tmp/fake" "$tmp/mnt"
export FAKE_LOG="$tmp/calls.log"
dir="$tmp/mnt/BACKUP DISCOS RÍGIDOS"

# ── Comandos de mentira ──
cat > "$tmp/fake/lsblk" <<'EOF'
#!/bin/bash
[[ $1 == -*r* && $1 == -*P* ]] && { echo "lsblk: mutually exclusive arguments: --json --pairs --raw" >&2; exit 1; }   # o de verdade recusa -r com -P
case "$*" in
  *"-dnbP"*)   # discos: sda (origem, 4 MiB de mentira), sdc (HD de destino), loop0 (não é disco)
    echo "NAME=\"sda\" SIZE=\"${FAKE_SDA_SIZE:-4194304}\" MODEL=\"Samsung\x20SSD\x20860\" SERIAL=\"S1\" TYPE=\"disk\""
    echo 'NAME="sdc" SIZE="8388608" MODEL="WD\x20Elements" SERIAL="" TYPE="disk"'
    echo 'NAME="loop0" SIZE="1000" MODEL="" SERIAL="" TYPE="loop"'
    echo 'NAME="zram0" SIZE="0" MODEL="" SERIAL="" TYPE="disk"' ;;
  *"-nbP"*)   # partições
    echo 'NAME="sda1" SIZE="3000000" FSTYPE="ext4" LABEL="" MOUNTPOINT="/" TYPE="part" PKNAME="sda"'
    echo 'NAME="sda2" SIZE="1000000" FSTYPE="swap" LABEL="" MOUNTPOINT="[SWAP]" TYPE="part" PKNAME="sda"'
    echo 'NAME="sdc1" SIZE="8000000" FSTYPE="exfat" LABEL="Ventoy\x20dados" MOUNTPOINT="" TYPE="part" PKNAME="sdc"'
    echo 'NAME="sdc2" SIZE="300000" FSTYPE="vfat" LABEL="EFI" MOUNTPOINT="" TYPE="part" PKNAME="sdc"' ;;
  *"-nrpo NAME /dev/sda") printf '/dev/sda\n/dev/sda1\n/dev/sda2\n' ;;
  *"-nrpo NAME /dev/sdc") printf '/dev/sdc\n/dev/sdc1\n/dev/sdc2\n' ;;
  *) echo "lsblk: chamada inesperada: $*" >&2; exit 1 ;;
esac
EOF
cat > "$tmp/fake/findmnt" <<'EOF'
#!/bin/bash
case "$*" in
  *"-no FSTYPE /") echo "${FAKE_ROOTFS:-btrfs}" ;;
  *"-S /dev/sda1") [[ -n ${FAKE_SDA_MOUNTED:-} ]] && { echo /; exit 0; }; exit 1 ;;
  *"-S /dev/sdc1") [[ -n ${FAKE_SDC_MOUNTED:-} ]] && { echo /run/media/sdc1; exit 0; }; exit 1 ;;
  *) exit 1 ;;
esac
EOF
cat > "$tmp/fake/swapon" <<'EOF'
#!/bin/bash
[[ -n ${FAKE_SWAP:-} ]] && echo /dev/sda2; exit 0
EOF
for c in mount umount sync fstrim paccache journalctl snapper btrfs eclean-dist; do   # só registram
  printf '#!/bin/bash\necho "%s $*" >> "$FAKE_LOG"\n' "$c" > "$tmp/fake/$c"
done
# snapper list-configs/list só imprimem; delete é registrado (acima), então fica a versão com saída
cat > "$tmp/fake/snapper" <<'EOF'
#!/bin/bash
echo "snapper $*" >> "$FAKE_LOG"; echo "(saída do snapper $*)"
EOF
cat > "$tmp/fake/ddrescue" <<'EOF'
#!/bin/bash
echo "ddrescue $*" >> "$FAKE_LOG"
[[ -n ${FAKE_DDRESCUE_FAIL:-} ]] && exit 1
img=${@: -2:1}; mapf=${@: -1}
echo dados > "$img"
{ echo "# Mapfile. Created by GNU ddrescue version 1.27"; echo "# Finished"
  echo "0x400000     +     1"
  if [[ -n ${FAKE_BAD:-} ]]; then echo "0x00000000  0x100000  +"; echo "0x00100000  0x1000  -"; echo "0x00101000  0x2FF000  +"
  else echo "0x00000000  0x400000  +"; fi; } > "$mapf"
EOF
cat > "$tmp/fake/zstd" <<'EOF'
#!/bin/bash
echo "zstd $*" >> "$FAKE_LOG"
case " $* " in
  *" -lv "*) echo "Decompressed Size : 4.00 MiB (${FAKE_ZST_SIZE:-4194304} B)" ;;
  *" -t "*) ;;
  *" -d "*) echo imagem ;;
  *) in=; out=; rm=; a=("$@"); for ((i=0;i<${#a[@]};i++)); do case ${a[i]} in --rm) rm=1 ;; -o) out=${a[i+1]} ;; -*) ;; *) [[ ${a[i-1]:-} == -o ]] || in=${a[i]} ;; esac; done
     [[ -e $out ]] && { echo "zstd: $out already exists; not overwritten" >&2; exit 1; }   # o de verdade só sobrescreve com -f
     echo comprimido > "$out"; [[ -z $rm ]] || rm -f "$in" ;;
esac
EOF
cat > "$tmp/fake/dd" <<'EOF'
#!/bin/bash
echo "dd $*" >> "$FAKE_LOG"; case " $* " in *" if="*) ;; *) cat >/dev/null ;; esac
EOF
chmod +x "$tmp/fake/"*

# PATH enxuto para testar cada receita de cache do `limpar`: só o básico + as ferramentas de mentira de uma distro
mkdir "$tmp/tools"; for c in bash env cat grep awk sed tr tail head df stat ls mkdir rm numfmt cut; do p=$(command -v "$c") && ln -s "$p" "$tmp/tools/$c"; done
mkpath() {  # nome comando... — cria uma pasta só com esses comandos de mentira e devolve o PATH (ela + o básico)
  local d="$tmp/p-$1" c; shift; mkdir -p "$d"
  for c; do printf '#!/bin/bash\necho "%s $*" >> "$FAKE_LOG"\n' "$c" > "$d/$c"; chmod +x "$d/$c"; done
  echo "$d:$tmp/tools"
}

fail=0 out="" rc=0
bd() {  # "entrada" [VAR=valor ...] -- argumentos — roda o script com a entrada digitada; saída em $out, status em $rc; chamadas em $tmp/calls.log
  local in=$1; shift; local -a envs=()
  while [[ ${1:-} != -- ]]; do envs+=("$1"); shift; done; shift
  : > "$FAKE_LOG"
  out=$(printf '%b' "$in" | env PATH="${BD_PATH:-$tmp/fake:$PATH}" BACKUP_MNT="$tmp/mnt" "${envs[@]}" bash "$here/../backup-disco.sh" "$@" 2>&1); rc=$?
}
has()    { grep -qF -- "$1" <<<"$out" || { echo "FALHOU: faltou \"$1\" na saída"; fail=1; }; }
hasnt()  { ! grep -qF -- "$1" <<<"$out" || { echo "FALHOU: não devia ter \"$1\" na saída"; fail=1; }; }
called() { grep -qF -- "$1" "$FAKE_LOG" || { echo "FALHOU: não chamou \"$1\" (chamadas: $(tr '\n' '~' < "$FAKE_LOG"))"; fail=1; }; }
never()  { ! grep -qF -- "$1" "$FAKE_LOG" || { echo "FALHOU: não devia ter chamado \"$1\""; fail=1; }; }
rcis()   { [[ $rc == "$1" ]] || { echo "FALHOU: status $rc, esperava $1. Saída: $out"; fail=1; }; }
before() { local a b; a=$(grep -nF -- "$1" "$FAKE_LOG" | head -1 | cut -d: -f1); b=$(grep -nF -- "$2" "$FAKE_LOG" | tail -1 | cut -d: -f1)
           [[ -n $a && -n $b && $a -lt $b ]] || { echo "FALHOU: \"$1\" devia vir antes de \"$2\" (chamadas: $(tr '\n' '~' < "$FAKE_LOG"))"; fail=1; }; }
fresh() { rm -rf "$tmp/mnt"; mkdir -p "$dir"; }

# ─── Linha de comando ───
bd '' -- --help;            rcis 0; has 'Uso: bash backup-disco.sh'
bd '' --;                   rcis 1; has 'Uso:'
bd '' -- backup --foo;      rcis 1; has 'argumento desconhecido: --foo'
bd '' -- backup --nivel=25; rcis 1; has '--nivel vai de 1 a 19'

# ─── backup: caminho feliz (disco 1 = sda, partição 1 = sdc1; nome padrão; confirma) ───
fresh; bd '1\n1\n\ns\n' -- backup; rcis 0
has 'Samsung SSD 860'; has 'serial S1'; has 'WD Elements'; hasnt 'loop0'; hasnt 'zram0'                       # discos listados com modelo e serial; loop não é disco
has 'sdc1'; hasnt 'sda1'; has 'Ventoy dados'                                                    # partições do próprio disco de origem não são oferecidas
called "mount /dev/sdc1 $tmp/mnt"
called "ddrescue -v /dev/sda $dir/backup_ssd.img $dir/backup_ssd.log"
called "zstd -T0 -19 --rm $dir/backup_ssd.img -o $dir/backup_ssd.img.zst"
called "zstd -t $dir/backup_ssd.img.zst"; called "umount $tmp/mnt"
before 'ddrescue' 'zstd -T0'; before 'zstd -T0' 'zstd -t'; before 'zstd -t' 'umount'          # a ordem do guia: backup, comprimir, testar, desmontar
[[ -f $dir/backup_ssd.img.zst && ! -e $dir/backup_ssd.img ]] || { echo "FALHOU: devia sobrar só o .zst"; fail=1; }
# nível e sem compressão
fresh; bd '1\n1\nmeu\ns\n' -- backup --nivel=12;  rcis 0; called "zstd -T0 -12 --rm $dir/meu.img -o $dir/meu.img.zst"
fresh; bd '1\n1\nmeu\ns\n' -- backup --sem-compressao; rcis 0; never zstd; [[ -f $dir/meu.img ]] || { echo "FALHOU: --sem-compressao devia deixar o .img"; fail=1; }
# cancelar na confirmação não lê o disco
fresh; bd '1\n1\n\n\n' -- backup; rcis 1; has 'cancelado'; never ddrescue

# ─── backup: travas de segurança ───
fresh; bd '1\n' FAKE_SDA_MOUNTED=1 -- backup; rcis 1; has 'montada ou swap'; never ddrescue; never mount   # origem com partição montada (o sistema rodando)
fresh; bd '1\n' FAKE_SWAP=1 -- backup;        rcis 1; has 'montada ou swap'; never ddrescue                  # só o swap em uso já basta
fresh; bd '1\n2\n' -- backup;                 rcis 1; has 'FAT32'; never ddrescue                            # FAT32 não guarda arquivo grande
fresh; bd 'q\n' -- backup;                    rcis 1; has 'cancelado'
fresh; bd '9\n1\n1\n\n\n' -- backup;          has 'Digite um número de 1 a'                                  # número fora da lista pergunta de novo
fresh; bd '1\n1\n../x\n' -- backup;           rcis 1; has 'nome inválido'; never ddrescue
fresh; bd '1\n1\n\ns\n' FAKE_SDA_SIZE=99999999999999 -- backup; rcis 1; has 'faltam'; never ddrescue     # destino sem espaço
fresh; bd '1\n1\n\ns\n' FAKE_DDRESCUE_FAIL=1 -- backup; rcis 1; has 'continua de onde parou'; never 'zstd -T0'; called "umount $tmp/mnt"   # falhou: o HD não pode ficar montado
fresh; bd '1\n1\n\ns\n' FAKE_BAD=1 -- backup;  rcis 1; has 'setores problemáticos'; never 'zstd -T0'; called "umount $tmp/mnt"; [[ -f $dir/backup_ssd.img ]] || { echo "FALHOU: o .img devia ficar"; fail=1; }
# nomes que já existem
fresh; : > "$dir/backup_ssd.img.zst"; bd '1\n1\n\n' -- backup; rcis 1; has 'já existe'; never ddrescue
fresh; : > "$dir/backup_ssd.img"; printf '# Finished\n0x1 + 1\n0x0 0x1 +\n' > "$dir/backup_ssd.log"
bd '1\n1\n\nn\n' -- backup; rcis 1; has 'já existem'; never ddrescue; never zstd; hasnt 'INTERROMPIDO'     # log acabado: nunca retoma o ddrescue; recusar o "só comprimir" cancela
# bruto COMPLETO (log acabado e limpo): oferece só comprimir, sem ler o disco de novo
fresh; echo dados > "$dir/backup_ssd.img"; printf '# Finished\n0x1 + 1\n0x0 0x1 +\n' > "$dir/backup_ssd.log"
bd '1\n1\n\ns\ns\n' -- backup; rcis 0; has 'SEM ler o disco'; has 'não será lida'; has 'NÃO foi lido agora'; never ddrescue
called "zstd -T0 -19 --rm $dir/backup_ssd.img -o $dir/backup_ssd.img.zst"; called 'zstd -t'; called "umount $tmp/mnt"
[[ -f $dir/backup_ssd.img.zst && ! -e $dir/backup_ssd.img ]] || { echo "FALHOU: só comprimir devia deixar o .zst e tirar o .img"; fail=1; }
# .zst parcial de uma compressão interrompida: é apagado (o zstd não sobrescreve), o .img completo é a fonte
fresh; echo dados > "$dir/backup_ssd.img"; echo parcial > "$dir/backup_ssd.img.zst"; printf '# Finished\n0x1 + 1\n0x0 0x1 +\n' > "$dir/backup_ssd.log"
bd '1\n1\n\ns\ns\n' -- backup; rcis 0; never ddrescue; [[ $(cat "$dir/backup_ssd.img.zst") == comprimido && ! -e $dir/backup_ssd.img ]] || { echo "FALHOU: o .zst parcial devia ser trocado pelo novo"; fail=1; }
bd '1\n1\n\nn\n' -- backup; rcis 1; never zstd                                                           # (sem o .img de novo: agora cai em "já existe o .zst")
# com setores ruins no log, ou com --sem-compressao, ou com o .zst e um backup interrompido: nada de "só comprimir"
fresh; echo dados > "$dir/backup_ssd.img"; printf '# Finished\n0x1 + 1\n0x0 0x1 -\n' > "$dir/backup_ssd.log"
bd '1\n1\n\ns\ns\n' -- backup; rcis 1; has 'já existem'; hasnt 'SEM ler'; never zstd; never ddrescue
fresh; echo dados > "$dir/backup_ssd.img"; printf '# Finished\n0x1 + 1\n0x0 0x1 +\n' > "$dir/backup_ssd.log"
bd '1\n1\n\ns\ns\n' -- backup --sem-compressao; rcis 1; has 'já existem'; hasnt 'SEM ler'; never zstd
fresh; echo dados > "$dir/backup_ssd.img"; echo parcial > "$dir/backup_ssd.img.zst"; printf '# Mapfile\n0x1 ? 1\n0x0 0x1 ?\n' > "$dir/backup_ssd.log"
bd '1\n1\n\ns\ns\n' -- backup; rcis 1; has 'já existe'; never ddrescue                               # retomar com um .zst no caminho: o zstd ia falhar no fim, então recusa antes
fresh; : > "$dir/backup_ssd.img"; printf '# Mapfile\n0x1 ? 1\n0x0 0x1 ?\n' > "$dir/backup_ssd.log"
bd '1\n1\n\nn\n' -- backup; rcis 1; has 'já existem'; never ddrescue                                         # interrompido: não retomar = recusa
bd '1\n1\n\ns\ns\n' -- backup; rcis 0; called 'ddrescue -v /dev/sda'                                         # retomar: roda o mesmo comando

# ─── backup --dry-run: lista os discos, não monta, não lê nada ───
fresh; bd '1\n1\n\ns\n' -- backup --dry-run; rcis 0
has '[sim]'; has 'ddrescue -v /dev/sda'; has 'zstd -T0 -19 --rm'
never mount; never ddrescue; never 'zstd -T0'; never umount; never mkdir

# ─── restaurar (aqui a partição 1 é a sda1, montada em /; a 2 é a sdc1; arquivo; disco 1 = sda; digita o caminho) ───
fresh; : > "$dir/a.img.zst"; : > "$dir/b.img"
bd '2\n1\n1\n/dev/sda\n' -- restaurar; rcis 0
has 'a.img.zst'; has 'b.img'; has 'SOBRESCREVE'
called "mount /dev/sdc1 $tmp/mnt"; called 'dd of=/dev/sda bs=4M status=progress conv=fsync'; called "zstd -d $dir/a.img.zst -c"; called umount
before 'dd of=/dev/sda' 'umount'   # zstd -d e dd rodam em paralelo (pipe): a ordem entre os dois no log não é fixa
bd '2\n2\n1\n/dev/sda\n' -- restaurar; rcis 0; called "dd if=$dir/b.img of=/dev/sda bs=4M status=progress conv=fsync"; never 'zstd -d'   # .img sem compressão
bd '2\n1\n1\n/dev/sdb\n' -- restaurar; rcis 1; has 'não confere'; never 'dd of='                      # caminho errado: nada é escrito
bd '2\n1\n1\n\n' -- restaurar;         rcis 1; has 'não confere'; never 'dd of='
bd '2\n1\n1\n/dev/sda\n' FAKE_SDA_MOUNTED=1 -- restaurar; rcis 1; has 'montada ou swap'; never 'dd of='       # disco de destino em uso
bd '2\n1\n1\n/dev/sda\n' FAKE_ZST_SIZE=99999999 -- restaurar; rcis 1; has 'menor que o backup'; never 'dd of='  # disco menor que a imagem
bd '2\n1\n1\n/dev/sda\n' FAKE_ZST_SIZE=4194304 -- restaurar; rcis 0                                  # mesmo tamanho: passa
fresh; bd '2\n' -- restaurar; rcis 1; has 'nenhum .img.zst nem .img'
rm -rf "$dir"; bd '2\n' -- restaurar; rcis 1; has 'não existe a pasta'; never 'dd of='   # sem a pasta (e fora da simulação) não inventa um arquivo
fresh; : > "$dir/a.img.zst"; bd '2\n1\n1\n/dev/sda\n' -- restaurar --dry-run; rcis 0; never mount; never 'dd of='; has 'zstd -d'; has '| dd of=/dev/sda'

# ─── limpar ───
bd '\n12 116-138\n' -- limpar; rcis 0
called 'paccache -rk1'; called 'paccache -ruk0'; called 'journalctl --vacuum-size=200M'
called 'snapper -c root delete 12 116-138'; called 'btrfs subvolume sync /'; called 'fstrim -av'
before 'paccache -ruk0' 'journalctl'; before 'snapper -c root delete' 'btrfs subvolume sync'; before 'btrfs subvolume sync' 'fstrim -av'   # fstrim SEMPRE por último
[[ $(tail -n1 "$FAKE_LOG") == 'fstrim -av' && $(grep -c '^fstrim' "$FAKE_LOG") == 1 ]] || { echo "FALHOU: o fstrim devia rodar uma vez e ser a última chamada (chamadas: $(tr '\n' '~' < "$FAKE_LOG"))"; fail=1; }
bd 'home\n7\n' -- limpar;       rcis 0; called 'snapper -c home delete 7'
bd '\n0\n' -- limpar;           rcis 0; never ' delete '; has 'nada apagado'                       # o 0 é o sistema atual
bd '\n12;reboot\n' -- limpar;   rcis 0; never ' delete '; never 'sync /'; called 'fstrim -av'      # injeção: nada vai ao snapper
bd '../x\n' -- limpar;          rcis 1; has 'nome de config inválido'
bd '\n\n' -- limpar;            rcis 0; never ' delete '                                           # vazio = nenhum
bd '\n\n' FAKE_ROOTFS=ext4 -- limpar; rcis 0; has 'raiz não é btrfs'; never 'snapper'
bd '' -- limpar --sem-cache --sem-journal --sem-snapshots --sem-fstrim; rcis 0; never paccache; never journalctl; never snapper; never fstrim
bd '' -- limpar --sem-cache --sem-journal --sem-snapshots; rcis 0; called 'fstrim -av'
bd '\n12\n' -- limpar --dry-run; rcis 0; has '[sim]'; never paccache; never journalctl; never ' delete '; never fstrim; never 'sync /'

# ─── limpar: a receita de cache de cada distro (sem paccache no PATH, os outros ramos finalmente rodam) ───
only_cache="--sem-journal --sem-snapshots --sem-fstrim"
# shellcheck disable=SC2086
{
BD_PATH=$(mkpath pac pacman) bd '' -- limpar $only_cache; rcis 0; has 'falta o paccache'; never pacman
BD_PATH=$(mkpath gentoo eclean-dist) bd '' -- limpar $only_cache; rcis 0; called 'eclean-dist -d'
BD_PATH=$(mkpath deb apt-get) bd '' -- limpar $only_cache; rcis 0; called 'apt-get clean'; called 'apt-get autoremove'; before 'apt-get clean' 'apt-get autoremove'
BD_PATH=$(mkpath fed dnf) bd '' -- limpar $only_cache; rcis 0; called 'dnf clean all'; called 'dnf autoremove'; before 'dnf clean all' 'dnf autoremove'
BD_PATH=$(mkpath nada) bd '' -- limpar $only_cache; rcis 0; has 'sem receita de cache'; [[ ! -s $FAKE_LOG ]] || { echo "FALHOU: sem receita não devia chamar nada"; fail=1; }
BD_PATH=$(mkpath nada) bd '' -- limpar --sem-cache --sem-snapshots --sem-fstrim; rcis 0; has 'sem systemd-journald'
}

# ─── sem root: reexecuta com sudo e leva as MESMAS opções (o parse consome os argumentos; a cópia vem antes) ───
if command -v setpriv >/dev/null; then
  cp "$here/../backup-disco.sh" "$tmp/bd.sh"; chmod 755 "$tmp/bd.sh"
  printf '#!/bin/bash\necho "SUDO $*"\n' > "$tmp/fake/sudo"; chmod +x "$tmp/fake/sudo"
  out=$(setpriv --reuid=65534 --regid=65534 --clear-groups env PATH="$tmp/fake:$PATH" bash "$tmp/bd.sh" limpar --sem-cache --nivel=12 2>&1)
  grep -qF 'SUDO bash '"$tmp"'/bd.sh limpar --sem-cache --nivel=12' <<<"$out" || { echo "FALHOU: o sudo devia receber a ação e as opções ($out)"; fail=1; }
else echo "pulado: sem setpriv para testar a reexecução com sudo"; fi

((fail)) && exit 1
echo "backup-disco.test.sh: ok"
