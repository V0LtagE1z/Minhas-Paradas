#!/usr/bin/env bash
# Teste do nvidia.sh: carrega as funções com `source` e usa os ganchos NVSH_* numa pasta temporária. Nada é instalado nem lido de /boot:
# só --dry-run e arquivos de mentira. Cobre o que edita o bootloader (a mesclagem dos parâmetros, o GRUB e o Limine) e as recusas do plano.
# Uso: bash tests/nvidia.test.sh
# shellcheck disable=SC2034  # as variáveis NV_*, OPT_* e SNAP_PRE são lidas pelas funções do nvidia.sh carregado com source
here=$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")
repo=$here/..
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
bad() { echo "FALHOU: $1"; fail=1; }
has() { grep -qF -- "$1" <<<"$out" || bad "faltou \"$1\" na saída"; }
hasnt() { ! grep -qF -- "$1" <<<"$out" || bad "não devia ter \"$1\" na saída"; }

# O shebang tem que ser a linha 1: o kernel só o lê ali. Rodar pelo bash esconde o erro (o bash executa o arquivo mesmo assim), então confere a linha.
[[ $(head -n1 "$repo/nvidia.sh") == '#!/usr/bin/env bash' ]] || bad "a linha 1 do nvidia.sh devia ser o shebang"
# O README manda rodar ./nvidia.sh: sem o bit de execução (modo 644 no git) o clone dá "Permissão negada".
[[ -x $repo/nvidia.sh ]] || bad "o nvidia.sh devia ser executável (git update-index --chmod=+x nvidia.sh)"

export NVSH_ROOT=$tmp/root
mkdir -p "$NVSH_ROOT/etc/default"
printf '[options]\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' > "$NVSH_ROOT/etc/pacman.conf"
# shellcheck source=/dev/null
source "$repo/nvidia.sh"

# Mesclagem dos parâmetros: tira o antigo (com _ ou valor errado), põe o certo no fim, mantém o resto.
[[ $(cmdline_merge "") == "nvidia-drm.modeset=1 nvidia-drm.fbdev=1" ]] || bad "cmdline_merge de linha vazia"
[[ $(cmdline_merge "quiet nvidia_drm.modeset=0 splash") == "quiet splash nvidia-drm.modeset=1 nvidia-drm.fbdev=1" ]] || bad "cmdline_merge devia trocar o modeset=0 antigo"
_cmdline_ok "quiet nvidia_drm.modeset=1 nvidia-drm.fbdev=1" || bad "_cmdline_ok devia aceitar o _ no lugar do -"
! _cmdline_ok "nvidia-drm.modeset=0 nvidia-drm.fbdev=1" || bad "_cmdline_ok não devia aceitar modeset=0"

# GRUB (--dry-run): aspas duplas com comentário, aspas simples e linha ausente; o diff mostra o que mudaria e nada é escrito.
OPT_DRY=1; OPT_YES=0; NV_FAMILY=arch; NV_KPARAMS=(nvidia-drm.modeset=1 nvidia-drm.fbdev=1)
grub=$NVSH_ROOT/etc/default/grub
grub_case() {  # conteúdo do arquivo — roda bl_grub e guarda a saída
  printf '%s\n' "$1" > "$grub"; out=$(bl_grub 2>&1); rc=$?
  [[ $rc == 0 ]] || bad "bl_grub saiu com $rc"
  [[ $(cat "$grub") == "$1" ]] || bad "o --dry-run alterou o arquivo do GRUB"
}
grub_case 'GRUB_CMDLINE_LINUX_DEFAULT="quiet nvidia_drm.modeset=0 splash" # meu comentario'
has '+GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nvidia-drm.modeset=1 nvidia-drm.fbdev=1" # meu comentario'; has 'grub-mkconfig'
grub_case "GRUB_CMDLINE_LINUX_DEFAULT='quiet splash'"
has '+GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nvidia-drm.modeset=1 nvidia-drm.fbdev=1"'
grub_case 'GRUB_TIMEOUT=5'
has '+GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"'
grub_case 'GRUB_CMDLINE_LINUX_DEFAULT="quiet nvidia-drm.modeset=1 nvidia-drm.fbdev=1"'
has 'nada a alterar'; hasnt 'grub-mkconfig'

# Limine: sintaxe nova (cmdline:) e antiga (CMDLINE=), todas as entradas; a que já tem os parâmetros não conta como mudada.
printf '/Arch\n    protocol: linux\n    cmdline: root=UUID=abc rw quiet\n/Fallback\n    cmdline: root=UUID=abc rw nvidia-drm.modeset=1 nvidia-drm.fbdev=1\n' > "$tmp/lim.conf"
_limine_rewrite "$tmp/lim.conf" "$tmp/lim.out"
[[ $LIM_SEEN == 2 && $LIM_CHANGED == 1 ]] || bad "limine: esperava 2 linhas cmdline e 1 mudada (viu $LIM_SEEN e $LIM_CHANGED)"
grep -qxF '    cmdline: root=UUID=abc rw quiet nvidia-drm.modeset=1 nvidia-drm.fbdev=1' "$tmp/lim.out" || bad "limine: a linha cmdline não ganhou os parâmetros"
printf 'CMDLINE=root=UUID=abc rw\n' > "$tmp/lim.cfg"; _limine_rewrite "$tmp/lim.cfg" "$tmp/lim.out"
grep -qxF 'CMDLINE=root=UUID=abc rw nvidia-drm.modeset=1 nvidia-drm.fbdev=1' "$tmp/lim.out" || bad "limine: sintaxe antiga CMDLINE= não foi reescrita"

# Arch: o módulo proprietário saiu dos repositórios no driver 590 (nvidia e nvidia-dkms viraram nvidia-open e nvidia-open-dkms).
# --proprietary tem que ser recusado no plano (saída 14), antes de qualquer pacman -Syu; --open segue normal.
NV_NVIDIA_ARCH=ampere; NV_NVIDIA_ID=0x2520; NV_KERNEL_PKGBASE=linux
arch_flow() {  # opções do install — escolhe o driver e monta o plano do Arch
  PLAN_NOTES=(); inst_parse "$@"; plan_flavor || return 14; arch_plan; }
out=$(arch_flow --dry-run --proprietary 2>&1); rc=$?
[[ $rc == 14 ]] || bad "--proprietary no Arch devia sair com 14 (saiu com $rc)"; has 'nvidia-open'
arch_flow --dry-run --open; [[ $? == 0 && ${PKG_REPO[*]} == "nvidia-open nvidia-utils nvidia-settings lib32-nvidia-utils" ]] || bad "--open no Arch devia planejar nvidia-open: ${PKG_REPO[*]}"
arch_flow --dry-run; [[ ${PKG_REPO[0]} == nvidia-open ]] || bad "o automático no Arch devia planejar nvidia-open"
NV_NVIDIA_ARCH=pascal; NV_NVIDIA_ID=0x1c8d
arch_flow --dry-run --proprietary; [[ $PLAN_FLAVOR == legacy580 && ${PKG_AUR[0]} == nvidia-580xx-dkms ]] || bad "Pascal com --proprietary devia ir para o legado 580xx"

# O mesmo, de ponta a ponta pelo script: sai com 14 e nem chega ao pacman -Syu.
mkdir -p "$tmp/pci/0000:01:00.0" "$tmp/dmi"
printf '0x030000\n' > "$tmp/pci/0000:01:00.0/class"; printf '0x10de\n' > "$tmp/pci/0000:01:00.0/vendor"; printf '0x2520\n' > "$tmp/pci/0000:01:00.0/device"
printf 'ID=arch\nPRETTY_NAME="Arch Linux"\n' > "$tmp/os-release"
out=$(env NVSH_SKIP_ENV_CHECK=1 NVSH_OS_RELEASE="$tmp/os-release" NVSH_PCI_ROOT="$tmp/pci" NVSH_DMI_ROOT="$tmp/dmi" \
      bash "$repo/nvidia.sh" install --dry-run --proprietary 2>&1); rc=$?
[[ $rc == 14 ]] || bad "nvidia.sh install --proprietary (Arch) devia sair com 14 (saiu com $rc)"; hasnt 'pacman -Syu'

# Recusar na decisão é uma coisa; cancelar é outra: o exit 16 (você disse não) não pode aparecer como falha.
SNAP_PRE=""; out=$(inst_fail 16 2>&1); hasnt 'falhou'; has 'Cancelado'
out=$(inst_fail 15 2>&1); has 'um passo falhou'

((fail)) && { echo "Há testes falhando."; exit 1; }
echo "OK: tests/nvidia.test.sh"
