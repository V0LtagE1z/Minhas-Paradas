#!/usr/bin/env bash
# backup-disco.sh — backup bit a bit de um disco inteiro (ddrescue + zstd) e restauração, passo a passo do
# "GUIA BACKUP E RESTAURAÇÃO SSD" (SystemRescue). Interativo: escolhe os discos por número, mostrando MODELO e SERIAL.
# Uso: bash backup-disco.sh limpar|backup|restaurar [opções]   (--help lista as opções)
#   limpar     no sistema normal, ANTES do backup: cache de pacotes, journal, snapshots do snapper e, por último, fstrim
#   backup     no live boot (SystemRescue, "copytoram"): disco inteiro -> .img (ddrescue) -> .img.zst (zstd) -> teste -> umount
#   restaurar  no live boot: .img.zst (ou .img) -> disco inteiro, SOBRESCREVENDO-O
# Segurança: o disco de origem (backup) e o de destino (restaurar) não podem ter nada montado nem swap em uso;
# a restauração só roda depois de você digitar o caminho do disco. --dry-run só mostra os comandos que mudam algo.
# shortcut: não pausa/retoma o fstrim nem o zstd (ddrescue retoma sozinho: rode o mesmo backup de novo); o tamanho do
#   destino da restauração só é conferido se o zstd informar o tamanho descomprimido (zstd -lv). Upgrade: ler o frame.
# shortcut: o AUR (paru -Sc) e o balance do btrfs do guia ficam de fora (o paru roda como usuário e o balance é opcional).
# shortcut: o destino (e a origem do restaurar) é uma PARTIÇÃO com sistema de arquivos (lsblk TYPE=part); disco inteiro formatado
#   sem tabela de partições, LVM e LUKS não aparecem na lista. Upgrade: aceitar TYPE=lvm/crypt e disco sem partições.

set -u -o pipefail
ARGS=("$@")   # para o root_or_exec reexecutar com as mesmas opções (o parse abaixo consome os argumentos)

DRY_RUN=0 ACTION="" NIVEL=19 NOZ=0 NOCACHE=0 NOJOURNAL=0 NOSNAP=0 NOTRIM=0
MNT=${BACKUP_MNT:-/mnt/destino}                       # onde o disco de destino é montado (BACKUP_MNT existe só para o teste)
DIRNAME=${BACKUP_DIR_NAME:-BACKUP DISCOS RÍGIDOS}     # pasta, dentro do destino, onde ficam os backups
MOUNTED=0

log()  { if ((DRY_RUN)); then printf '\033[1;36m[sim]\033[0m %s\n' "$*"; else printf '\033[1;32m[ok]\033[0m %s\n' "$*"; fi; }
warn() { printf '\033[1;33m[!!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

shq() { local a o=""; for a; do [[ $a =~ ^[A-Za-z0-9_./=:@%+,-]+$ ]] && o+="$a " || o+="\"$a\" "; done; printf '%s' "${o% }"; }
run() {  # comando que muda algo: em --dry-run só imprime
  if ((DRY_RUN)); then printf '\033[1;36m[sim]\033[0m $ %s\n' "$(shq "$@")"; else "$@"; fi
}

usage() {
  cat <<'EOF'
Uso: bash backup-disco.sh <limpar|backup|restaurar> [opções]
  --dry-run          mostra o que seria feito, sem alterar nada (os discos ainda são listados)
  limpar:            --sem-cache  --sem-journal  --sem-snapshots  --sem-fstrim
  backup:            --nivel=N (1 a 19; padrão 19, 12 se o PC for fraco)  --sem-compressao (deixa o .img)
Variáveis: BACKUP_DIR_NAME (pasta no destino; padrão "BACKUP DISCOS RÍGIDOS"), BACKUP_MNT (padrão /mnt/destino)
EOF
}

while (($#)); do
  case $1 in
    limpar|backup|restaurar) ACTION=$1 ;;
    --dry-run) DRY_RUN=1 ;;
    --sem-cache) NOCACHE=1 ;; --sem-journal) NOJOURNAL=1 ;; --sem-snapshots) NOSNAP=1 ;; --sem-fstrim) NOTRIM=1 ;;
    --sem-compressao) NOZ=1 ;;
    --nivel=*) NIVEL=${1#*=}; [[ $NIVEL =~ ^([1-9]|1[0-9])$ ]] || die "--nivel vai de 1 a 19 (recebi '$NIVEL')" ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "argumento desconhecido: $1" ;;
  esac
  shift
done
[[ -n $ACTION ]] || { usage >&2; exit 1; }

# ─── Utilidades ───────────────────────────────────────────────────────────────
need() {  # comandos... — sem eles não dá para seguir (em --dry-run só avisa)
  local c miss=""
  for c; do command -v "$c" >/dev/null 2>&1 || miss+=" $c"; done
  [[ -z $miss ]] && return 0
  ((DRY_RUN)) && { warn "faltam:$miss (o SystemRescue já traz; a simulação segue)"; return 0; }
  die "faltam os comandos:$miss"
}

root_or_exec() {  # tudo aqui precisa de root: reexecuta com sudo/doas, mantendo o terminal
  [[ $EUID == 0 ]] && return 0
  local su; su=$(command -v sudo || command -v doas) || die "rode como root (sem sudo nem doas aqui)"
  exec "$su" env "BACKUP_MNT=$MNT" "BACKUP_DIR_NAME=$DIRNAME" bash "$0" "${ARGS[@]}"   # o sudo limpa o ambiente: leva as duas variáveis do script
}

ask() { local r; printf '%s [s/N] ' "$1"; read -r r || return 1; [[ $r == [sSyY]* ]]; }

hum() { numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1 B"; }

lsfield() {  # linha-de-lsblk-P CAMPO — o valor do campo (\x20 do lsblk vira espaço; outros escapes ficam visíveis, sem controlar o terminal)
  [[ $1 =~ (^|[[:space:]])$2=\"([^\"]*)\" ]] && printf '%s' "${BASH_REMATCH[2]//\\x20/ }"
}

choose() {  # "pergunta" máximo — número de 1 a máximo em CH; q cancela
  local r
  while :; do
    printf '%s' "$1"; read -r r || die "sem resposta (entrada fechada)"
    [[ $r == q ]] && die "cancelado"
    [[ $r =~ ^[0-9]{1,4}$ ]] && ((10#$r >= 1 && 10#$r <= $2)) && { CH=$((10#$r)); return 0; }   # 10#: "010" é dez, não oito (octal)
    echo "Digite um número de 1 a $2 (q cancela)."
  done
}

in_use() {  # disco — 0 se ele, uma partição ou um volume dentro dele está montado ou é swap (qualquer dúvida conta como "em uso")
  local p all
  all=$(lsblk -nrpo NAME "$1") || return 0
  for p in $all; do
    findmnt -rn -S "$p" >/dev/null 2>&1 && return 0
    swapon --noheadings --show=NAME 2>/dev/null | grep -qxF "$p" && return 0
  done
  return 1
}

pick_disk() {  # "o que é este disco" — escolhe um disco inteiro: DEV, DSIZE, DDESC
  local line i=0 out; local -a L=()
  out=$(lsblk -dnbP -o NAME,SIZE,MODEL,SERIAL,TYPE) || die "lsblk falhou"
  while IFS= read -r line; do   # só discos com mídia (leitor de cartão vazio e zram têm 0 byte ou não são disco de verdade)
    [[ $(lsfield "$line" TYPE) == disk && $(lsfield "$line" SIZE) -gt 0 && $(lsfield "$line" NAME) != zram* ]] && L+=("$line")
  done <<<"$out"
  ((${#L[@]})) || die "nenhum disco encontrado"
  echo; echo "Discos (confira por MODELO e SERIAL, a letra muda entre boots):"
  for line in "${L[@]}"; do
    ((++i)); printf '  %d) /dev/%-10s %9s  %s  serial %s\n' "$i" "$(lsfield "$line" NAME)" "$(hum "$(lsfield "$line" SIZE)")" \
      "$(lsfield "$line" MODEL)" "$(lsfield "$line" SERIAL)"
  done
  choose "$1 [1-$i, q cancela]: " "$i"
  line=${L[CH - 1]}; DEV=/dev/$(lsfield "$line" NAME); DSIZE=$(lsfield "$line" SIZE)
  DDESC="$DEV, $(hum "$DSIZE"), $(lsfield "$line" MODEL), serial $(lsfield "$line" SERIAL)"
}

mount_part() {  # "o que é esta partição" [disco a evitar] — escolhe uma partição com sistema de arquivos e a monta (se preciso) em $MNT: DIR
  local line i=0 dev fs mp out; local -a L=()
  out=$(lsblk -nbP -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE,PKNAME) || die "lsblk falhou"
  while IFS= read -r line; do
    [[ $(lsfield "$line" TYPE) == part && -n $(lsfield "$line" FSTYPE) && $(lsfield "$line" FSTYPE) != swap ]] || continue
    [[ -n ${2:-} && /dev/$(lsfield "$line" PKNAME) == "$2" ]] && continue   # nunca o próprio disco de origem
    L+=("$line")
  done <<<"$out"
  ((${#L[@]})) || die "nenhuma partição utilizável (com sistema de arquivos) fora do disco de origem"
  echo; echo "Partições:"
  for line in "${L[@]}"; do
    ((++i)); mp=$(lsfield "$line" MOUNTPOINT)
    printf '  %d) /dev/%-12s %9s  %-7s %s%s\n' "$i" "$(lsfield "$line" NAME)" "$(hum "$(lsfield "$line" SIZE)")" \
      "$(lsfield "$line" FSTYPE)" "$(lsfield "$line" LABEL)" "${mp:+  (montada em $mp)}"
  done
  choose "$1 [1-$i, q cancela]: " "$i"
  line=${L[CH - 1]}; dev=/dev/$(lsfield "$line" NAME); fs=$(lsfield "$line" FSTYPE); mp=$(lsfield "$line" MOUNTPOINT)
  [[ $fs == vfat ]] && die "$dev é FAT32: não guarda um arquivo de mais de 4 GiB. Use exFAT, NTFS ou ext4."
  if [[ -n $mp ]]; then MNT=$mp
  else
    run mkdir -p "$MNT" && run mount "$dev" "$MNT" || die "não consegui montar $dev em $MNT"
    ((DRY_RUN)) || MOUNTED=1
  fi
  DIR=$MNT/$DIRNAME
}

finish_mount() {  # desmonta o que o script montou (sync antes); roda também ao morrer, então é seguro repetir
  ((MOUNTED)) || return 0
  cd / && sync && umount "$MNT" && { MOUNTED=0; log "desmontado $MNT (pode remover o disco)"; } || warn "não consegui desmontar $MNT: rode 'sync; umount $MNT' antes de remover o disco"
}
trap finish_mount EXIT

# ─── limpar ───────────────────────────────────────────────────────────────────
cmd_limpar() {
  ((DRY_RUN)) || root_or_exec
  echo "Isto roda no sistema normal, ANTES do live boot. Depois do fstrim: não use mais o sistema, desligue e reinicie pela pendrive."
  if ((! NOCACHE)); then
    echo; echo "── 1. Cache de pacotes ──"
    if   command -v paccache    >/dev/null; then run paccache -rk1; run paccache -ruk0
    elif command -v pacman      >/dev/null; then warn "falta o paccache (pacote pacman-contrib); cache do pacman ignorado"
    elif command -v eclean-dist >/dev/null; then run eclean-dist -d
    elif command -v apt-get     >/dev/null; then run apt-get clean; run apt-get autoremove
    elif command -v dnf         >/dev/null; then run dnf clean all; run dnf autoremove
    else warn "sem receita de cache para esta distro (o guia cobre Arch, Gentoo, Debian/Ubuntu e Fedora)"; fi
  fi
  if ((! NOJOURNAL)); then
    echo; echo "── 2. Journal do systemd ──"
    if command -v journalctl >/dev/null; then run journalctl --vacuum-size=200M; else echo "sem systemd-journald: nada a fazer"; fi
  fi
  if ((! NOSNAP)); then
    echo; echo "── 3. Snapshots do snapper (só btrfs) ──"
    if ! command -v snapper >/dev/null || [[ $(findmnt -no FSTYPE / 2>/dev/null) != btrfs ]]; then echo "sem snapper ou a raiz não é btrfs: pulando"
    else
      snapper list-configs
      local cfg ids id ok=1
      printf 'Config do snapper [root]: '; read -r cfg || die "sem resposta"; cfg=${cfg:-root}
      [[ $cfg =~ ^[A-Za-z0-9_.-]+$ ]] || die "nome de config inválido: $cfg"
      snapper -c "$cfg" list
      echo "Mantenha os important=yes e os que você nomeou. Olhe o espaço usado antes de apagar (snapper setup-quota ativa essa coluna)."
      printf 'Números para apagar (ex.: 12 ou 116-138; vários separados por espaço; vazio = nenhum): '; read -r ids || die "sem resposta"
      for id in $ids; do [[ $id =~ ^[1-9][0-9]*(-[1-9][0-9]*)?$ ]] || { warn "'$id' não é um número nem um intervalo (o 0 é o sistema atual)"; ok=0; }; done
      if ((! ok)); then warn "nada apagado"
      elif [[ -n $ids ]]; then
        # shellcheck disable=SC2086  # $ids foi validado acima: só números e intervalos separados por espaço
        run snapper -c "$cfg" delete $ids && run btrfs subvolume sync /   # a remoção corre em segundo plano: espera terminar
      fi
    fi
  fi
  if ((! NOTRIM)); then
    echo; echo "── 4. fstrim (SEMPRE POR ÚLTIMO: só ele zera os blocos livres) ──"
    run fstrim -av
  fi
  echo; log "limpeza pronta. Desligue e reinicie pela pendrive; não use mais o sistema antes do backup."
}

# ─── backup ───────────────────────────────────────────────────────────────────
log_ok() { awk '/^#/ {next} ++n == 1 {next} $3 != "+" {bad = 1} END {exit bad}' "$1"; }   # mapfile do ddrescue: só blocos "+" (a 1ª linha é o estado)

cmd_backup() {
  need lsblk findmnt swapon ddrescue; ((NOZ)) || need zstd
  ((DRY_RUN)) || root_or_exec
  local name img mapf zst cur=0 avail need_b resume=0 only_zip=0
  pick_disk "Disco de ORIGEM (será só lido)"; local src=$DEV src_size=$DSIZE src_desc=$DDESC
  in_use "$src" && die "$src tem partição montada ou swap em uso. Rode no live boot (SystemRescue), com o disco de origem desmontado."
  mount_part "Partição de DESTINO (onde ficará o backup)" "$src"
  run mkdir -p "$DIR" || die "não consegui criar $DIR"
  local dflt; dflt=backup_ssd_$(date +%Y%m%d)   # com a data, o backup de hoje não esbarra no de ontem
  printf 'Nome do backup, sem extensão [%s]: ' "$dflt"; read -r name || die "sem resposta"; name=${name:-$dflt}
  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || die "nome inválido (use letras, números, . _ -): $name"
  img=$DIR/$name.img mapf=$DIR/$name.log zst=$img.zst
  [[ -e $zst && ! -e $img ]] && die "já existe $zst. Apague-o ou escolha outro nome."
  if [[ -e $img || -e $mapf ]]; then
    if [[ -e $img && -e $mapf ]] && ! grep -q '^# Finished' "$mapf"; then
      ask "Existe um backup INTERROMPIDO com esse nome. Retomar de onde parou?" && resume=1
    elif ((! NOZ)) && [[ -e $img && -e $mapf ]] && log_ok "$mapf"; then   # bruto completo e limpo: só a compressão não terminou (ou foi adiada)
      ask "Já existe o backup bruto COMPLETO $name.img. Só comprimir ele, SEM ler o disco de novo?" && only_zip=1
    fi
    ((resume || only_zip)) || die "já existem $name.img/.log (o .log é o que o ddrescue usa para retomar: um antigo e acabado atrapalha). Renomeie ou apague, ou escolha outro nome."
  fi
  [[ -e $zst ]] && ((! only_zip)) && die "já existe $zst. Apague-o ou escolha outro nome."
  if [[ -d $DIR ]] && ((! only_zip)); then
    [[ -e $img ]] && cur=$(stat -c %s "$img")
    avail=$(df -B1 --output=avail "$DIR" | tail -n1 | tr -d ' '); need_b=$((src_size - cur))
    ((avail >= need_b)) || die "faltam $(hum $((need_b - avail))) no destino (livre: $(hum "$avail"), o .img precisa de $(hum "$need_b"))."
    ((avail >= 2 * need_b)) || warn "livre ($(hum "$avail")) cabe o .img, mas o .zst precisa de espaço extra enquanto o .img existe; no pior caso, outro tanto."
  fi
  echo; if ((only_zip)); then echo "Origem : (não será lida; só vou comprimir $name.img)"; else echo "Origem : $src_desc"; fi
  echo "Destino: $img  (livre em $MNT)"
  ((NOZ)) && echo "Depois: fica só o .img (sem compressão)" || echo "Depois: zstd -T0 -$NIVEL --rm -> $name.img.zst, teste, umount"
  if ((only_zip)); then ask "Comprimir $name.img?" || die "cancelado"; else ask "Fazer o backup de $src?" || die "cancelado"; fi
  if ((! only_zip)); then
    run ddrescue -v "$src" "$img" "$mapf" || die "o ddrescue falhou (código $?). Rode de novo e digite o mesmo nome ($name): ele continua de onde parou."
    if ! ((DRY_RUN)); then
      log_ok "$mapf" || die "o ddrescue terminou com setores problemáticos (veja $mapf: só um bloco '+' é um backup limpo). O .img NÃO foi comprimido."
    fi
    log "backup bruto pronto: $img"
  fi
  if ((! NOZ)); then
    ((only_zip)) && [[ -e $zst ]] && run rm -f "$zst"   # sobra parcial de uma compressão interrompida: o .img completo é a fonte
    echo "Comprimindo (nível $NIVEL; use --nivel=12 em PC fraco; HD mecânico: não rode outras cópias grandes ao mesmo tempo)..."
    run zstd -T0 "-$NIVEL" --rm "$img" -o "$zst" || die "o zstd falhou (código $?); o .img foi mantido."
    run zstd -t "$zst" || die "o teste de integridade de $zst falhou: o .img já foi apagado pelo --rm; refaça o backup."
    ((DRY_RUN)) || ls -lh "$zst"
  fi
  ((only_zip)) && warn "lembrete: o disco $src NÃO foi lido agora; o que foi comprimido é o backup bruto que já existia."
  finish_mount
  log "tudo certo. Só desligue ou remova o disco depois do umount."
}

# ─── restaurar ────────────────────────────────────────────────────────────────
cmd_restaurar() {
  need lsblk findmnt swapon dd
  ((DRY_RUN)) || root_or_exec
  local i=0 f est typed; local -a F=()
  mount_part "Partição onde está o backup"
  if [[ -d $DIR ]]; then
    shopt -s nullglob; F=("$DIR"/*.img.zst "$DIR"/*.img); shopt -u nullglob
    ((${#F[@]})) || die "nenhum .img.zst nem .img em $DIR"
    echo; echo "Backups em $DIR:"
    for f in "${F[@]}"; do ((++i)); printf '  %d) %s  (%s)\n' "$i" "${f##*/}" "$(hum "$(stat -c %s "$f")")"; done
    choose "Qual restaurar [1-$i, q cancela]: " "$i"; f=${F[CH - 1]}
  elif ((DRY_RUN)); then f=$DIR/backup_ssd.img.zst; warn "simulação: sem o destino montado não dá para listar os backups; usando $f"
  else die "não existe a pasta '$DIRNAME' nessa partição (BACKUP_DIR_NAME muda o nome)"; fi
  [[ $f == *.zst ]] && need zstd
  pick_disk "Disco a SOBRESCREVER"; local dst=$DEV dst_size=$DSIZE dst_desc=$DDESC
  in_use "$dst" && die "$dst tem partição montada ou swap em uso. Rode no live boot, com o disco desmontado."
  if [[ -e $f ]]; then
    if [[ $f == *.zst ]]; then est=$(zstd -lv "$f" 2>/dev/null | sed -n 's/.*Decompressed Size *: .*(\([0-9]*\) B).*/\1/p' | head -n1)
    else est=$(stat -c %s "$f"); fi
    if [[ -z ${est:-} ]]; then warn "não consegui saber o tamanho descomprimido: confirme você mesmo que o disco de destino não é menor que o original."
    elif ((dst_size < est)); then die "$dst ($(hum "$dst_size")) é menor que o backup ($(hum "$est")). O destino precisa ser do mesmo tamanho ou maior."; fi
  fi
  echo; warn "ISTO SOBRESCREVE O DISCO INTEIRO, sem volta:"
  echo "  Backup : ${f##*/}"; echo "  Destino: $dst_desc"
  printf 'Para confirmar, digite o caminho do disco (%s): ' "$dst"; read -r typed || die "sem resposta"
  [[ $typed == "$dst" ]] || die "não confere: nada foi escrito"
  if [[ $f == *.zst ]]; then
    if ((DRY_RUN)); then printf '\033[1;36m[sim]\033[0m $ %s\n' "zstd -d $(shq "$f") -c | dd of=$dst bs=4M status=progress conv=fsync"
    else zstd -d "$f" -c | dd of="$dst" bs=4M status=progress conv=fsync || die "a restauração falhou (zstd ou dd): o disco $dst está num estado inválido; refaça."; fi
  else run dd if="$f" of="$dst" bs=4M status=progress conv=fsync || die "a restauração falhou: o disco $dst está num estado inválido; refaça."; fi
  run sync
  finish_mount
  log "restaurado. O disco volta idêntico: tabela de partições, bootloader e dados."
}

"cmd_$ACTION"
