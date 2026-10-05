#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034  # fonte dinamica do os-release; NV_* sao lidas por indirecao (${!v})
# =============================================================================
# nvidia.sh — driver NVIDIA no Linux
#
#   ETAPA 1  DETECÇÃO    somente leitura          ./nvidia.sh [--env]
#   ETAPA 2  INSTALAÇÃO  altera o sistema         ./nvidia.sh install [opções]
#
# Alvo: Arch, Debian, Ubuntu e Fedora (mais derivadas, via ID_LIKE).
#
# Estado da etapa 2:
#   Arch                       real. GRUB e Limine, PRIME offload, snapper.
#   Fedora / Ubuntu / Debian   só --dry-run até serem testados em máquina real
#                              (execução real exige --allow-untested).
#   Sessão: só Wayland por enquanto. X11 (PRIME sync, xorg.conf) está nos planos.
#   Secure Boot: não tratado (o script apenas avisa se estiver ativo).
#   Distros que gerenciam o driver sozinhas (chwd, mhwd, nvidia-inst...): recusa.
#
# Uso:
#   ./nvidia.sh                    relatório legível (etapa 1)
#   ./nvidia.sh --env              imprime NV_CHAVE=valor  (eval "$(./nvidia.sh --env)")
#   ./nvidia.sh install --dry-run  mostra o plano e os comandos, sem alterar nada
#   ./nvidia.sh install            instala (pede confirmação)
#   ./nvidia.sh --help             lista todas as opções
#   source ./nvidia.sh             só carrega as funções (depois: nv_detect_all)
#
# Códigos de saída:
#   0   ok (detecção: NVIDIA encontrada e ambiente suportado; install: concluído)
#   2   uso incorreto
#   10  nenhuma GPU NVIDIA detectada
#   11  ambiente sem suporte (Termux, proot, container, WSL, sistema imutável)
#   12  distro não suportada
#   13  recusado por política (distro com gerenciador próprio, distro ainda não
#       validada sem --allow-untested, execução como root)
#   14  não consigo decidir/continuar com segurança (GPU desconhecida ou legada
#       não automatizada, pacote ausente, bootloader ambíguo, .run instalado...)
#   15  um passo da instalação falhou
#   16  cancelado pelo usuário
#
# Ganchos de teste (opcionais):
#   NVSH_PCI_ROOT  NVSH_OS_RELEASE  NVSH_DMI_ROOT  NVSH_SKIP_ENV_CHECK=1
#   NVSH_ROOT (prefixo p/ arquivos de config na etapa 2)  NVSH_FAKE_EUID
#
# Limitação conhecida: se a dGPU estiver desligada pela BIOS/ACPI (modo
# "integrated only" em alguns notebooks), ela some do barramento PCI e não
# pode ser detectada por nenhum script.
# =============================================================================

NVSH_PCI_ROOT=${NVSH_PCI_ROOT:-/sys/bus/pci/devices}
NVSH_OS_RELEASE=${NVSH_OS_RELEASE:-/etc/os-release}
NVSH_DMI_ROOT=${NVSH_DMI_ROOT:-/sys/class/dmi/id}

NV_VARS=(
  NV_ENV_OK NV_ENV_REASON
  NV_DISTRO_ID NV_DISTRO_PRETTY NV_DISTRO_VERSION NV_DISTRO_SOURCE
  NV_FAMILY NV_PKG_MGR NV_MANAGED_BY
  NV_GPU_COUNT NV_NVIDIA_COUNT NV_NVIDIA_PRESENT NV_NVIDIA_ADDR NV_NVIDIA_ID
  NV_NVIDIA_NAME NV_NVIDIA_BUSID NV_NVIDIA_BOOT_VGA NV_NVIDIA_ARCH
  NV_OPEN_SUPPORT NV_OPEN_REQUIRED NV_LEGACY_LIKELY
  NV_IGPU_VENDOR NV_IGPU_ADDR NV_IGPU_NAME NV_IGPU_BUSID
  NV_HYBRID NV_HYBRID_KIND NV_CHASSIS NV_LAPTOP
  NV_STATE NV_MOD_LOADED NV_MOD_KIND NV_MOD_SOURCE NV_DRV_VERSION
  NV_DRM_MODESET NV_DRM_FBDEV NV_NOUVEAU_LOADED NV_NOUVEAU_BLACKLISTED
  NV_PKGS NV_PKG_DRIVER NV_RUNFILE NV_SMI_OK
  NV_UEFI NV_SECUREBOOT NV_BOOTLOADERS NV_INITRAMFS
  NV_KERNEL NV_KERNEL_PKGBASE NV_HEADERS
  NV_TOOLS NV_SESSION NV_REPO_OK NV_REPO_NOTE
)

# ---------- utilitários -------------------------------------------------------
_have() { command -v "$1" >/dev/null 2>&1; }
_cat()  { [[ -r $1 ]] && tr -d '\0\n' <"$1"; }
_any()  { local p; for p in "$@"; do [[ -e $p ]] && return 0; done; return 1; }
_glob() { compgen -G "$1" >/dev/null 2>&1; }
_warn() { NV_WARNINGS+="$1"$'\n'; }
_info() { NV_NOTES+="$1"$'\n'; }

_pci_name() {
  local n=""
  if _have lspci; then
    n=$(lspci -s "$1" 2>/dev/null | sed -E 's/^[^ ]+ //')
  else
    n="(lspci ausente: instale pciutils para ver o nome)"
  fi
  printf '%s' "${n:-(nome indisponível)}"
}

# 0000:01:00.0 -> PCI:1:0:0   (formato decimal exigido pelo xorg.conf)
_busid() {
  local d=${1%%:*} rest=${1#*:} b s f
  b=${rest%%:*}; rest=${rest#*:}
  s=${rest%%.*}; f=${rest#*.}
  if (( 0x$d == 0 )); then
    printf 'PCI:%d:%d:%d' "0x$b" "0x$s" "0x$f"
  else
    printf 'PCI:%d@%d:%d:%d' "0x$b" "0x$d" "0x$s" "0x$f"
  fi
}

# Arquitetura estimada pela FAIXA do device ID (não é tabela oficial: tratar
# como estimativa; a confirmação definitiva vem do próprio driver na instalação).
_nv_arch() {
  [[ $1 == 0x* ]] || { echo unknown; return; }
  local id=$(( $1 ))
  if   (( id >= 0x2900 && id <= 0x2fff )); then echo blackwell
  elif (( id >= 0x2600 && id <= 0x28ff )); then echo ada
  elif (( id >= 0x2300 && id <= 0x23ff )); then echo hopper
  elif (( id >= 0x2200 && id <= 0x25ff )); then echo ampere
  elif (( id >= 0x2100 && id <= 0x21ff )); then echo turing
  elif (( id >= 0x2000 && id <= 0x20ff )); then echo ampere
  elif (( id >= 0x1e00 && id <= 0x1fff )); then echo turing
  elif (( id >= 0x1d80 && id <= 0x1dff )); then echo volta
  elif (( id >= 0x1b00 && id <= 0x1d7f )) || (( id >= 0x15f0 && id <= 0x15ff )); then echo pascal
  elif (( id >= 0x1340 && id <= 0x17ff )); then echo maxwell
  elif (( id >= 0x0400 && id <= 0x133f )); then echo kepler_or_older
  else echo unknown
  fi
}

_apt_has_component() {
  grep -hsE "^[[:space:]]*(deb[[:space:]]|Components:).*[[:space:]]$1([[:space:]]|\$)" \
    /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | grep -q .
}

# ---------- 1. ambiente -------------------------------------------------------
nv_detect_env() {
  NV_ENV_OK=1; NV_ENV_REASON=""
  [[ ${NVSH_SKIP_ENV_CHECK:-0} == 1 ]] && return 0
  local why=()
  [[ -n ${TERMUX_VERSION:-} || ${PREFIX:-} == *com.termux* ]] && why+=("Termux")
  grep -qE '^TracerPid:[[:space:]]*[1-9]' /proc/self/status 2>/dev/null \
    && why+=("proot (processo rastreado via ptrace)")
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null \
    && why+=("WSL (o driver NVIDIA fica no Windows)")
  if [[ -f /.dockerenv || -f /run/.containerenv ]] \
     || { _have systemd-detect-virt && systemd-detect-virt -cq 2>/dev/null; }; then
    why+=("container (o driver pertence ao host)")
  fi
  [[ -e /run/ostree-booted ]] \
    && why+=("sistema imutável/ostree (Silverblue, Kinoite, Bazzite)")
  if (( ${#why[@]} )); then
    NV_ENV_OK=0
    NV_ENV_REASON=$(printf '%s; ' "${why[@]}")
    NV_ENV_REASON=${NV_ENV_REASON%; }
  fi
}

# ---------- 2. distro ---------------------------------------------------------
nv_detect_distro() {
  NV_DISTRO_ID=""; NV_DISTRO_PRETTY=""; NV_DISTRO_VERSION=""
  NV_DISTRO_SOURCE="os-release"; NV_FAMILY=""; NV_PKG_MGR=""; NV_MANAGED_BY=""
  local line id="" like="" ver="" pretty=""

  if [[ -r $NVSH_OS_RELEASE ]]; then
    # subshell: não vaza NAME, VERSION etc. para o shell de quem fez `source`
    line=$( . "$NVSH_OS_RELEASE" >/dev/null 2>&1
            printf '%s|%s|%s|%s' "${ID:-}" "${ID_LIKE:-}" "${VERSION_ID:-}" "${PRETTY_NAME:-}" )
    IFS='|' read -r id like ver pretty <<<"$line"
  fi
  NV_DISTRO_ID=$id; NV_DISTRO_VERSION=$ver; NV_DISTRO_PRETTY=$pretty

  local t=" ${id} ${like} "
  # clones de RHEL não têm RPM Fusion do mesmo jeito: fora do escopo
  case $id in rhel|centos|rocky|almalinux|ol|amzn|scientific) t=" " ;; esac
  case $t in            # ubuntu antes de debian (Mint/Pop declaram ambos)
    *" ubuntu "*) NV_FAMILY=ubuntu ;;
    *" debian "*) NV_FAMILY=debian ;;
    *" arch "*)   NV_FAMILY=arch ;;
    *" fedora "*) NV_FAMILY=fedora ;;
  esac

  if [[ -z $NV_FAMILY && ! -r $NVSH_OS_RELEASE ]]; then
    NV_DISTRO_SOURCE="fallback (sem os-release)"
    if   _have pacman;  then NV_FAMILY=arch
    elif _have dnf;     then NV_FAMILY=fedora
    elif _have apt-get; then NV_FAMILY=debian
    fi
  fi

  case $NV_FAMILY in
    arch)          NV_PKG_MGR=pacman ;;
    debian|ubuntu) NV_PKG_MGR=apt ;;
    fedora)        NV_PKG_MGR=dnf ;;
  esac

  case $id in
    cachyos)     NV_MANAGED_BY="chwd" ;;
    endeavouros) NV_MANAGED_BY="nvidia-inst" ;;
    manjaro)     NV_MANAGED_BY="mhwd" ;;
    pop)         NV_MANAGED_BY="Pop!_OS (ISO NVIDIA própria / system76-power)" ;;
    linuxmint)   NV_MANAGED_BY="Gerenciador de Drivers do Mint" ;;
    nobara)      NV_MANAGED_BY="nobara-driver-manager" ;;
  esac
}

# ---------- 3. GPUs -----------------------------------------------------------
nv_detect_gpus() {
  NV_GPU_COUNT=0; NV_NVIDIA_COUNT=0; NV_NVIDIA_PRESENT=0; NV_GPU_SUMMARY=""
  NV_NVIDIA_ADDR=""; NV_NVIDIA_ID=""; NV_NVIDIA_NAME=""; NV_NVIDIA_BUSID=""
  NV_NVIDIA_BOOT_VGA=""; NV_NVIDIA_ARCH=""; NV_OPEN_SUPPORT=""
  NV_OPEN_REQUIRED=0; NV_LEGACY_LIKELY=0
  NV_IGPU_VENDOR=""; NV_IGPU_ADDR=""; NV_IGPU_NAME=""; NV_IGPU_BUSID=""
  NV_HYBRID=0; NV_HYBRID_KIND=""

  local dev class vendor device addr name
  for dev in "$NVSH_PCI_ROOT"/*; do
    [[ -r $dev/class ]] || continue
    class=$(_cat "$dev/class")
    [[ $class == 0x03* ]] || continue          # 0300 VGA | 0302 3D | 0380 outros
    vendor=$(_cat "$dev/vendor"); device=$(_cat "$dev/device"); addr=${dev##*/}
    name=$(_pci_name "$addr")
    NV_GPU_COUNT=$(( NV_GPU_COUNT + 1 ))
    NV_GPU_SUMMARY+="${addr} [${vendor#0x}:${device#0x}] ${name}"$'\n'
    case $vendor in
      0x10de)
        NV_NVIDIA_COUNT=$(( NV_NVIDIA_COUNT + 1 ))
        if (( NV_NVIDIA_COUNT == 1 )); then
          NV_NVIDIA_ADDR=$addr; NV_NVIDIA_ID=$device; NV_NVIDIA_NAME=$name
          NV_NVIDIA_BUSID=$(_busid "$addr")
          NV_NVIDIA_BOOT_VGA=$(_cat "$dev/boot_vga")
        fi ;;
      0x8086|0x1002)
        if [[ -z $NV_IGPU_ADDR ]]; then
          NV_IGPU_ADDR=$addr; NV_IGPU_NAME=$name; NV_IGPU_BUSID=$(_busid "$addr")
          [[ $vendor == 0x8086 ]] && NV_IGPU_VENDOR=intel || NV_IGPU_VENDOR=amd
        fi ;;
    esac
  done

  if (( NV_NVIDIA_COUNT )); then
    NV_NVIDIA_PRESENT=1
    NV_NVIDIA_ARCH=$(_nv_arch "$NV_NVIDIA_ID")
    case $NV_NVIDIA_ARCH in
      turing|ampere|hopper|ada|blackwell) NV_OPEN_SUPPORT=yes ;;
      volta|pascal|maxwell|kepler_or_older) NV_OPEN_SUPPORT=no; NV_LEGACY_LIKELY=1 ;;
      *) NV_OPEN_SUPPORT=unknown ;;
    esac
    [[ $NV_NVIDIA_ARCH == blackwell ]] && NV_OPEN_REQUIRED=1
    [[ -n $NV_IGPU_ADDR ]] && NV_HYBRID=1
  fi
}

nv_detect_chassis() {
  local ct; ct=$(_cat "$NVSH_DMI_ROOT/chassis_type")
  NV_CHASSIS=${ct:-unknown}; NV_LAPTOP=0
  case $ct in 8|9|10|14|30|31|32) NV_LAPTOP=1 ;; esac   # portátil/notebook/conversível...
  _glob '/sys/class/power_supply/BAT*' && NV_LAPTOP=1
  if (( NV_HYBRID )); then
    (( NV_LAPTOP )) && NV_HYBRID_KIND=laptop || NV_HYBRID_KIND=desktop
  fi
}

# ---------- 4. estado atual do driver ------------------------------------------
nv_detect_driver() {
  NV_STATE=absent; NV_MOD_LOADED=0; NV_MOD_KIND=""; NV_MOD_SOURCE=none
  NV_DRV_VERSION=""; NV_DRM_MODESET=""; NV_DRM_FBDEV=""
  NV_NOUVEAU_LOADED=0; NV_NOUVEAU_BLACKLISTED=0
  NV_PKGS=""; NV_PKG_DRIVER=0; NV_RUNFILE=0; NV_SMI_OK=0
  local v lic

  grep -q '^nvidia ' /proc/modules 2>/dev/null && NV_MOD_LOADED=1
  grep -q '^nouveau ' /proc/modules 2>/dev/null && NV_NOUVEAU_LOADED=1

  if [[ -r /proc/driver/nvidia/version ]]; then
    NV_MOD_LOADED=1
    v=$(head -n1 /proc/driver/nvidia/version)
    [[ $v == *"Open Kernel Module"* ]] && NV_MOD_KIND=open || NV_MOD_KIND=proprietary
    NV_DRV_VERSION=$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$v" | head -n1)
  fi
  if (( NV_MOD_LOADED )); then NV_MOD_SOURCE=loaded; fi

  if [[ -z $NV_MOD_KIND ]] && _have modinfo; then
    lic=$(modinfo -F license nvidia 2>/dev/null)
    if [[ -n $lic ]]; then
      case $lic in *MIT*|*GPL*) NV_MOD_KIND=open ;; *) NV_MOD_KIND=proprietary ;; esac
      NV_DRV_VERSION=$(modinfo -F version nvidia 2>/dev/null)
      (( NV_MOD_LOADED )) || NV_MOD_SOURCE=disk
    fi
  fi

  [[ -r /sys/module/nvidia_drm/parameters/modeset ]] \
    && NV_DRM_MODESET=$(_cat /sys/module/nvidia_drm/parameters/modeset)
  [[ -r /sys/module/nvidia_drm/parameters/fbdev ]] \
    && NV_DRM_FBDEV=$(_cat /sys/module/nvidia_drm/parameters/fbdev)

  grep -rqsE '^[[:space:]]*(blacklist|install)[[:space:]]+nouveau' \
    /etc/modprobe.d /usr/lib/modprobe.d /run/modprobe.d 2>/dev/null \
    && NV_NOUVEAU_BLACKLISTED=1

  case $NV_FAMILY in
    arch)
      NV_PKGS=$(pacman -Qq 2>/dev/null | grep -E \
        '^(nvidia|nvidia-open|nvidia-dkms|nvidia-open-dkms|nvidia-lts|nvidia-open-lts|nvidia-utils|nvidia-580xx.*|linux.*-nvidia.*)$') ;;
    debian|ubuntu)
      NV_PKGS=$(dpkg-query -W -f='${db:Status-Abbrev}\t${Package}\n' 2>/dev/null | awk -F'\t' \
        '$1 ~ /^ii/ && $2 ~ /^(nvidia-(driver|kernel|open|dkms|utils)|linux-(modules|objects|signatures)-nvidia)/ {print $2}') ;;
    fedora)
      NV_PKGS=$(rpm -qa --qf '%{NAME}\n' 'akmod-nvidia*' 'kmod-nvidia*' \
        'xorg-x11-drv-nvidia*' 'nvidia-driver*' 'nvidia-open*' 2>/dev/null | sort -u) ;;
  esac
  NV_PKGS=$(tr '\n' ' ' <<<"$NV_PKGS"); NV_PKGS=${NV_PKGS% }
  [[ -n $NV_PKGS ]] && NV_PKG_DRIVER=1

  # instalação via .run da NVIDIA conflita com pacotes da distro
  _any /usr/bin/nvidia-uninstall /usr/local/bin/nvidia-uninstall && NV_RUNFILE=1

  if _have nvidia-smi; then
    if _have timeout; then timeout 10 nvidia-smi -L >/dev/null 2>&1 && NV_SMI_OK=1
    else nvidia-smi -L >/dev/null 2>&1 && NV_SMI_OK=1
    fi
  fi

  if   (( NV_RUNFILE )); then NV_STATE=runfile
  elif [[ $NV_MOD_SOURCE == loaded ]]; then NV_STATE=active
  elif (( NV_PKG_DRIVER )) || [[ $NV_MOD_SOURCE == disk ]]; then NV_STATE=installed_inactive
  fi
}

# ---------- 5. boot, kernel, ferramentas, repositórios -------------------------
nv_detect_boot() {
  NV_UEFI=0; NV_SECUREBOOT=na; NV_BOOTLOADERS=""; NV_INITRAMFS=""
  local sbvar=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c v

  if [[ -d /sys/firmware/efi ]]; then
    NV_UEFI=1; NV_SECUREBOOT=unknown
    if [[ -r $sbvar ]]; then
      v=$(od -An -t u1 -j4 -N1 "$sbvar" 2>/dev/null | tr -d ' ')
      case $v in 1) NV_SECUREBOOT=enabled ;; 0) NV_SECUREBOOT=disabled ;; esac
    elif _have mokutil; then
      case $(mokutil --sb-state 2>/dev/null) in
        *enabled*)  NV_SECUREBOOT=enabled ;;
        *disabled*) NV_SECUREBOOT=disabled ;;
      esac
    fi
  fi

  local bl=() ir=()
  _any /boot/limine.conf /boot/limine.cfg /boot/limine/limine.conf /boot/limine/limine.cfg \
       /efi/limine.conf /efi/limine/limine.conf /boot/efi/limine.conf \
       /boot/EFI/limine /efi/EFI/limine /boot/efi/EFI/limine && bl+=(limine)
  { _have bootctl && bootctl is-installed >/dev/null 2>&1; } \
    || _any /boot/loader/loader.conf /efi/loader/loader.conf /boot/efi/loader/loader.conf \
    && bl+=(systemd-boot)
  _any /etc/default/grub \
    && _any /boot/grub/grub.cfg /boot/grub2/grub.cfg /boot/efi/EFI/*/grub.cfg /efi/EFI/*/grub.cfg \
    && bl+=(grub)
  _any /boot/EFI/refind /efi/EFI/refind /boot/efi/EFI/refind /boot/refind_linux.conf && bl+=(refind)
  NV_BOOTLOADERS="${bl[*]}"

  _have mkinitcpio       && ir+=(mkinitcpio)
  _have dracut           && ir+=(dracut)
  _have update-initramfs && ir+=(initramfs-tools)
  NV_INITRAMFS="${ir[*]}"
}

nv_detect_kernel() {
  NV_KERNEL=$(uname -r); NV_KERNEL_PKGBASE=""; NV_HEADERS=no
  [[ -r /usr/lib/modules/$NV_KERNEL/pkgbase ]] \
    && NV_KERNEL_PKGBASE=$(<"/usr/lib/modules/$NV_KERNEL/pkgbase")
  # headers instalados do kernel em execução (Arch, Debian/Ubuntu e Fedora)
  [[ -e /lib/modules/$NV_KERNEL/build/Makefile ]] && NV_HEADERS=yes
}

nv_detect_tools() {
  local t found=()
  for t in nvidia-smi nvidia-settings prime-run prime-select switcherooctl \
           envycontrol supergfxctl optimus-manager system76-power ubuntu-drivers \
           chwd nvidia-inst mhwd; do
    _have "$t" && found+=("$t")
  done
  NV_TOOLS="${found[*]}"
  NV_SESSION=${XDG_SESSION_TYPE:-unknown}
}

nv_detect_repos() {
  NV_REPO_OK=1; NV_REPO_NOTE=""
  case $NV_FAMILY in
    debian)
      _apt_has_component non-free \
        || { NV_REPO_OK=0; NV_REPO_NOTE="componente 'non-free' não habilitado no APT (necessário p/ nvidia-driver)"; } ;;
    ubuntu)
      _apt_has_component restricted \
        || { NV_REPO_OK=0; NV_REPO_NOTE="componente 'restricted' não habilitado no APT"; } ;;
    fedora)
      rpm -q rpmfusion-nonfree-release >/dev/null 2>&1 \
        || { NV_REPO_OK=0; NV_REPO_NOTE="RPM Fusion nonfree não habilitado (necessário p/ akmod-nvidia)"; } ;;
  esac
}

# ---------- 6. avaliação (avisos e observações) --------------------------------
nv_assess() {
  NV_WARNINGS=""; NV_NOTES=""
  (( NV_ENV_OK )) && [[ -n $NV_FAMILY ]] || return 0

  [[ -n $NV_MANAGED_BY ]] && _warn "Esta distro gerencia drivers NVIDIA via: $NV_MANAGED_BY. Prefira essa ferramenta; instalar por cima pode conflitar."
  (( NV_NVIDIA_PRESENT )) || return 0

  [[ $NV_MOD_KIND == open && $NV_OPEN_SUPPORT == no ]] \
    && _warn "Módulo OPEN presente, mas a GPU ($NV_NVIDIA_ARCH) não é compatível com ele."
  (( NV_OPEN_REQUIRED )) && [[ $NV_MOD_KIND == proprietary ]] \
    && _warn "GPU Blackwell exige o módulo OPEN; o módulo proprietário não serve."
  [[ $NV_OPEN_SUPPORT == unknown ]] \
    && _warn "Device ID $NV_NVIDIA_ID fora das faixas conhecidas: confirme a compatibilidade com o módulo open antes de instalar."
  [[ $NV_STATE == runfile ]] \
    && _warn "Driver instalado via .run da NVIDIA (nvidia-uninstall). Remova-o antes de usar pacotes da distro."
  if [[ $NV_STATE == installed_inactive ]]; then
    _warn "Driver instalado, mas o módulo NÃO está carregado (falta reiniciar, DKMS/akmod falhou ou Secure Boot bloqueou)."
    [[ $NV_SECUREBOOT == enabled ]] && _warn "Secure Boot ativo: módulos DKMS/akmod precisam ser assinados (MOK)."
    [[ $NV_HEADERS == no ]] && _warn "Headers do kernel em execução ($NV_KERNEL) ausentes: DKMS/akmod não consegue compilar."
  fi
  [[ $NV_STATE == active && $NV_SMI_OK == 0 ]] \
    && _warn "Módulo carregado, mas o nvidia-smi não responde."
  (( NV_REPO_OK )) || _warn "$NV_REPO_NOTE"
  if (( $(wc -w <<<"$NV_BOOTLOADERS") > 1 )); then
    _warn "Mais de um bootloader detectado ($NV_BOOTLOADERS): confirmar qual está em uso antes de mexer em parâmetros do kernel."
  fi
  if (( $(wc -w <<<"$NV_INITRAMFS") > 1 )); then
    _warn "Mais de um gerador de initramfs instalado ($NV_INITRAMFS): confirmar qual a distro usa de fato."
  fi

  (( NV_NVIDIA_COUNT > 1 )) && _info "$NV_NVIDIA_COUNT GPUs NVIDIA; os dados acima são da primeira."
  [[ $NV_HYBRID_KIND == desktop ]] && _info "iGPU + dGPU em desktop: PRIME costuma ser irrelevante."
  (( NV_LEGACY_LIKELY )) && _info "GPU pré-Turing: provável ramo legado do driver (confirmar na instalação)."
  [[ $NV_STATE == absent && $NV_NOUVEAU_LOADED == 1 ]] && _info "Sem driver NVIDIA; o nouveau está em uso."
  [[ $NV_STATE == active && $NV_DRM_MODESET == N ]] \
    && _info "nvidia_drm.modeset=N (Wayland e PRIME sync exigem Y)."
  return 0
}

# ---------- orquestração e saída ---------------------------------------------
nv_detect_all() {
  nv_detect_env
  nv_detect_distro
  if (( NV_ENV_OK )) && [[ -n $NV_FAMILY ]]; then
    nv_detect_gpus
    nv_detect_chassis
    nv_detect_driver
    nv_detect_boot
    nv_detect_kernel
    nv_detect_tools
    nv_detect_repos
  fi
  nv_assess
}

nv_env() {
  local v
  for v in "${NV_VARS[@]}"; do printf '%s=%q\n' "$v" "${!v-}"; done
}

_row() { printf '  %-24s %s\n' "$1" "$2"; }
_yn()  { case $1 in yes|1) echo sim ;; no|0) echo não ;; *) echo "$1" ;; esac; }

_print_notes() {
  if [[ -n $NV_WARNINGS ]]; then
    echo "== Avisos =="
    sed 's/^/  ! /' <<<"${NV_WARNINGS%$'\n'}"
  fi
  if [[ -n $NV_NOTES ]]; then
    echo "== Observações =="
    sed 's/^/  - /' <<<"${NV_NOTES%$'\n'}"
  fi
}

nv_report() {
  echo "== Ambiente =="
  if (( NV_ENV_OK )); then _row "Suportado" "sim"
  else _row "Suportado" "NÃO: $NV_ENV_REASON"; fi

  echo "== Distro =="
  _row "Sistema" "${NV_DISTRO_PRETTY:-desconhecido} (id=${NV_DISTRO_ID:-?}, versão ${NV_DISTRO_VERSION:-?})"
  _row "Família / gerenciador" "${NV_FAMILY:-NÃO SUPORTADA} / ${NV_PKG_MGR:--}"
  _row "Origem da detecção" "$NV_DISTRO_SOURCE"
  [[ -n $NV_MANAGED_BY ]] && _row "Drivers gerenciados por" "$NV_MANAGED_BY"
  if (( ! NV_ENV_OK )) || [[ -z $NV_FAMILY ]]; then _print_notes; return 0; fi

  echo "== GPUs =="
  if (( NV_GPU_COUNT )); then sed 's/^/  /' <<<"${NV_GPU_SUMMARY%$'\n'}"; else echo "  nenhuma"; fi
  if (( NV_NVIDIA_PRESENT )); then
    _row "Arquitetura (estimada)" "$NV_NVIDIA_ARCH"
    _row "Módulo open" "$(_yn "$NV_OPEN_SUPPORT")$( ((NV_OPEN_REQUIRED)) && echo ' (obrigatório)')"
    _row "BusID NVIDIA" "$NV_NVIDIA_BUSID"
    _row "É a GPU de boot" "$(_yn "${NV_NVIDIA_BOOT_VGA:-?}")"
    if (( NV_HYBRID )); then
      _row "Híbrida" "sim (${NV_HYBRID_KIND}; iGPU ${NV_IGPU_VENDOR}, BusID ${NV_IGPU_BUSID})"
    else
      _row "Híbrida" "não"
    fi
    _row "Chassi (DMI)" "$NV_CHASSIS"
  fi

  echo "== Driver atual =="
  local s
  case $NV_STATE in
    active)             s="ATIVO (${NV_MOD_KIND:-?} ${NV_DRV_VERSION})" ;;
    installed_inactive) s="instalado, mas NÃO carregado (${NV_MOD_KIND:-?} ${NV_DRV_VERSION})" ;;
    runfile)            s="instalado via .run da NVIDIA" ;;
    *)                  s="ausente" ;;
  esac
  _row "Estado" "$s"
  _row "Pacotes" "${NV_PKGS:--}"
  _row "nvidia-smi funciona" "$(_yn "$NV_SMI_OK")"
  _row "nouveau" "carregado=$(_yn "$NV_NOUVEAU_LOADED"), blacklist=$(_yn "$NV_NOUVEAU_BLACKLISTED")"
  _row "nvidia_drm modeset/fbdev" "${NV_DRM_MODESET:--} / ${NV_DRM_FBDEV:--}"

  echo "== Boot e kernel =="
  _row "Firmware" "$( ((NV_UEFI)) && echo UEFI || echo 'BIOS legado')"
  _row "Secure Boot" "$NV_SECUREBOOT"
  _row "Bootloader(s)" "${NV_BOOTLOADERS:-não identificado}"
  _row "Initramfs" "${NV_INITRAMFS:-não identificado}"
  _row "Kernel" "$NV_KERNEL${NV_KERNEL_PKGBASE:+ (pkgbase: $NV_KERNEL_PKGBASE)}"
  _row "Headers instalados" "$(_yn "$NV_HEADERS")"
  _row "Sessão gráfica" "$NV_SESSION"

  echo "== Repositórios e ferramentas =="
  _row "Repositório necessário" "$( ((NV_REPO_OK)) && echo ok || echo "FALTA: $NV_REPO_NOTE")"
  _row "Ferramentas presentes" "${NV_TOOLS:--}"

  _print_notes
  return 0
}

# =============================================================================
# ETAPA 2: INSTALAÇÃO
# =============================================================================

NVSH_ROOT=${NVSH_ROOT:-}    # prefixo de teste para arquivos de configuração

# Parâmetros que garantem o DRM KMS do driver NVIDIA (exigido por Wayland e
# PRIME). Drivers recentes podem ativar por padrão; declarar é inofensivo.
NV_KPARAMS=(nvidia-drm.modeset=1 nvidia-drm.fbdev=1)
NV_MODPROBE_CONF=/etc/modprobe.d/nvidia-nvsh.conf   # alternativa ao bootloader

# ---------- utilitários da etapa 2 ---------------------------------------------
_p()    { printf '%s%s' "$NVSH_ROOT" "$1"; }
_euid() { printf '%s' "${NVSH_FAKE_EUID:-$EUID}"; }
_err()  { printf 'ERRO: %s\n' "$*" >&2; }
_msg()  { printf '  %s\n' "$*"; }
_step() { printf '\n==> %s\n' "$*"; }
_fmt()  { local a o=""; for a in "$@"; do o+="$(printf '%q' "$a") "; done; printf '%s' "${o% }"; }

# executa (ou, em --dry-run, apenas mostra) um comando
run() {
  if (( OPT_DRY )); then printf '  [dry-run] %s\n' "$(_fmt "$@")"; return 0; fi
  printf '  $ %s\n' "$(_fmt "$@")"
  "$@"
}
run_root() { if [[ $(_euid) == 0 ]]; then run "$@"; else run sudo "$@"; fi; }
_root()    { if [[ $(_euid) == 0 ]]; then "$@"; else sudo "$@"; fi; }   # sem eco (captura)

# pergunta s/N; "always" ignora --yes (usado para o que realmente reduz a segurança)
_confirm() {
  local q=$1 mode=${2:-normal} ans
  if (( OPT_DRY )); then printf '  [dry-run] pediria confirmação: %s\n' "$q"; return 0; fi
  if (( OPT_YES )) && [[ $mode != always ]]; then printf '  (--yes) %s -> sim\n' "$q"; return 0; fi
  if [[ ! -t 0 ]]; then _err "sem terminal para perguntar: $q"; return 1; fi
  read -r -p "  $q [s/N] " ans
  [[ $ans == [sSyY]* ]]
}

_show_diff() {   # $1 atual  $2 novo
  _have diff || return 0
  diff -u --label "$1" --label "$1 (novo)" "$1" "$2" | sed 's/^/    /' || true
}

# instala $1 (tmp) em $2, com backup ao lado e diff; $3=ask pede confirmação
_install_file() {
  local new=$1 dest=$2 ask=${3:-} mode bak
  if [[ -e $dest ]]; then
    if cmp -s "$new" "$dest"; then _msg "$dest: já está como deveria"; return 0; fi
    _show_diff "$dest" "$new"
    [[ $ask == ask ]] && { _confirm "Aplicar esta alteração em $dest?" || return 16; }
    bak="$dest.nvsh-bak-$(date +%Y%m%d-%H%M%S)"
    mode=$(stat -c %a "$dest" 2>/dev/null || echo 644)
    run_root cp -a -- "$dest" "$bak" || return 15
  else
    _msg "criando $dest:"; sed 's/^/    + /' "$new"
    [[ $ask == ask ]] && { _confirm "Criar $dest?" || return 16; }
    mode=644
  fi
  run_root install -m "$mode" -o root -g root -- "$new" "$dest" || return 15
}

# ---------- parâmetros de kernel: mesclagem ------------------------------------
_norm_key() { local k=${1%%=*}; printf '%s' "${k//_/-}"; }

_cmdline_ok() {   # 0 se todos os NV_KPARAMS já estão em "$1" (hífen ou underscore)
  local -a toks; local p tok found
  read -ra toks <<<"$1"
  for p in "${NV_KPARAMS[@]}"; do
    found=0
    for tok in "${toks[@]}"; do
      [[ $(_norm_key "$tok") == "$(_norm_key "$p")" && ${tok#*=} == "${p#*=}" ]] && found=1
    done
    (( found )) || return 1
  done
  return 0
}

cmdline_merge() {   # remove versões antigas dos nossos parâmetros e acrescenta as certas
  local -a toks; local tok p skip out=""
  read -ra toks <<<"$1"
  for tok in "${toks[@]}"; do
    skip=0
    for p in "${NV_KPARAMS[@]}"; do
      [[ $(_norm_key "$tok") == "$(_norm_key "$p")" ]] && skip=1
    done
    (( skip )) || out+="$tok "
  done
  for p in "${NV_KPARAMS[@]}"; do out+="$p "; done
  printf '%s' "${out% }"
}

# ---------- argumentos ---------------------------------------------------------
inst_parse() {
  OPT_DRY=0; OPT_FLAVOR=auto; OPT_DKMS=0; OPT_BL=auto; OPT_PRIME=1
  OPT_SNAPSHOT=1; OPT_RECONFIGURE=0; OPT_IGNORE_MANAGED=0; OPT_UNTESTED=0; OPT_YES=0
  while (( $# )); do
    case $1 in
      -n|--dry-run)     OPT_DRY=1 ;;
      --open|--proprietary)
        if [[ $OPT_FLAVOR != auto && $OPT_FLAVOR != "${1#--}" ]]; then
          _err "--open e --proprietary são excludentes"; return 2
        fi
        OPT_FLAVOR=${1#--} ;;
      --dkms)           OPT_DKMS=1 ;;
      --bootloader=*)   OPT_BL=${1#*=}
                        case $OPT_BL in auto|grub|limine|none) ;;
                          *) _err "--bootloader: use auto, grub, limine ou none"; return 2 ;; esac ;;
      --no-prime)       OPT_PRIME=0 ;;
      --no-snapshot)    OPT_SNAPSHOT=0 ;;
      --reconfigure)    OPT_RECONFIGURE=1 ;;
      --ignore-managed) OPT_IGNORE_MANAGED=1 ;;
      --allow-untested) OPT_UNTESTED=1 ;;
      -y|--yes)         OPT_YES=1 ;;
      -h|--help)        nv_usage; return 100 ;;
      *) _err "opção desconhecida: $1"; nv_usage >&2; return 2 ;;
    esac
    shift
  done
  return 0
}

# ---------- portões de segurança -----------------------------------------------
inst_gate() {
  (( NV_ENV_OK )) || { _err "ambiente sem suporte: $NV_ENV_REASON"; return 11; }
  [[ -n $NV_FAMILY ]] || { _err "distro não suportada (id=${NV_DISTRO_ID:-?})"; return 12; }
  (( NV_NVIDIA_PRESENT )) || { _err "nenhuma GPU NVIDIA detectada"; return 10; }

  if [[ -n $NV_MANAGED_BY ]] && (( ! OPT_IGNORE_MANAGED )); then
    _err "Esta distro gerencia os drivers NVIDIA por conta própria: $NV_MANAGED_BY."
    _msg "Use a ferramenta nativa: ela conhece os pacotes e o kernel da distro, e instalar"
    _msg "por cima pode conflitar. Para ignorar mesmo assim: --ignore-managed"
    return 13
  fi

  if [[ $NV_FAMILY != arch ]] && (( ! OPT_DRY && ! OPT_UNTESTED )); then
    _err "O plano para '$NV_FAMILY' ainda NÃO foi validado em máquina real."
    _msg "Rode com --dry-run para ver o que seria feito. Depois de testar: --allow-untested."
    return 13
  fi

  if (( ! OPT_DRY )); then
    if [[ $(_euid) == 0 ]]; then
      _err "Não rode como root: o makepkg/paru recusam root e o script chama sudo quando precisa."
      return 13
    fi
    _have sudo || { _err "sudo não encontrado"; return 13; }
  fi

  if [[ $NV_STATE == runfile ]]; then
    _err "Há um driver instalado via .run da NVIDIA (nvidia-uninstall)."
    _msg "Remova-o antes (sudo nvidia-uninstall): ele conflita com os pacotes da distro."
    return 14
  fi

  [[ $NV_SESSION == x11 ]] && _info "Sessão X11: PRIME sync e xorg.conf ainda não são tratados (nos planos); só offload."
  [[ $NV_SECUREBOOT == enabled ]] && _warn "Secure Boot ATIVO: este script não assina módulos; o driver DKMS/akmod não vai carregar."
  return 0
}

# ---------- decisão: qual driver -----------------------------------------------
# define PLAN_FLAVOR = open | proprietary | legacy580  (e PLAN_WHY)
plan_flavor() {
  PLAN_FLAVOR=""; PLAN_WHY=""
  local arch=$NV_NVIDIA_ARCH
  case $arch in
    kepler_or_older)
      PLAN_WHY="GPU Kepler/Fermi (ou mais antiga): os ramos legados 470xx/390xx não são automatizados."
      return 14 ;;
    unknown)
      if [[ $OPT_FLAVOR == auto ]]; then
        PLAN_WHY="Device ID $NV_NVIDIA_ID fora das faixas conhecidas: não escolho sozinho. Confirme a arquitetura e rode com --open ou --proprietary."
        return 14
      fi
      PLAN_FLAVOR=$OPT_FLAVOR; PLAN_WHY="escolha manual (--$OPT_FLAVOR); arquitetura não identificada" ;;
    maxwell|pascal|volta)
      if [[ $OPT_FLAVOR == open ]]; then
        PLAN_WHY="módulos open não suportam GPU $arch (só Turing em diante)."; return 14
      fi
      PLAN_FLAVOR=legacy580
      PLAN_WHY="GPU $arch: o ramo atual (590+) não a suporta; o último compatível é o 580.xx (proprietário, legado)" ;;
    blackwell)
      if [[ $OPT_FLAVOR == proprietary ]]; then
        PLAN_WHY="GPU Blackwell exige os módulos open."; return 14
      fi
      PLAN_FLAVOR=open; PLAN_WHY="Blackwell exige os módulos open" ;;
    *)  # turing | ampere | ada | hopper
      case $OPT_FLAVOR in
        proprietary) PLAN_FLAVOR=proprietary; PLAN_WHY="escolha manual (--proprietary)" ;;
        *)           PLAN_FLAVOR=open
                     PLAN_WHY="GPU $arch: módulos open são o padrão recomendado pela NVIDIA para Turing em diante" ;;
      esac ;;
  esac
  [[ $arch == unknown ]] || PLAN_WHY+=" (arquitetura estimada pela faixa do Device ID)"
  return 0
}

# ---------- planos por família -------------------------------------------------
arch_plan() {
  PKG_REPO=(); PKG_AUR=()
  local pb=$NV_KERNEL_PKGBASE dkms=$OPT_DKMS hdr=""
  [[ $PLAN_FLAVOR == legacy580 ]] && dkms=1      # o AUR só oferece DKMS
  [[ $pb == linux ]] || dkms=1                   # pacote pré-compilado só p/ o kernel "linux"
  PLAN_DKMS=$dkms
  if (( dkms )); then
    if [[ -z $pb ]]; then
      _err "Não consegui identificar o pacote do kernel em uso (pkgbase); sem isso não sei qual *-headers instalar para o DKMS."
      _msg "Instale os headers do seu kernel e rode de novo com --dkms."
      return 14
    fi
    hdr="${pb}-headers"
  fi
  case $PLAN_FLAVOR in
    open)
      if (( dkms )); then PKG_REPO+=(nvidia-open-dkms "$hdr"); else PKG_REPO+=(nvidia-open); fi
      PKG_REPO+=(nvidia-utils nvidia-settings) ;;
    proprietary)
      if (( dkms )); then PKG_REPO+=(nvidia-dkms "$hdr"); else PKG_REPO+=(nvidia); fi
      PKG_REPO+=(nvidia-utils nvidia-settings) ;;
    legacy580)
      PKG_REPO+=("$hdr"); PKG_AUR+=(nvidia-580xx-dkms nvidia-580xx-utils nvidia-580xx-settings) ;;
  esac
  if grep -qE '^\[multilib\]' "$(_p /etc/pacman.conf)" 2>/dev/null; then
    if [[ $PLAN_FLAVOR == legacy580 ]]; then PKG_AUR+=(lib32-nvidia-580xx-utils)
    else PKG_REPO+=(lib32-nvidia-utils); fi
  else
    PLAN_NOTES+=("[multilib] desativado em /etc/pacman.conf: as libs NVIDIA de 32 bits (Steam/Wine) não serão instaladas. Ative o [multilib] e rode o script de novo.")
  fi
  if [[ $PLAN_FLAVOR == legacy580 ]]; then
    PLAN_NOTES+=("Ramo legado 580xx é DKMS via AUR: se um kernel novo demorar a ser suportado, o módulo pode falhar ao compilar (dkms status / log em /var/lib/dkms).")
  fi
  _have snapper && pacman -Qq snap-pac >/dev/null 2>&1 \
    && PLAN_NOTES+=("snap-pac detectado: o pacman já cria snapshots pre/post nas transações (além do snapshot deste script).")
  return 0
}

fedora_plan() {
  PKG_REPO=(); PKG_AUR=()
  case $PLAN_FLAVOR in
    open)        PKG_REPO=(akmod-nvidia-open) ;;
    proprietary) PKG_REPO=(akmod-nvidia) ;;
    legacy580)   PKG_REPO=(akmod-nvidia-580xx) ;;
  esac
  PLAN_NOTES+=("NÃO VALIDADO: os nomes dos pacotes do RPM Fusion (akmod-nvidia-open / akmod-nvidia-580xx) precisam ser confirmados com 'dnf info <pacote>' na máquina Fedora.")
}

ubuntu_pick_driver() {   # imprime nvidia-driver-VER[-open] adequado, a partir do ubuntu-drivers
  local want_open=0 cap=99999 line v isopen best=0 bestpkg=""
  [[ $PLAN_FLAVOR == open ]] && want_open=1
  [[ $PLAN_FLAVOR == legacy580 ]] && cap=580
  _have ubuntu-drivers || return 1
  while IFS= read -r line; do
    [[ $line =~ ^nvidia-driver-([0-9]+)(-open)?([,[:space:]]|$) ]] || continue
    v=${BASH_REMATCH[1]}; isopen=0; [[ -n ${BASH_REMATCH[2]} ]] && isopen=1
    (( isopen == want_open && v <= cap && v > best )) && { best=$v; bestpkg="nvidia-driver-$v$([[ $isopen == 1 ]] && echo -open)"; }
  done < <(ubuntu-drivers list 2>/dev/null)
  [[ -n $bestpkg ]] || return 1
  printf '%s' "$bestpkg"
}

apt_plan() {
  PKG_REPO=(); PKG_AUR=()
  if (( ! NV_REPO_OK )); then
    if (( OPT_DRY )); then
      PLAN_NOTES+=("repositório: $NV_REPO_NOTE (numa execução real o script pararia aqui)")
    else
      _err "$NV_REPO_NOTE"
      _msg "Habilite o componente em /etc/apt/sources.list (ou sources.list.d), rode 'apt update' e tente de novo."
      return 14
    fi
  fi
  case $NV_FAMILY in
    ubuntu)
      local pkg
      pkg=$(ubuntu_pick_driver) || pkg=""
      if [[ -z $pkg ]]; then
        if (( OPT_DRY )); then
          pkg="nvidia-driver-VERSAO$([[ $PLAN_FLAVOR == open ]] && echo -open)"
          PLAN_NOTES+=("ubuntu-drivers não disponível aqui: a versão do pacote será escolhida no teste real (ubuntu-drivers list).")
        else
          _err "não consegui escolher a versão (ubuntu-drivers list sem saída útil). Instale ubuntu-drivers-common."; return 14
        fi
      fi
      PKG_REPO=("$pkg") ;;
    debian)
      case $PLAN_FLAVOR in
        open) PKG_REPO=(nvidia-open-kernel-dkms) ;;
        *)    PKG_REPO=(nvidia-driver firmware-misc-nonfree) ;;
      esac
      PLAN_NOTES+=("NÃO VALIDADO: nomes de pacote do Debian a confirmar com 'apt-cache policy' (o pacote open pode ter outro nome)."
                   "Debian: a versão do nvidia-driver no repositório pode não suportar GPUs Pascal/Maxwell; confira a tabela de suporte do pacote.") ;;
  esac
  [[ $NV_FAMILY == ubuntu && $PLAN_FLAVOR == legacy580 ]] && PLAN_NOTES+=("Ubuntu: limitei a versão do driver a 580 (último ramo com suporte Pascal).")
  return 0
}

# ---------- bootloader ---------------------------------------------------------
inst_choose_bl() {
  local -a det; read -ra det <<<"$NV_BOOTLOADERS"
  INST_BL=none; INST_BL_WHY=""
  case $OPT_BL in
    none) INST_BL_WHY="ignorado (--bootloader=none)" ;;
    grub|limine)
      if [[ " $NV_BOOTLOADERS " != *" $OPT_BL "* ]]; then
        _err "--bootloader=$OPT_BL, mas esse bootloader não foi detectado (detectados: ${NV_BOOTLOADERS:-nenhum})."
        return 14
      fi
      INST_BL=$OPT_BL ;;
    auto)
      case ${#det[@]} in
        0) INST_BL_WHY="nenhum bootloader identificado" ;;
        1) case ${det[0]} in
             grub|limine) INST_BL=${det[0]} ;;
             *) INST_BL_WHY="${det[0]} ainda não é suportado pelo script" ;;
           esac ;;
        *) _err "Mais de um bootloader detectado (${det[*]}). Diga qual está em uso: --bootloader=<grub|limine|none>"
           return 14 ;;
      esac ;;
  esac
  return 0
}

bl_grub() {
  local f cfg n line cur new tmp rc re_dq re_sq comment=""
  local -a lines
  if [[ $NV_FAMILY == fedora ]]; then
    _msg "Fedora: parâmetros aplicados com grubby em todas as entradas de boot."
    run_root grubby --update-kernel=ALL --args="${NV_KPARAMS[*]}" || return 15
    return 0
  fi
  f=$(_p /etc/default/grub)
  [[ -r $f ]] || { _msg "não consegui ler $f"; return 3; }
  re_dq='^GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"[[:space:]]*(#.*)?$'
  re_sq="^GRUB_CMDLINE_LINUX_DEFAULT='([^']*)'[[:space:]]*(#.*)?\$"
  mapfile -t lines <"$f"
  n=$(grep -nE '^GRUB_CMDLINE_LINUX_DEFAULT=' "$f" | tail -n1 | cut -d: -f1)
  if [[ -z $n ]]; then
    new=$(cmdline_merge "")
    lines+=("GRUB_CMDLINE_LINUX_DEFAULT=\"$new\"")
  else
    line=${lines[n-1]}
    if [[ $line =~ $re_dq || $line =~ $re_sq ]]; then
      cur=${BASH_REMATCH[1]}; comment=${BASH_REMATCH[2]}
    else
      _msg "GRUB_CMDLINE_LINUX_DEFAULT em formato que não sei editar com segurança: $line"
      return 3
    fi
    if _cmdline_ok "$cur"; then _msg "GRUB: parâmetros já presentes ($f): nada a alterar"; return 0; fi
    new=$(cmdline_merge "$cur")
    lines[n-1]="GRUB_CMDLINE_LINUX_DEFAULT=\"$new\"${comment:+ $comment}"
  fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/nvsh-grub.XXXXXX") || return 15
  printf '%s\n' "${lines[@]}" >"$tmp"
  _install_file "$tmp" "$f" ask; rc=$?
  rm -f "$tmp"
  (( rc == 0 )) || return "$rc"
  case $NV_FAMILY in
    arch)
      cfg=/boot/grub/grub.cfg
      [[ ! -e $(_p /boot/grub/grub.cfg) && -e $(_p /boot/grub2/grub.cfg) ]] && cfg=/boot/grub2/grub.cfg
      run_root grub-mkconfig -o "$cfg" || return 15 ;;
    debian|ubuntu) run_root update-grub || return 15 ;;
  esac
  return 0
}

# reescreve as linhas cmdline de um limine.conf (sintaxe nova "cmdline:" e antiga "CMDLINE=")
_limine_rewrite() {   # $1 entrada  $2 saída ; define LIM_SEEN e LIM_CHANGED
  local line lc pre cur new n
  LIM_SEEN=0; LIM_CHANGED=0
  : >"$2"
  while IFS= read -r line || [[ -n $line ]]; do
    lc=${line,,}
    if [[ $lc =~ ^([[:space:]]*(kernel_)?cmdline[[:space:]]*:[[:space:]]*) ]] \
       || [[ $lc =~ ^([[:space:]]*(kernel_)?cmdline=) ]]; then
      n=${#BASH_REMATCH[1]}
      pre=${line:0:n}; cur=${line:n}
      LIM_SEEN=$(( LIM_SEEN + 1 ))
      if _cmdline_ok "$cur"; then new=$cur
      else new=$(cmdline_merge "$cur"); LIM_CHANGED=$(( LIM_CHANGED + 1 )); fi
      printf '%s%s\n' "$pre" "$new" >>"$2"
    else
      printf '%s\n' "$line" >>"$2"
    fi
  done <"$1"
}

bl_limine() {
  local c f tmp rc done_any=0 seen_any=0
  local -a found=()
  if [[ -e $(_p /etc/default/limine) ]]; then
    _msg "limine-entry-tool detectado (/etc/default/limine): ele regenera o limine.conf e"
    _msg "sobrescreveria edições diretas. Adicione os parâmetros ao KERNEL_CMDLINE desse arquivo"
    _msg "(veja a documentação do limine-entry-tool) e rode o limine-update."
    return 3
  fi
  for c in /boot/limine.conf /boot/limine/limine.conf /efi/limine.conf /efi/limine/limine.conf \
           /boot/efi/limine.conf /boot/efi/limine/limine.conf /boot/EFI/BOOT/limine.conf \
           /efi/EFI/BOOT/limine.conf /boot/efi/EFI/BOOT/limine.conf \
           /boot/limine.cfg /boot/limine/limine.cfg /efi/limine.cfg /efi/limine/limine.cfg \
           /boot/efi/limine.cfg /boot/efi/limine/limine.cfg; do
    [[ -f $(_p "$c") ]] && found+=("$c")
  done
  (( ${#found[@]} )) || { _msg "não achei o arquivo de configuração do Limine"; return 3; }
  _msg "AVISO: suporte ao Limine ainda não validado em máquina real; haverá backup ao lado de cada arquivo."
  (( ${#found[@]} > 1 )) && _msg "Várias cópias de config encontradas (${found[*]}); todas serão ajustadas."
  for c in "${found[@]}"; do
    f=$(_p "$c")
    tmp=$(mktemp "${TMPDIR:-/tmp}/nvsh-limine.XXXXXX") || return 15
    _limine_rewrite "$f" "$tmp"
    if (( LIM_SEEN == 0 )); then
      _msg "$c: nenhuma linha cmdline encontrada; ignorado"
    elif (( LIM_CHANGED == 0 )); then
      seen_any=1; _msg "$c: parâmetros já presentes em todas as $LIM_SEEN entradas"
    else
      seen_any=1; _msg "$c: $LIM_CHANGED de $LIM_SEEN linhas cmdline serão ajustadas"
      _install_file "$tmp" "$f" ask; rc=$?
      if (( rc != 0 )); then rm -f "$tmp"; return "$rc"; fi
      done_any=1
    fi
    rm -f "$tmp"
  done
  (( seen_any )) || return 3
  (( done_any )) || return 0
  return 0
}

modprobe_fallback() {
  local tmp rc dest opts="" p
  dest=$(_p "$NV_MODPROBE_CONF")
  for p in "${NV_KPARAMS[@]}"; do opts+=" ${p#*.}"; done
  _msg "Sem edição de bootloader: usando $NV_MODPROBE_CONF (equivalente para o módulo nvidia_drm)."
  _msg "Se preferir, adicione ao cmdline do kernel: ${NV_KPARAMS[*]}"
  tmp=$(mktemp "${TMPDIR:-/tmp}/nvsh-modprobe.XXXXXX") || return 15
  printf '%s\n' "# gerado por nvidia.sh: habilita o DRM KMS do driver NVIDIA (Wayland/PRIME)" \
                "options nvidia_drm$opts" >"$tmp"
  _install_file "$tmp" "$dest"; rc=$?
  rm -f "$tmp"
  return "$rc"
}

kparams_apply() {
  local rc
  case $INST_BL in
    grub)   bl_grub;   rc=$? ;;
    limine) bl_limine; rc=$? ;;
    *)      [[ -n $INST_BL_WHY ]] && _msg "Bootloader: $INST_BL_WHY"; rc=3 ;;
  esac
  case $rc in
    0) return 0 ;;
    3) modprobe_fallback; return $? ;;
    *) return "$rc" ;;
  esac
}

regen_initramfs() {
  local tool=""
  case $NV_FAMILY in
    arch)   _have mkinitcpio && tool=mkinitcpio
            [[ -z $tool ]] && _have dracut && tool=dracut
            : "${tool:=mkinitcpio}" ;;
    fedora) tool=dracut ;;
    *)      tool=initramfs-tools ;;
  esac
  _msg "O initramfs precisa refletir o bloqueio do nouveau e as opções do módulo NVIDIA."
  case $tool in
    mkinitcpio)      run_root mkinitcpio -P || return 15 ;;
    dracut)          run_root dracut --force --regenerate-all || return 15 ;;
    initramfs-tools) run_root update-initramfs -u -k all || return 15 ;;
  esac
  return 0
}

# ---------- snapper ------------------------------------------------------------
snap_available() { _have snapper && [[ -e $(_p /etc/snapper/configs/root) ]]; }

snap_pre() {
  SNAP_PRE=""
  if (( ! OPT_SNAPSHOT )); then _msg "snapshot desativado (--no-snapshot)"; return 0; fi
  if snap_available; then
    if (( OPT_DRY )); then
      printf '  [dry-run] sudo snapper --config root create --type pre --print-number --description "nvidia.sh: antes"\n'
      SNAP_PRE=dry
      return 0
    fi
    local n
    n=$(_root snapper --config root create --type pre --print-number \
          --cleanup-algorithm number --description "nvidia.sh: antes de instalar o driver NVIDIA") || n=""
    if [[ $n =~ ^[0-9]+$ ]]; then
      SNAP_PRE=$n; _msg "snapshot pré criado: #$n (root)"
      return 0
    fi
    _err "o snapper não conseguiu criar o snapshot."
  else
    _msg "snapper não encontrado/configurado para '/' (esperado: pacote snapper + /etc/snapper/configs/root)."
  fi
  _msg "Sem snapshot, só os backups *.nvsh-bak-* dos arquivos de configuração servem de rede de segurança."
  _confirm "Continuar sem snapshot?" always || return 16
  return 0
}

snap_post() {
  [[ -n $SNAP_PRE ]] || return 0
  if (( OPT_DRY )); then
    printf '  [dry-run] sudo snapper --config root create --type post --pre-number <N> --description "nvidia.sh: depois"\n'
    return 0
  fi
  if _root snapper --config root create --type post --pre-number "$SNAP_PRE" \
       --cleanup-algorithm number --description "nvidia.sh: depois de instalar o driver NVIDIA" >/dev/null; then
    _msg "snapshot pós criado (par do #$SNAP_PRE). Ver mudanças: snapper -c root status $SNAP_PRE..0"
  else
    _msg "não consegui criar o snapshot pós; o pré (#$SNAP_PRE) continua valendo."
  fi
}

# ---------- Arch ---------------------------------------------------------------
arch_verify_repo() {
  local p; local -a missing=()
  if ! _have pacman; then _msg "(pacman ausente aqui: nomes de pacote não verificados)"; return 0; fi
  for p in "${PKG_REPO[@]}"; do pacman -Si "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if (( ${#missing[@]} )); then
    _err "pacotes não encontrados nos repositórios: ${missing[*]}"
    _msg "O nome pode ter mudado no Arch. Confira com 'pacman -Ss nvidia' e ajuste o script/flags."
    return 14
  fi
  _msg "pacotes dos repositórios conferidos com pacman -Si"
  return 0
}

arch_ensure_paru() {
  if _have paru; then _msg "paru já instalado: $(command -v paru)"; return 0; fi
  _step "Instalando o paru (compilando da fonte, pacote AUR 'paru')"
  _msg "Necessário para os pacotes do AUR (ramo legado 580xx). Compilar leva alguns minutos."
  local d=${TMPDIR:-/tmp}/nvsh-paru.$$
  local -a deps=(base-devel git)
  _have cargo || deps+=(rust)
  run_root pacman -S --needed "${deps[@]}" || return 1
  run rm -rf "$d"
  run git clone https://aur.archlinux.org/paru.git "$d" || return 1
  if (( OPT_DRY )); then
    printf '  [dry-run] (em %s) makepkg -si\n' "$d"
  else
    _msg "Quando o makepkg pedir, confirme as dependências e a instalação."
    ( cd "$d" && run makepkg -si ) || { rm -rf "$d"; return 1; }
  fi
  run rm -rf "$d"
  if (( ! OPT_DRY )); then hash -r; _have paru || return 1; fi
  return 0
}

arch_install() {
  _msg "O Arch não suporta upgrade parcial: o driver vai junto de uma atualização completa (pacman -Syu)."
  run_root pacman -Syu || { _err "pacman -Syu falhou"; return 15; }
  arch_verify_repo || return $?
  if (( ${#PKG_AUR[@]} )); then
    arch_ensure_paru || {
      _err "não consegui instalar o paru."
      _msg "Manual: sudo pacman -S --needed base-devel git rust && git clone https://aur.archlinux.org/paru.git"
      _msg "        && cd paru && makepkg -si   (depois rode este script de novo)"
      return 15
    }
    _msg "Pacotes do AUR: ${PKG_AUR[*]}. O paru vai mostrar o PKGBUILD: dê uma olhada antes de aceitar."
    run paru -S --needed "${PKG_AUR[@]}" "${PKG_REPO[@]}" || {
      _err "paru falhou."
      _msg "Manual: paru -S --needed ${PKG_AUR[*]} ${PKG_REPO[*]}"
      _msg "Se o DKMS não compilou: 'dkms status' e o log em /var/lib/dkms/nvidia/*/build/make.log"
      return 15
    }
  else
    run_root pacman -S --needed "${PKG_REPO[@]}" || return 15
  fi
  return 0
}

# ---------- Fedora / Debian / Ubuntu (NÃO VALIDADOS: use --dry-run) -------------
fedora_install() {
  local rel p; local -a bad=()
  rel=$(rpm -E %fedora 2>/dev/null) || rel=$NV_DISTRO_VERSION
  if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    run_root dnf install \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${rel}.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${rel}.noarch.rpm" || return 15
  fi
  run_root dnf upgrade --refresh || return 15
  if (( ! OPT_DRY )); then
    for p in "${PKG_REPO[@]}"; do dnf -q list --available "$p" >/dev/null 2>&1 || bad+=("$p"); done
    if (( ${#bad[@]} )); then _err "pacotes não encontrados no dnf: ${bad[*]}"; return 14; fi
  fi
  run_root dnf install "${PKG_REPO[@]}" || return 15
  _msg "O akmod compila o módulo no primeiro boot/instalação; confirme antes de reiniciar:"
  run_root akmods --force || return 15
  run modinfo -F version nvidia || true
  return 0
}

apt_install() {
  local p; local -a bad=()
  run_root apt update || return 15
  if (( ! OPT_DRY )); then
    for p in "${PKG_REPO[@]}"; do apt-cache show "$p" >/dev/null 2>&1 || bad+=("$p"); done
    if (( ${#bad[@]} )); then _err "pacotes não encontrados no apt: ${bad[*]}"; return 14; fi
  fi
  if [[ $NV_FAMILY == debian ]]; then
    run_root apt install "linux-headers-$(dpkg --print-architecture 2>/dev/null || echo amd64)" || return 15
  fi
  run_root apt install "${PKG_REPO[@]}" || return 15
  return 0
}

# ---------- PRIME (offload, Wayland) -------------------------------------------
prime_setup() {
  if (( ! PLAN_PRIME )); then _msg "PRIME: não aplicável ou desativado"; return 0; fi
  if [[ $NV_FAMILY == arch ]]; then
    if ! run_root pacman -S --needed nvidia-prime; then
      _msg "não consegui instalar o nvidia-prime; use as variáveis manuais abaixo."
    fi
  fi
  echo "  PRIME render offload: a iGPU desenha o desktop; a NVIDIA só roda o que você mandar."
  if [[ $NV_FAMILY == arch ]]; then
    echo "    prime-run <programa>                 (pacote nvidia-prime; define as variáveis abaixo)"
    echo "    Steam, opções de inicialização:      prime-run %command%"
  fi
  cat <<'EOF'
    Manual (qualquer distro):
      __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia <programa>
    Conferir depois de reiniciar (com as variáveis acima):   glxinfo -B | grep -i renderer     e     nvidia-smi
EOF
  return 0
}

# ---------- orquestração -------------------------------------------------------
inst_print_plan() {
  echo "== Plano =="
  _row "Modo" "$( ((OPT_DRY)) && echo 'SIMULAÇÃO (--dry-run): nada será alterado' || echo 'REAL')"
  _row "Sistema" "${NV_DISTRO_PRETTY:-?} (família $NV_FAMILY, $NV_PKG_MGR)"
  _row "GPU" "$NV_NVIDIA_NAME [$NV_NVIDIA_ID]"
  _row "Driver escolhido" "$PLAN_FLAVOR"
  _row "Motivo" "$PLAN_WHY"
  if (( OPT_RECONFIGURE )); then
    _row "Pacotes" "(pulado: --reconfigure)"
  else
    _row "Pacotes (repo)" "${PKG_REPO[*]:--}"
    [[ $NV_FAMILY == arch ]] && _row "Pacotes (AUR via paru)" "${PKG_AUR[*]:--}"
    [[ $NV_FAMILY == arch ]] && _row "Módulo do kernel" "$( ((PLAN_DKMS)) && echo "DKMS (kernel: ${NV_KERNEL_PKGBASE:-?})" || echo 'pré-compilado (kernel linux)')"
  fi
  _row "Parâmetros do kernel" "${NV_KPARAMS[*]}"
  _row "Aplicados via" "$( [[ $INST_BL == none ]] && echo "$NV_MODPROBE_CONF (${INST_BL_WHY:-sem bootloader suportado})" || echo "bootloader $INST_BL" )"
  _row "PRIME (offload)" "$( ((PLAN_PRIME)) && echo 'sim (notebook híbrido, Wayland)' || echo 'não')"
  _row "Snapshot" "$( ((OPT_SNAPSHOT)) && { snap_available && echo 'snapper (root), par pre/post' || echo 'snapper indisponível: pedirei confirmação'; } || echo 'desativado')"
  if (( ${#PLAN_NOTES[@]} )); then
    echo "== Observações do plano =="
    printf '  - %s\n' "${PLAN_NOTES[@]}"
  fi
  _print_notes
}

inst_summary() {
  _step "Concluído"
  if (( OPT_DRY )); then
    _msg "Simulação terminou: nada foi alterado. Rode sem --dry-run para aplicar."
    return 0
  fi
  _msg "Reinicie para carregar o módulo. Depois confira:"
  _msg "  ./nvidia.sh                   (Estado: ATIVO)    e    nvidia-smi"
  [[ -n $SNAP_PRE ]] && _msg "Snapshot pré: #$SNAP_PRE  (snapper -c root status $SNAP_PRE..0)"
  _msg "Backups dos arquivos editados: *.nvsh-bak-* ao lado de cada um."
}

inst_execute() {
  local rc
  SNAP_PRE=""
  if (( ! OPT_DRY )); then
    _step "Credenciais"; run sudo -v || return 13
  fi
  _step "Snapshot (antes)";                snap_pre || return $?
  if (( ! OPT_RECONFIGURE )); then
    _step "Pacotes"
    case $NV_FAMILY in
      arch)          arch_install ;;
      fedora)        fedora_install ;;
      debian|ubuntu) apt_install ;;
    esac; rc=$?
    (( rc == 0 )) || { inst_fail; return "$rc"; }
  fi
  _step "Parâmetros do kernel (modeset)";  kparams_apply; rc=$?; (( rc == 0 )) || { inst_fail; return "$rc"; }
  _step "Initramfs";                       regen_initramfs; rc=$?; (( rc == 0 )) || { inst_fail; return "$rc"; }
  _step "PRIME";                           prime_setup
  _step "Snapshot (depois)";               snap_post
  inst_summary
  return 0
}

inst_fail() {
  echo
  _err "um passo falhou; nada foi desfeito automaticamente."
  [[ -n $SNAP_PRE && $SNAP_PRE != dry ]] && _msg "Snapshot pré: #$SNAP_PRE (snapper -c root status $SNAP_PRE..0 mostra o que mudou)."
  _msg "Arquivos editados têm backup *.nvsh-bak-* ao lado. O script é idempotente: corrija e rode de novo."
}

inst_run() {   # assume inst_parse + nv_detect_all já executados
  inst_gate || return $?
  PLAN_NOTES=(); PKG_REPO=(); PKG_AUR=(); PLAN_DKMS=0; PLAN_PRIME=0
  plan_flavor || { _err "$PLAN_WHY"; return 14; }
  case $NV_FAMILY in
    arch)          arch_plan   || return $? ;;
    fedora)        fedora_plan ;;
    debian|ubuntu) apt_plan    || return $? ;;
  esac
  inst_choose_bl || return $?
  if (( NV_HYBRID )) && [[ $NV_HYBRID_KIND == laptop ]] && (( OPT_PRIME )); then PLAN_PRIME=1; fi
  inst_print_plan
  if (( ! OPT_DRY )); then
    echo
    _confirm "Executar este plano?" || { _msg "cancelado."; return 16; }
  fi
  inst_execute
}

inst_main() {
  local rc
  inst_parse "$@"; rc=$?
  (( rc == 100 )) && return 0
  (( rc == 0 )) || return "$rc"
  nv_detect_all
  inst_run
}

nv_usage() {
  cat <<'EOF'
nvidia.sh — driver NVIDIA no Linux

  ./nvidia.sh                     etapa 1: relatório de detecção (somente leitura)
  ./nvidia.sh --env               imprime NV_CHAVE=valor
  ./nvidia.sh install [opções]    etapa 2: instalação (Arch real; demais só --dry-run)
  ./nvidia.sh --help              esta ajuda

Opções do install:
  -n, --dry-run        mostra o plano e os comandos, sem alterar nada
      --open           força os módulos open (Turing ou mais nova)
      --proprietary    força os módulos proprietários (Turing a Hopper)
                       Maxwell/Pascal/Volta usam sempre o ramo legado 580xx
      --dkms           usa pacotes DKMS mesmo no kernel "linux" (Arch)
      --bootloader=X   auto (padrão) | grub | limine | none (usa /etc/modprobe.d)
      --no-prime       não configura PRIME (notebooks híbridos)
      --no-snapshot    não cria snapshot do snapper antes/depois
      --reconfigure    só kernel/modeset, initramfs e PRIME (pula pacotes)
      --ignore-managed ignora a recusa em distros com gerenciador próprio (chwd, mhwd...)
      --allow-untested permite execução real em Fedora/Ubuntu/Debian (ainda não validados)
  -y, --yes            responde "sim" às perguntas do script (pacman/paru continuam perguntando)

Por ora só Wayland; X11 (PRIME sync, xorg.conf) está nos planos. Secure Boot não é tratado.
Saída: 0 ok | 2 uso | 10 sem NVIDIA | 11 ambiente | 12 distro | 13 recusado
       14 não consigo decidir | 15 passo falhou | 16 cancelado
EOF
}

nv_main() {
  case ${1:-} in
    -h|--help) nv_usage; return 0 ;;
    install)   shift; inst_main "$@"; return $? ;;
    ""|--env)  ;;
    *) echo "opção desconhecida: $1" >&2; nv_usage >&2; return 2 ;;
  esac
  nv_detect_all
  if [[ ${1:-} == --env ]]; then nv_env; else nv_report; fi
  (( NV_ENV_OK ))          || return 11
  [[ -n $NV_FAMILY ]]      || return 12
  (( NV_NVIDIA_PRESENT ))  || return 10
  return 0
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  nv_main "$@"
  exit $?
fi
