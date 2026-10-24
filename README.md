# Só Quero Facilitar Ae

### Pumba Lá Pumba

Meus dotfiles de terminal em um script que monta tudo em uma máquina nova, seja uma distro Linux ou o Termux.

## Conteúdo

| Caminho | Para que serve |
| ------- | -------------- |
| `setup.sh` | O script principal: cria o usuário `gustavo`, instala pacotes, locales, oh-my-zsh, powerlevel10k, plugins, Kitty e fontes e aplica os dotfiles. Funciona em distros de desktop, WSL, proot e Termux (veja "Gerenciadores e ambientes") |
| `nvidia.sh` | Detecta a GPU NVIDIA e instala o driver (open, proprietário ou legado), com modeset, initramfs e PRIME. É independente do `setup.sh` (veja "nvidia.sh") |
| `oxwm-setup.sh` e `config.lua` | Instalam a configuração do OXWM (gerenciador de janelas X11), migrada do Caelestia/Hyprland (veja "OXWM") |
| `OXWM/` | Só uma nota (`MIMLeia.md`) sobre mover o `config.lua` para dentro dela |
| `Distro Normal/` | Dotfiles para distros Linux de desktop |
| `Distro Proot/` | Dotfiles para distros rodando em proot (proot-distro) |
| `Termux/` | Dotfiles do Termux e os scripts de backup e restauração (veja "Backup do Termux") |
| `Kitty/` | Configuração do terminal Kitty e os temas claro/escuro (só distros de desktop) |
| `Luna E Terra.png` | Papel de parede 1920x1080. O `setup.sh` não o aplica; o `config.lua` do OXWM o espera em `~/Pictures/Wallpapers/` |

Arquivos de cada pasta:

| Arquivo | Onde existe | O que é |
| ------- | ----------- | ------- |
| `.zshrc` | `Distro Normal/`, `Distro Proot/`, `Termux/` | Configuração do zsh: `fastfetch` ao abrir, oh-my-zsh (plugins `git`, `zsh-autosuggestions`, `fast-syntax-highlighting`, `zsh-history-substring-search`, `fzf`, `history`, `dirhistory`), `zoxide` no lugar do `cd`, `LANG=pt_BR.UTF-8` e `LC_MESSAGES=en_US.UTF-8`. Autosugestão aceita com Ctrl+Espaço ou Ctrl+F, e as setas ↑↓ buscam no histórico pelo trecho digitado. No proot, quando o root abre um shell, ele pergunta se quer atualizar o sistema e repassa a sessão para o `gustavo` |
| `.p10k.zsh` | `Distro Normal/`, `Distro Proot/`, `Termux/` | Configuração do prompt powerlevel10k |
| `.p10k-ascii.zsh` | `Distro Normal/` | Versão só ASCII do prompt, usada quando `TERM=linux` (console sem fontes especiais) |
| `.zsh_history` | `Termux/` | Histórico de comandos do Termux guardado no repo. O `setup.sh` **não** o aplica (só copia `.zshrc` e `.p10k.zsh`) |
| `Backup_Termux.sh`, `Backup-Restore.sh` | `Termux/` | Backup e restauração do Termux inteiro (veja "Backup do Termux") |
| `kitty.conf` | `Kitty/` | Fonte (MesloLGS NF), opacidade 0.85 e tamanho da janela do Kitty. É o único arquivo do Kitty que o `setup.sh` copia |
| `dark-theme.auto.conf`, `no-preference-theme.auto.conf` | `Kitty/` | Cores do Kitty para o tema escuro do sistema e para quando não há preferência. O Kitty (0.38 ou mais novo) carrega arquivos com esses nomes sozinho, mas o `setup.sh` **não** os copia: ponha em `~/.config/kitty/` à mão |

## Como usar

Em uma máquina nova, baixe e rode o script:

```
git clone https://github.com/V0LtagE1z/Minhas-Paradas.git
cd Minhas-Paradas
bash setup.sh
```

Como rodar depende do ambiente:

| Ambiente | Como rodar | O que acontece |
| -------- | ---------- | -------------- |
| Distro de desktop | Como root (`su -`) ou como usuário com `sudo` | Cria o usuário `gustavo` e aplica todo o setup nele; o root também passa a usar zsh (veja abaixo) |
| Termux | Como usuário normal | Aplica o setup direto no seu usuário |
| Alpine / postmarketOS (`apk`) | `sh setup.sh`, como root ou com `doas`/`sudo` (o bash é instalado sozinho) | Igual às distros de desktop, com as diferenças da seção "Alpine e postmarketOS" |
| WSL | Como root ou com `sudo`, dentro da distro (o script detecta o ambiente) | Igual às distros de desktop, sem bootloader, temas, Kitty e fonte, e com login automático no `gustavo` (veja a seção do WSL) |
| Distro em proot (qualquer uma) | Como root (o script detecta o ambiente) | Cria o usuário `gustavo` sem sudo e aplica o setup nele e no root (veja abaixo) |

O script precisa estar salvo em arquivo (`git clone` e `bash setup.sh`). Rodar via `curl ... | bash` não funciona nas distros, porque a segunda fase reexecuta o próprio arquivo.

Para ver tudo o que seria feito sem alterar nada, use `bash setup.sh --dry-run`.

## Gerenciadores e ambientes

| Gerenciador | Distros | Observações |
| ----------- | ------- | ----------- |
| `pkg` | Termux | Sem usuário novo; root é recusado de propósito |
| `apt` | Debian, Ubuntu e derivadas | O `fastfetch` não existe no Debian 12 nem no Ubuntu 22.04 |
| `dnf` | Fedora | Locales via `glibc-langpack-en` e `glibc-langpack-pt` |
| `zypper` | openSUSE (Tumbleweed testado) | O `micro` se chama `micro-editor` lá (o script troca o nome). Os códigos de saída 102, 103 e 106 do `zypper` (reinício recomendado, repositório ignorado) contam como sucesso; o 104 (pacote não encontrado) é falha. Locales via `glibc-locale` |
| `pacman` | Arch, CachyOS, EndeavourOS e derivadas, Arch Linux ARM | `paru` instalado pelo script; mirrors, `pacman.conf` e repositórios do CachyOS (veja "O que o script faz") |
| `apk` | Alpine e postmarketOS (musl) | Veja "Alpine e postmarketOS (apk)" |

O `emerge` (Gentoo) não é suportado. Os ambientes que mudam o comportamento do script são o Termux, o proot (qualquer distro), o WSL e a distro de desktop comum, descritos nas seções abaixo.

### Opções e variáveis

Opções de linha de comando (`bash setup.sh --help` lista todas):

| Opção | O que faz |
| ----- | --------- |
| `--dry-run`, `-n` | Mostra o que seria feito sem alterar nada |
| `--temas-minecraft` / `--sem-temas-minecraft` | Instala os temas Minecraft sem perguntar / não instala e não pergunta |
| `--reverter-temas` | Desfaz os temas Minecraft e sai |
| `--cachyos-repo` / `--sem-cachyos-repo` | Força / desliga os repositórios do CachyOS |
| `--kernel-cachyos` / `--sem-kernel-cachyos` | Fedora: instala o kernel do CachyOS (COPR) sem perguntar / não instala e não pergunta |
| `--help`, `-h` | Mostra a ajuda |

Variáveis de ambiente (valor padrão em negrito, quando existe):

| Variável | Para que serve |
| -------- | -------------- |
| `NEW_USER` (**gustavo**) | Nome do usuário criado |
| `REPO_URL`, `REPO_DIR` | Repositório dos dotfiles e onde ele é clonado (**`~/Minhas-Paradas`**) |
| `FORCE_PROOT=1`, `FORCE_ALARM_PROOT=1` | Forçam o modo proot (o segundo também marca Arch Linux ARM) |
| `FORCE_WSL=1` ou `0` | Força o modo WSL ou desliga a detecção dele |
| `WSL_SET_DEFAULT_USER` (**1**) | `0` não mexe no `/etc/wsl.conf` |
| `WSL_INSTALL_GUI=1` | No WSL, instala também Kitty e a fonte no Linux |
| `SKIP_LOCALES=1` | Não gera locales nem grava o locale do sistema |
| `SYS_LANG` (**pt_BR.UTF-8**), `SYS_LC_MESSAGES` (**en_US.UTF-8**) | Valores gravados no locale do sistema |
| `SKIP_MIRRORS=1`, `FORCE_MIRRORS=1` | Pula / refaz o ranking de mirrors no Arch puro |
| `SKIP_PACMAN_REPOS=1` | Não mexe em `core`, `extra` e `multilib` |
| `PACMAN_MIRRORLIST_INCLUDE` (**/etc/pacman.d/mirrorlist**) | `Include` usado nas seções do `pacman.conf` |
| `CACHYOS_REPO` (**auto**), `CACHYOS_REPO_URL`, `CACHYOS_SEM_SNAPSHOT=1` | Repositórios do CachyOS: `auto`, `1` ou `0`; o instalador; seguir sem snapshot |
| `CACHYOS_KERNEL` (**ask**), `CACHYOS_KERNEL_VARIANT` (**kernel-cachyos**) | Kernel do CachyOS no Fedora: `ask`, `1` ou `0`; a variante (`kernel-cachyos`, `-lto`, `-lts`, `-lts-lto`, `-rt` ou `-server`) |
| `MC_THEMES` (**ask**) | `1`, `0` ou `ask`, o mesmo que as opções dos temas |
| `SKIP_APK_REPOS=1`, `FORCE_APK=1`, `FORCE_LIBC`, `FORCE_INIT` | Alpine: não habilitar o `community`; aceitar `apk` em Wolfi/Chimera; trocar a detecção de libc e de init |

Outras variáveis (`OS_RELEASE_FILE`, `PACMAN_CONF`, `ROOT_PREFIX`, `KERNEL_RELEASE`, `APK_REPOS_FILE`...) só servem para testar o script contra arquivos de exemplo.

## Usuário gustavo (distros de desktop)

Nas distros de desktop o script trabalha em duas fases:

1. **Como root:** instala os pacotes do sistema (incluindo `sudo`, se faltar) e cria o usuário:
   - nome `gustavo`, home `/home/gustavo`, shell zsh (registrado em `/etc/shells` se preciso);
   - o shell do **root** também é trocado para zsh (`usermod -s`);
   - grupos `wheel`, `audio` e `video` (o `wheel` é criado nas distros que não o têm, como o Debian);
   - sudo liberado por `/etc/sudoers.d/10-gustavo`, validado com `visudo` antes de instalar (a senha continua sendo exigida);
   - `passwd gustavo` para você escolher a senha. Se a senha já estiver definida, ela é mantida.
2. **Como `gustavo`:** o script reexecuta a si mesmo e faz o setup tradicional (paru, oh-my-zsh, powerlevel10k, plugins, dotfiles, Kitty, `EDITOR` e fontes), tudo dentro de `/home/gustavo`.

No Arch/CachyOS, o `gustavo` recebe sudo **sem senha apenas durante a instalação do `paru`** (o `makepkg` precisa disso). O arquivo temporário `/etc/sudoers.d/99-setup-tmp` é removido assim que a fase termina, mesmo se ela falhar.

Os dotfiles são aplicados só ao `gustavo`. O root passa a usar zsh, mas sem `~/.zshrc`, então o zsh costuma mostrar o assistente de configuração inicial no primeiro login dele.

Se o usuário já existir, o script só ajusta grupos e shell. Para usar outro nome: `NEW_USER=nome bash setup.sh`.

## Alpine e postmarketOS (apk)

`apk`, OpenRC e musl são três coisas independentes, e o script detecta cada uma em vez de tratar tudo como "modo Alpine":

| Eixo | Como detecta | Valores |
| ---- | ------------ | ------- |
| Gerenciador de pacotes | `apk` no `PATH` (depois de `apt-get`, `zypper`, `dnf` e `pacman`) | `apk` |
| Init | `/run/systemd/system`, `/run/openrc` ou `rc-service`, `dinitctl`; no proot é sempre "nenhum" | `systemd`, `openrc`, `dinit`, `none` |
| libc | `ldd --version` (musl imprime "musl libc"); sem `ldd`, o carregador `ld-musl-*` ou `ld-linux-*` | `musl`, `glibc` |

Com `apk` o script só segue com **musl e sem dinit**. Recusa o Wolfi (glibc, sem init, feito para container) e o Chimera (dinit, userland BSD sem GNU coreutils); `apk` com glibc ou com dinit também. `FORCE_APK=1` ignora a recusa, sem garantia de que funcione. Uma distro com `apk` que não seja Alpine nem postmarketOS passa, com aviso. O log mostra o resultado (`Sistema apk: init=openrc, libc=musl, distro=alpine`).

O que muda no Alpine, em relação às outras distros de desktop:

- **Sem bash.** O Alpine só traz o ash do busybox. O começo do `setup.sh` é POSIX puro: se o bash não existir, instala com `apk add bash` (como root, ou com `doas`/`sudo`) e se reexecuta, por isso rode com `sh setup.sh`. Com `--dry-run` e `--help` nada é instalado: o script só diz para instalar o bash.
- **`shadow` e `sudo`.** O busybox não tem `useradd`, `usermod` nem `groupadd`: o pacote `shadow` entra na lista de pacotes. O `sudo` não vem instalado e é instalado antes de configurar o `gustavo`. Se você rodar como usuário comum com `doas` e sem `sudo`, o `doas` reexecuta o script como root.
- **Repositório community.** `fastfetch`, `zoxide`, `micro`, `fzf` e `kitty` ficam no `community`. O script garante um `community` ativo em `/etc/apk/repositories`: descomenta o da **mesma release** do `main` ativo, ou acrescenta o irmão do `main`, e nunca descomenta o do `edge` (misturar `edge` com release estável quebra o sistema). A primeira cópia fica em `repositories.setup.bak`. `SKIP_APK_REPOS=1` pula a etapa.
- **Cache do apk.** Se não há diretório de cache (container, proot), os pacotes são instalados com `apk add --no-cache`; senão o script roda `apk update` antes.
- **Locale.** O musl não tem `locale-gen`, e o OpenRC não lê o `/etc/locale.conf` (isso é do systemd). O script instala o `musl-locales` (comando `locale` e traduções de mensagens) e grava `LANG=pt_BR.UTF-8` e `LC_MESSAGES=en_US.UTF-8` em `/etc/profile.d/10-setup-locale.sh`, que o login executa. Sem os arquivos de locale compilados, o musl trata `pt_BR.UTF-8` como `C.UTF-8`: UTF-8 funciona, só não há ordenação nem formatação por idioma. `SKIP_LOCALES=1` pula a etapa.
- **Temas Minecraft pulados.** O Alpine usa `mkinitfs`, sem os ganchos de `mkinitcpio`, `initramfs-tools` ou `dracut` que o tema do Plymouth usa; `--temas-minecraft` é ignorado com um aviso.
- **Não se aplicam:** mirrors do Arch, `pacman.conf`, repositórios do CachyOS, `paru` e snapshot (são do `pacman`).
- **Serviços.** O `setup.sh` não liga nem desliga serviços, então não há `rc-update`/`rc-service` para tratar.
- **Proot.** O `proot-distro` do Alpine cai no modo proot (sem init, sem `sudo`); o `.zshrc` do root já reconhecia o Alpine e atualiza o sistema com `apk update` e `apk upgrade`.
- **`nvidia.sh`.** O driver proprietário da NVIDIA é só glibc, então o `nvidia.sh` recusa o Alpine e o postmarketOS (saída 12); no musl só o nouveau funciona.

No `--dry-run`, com o `apk` instalado, o script roda `apk add --simulate` em cada pacote e avisa os que não resolvem no índice local. É só informativo: a simulação não habilita o community e talvez não rode sem root.

**Validação:** o suporte ao apk foi testado só com `--dry-run`, com um `apk` falso e com os applets do busybox no lugar dos GNU (Alpine com e sem cache do apk, postmarketOS, proot, `doas`, as recusas, o bootstrap do bash no ash e a edição do `repositories` em vários formatos). Não foi testado num Alpine ou postmarketOS de verdade; teste lá antes de confiar, principalmente `useradd` com o `shadow`, a senha do `gustavo` e o locale no login.

## Simulação (--dry-run)

`bash setup.sh --dry-run` (ou `-n`) mostra o que o script faria sem alterar nada, nem precisa de root. Linhas `[dry]` são comandos que seriam executados e linhas `[sim]` são mensagens simuladas. Leituras (checar se um grupo, usuário ou repositório já existe) são feitas de verdade, então a saída reflete o estado atual da máquina. Como o repo não é clonado na simulação, os arquivos de dotfiles aparecem como "copiaria" em vez de comparados com os existentes.

## Distros em proot (proot-distro)

O script detecta sozinho quando está dentro de um proot, em qualquer distro com `apt`, `dnf`, `zypper`, `pacman` ou `apk` (Debian, Ubuntu, Fedora, openSUSE, Arch Linux ARM, Alpine e afins). Os critérios são:

1. O nome do kernel traz `proot`. O proot-distro devolve algo como `6.17.0-PRoot-Distro` em `uname -r`, o mesmo nome que aparece no `fastfetch`.
2. Só no Arch Linux ARM: `ID=archarm` em `/etc/os-release` (ou `/etc/arch-release` em CPU ARM) e processo rastreado por ptrace.

Se a detecção falhar, force com `FORCE_PROOT=1 bash setup.sh`. Rode como root (o `proot-distro login <distro>` já entra como root). Nesse modo o script:

1. Se a distro usa `pacman` (Arch Linux ARM e afins): ajusta o `/etc/pacman.conf` (com backup em `pacman.conf.bak`), comentando `CheckSpace` e `DownloadUser` e ativando a opção de desligar o sandbox do pacman (`DisableSandbox` no pacman 7.0; `DisableSandboxFilesystem` e `DisableSandboxSyscalls` no 7.1+). Inicializa o chaveiro (`archlinuxarm` no ALARM, `archlinux` nas demais), roda `pacman -Syu` uma vez e reaplica o ajuste, porque o pacman novo pode trazer outras opções.
2. Instala `zsh git curl fastfetch micro fzf zoxide` (sem `sudo`, já que está como root) e gera os locales `pt_BR.UTF-8` e `en_US.UTF-8`, usados pelo `.zshrc`, se a distro tiver `locale-gen`.
3. Cria o usuário `gustavo` (home `/home/gustavo`, shell zsh, grupos `audio` e `video`) e troca o shell do root para zsh. Você escolhe a senha com `passwd gustavo`; se ela já estiver definida, é mantida.
4. **Não** dá sudo ao `gustavo`: o setuid não funciona no proot, então o `sudo` de usuário comum costuma falhar lá. A administração fica com o root.
5. Aplica os dotfiles de `Distro Proot/` no root e, via `su -l gustavo`, no `gustavo` (oh-my-zsh, powerlevel10k, plugins, `EDITOR`).
6. **Não** instala `paru`, Kitty, `fontconfig` nem fontes. A fonte é a do próprio Termux.

Depois do setup, o `.zshrc` do root pergunta se você quer atualizar o sistema e passa a sessão para o `gustavo` com `su - gustavo`. Se a troca falhar, você continua no root.

Para escolher o gerenciador de pacotes dessa atualização, o `.zshrc` não depende só do `/etc/os-release` (algumas imagens, como o ALARM do proot-distro, não têm esse arquivo). Ele tenta, em ordem: `ID` e depois `ID_LIKE` de `/etc/os-release` e de `/usr/lib/os-release`; arquivos-marcadores como `/etc/arch-release` e `/etc/debian_version`; e, por último, o gerenciador que existir no `PATH` (`pacman`, `apt-get`, `dnf`, `zypper`, `apk`). No `--dry-run` em modo proot, o script informa qual gerenciador o `.zshrc` vai usar e por qual critério, ou avisa se ele não reconheceria a distro.

Antes disso o `.zshrc` decide se está no Termux de verdade ou numa distro em proot, porque as variáveis do Termux (`TERMUX_VERSION` e `PREFIX`) podem vazar para dentro do proot. Se ele confiasse só nelas, o root cairia no ramo do Termux (`pkg update`) e nunca atualizaria. A ordem é: sem variáveis do Termux, não é Termux; kernel com `proot` em `uname -r`, é distro; `uname -o` igual a `Android`, é Termux; arquivos de distro (`os-release`, `arch-release` etc.), é distro; senão, só é Termux se o `pkg` existir. O `--dry-run` em modo proot avisa (`[!!]`) se o `.zshrc` cairia no ramo do Termux por engano. Para ver as decisões do `.zshrc` ao vivo, abra um shell com `ZSHRC_DEBUG=1 zsh`.

O nome `gustavo` está fixo nesse `.zshrc` (no `su - gustavo`). Com `NEW_USER=outro` o usuário é criado, mas a troca automática não acontece até você ajustar essa linha.

No Termux, rodar como root continua bloqueado de propósito.

## WSL

O WSL (1 e 2) não é uma VM comum: o Windows inicia o kernel direto, sem bootloader nem tela de boot. O script o detecta sozinho e muda o que faz.

**Detecção.** Basta um destes sinais: kernel (`uname -r`) ou `/proc/version` com `microsoft` ou `wsl`; `systemd-detect-virt` devolvendo `wsl`; interop do WSL (`/proc/sys/fs/binfmt_misc/WSLInterop` ou `/run/WSL`); as variáveis `WSL_DISTRO_NAME` ou `WSL_INTEROP`. O script mostra no log qual sinal usou. Se a detecção errar, `FORCE_WSL=1` força o modo WSL e `FORCE_WSL=0` desliga a detecção.

**O que muda no WSL:**

- **Sem GRUB, Plymouth e initramfs.** Os temas Minecraft são pulados; `--temas-minecraft` é ignorado com um aviso. O `--reverter-temas` continua valendo, para limpar vestígios de execuções antigas.
- **Sem Kitty, fontconfig e fonte.** Veja o parágrafo "Kitty e fonte" abaixo.
- **Locales continuam sendo gerados** e o `LANG`/`LC_MESSAGES` do sistema gravados, como nas outras distros.
- **Login automático** no `gustavo` (abaixo). O `sudo` e o usuário funcionam como numa distro de desktop.

**Login automático no WSL:** depois de criar o usuário `gustavo`, o script define `[user] default=gustavo` no `/etc/wsl.conf` (troca só essa chave, preserva as outras seções e guarda a cópia original em `/etc/wsl.conf.setup.bak`), e o WSL passa a abrir direto como ele em vez de root. O WSL só lê o `wsl.conf` ao iniciar a distro, então a mudança vale depois de reiniciá-la pelo Windows, no PowerShell ou cmd: `wsl --terminate <nome-da-distro>` (nome em `wsl -l -v`) ou `wsl --shutdown`. Para entrar como root quando precisar: `wsl -u root`. `WSL_SET_DEFAULT_USER=0` não mexe no `wsl.conf`. Precisa de um WSL razoavelmente novo (`wsl --update`); em versões muito antigas o `[user] default` não é lido.

**Kitty e fonte no WSL:** o terminal do WSL é do Windows (Windows Terminal etc.) e a fonte também, então o script não instala `kitty`, `fontconfig` nem a MesloLGS NF dentro da distro. No fim ele avisa para instalar a MesloLGS NF no Windows (os 4 `.ttf` de [powerlevel10k-media](https://github.com/romkatv/powerlevel10k-media)) e escolhê-la no Windows Terminal; sem isso o prompt do p10k mostra glifos quebrados. `WSL_INSTALL_GUI=1` instala tudo isso no Linux mesmo assim (útil para apps gráficos pelo WSLg).

## O que o script faz

Nas distros de desktop, as etapas 1 a 3 rodam como root; depois o script cria o usuário `gustavo` (seção acima) e as etapas 4 a 10 rodam como ele. A etapa 11 (temas Minecraft) e a pergunta final da etapa 12 voltam a rodar como root. No Termux tudo roda direto, sem criar usuário. No proot o fluxo é o da seção anterior (as etapas abaixo se aplicam, menos `paru`, Kitty e fontes).

**Antes de tudo, só no Arch puro (`ID=arch`) de desktop:** instala o `rate-mirrors` (está no repositório oficial `extra`), ranqueia os mirrors, guarda a mirrorlist antiga em `/etc/pacman.d/mirrorlist.bak` (ou `.bak.1`, `.bak.2`...) e roda `pacman -Syyu`. É `-Syyu` e não só `-Syy`: atualizar o banco sem atualizar os pacotes é update parcial e quebra o sistema. CachyOS, EndeavourOS e Arch ARM mantêm a mirrorlist deles. `SKIP_MIRRORS=1` pula a etapa; `FORCE_MIRRORS=1` ranqueia de novo mesmo se a lista já veio do `rate-mirrors`.

**pacman.conf, em qualquer Arch ou derivada x86_64 de desktop:** garante que `[core]`, `[extra]` e `[multilib]` estejam ativos, cada um com `Include = /etc/pacman.d/mirrorlist`. Cobre os três casos: seção comentada (`#[multilib]`), seção ativa sem `Include` e seção ausente. Seções que já têm `Include` ou `Server` não são tocadas, então rodar de novo não muda nada. O primeiro backup fica em `/etc/pacman.conf.setup.bak`; se algo mudou, o script roda `pacman -Syu` (nunca `-Sy` sozinho). Não mexe no Artix (repositórios próprios) nem em aarch64 (sem multilib). Se o arquivo de mirrors (`/etc/pacman.d/mirrorlist`, ajustável em `PACMAN_MIRRORLIST_INCLUDE`) não existir, o script não grava nada, porque um `Include` para um arquivo inexistente quebra o pacman. `SKIP_PACMAN_REPOS=1` pula a etapa; `--dry-run` mostra o diff.

**Repositórios do CachyOS (Arch e EndeavourOS x86_64):** baixa `https://mirror.cachyos.org/cachyos-repo.tar.xz`, extrai e roda o `cachyos-repo.sh` oficial ([CachyOS/linux-cachyos](https://github.com/CachyOS/linux-cachyos)), que detecta o nível da CPU (x86-64-v3/v4/znver4) e ajusta o `pacman.conf` sozinho, e depois roda `pacman -Syu`. **Antes de rodar o instalador, tira um snapshot do snapper** (config `root`), porque o `cachyos-repo.sh` troca o `pacman` pelo fork do CachyOS e o `-Syu` seguinte pode trocar boa parte do sistema por builds otimizadas. Sem snapper, sem a config `root` (raiz em ext4, por exemplo) ou se o snapshot falhar, o script pergunta se você quer continuar sem ele (padrão: não; sem terminal a etapa é pulada). `CACHYOS_SEM_SNAPSHOT=1` continua sem perguntar. O snapshot cobre só a raiz: um `/boot` em partição separada (ESP) fica de fora. O instalador pode fazer perguntas, que aparecem no seu terminal. Pula se já for CachyOS ou se os repositórios já estiverem configurados. Em outras derivadas (Manjaro, Garuda etc.) fica desligado; `--cachyos-repo` (ou `CACHYOS_REPO=1`) força, `--sem-cachyos-repo` (ou `CACHYOS_REPO=0`) desliga.

**Kernel do CachyOS (só Fedora x86_64 de desktop, depois de tudo e antes dos temas Minecraft):** pergunta se você quer o kernel do CachyOS (padrão: não; sem terminal a etapa é pulada). Se aceitar (ou com `--kernel-cachyos`), habilita o COPR `bieszczaders/kernel-cachyos` (ou `bieszczaders/kernel-cachyos-lto` nas variantes `-lto`) e instala `kernel-cachyos` e `kernel-cachyos-devel-matched`, a receita do [CachyOS/copr-linux-cachyos](https://github.com/CachyOS/copr-linux-cachyos). O kernel novo entra ao lado do kernel do Fedora, que continua no menu do GRUB. O script confere antes: CPU com x86-64-v3 (v2 nas variantes `-lts`, `-lts-lto` e `-server`), nada de Silverblue/Kinoite (rpm-ostree) e Secure Boot desligado (com ele ligado o kernel só inicia se a chave estiver no MOK; `--kernel-cachyos` ignora o aviso). Com SELinux ligado roda `setsebool -P domain_kernel_load_modules on`. **NVIDIA:** o COPR não oferece mais módulos pré-compilados; use RPM Fusion (`akmod-nvidia`) ou Negativo17 e confira com `modinfo nvidia` no kernel novo. Não tira snapshot: um kernel a mais não precisa dele, e o antigo segue no menu. Reinicie e confira com `uname -r`.

1. Detecta o gerenciador de pacotes: `pkg` (Termux), `apt`, `zypper`, `dnf`, `pacman` ou `apk` (Alpine e postmarketOS; veja a seção própria).
2. Instala `zsh git curl fastfetch micro fzf zoxide`. Um pacote indisponível não interrompe o script, só aparece na lista de falhas no final.
3. **Só em distros** (no WSL, sem `kitty` e `fontconfig`; veja a seção do WSL):
   - Instala `kitty` e `fontconfig`.
   - Gera os locales `pt_BR.UTF-8` e `en_US.UTF-8` do sistema e grava `LANG=pt_BR.UTF-8` e `LC_MESSAGES=en_US.UTF-8` em `/etc/locale.conf`. Arch e Debian/Ubuntu usam o `/etc/locale.gen` com `locale-gen` (Debian/Ubuntu instalam antes o pacote `locales`); Fedora instala `glibc-langpack-en` e `glibc-langpack-pt`; openSUSE instala `glibc-locale`; Alpine/postmarketOS (musl) instala `musl-locales` e grava em `/etc/profile.d/10-setup-locale.sh` (veja a seção do Alpine). No Debian/Ubuntu o `/etc/default/locale` também recebe as duas chaves (é o que o login lê). Só `LANG` e `LC_MESSAGES` são tocados: as outras linhas do arquivo ficam, e a cópia original vai para `<arquivo>.setup.bak`. `SKIP_LOCALES=1` pula a etapa; `SYS_LANG` e `SYS_LC_MESSAGES` trocam os valores.
4. No Arch/CachyOS, instala o `paru` (pelo repositório ou compilando o `paru` do AUR). O `paru-bin` não é usado: ele é pré-compilado e quebra (`libalpm.so.15: cannot open shared object file`) quando o pacman sobe de versão. Se já houver um `paru` que não executa, o script remove o `paru-bin` e recompila.
5. Clona o oh-my-zsh, o powerlevel10k (em `~/powerlevel10k`) e os plugins `zsh-autosuggestions`, `fast-syntax-highlighting` e `zsh-history-substring-search`.
6. Copia os dotfiles para o `$HOME`, cada ambiente da sua pasta:
   - Termux: `Termux/.zshrc` e `Termux/.p10k.zsh`.
   - Proot: `Distro Proot/.zshrc` e `.p10k.zsh`.
   - Distros de desktop: `Distro Normal/.zshrc`, `.p10k.zsh` e `.p10k-ascii.zsh`.
7. **Só em distros:** copia `Kitty/kitty.conf` para `~/.config/kitty/kitty.conf`.
8. Define `EDITOR` e `VISUAL` como `micro` em `~/.zshenv`, se ainda não estiverem definidos.
9. Troca o shell padrão para o zsh. Nas distros de desktop e no proot isso já foi feito com `usermod -s` para o `gustavo` e para o root.
10. Instala a fonte MesloLGS NF:
    - Termux: baixa só a Regular, como `~/.termux/font.ttf`.
    - Distros: baixa Regular, Bold, Italic e Bold Italic (do repo `romkatv/powerlevel10k-media`) para `~/.local/share/fonts/MesloLGS-NF` e atualiza o cache com `fc-cache`.
11. **Só em distros, opcional:** instala os temas Minecraft (veja a seção abaixo). É a última etapa do setup.
12. **No fim, em qualquer ambiente:** pergunta `Deseja encerrar a sessão?`. Se você responder que sim, o script fecha o shell que o chamou (um `exit` dentro do script só encerraria o próprio script, então ele manda `SIGHUP` para o shell interativo que está acima, pulando `sudo`/`su`). Se responder que não, ou se não houver terminal para perguntar, mostra o aviso final de sempre (`Pronto. Entre como gustavo...`). Em `--dry-run` ele só informa que perguntaria.

## Temas Minecraft (GRUB + Plymouth)

Só em distros de desktop com bootloader: fora do WSL (veja a seção do WSL) e fora do Alpine/postmarketOS (veja a seção do apk, onde o `--temas-minecraft` é ignorado).

O script pergunta no começo se você quer instalar; `--temas-minecraft` (ou `MC_THEMES=1`) aceita sem perguntar e `--sem-temas-minecraft` (ou `MC_THEMES=0`) pula. Sem terminal para perguntar, o padrão é não instalar.

- **GRUB:** [minegrub-world-sel-theme](https://github.com/Lxtharia/minegrub-world-sel-theme). Copia o tema para `/boot/grub/themes` (`/boot/grub2/themes` no Fedora), define `GRUB_THEME`, `GRUB_TERMINAL_OUTPUT=gfxterm` e `GRUB_TIMEOUT_STYLE=menu` em `/etc/default/grub`, aplica os patches de ícone da entrada UEFI e do submenu "Advanced options" e roda o `grub-mkconfig`. Só funciona se o bootloader for o GRUB; em Limine ou systemd-boot essa parte é pulada com um aviso.
- **Plymouth:** [minecraft-plymouth-theme](https://github.com/nikp123/minecraft-plymouth-theme). Instala `plymouth` e o ImageMagick (no Fedora também `plymouth-plugin-script`), roda o `install.sh` do tema, adiciona o hook `plymouth` ao `HOOKS` do `/etc/mkinitcpio.conf` (Arch), acrescenta `quiet splash` ao `GRUB_CMDLINE_LINUX_DEFAULT` (no Fedora o `rhgb quiet` padrão já basta) e define o tema `mc` regenerando o initramfs (`mkinitcpio -P` no Arch; `plymouth-set-default-theme -R mc` no Debian, Ubuntu e Fedora). Em outros bootloaders, o script avisa para você acrescentar `quiet splash` à linha de comando do kernel por conta própria.
- Antes de mexer em qualquer coisa, tira um snapshot do snapper (config `root`), se existir.
- Cada arquivo alterado ganha uma cópia da versão original ao lado, como `<arquivo>.mc.bak`, criada só na primeira vez. Os `.mc.bak` ficam sem permissão de execução: o `grub-mkconfig` executa tudo que for executável em `/etc/grub.d`, e um backup executável duplicaria as entradas do menu. (Versões antigas do script deixavam esses backups executáveis; rodar o script de novo com `--temas-minecraft` corrige e regenera o `grub.cfg`.)
- Atualizações do pacote do GRUB podem sobrescrever os patches de ícone em `/etc/grub.d`; rode o script de novo para reaplicá-los.

### Reverter: `bash setup.sh --reverter-temas`

Desfaz tudo e sai (não executa mais nada do setup). Mostra o que vai fazer, pergunta antes (padrão: não) e tira um snapshot do snapper, se existir. Suporta `--dry-run`.

- `/etc/default/grub` volta para a cópia `.mc.bak`. **Edições que você fez nele depois de instalar os temas se perdem**; refaça-as depois.
- `30_uefi-firmware`, `10_linux` e `mkinitcpio.conf` não voltam para a cópia velha: o script remove só o trecho que ele mesmo acrescentou (`--class uefi`, `--class submenu`, hook `plymouth`). Assim uma atualização do pacote que veio depois não é desfeita.
- Apaga o tema do GRUB e os arquivos do tema do Plymouth (tema `mc`, fonte Minecraft, configs do dracut/mkinitcpio e o hook do initramfs-tools), reseta o tema padrão do Plymouth, regenera o initramfs (`mkinitcpio -P`, `update-initramfs -u -k all` ou `dracut -f --regenerate-all`) e o `grub.cfg`.
- Os pacotes `plymouth` e `imagemagick` continuam instalados.
- Sem vestígios dos temas, não faz nada. Sem terminal para perguntar, não altera nada.

## Backups

Se já existir um dos arquivos de configuração e ele for diferente do repo, o original é guardado ao lado dele como `.bak` (por exemplo `~/.zshrc.bak`). Se o `.bak` já existir, o script usa `.bak.1`, `.bak.2` e assim por diante, sem sobrescrever backups antigos. Isso vale também para o `kitty.conf`.

O script pode ser executado várias vezes: repositórios já clonados só são atualizados, arquivos idênticos ao repo não são copiados de novo e fontes já instaladas são ignoradas.

Como o repo é a fonte da verdade, alterações feitas direto no `~/.zshrc` ou no `kitty.conf` são sobrescritas na próxima execução (com backup). Edite os arquivos aqui.

## nvidia.sh

Script à parte do `setup.sh` (use um sem o outro, se quiser) para o driver NVIDIA em notebook ou desktop. Tem duas etapas:

```
./nvidia.sh                     # etapa 1: relatório de detecção, somente leitura
./nvidia.sh --env               # imprime NV_CHAVE=valor (eval "$(./nvidia.sh --env)")
./nvidia.sh install --dry-run   # etapa 2: mostra o plano e os comandos, sem alterar nada
./nvidia.sh install             # instala (mostra o plano e pede confirmação)
```

`source ./nvidia.sh` só carrega as funções (depois, `nv_detect_all`). Não rode o `install` como root (o `--dry-run` pode): o `makepkg` e o `paru` recusam root e o script chama `sudo` quando precisa.

**Etapa 1, detecção.** Lê o ambiente (recusa Termux, proot, container, WSL e sistema imutável), a distro (Arch, Debian, Ubuntu e Fedora, mais derivadas pelo `ID_LIKE`), as GPUs (híbrida, BusID, arquitetura estimada pela faixa do Device ID e se o módulo open serve), o estado do driver, o bootloader, o gerador de initramfs, o Secure Boot (só avisa), os headers do kernel e os repositórios.

**Etapa 2, instalação.** Escolhe o driver pela arquitetura da GPU:

| GPU | Driver |
| --- | ------ |
| Turing, Ampere, Ada, Hopper | Módulos **open** (padrão recomendado pela NVIDIA); `--proprietary` troca |
| Blackwell | Só **open** |
| Maxwell, Pascal, Volta | Ramo legado **580xx** (proprietário, DKMS pelo AUR); o ramo atual não as suporta |
| Kepler ou mais antiga, ou Device ID desconhecido | Não escolhe sozinho (saída 14): confirme a arquitetura e use `--open` ou `--proprietary` |

Passos, nesta ordem: credenciais (`sudo -v`), snapshot antes, pacotes, parâmetros do kernel, initramfs, PRIME e snapshot depois.

- **Pacotes (Arch):** roda `pacman -Syu` completo (o Arch não suporta upgrade parcial), confere os nomes com `pacman -Si` e instala `nvidia-open` (ou `nvidia`) mais `nvidia-utils` e `nvidia-settings`. Usa DKMS (`nvidia-open-dkms` ou `nvidia-dkms`, com os headers) se o kernel não for o `linux`, com `--dkms` ou no ramo legado. Instala `lib32-nvidia-utils` se o `[multilib]` estiver ativo (senão avisa: Steam e Wine ficam sem as libs de 32 bits). O ramo legado vem do AUR pelo `paru`; se ele não existir, o script o compila da fonte.
- **Pacotes (Fedora, Ubuntu, Debian):** RPM Fusion e akmod no Fedora, `apt` no Debian e Ubuntu. Só em `--dry-run`: a execução real exige `--allow-untested`.
- **Parâmetros do kernel:** `nvidia-drm.modeset=1` e `nvidia-drm.fbdev=1`, pelo bootloader detectado (GRUB, com `grubby` no Fedora; ou Limine). Sem bootloader suportado, grava em `/etc/modprobe.d`. Com mais de um bootloader, para (saída 14) e pede `--bootloader=grub|limine|none`.
- **Initramfs:** `mkinitcpio -P`, `dracut --force --regenerate-all` ou `update-initramfs -u -k all`, conforme o sistema.
- **Snapshot:** par pre/post do snapper (config `root`). Sem snapper, pede confirmação; `--no-snapshot` desliga. Se o `snap-pac` estiver instalado, o script avisa que o pacman já tira snapshots.
- **PRIME (notebook híbrido, Wayland):** render offload. No Arch instala o `nvidia-prime` e use `prime-run <programa>` (na Steam: `prime-run %command%`). Fora do Arch, mostra as variáveis manuais. `--no-prime` desliga.
- Cada arquivo editado ganha um backup `*.nvsh-bak-*` ao lado, e o script pode rodar de novo. Se um passo falhar, nada é desfeito sozinho: ele diz onde estão o snapshot e os backups.

Opções do `install`:

| Opção | O que faz |
| ----- | --------- |
| `-n`, `--dry-run` | Mostra o plano e os comandos, sem alterar nada |
| `--open`, `--proprietary` | Força o tipo de módulo (o legado 580xx não tem versão open) |
| `--dkms` | Usa pacotes DKMS mesmo no kernel `linux` (Arch) |
| `--bootloader=X` | `auto` (padrão), `grub`, `limine` ou `none` |
| `--no-prime`, `--no-snapshot` | Não configura PRIME / não tira snapshot |
| `--reconfigure` | Só kernel/modeset, initramfs e PRIME (pula os pacotes) |
| `--ignore-managed` | Ignora a recusa em distros que gerenciam o driver sozinhas |
| `--allow-untested` | Permite execução real em Fedora, Ubuntu e Debian |
| `-y`, `--yes` | Responde "sim" às perguntas do script (`pacman` e `paru` continuam perguntando) |

Códigos de saída: `0` ok, `2` uso incorreto, `10` sem GPU NVIDIA, `11` ambiente sem suporte, `12` distro não suportada (inclui Alpine e postmarketOS: o driver proprietário é só glibc, e no musl só o nouveau funciona), `13` recusado por política, `14` não consigo decidir com segurança, `15` um passo falhou, `16` cancelado.

Recusa por política (`13`): rodar o `install` real como root; distro que gerencia o driver sozinha (`chwd`, `mhwd`, `nvidia-inst`...), porque a ferramenta nativa conhece melhor os pacotes e o kernel; Fedora, Ubuntu e Debian sem `--allow-untested`.

Fora do escopo por enquanto: sessão X11 (PRIME sync e `xorg.conf` estão nos planos), Secure Boot (o script só avisa que o módulo precisa ser assinado) e o driver instalado pelo `.run` da NVIDIA (ele pede para você removê-lo antes). Se a GPU dedicada estiver desligada pela BIOS (modo "integrated only" de alguns notebooks), ela some do barramento PCI e nenhum script a detecta.

## OXWM

`oxwm-setup.sh` instala a configuração do OXWM, um gerenciador de janelas X11, com os atalhos migrados do Caelestia (Hyprland). Só para Arch e derivadas: precisa de `paru` ou `yay` (o `oxwm-git` vem do AUR). O `config.lua` tem que estar na **mesma pasta** do script.

```
bash oxwm-setup.sh [--startx] [--dm=sddm|lightdm] [--sem-sistema]
```

Sem opções, o script pergunta como iniciar o OXWM: `startx`, SDDM, LightDM ou nenhum (dá para combinar `startx` com um gerenciador de login; só um gerenciador vale).

| Opção | O que faz |
| ----- | --------- |
| `--startx` | Cria `~/.xinitrc` para iniciar com `startx` (o antigo vira `.xinitrc.bak-<data>`) |
| `--dm=sddm`, `--dm=lightdm` | Instala e habilita o gerenciador de login. Vale a partir do próximo boot (não derruba a sessão aberta) e o script mostra como voltar ao anterior |
| `--sem-sistema` | Só copia os arquivos do usuário: sem pacotes, sem `/etc` e sem gerenciador de login |

O que faz (sem `--sem-sistema`), depois de pedir confirmação:

- Instala os pacotes que faltam (`oxwm-git`, Xorg, `rofi`, `dunst`, `i3lock`, `maim`, `ffmpeg`, `kitty`, `micro`, `thunar`, `btop`, `playerctl`, `brightnessctl`, `ttf-jetbrains-mono-nerd` e outros); os que não existirem são listados, sem travar.
- Cria `/etc/X11/xorg.conf.d/40-flat-accel.conf` (mouse sem aceleração).
- Cria `/usr/share/xsessions/oxwm.desktop` se o `oxwm-git` não o trouxe (só com `--dm`).

Sempre, também com `--sem-sistema`: copia o `config.lua` para `~/.config/oxwm/` (o antigo vira `config.lua.bak-<data>`) e cria os scripts `screenshot.sh` (tela cheia ou região, copia para a área de transferência), `record.sh` (grava a tela, com ou sem som do sistema; rode de novo para parar) e `powermenu.sh` (menu de energia no `rofi`) em `~/.config/oxwm/scripts/`. A sessão do Hyprland continua intacta.

O `config.lua` usa Super como tecla principal, tags 1 a 8 normais e 9 a 12 "especiais" (`mus`, `com`, `todo`, `sys`: música, comunicação, tarefas e monitor do sistema). Como o OXWM não tem scratchpad, os especiais são tags comuns alternadas por atalho (Super+M, D, R e Ctrl+Shift+Esc). Super+C abre o app do Claude (`claude-desktop`), Super+Shift+R recarrega a configuração, e o wallpaper (`feh`) aponta para `/home/gustavo/Pictures/Wallpapers/Luna E Terra.png`: copie o `Luna E Terra.png` do repo para lá ou ajuste a variável `wallpaper`. A nota `OXWM/MIMLeia.md` lembra de fazer o `oxwm-setup.sh` ler o `config.lua` de dentro dessa pasta; por enquanto ele continua na raiz.

## Backup do Termux

Dois scripts em `Termux/`, escritos em zsh e que precisam de `zstd` e `pv` (`pkg install zstd pv`) e do acesso ao armazenamento (`termux-setup-storage`, porque gravam em `~/storage/shared/Documents`):

- **`Backup_Termux.sh`** faz o backup de `home` e `usr` do Termux com `tar` e `zstd -19`, ignorando `home/storage`, `home/.cache` e as pastas `cache`. O arquivo sai em `~/storage/shared/Documents/termux_backup_<data>_<hora>.tar.zst`, com barra de progresso.
- **`Backup-Restore.sh`** restaura um backup em cima do `home` e do `usr`, **depois de pedir confirmação** (ele sobrescreve arquivos). Aceita o caminho do arquivo como argumento. **Sem argumento, procura `Termux-Backup.tar.zst` em `Documents`**: esse nome não é o que o `Backup_Termux.sh` gera (que leva data e hora), então passe o caminho do backup ou renomeie o arquivo. Depois de restaurar, feche o Termux à força e abra de novo.

## Limitações

- O `emerge` (Gentoo) ainda não é suportado.
- O `nvidia.sh` foi testado só com cenários simulados, sem hardware NVIDIA no desenvolvimento; só o Arch tem execução real prevista (Fedora, Ubuntu e Debian ficam em `--dry-run`). Rode `./nvidia.sh install --dry-run` e leia o plano antes de instalar.
- O `oxwm-setup.sh` só funciona em Arch e derivadas (usa `paru` ou `yay` e o AUR), é para X11 e o `config.lua` espera o wallpaper e o `claude-desktop` do seu usuário.
- O `Backup-Restore.sh` procura por padrão um nome diferente do que o `Backup_Termux.sh` gera (veja "Backup do Termux").
- O `setup.sh` não copia o `Termux/.zsh_history` nem os temas `*.auto.conf` do Kitty; só `.zshrc`, `.p10k.zsh` e o `kitty.conf`.
- O suporte ao `apk` não foi testado num Alpine ou postmarketOS de verdade (veja "Validação" na seção do Alpine). Wolfi e Chimera são recusados de propósito.
- Os temas Minecraft e o `--reverter-temas` foram validados com `--dry-run` e com testes em arquivos de exemplo (instalar, reverter e comparar com os originais: `/etc/default/grub`, `mkinitcpio.conf` e `/etc/grub.d`), mas não num boot de verdade. Teste primeiro no Arch com GRUB; Fedora, Debian e Ubuntu só foram escritos a partir da documentação dos dois temas.
- Encerrar a sessão fecha o shell (ou o terminal) que chamou o script; não faz logout da sessão gráfica.
- O modo proot foi escrito para qualquer distro com `apt`, `dnf`, `zypper`, `pacman` ou `apk`, mas só foi validado com `--dry-run`. Teste de verdade em cada distro antes de confiar (o `su -l gustavo` e o `useradd` dependem de como o proot emula usuários).
- Nas distros de desktop o setup é sempre aplicado ao usuário `gustavo`, e não ao usuário que rodou o script. Para rodar de novo depois, basta executar o script outra vez (por root ou por qualquer usuário com `sudo`, inclusive o próprio `gustavo`). No proot, rode de novo como root.
- Termux não cria usuário.
- O sudo do `gustavo` exige senha. A exceção é a instalação do `paru` no Arch/CachyOS, descrita acima. No proot o `gustavo` não tem sudo.
- No proot, a detecção por ptrace só vale para o Arch Linux ARM; nas outras distros ela depende do nome do kernel trazer `proot` (ou de `FORCE_PROOT=1`).
- O `.zshrc` do proot tem `gustavo` fixo no `su - gustavo`; veja a seção do proot.
- O `fastfetch` não existe nos repositórios do Debian 12 e do Ubuntu 22.04. Nessas versões ele aparece como falha e o `fastfetch` na primeira linha do `.zshrc` mostra "command not found" a cada terminal novo.
- O Kitty e as fontes só são instalados em distros. No Termux a fonte é trocada pelo `termux-reload-settings`, sem `fc-cache`.
- Em terminais que não sejam o Kitty, você precisa selecionar **MesloLGS NF** nas preferências do terminal. O `kitty.conf` já aponta para ela.
- O `.zshrc` define `LANG=pt_BR.UTF-8` e `LC_MESSAGES=en_US.UTF-8`. Em instalações mínimas sem esses locales gerados, alguns programas mostram avisos.
- O `Termux/.zshrc` roda `pkg update` e `pkg upgrade` a cada terminal novo, o que deixa a abertura lenta.

## Licença

Apache License 2.0. Veja o arquivo `LICENSE`.
