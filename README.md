# Só Quero Facilitar Ae

### Pumba Lá Pumba

Meus dotfiles de terminal em um script que monta tudo em uma máquina nova, seja uma distro Linux ou o Termux.

## Conteúdo

| Caminho | Para que serve |
| ------- | -------------- |
| `setup.sh` | O script principal: cria o usuário `gustavo`, instala pacotes, locales, oh-my-zsh, powerlevel10k, plugins, Kitty e fontes e aplica os dotfiles. Funciona em distros de desktop, WSL, proot e Termux (veja "Gerenciadores e ambientes") |
| `mirrors.sh` | Ranqueia os mirrors de novo, quando você quiser, sem refazer o resto. É só um atalho para `bash setup.sh --mirrors` (veja "Ranquear os mirrors de novo") |
| `menu.sh` | Menu em tela cheia (TUI): escolhe o que rodar (setup, mirrors, NVIDIA, OXWM), pede "Tem certeza", executa o script e volta ao menu; também reinicia, desliga (não no Termux nem no proot) e fecha o terminal; roda também sem clonar, por `curl ... \| bash`, baixando só o script do item escolhido (veja "Menu") |
| `tests/menu.test.sh` | Teste do `menu.sh` com scripts de mentira, teclas lidas de um arquivo e um `curl` de mentira (rota sem clone); não altera o sistema |
| `tests/dotfiles.test.sh` | Teste do `setup.sh --dotfiles` com um `curl` de mentira que serve os arquivos desta pasta: confere as URLs, o que é baixado, o backup `.bak` e os erros; roda num `HOME` temporário |
| `nvidia.sh` | Detecta a GPU NVIDIA e instala o driver (open, proprietário ou legado), com modeset, initramfs e PRIME. É independente do `setup.sh` (veja "nvidia.sh") |
| `oxwm-setup.sh` e `config.lua` | Instalam a configuração do OXWM (gerenciador de janelas X11), migrada do Caelestia/Hyprland (veja "OXWM") |
| `OXWM/` | Só uma nota (`MIMLeia.md`) sobre mover o `config.lua` para dentro dela |
| `Distro Normal/` | Dotfiles para distros Linux de desktop |
| `Distro Proot/` | Dotfiles para distros rodando em proot (proot-distro) |
| `Termux/` | Dotfiles do Termux e os scripts de backup e restauração (veja "Backup do Termux") |
| `Kitty/` | Configuração do terminal Kitty e os temas claro/escuro (só distros de desktop) |
| `Luna E Terra.jpg` | Papel de parede 1920 x 1280. O `setup.sh` não o aplica; o `config.lua` do OXWM o espera em `~/Pictures/Wallpapers/` |

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

### Uso rápido

Em uma máquina nova, clone e rode o setup:

```
git clone https://github.com/V0LtagE1z/Minhas-Paradas.git
cd Minhas-Paradas
bash setup.sh
```

Ou, sem clonar nada, abra o menu e escolha o que rodar (ele baixa só o script do item escolhido):

```
curl -fsSL https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/main/menu.sh | bash
```

Já com o repo clonado, `bash menu.sh` abre o mesmo menu. Como rodar o `setup.sh` depende do ambiente:

| Ambiente | Como rodar | O que acontece |
| -------- | ---------- | -------------- |
| Distro de desktop | Como root (`su -`) ou como usuário com `sudo` | Cria o usuário `gustavo` e aplica todo o setup nele; o root também passa a usar zsh (veja abaixo) |
| Termux | Como usuário normal | Aplica o setup direto no seu usuário |
| Alpine / postmarketOS (`apk`) | `sh setup.sh`, como root ou com `doas`/`sudo` (o bash é instalado sozinho) | Igual às distros de desktop, com as diferenças da seção "Alpine e postmarketOS" |
| WSL | Como root ou com `sudo`, dentro da distro (o script detecta o ambiente) | Igual às distros de desktop, sem bootloader, temas, Kitty e fonte, e com login automático no `gustavo` (veja a seção do WSL) |
| Distro em proot (qualquer uma) | Como root (o script detecta o ambiente) | Cria o usuário `gustavo` com `sudo` (se o proot permitir; o script testa) e aplica o setup nele e no root (veja abaixo) |

### Opções adicionais

Só se precisar:

```
bash setup.sh --dry-run                # mostra o que seria feito, sem alterar nada
bash setup.sh --dotfiles               # só atualiza os dotfiles (veja "Só os dotfiles")
bash setup.sh --mirrors                # só ranqueia os mirrors de novo (veja "Ranquear os mirrors de novo")
bash setup.sh --clonar-repo            # pega os dotfiles clonando o repo em ~/Minhas-Paradas
bash setup.sh --help                   # lista todas as opções (veja "Opções e variáveis")
```

- **O `setup.sh` precisa estar salvo em arquivo.** Rodar o `setup.sh` por `curl ... | bash` não funciona nas distros, porque a segunda fase reexecuta o próprio arquivo. Quem roda sem clonar é o `menu.sh`: ele baixa o `setup.sh` para uma pasta temporária e chama-o de lá (veja "Rodar sem clonar").
- **Fixar uma versão** (um commit ou tag no lugar da `main`) no menu sem clone: veja "Rodar sem clonar".
- Os dotfiles não exigem clonar o repo: o `setup.sh` baixa só os arquivos de que precisa (veja "O que o script faz", etapa 6).

## Gerenciadores e ambientes

| Gerenciador | Distros | Observações |
| ----------- | ------- | ----------- |
| `pkg` | Termux | Sem usuário novo; root é recusado de propósito |
| `apt` | Debian, Ubuntu e derivadas | O `fastfetch` não existe no Debian 12 nem no Ubuntu 22.04. Sem ranking de mirrors (veja "Antes de tudo") |
| `dnf` | Fedora | Locales via `glibc-langpack-en` e `glibc-langpack-pt`. `max_parallel_downloads=10` no `dnf.conf` (veja "Antes de tudo") |
| `zypper` | openSUSE (Tumbleweed testado) | O `micro` se chama `micro-editor` lá (o script troca o nome). Os códigos de saída 102, 103 e 106 do `zypper` (reinício recomendado, repositório ignorado) contam como sucesso; o 104 (pacote não encontrado) é falha. Locales via `glibc-locale` |
| `pacman` | Arch, CachyOS, EndeavourOS e derivadas, Arch Linux ARM | `paru` instalado pelo script; mirrors, `pacman.conf` e repositórios do CachyOS (veja "O que o script faz") |
| `apk` | Alpine e postmarketOS (musl) | Veja "Alpine e postmarketOS (apk)" |

O `emerge` (Gentoo) não é suportado. Os ambientes que mudam o comportamento do script são o Termux, o proot (qualquer distro), o WSL e a distro de desktop comum, descritos nas seções abaixo.

### Opções e variáveis

Opções de linha de comando (`bash setup.sh --help` lista todas):

| Opção | O que faz |
| ----- | --------- |
| `--dry-run`, `-n` | Mostra o que seria feito sem alterar nada |
| `--dotfiles` | Só aplica os dotfiles (`.zshrc`, `.p10k.zsh`, `kitty.conf`) no `HOME` de quem roda, com backup `.bak`; sem pacotes, sem usuário (veja "Só os dotfiles") |
| `--clonar-repo` | Pega os dotfiles clonando o repo em `REPO_DIR`, em vez de baixar só os arquivos necessários |
| `--temas-minecraft` / `--sem-temas-minecraft` | Instala os temas Minecraft sem perguntar / não instala e não pergunta |
| `--reverter-temas` | Desfaz os temas Minecraft e sai |
| `--mirrors` | Só ranqueia os mirrors de novo (como `FORCE_MIRRORS=1`) e sai; é o que o `mirrors.sh` chama |
| `--cachyos-repo` / `--sem-cachyos-repo` | Força / desliga os repositórios do CachyOS |
| `--kernel-cachyos` / `--sem-kernel-cachyos` | Fedora: instala o kernel do CachyOS (COPR) sem perguntar / não instala e não pergunta |
| `--help`, `-h` | Mostra a ajuda |

Variáveis de ambiente (valor padrão em negrito, quando existe):

| Variável | Para que serve |
| -------- | -------------- |
| `NEW_USER` (**gustavo**) | Nome do usuário criado |
| `REPO_URL` | Repositório dos dotfiles (**`https://github.com/V0LtagE1z/Minhas-Paradas.git`**); os arquivos são baixados de `raw.githubusercontent.com` com base nele, então só vale para repositórios do GitHub (outro host cai no clone) |
| `DOTFILES_REF` (**main**) | Branch, tag ou commit de onde saem os dotfiles; o `menu.sh` repassa o `MENU_REF` |
| `DOTFILES_CLONE=1`, `REPO_DIR` | Clonam o repo em `REPO_DIR` (**`~/Minhas-Paradas`**) para pegar os dotfiles de lá (o mesmo que `--clonar-repo`) |
| `FORCE_PROOT=1`, `FORCE_ALARM_PROOT=1` | Forçam o modo proot (o segundo também marca Arch Linux ARM) |
| `FORCE_WSL=1` ou `0` | Força o modo WSL ou desliga a detecção dele |
| `WSL_SET_DEFAULT_USER` (**1**) | `0` não mexe no `/etc/wsl.conf` |
| `WSL_INSTALL_GUI=1` | No WSL, instala também Kitty e a fonte no Linux |
| `SKIP_LOCALES=1` | Não gera locales nem grava o locale do sistema |
| `SYS_LANG` (**pt_BR.UTF-8**), `SYS_LC_MESSAGES` (**en_US.UTF-8**) | Valores gravados no locale do sistema |
| `SKIP_MIRRORS=1`, `FORCE_MIRRORS=1` | Pula / refaz o ranking de mirrors (Arch, Arch Linux ARM, EndeavourOS, Artix, CachyOS e Manjaro); no Fedora, `SKIP_MIRRORS=1` também deixa o `dnf.conf` em paz |
| `SKIP_PACMAN_REPOS=1` | Não mexe em `core`, `extra` e `multilib` |
| `PACMAN_MIRRORLIST_INCLUDE` (**/etc/pacman.d/mirrorlist**) | `Include` usado nas seções do `pacman.conf` |
| `CACHYOS_REPO` (**auto**), `CACHYOS_REPO_URL`, `CACHYOS_SEM_SNAPSHOT=1` | Repositórios do CachyOS: `auto`, `1` ou `0`; o instalador; seguir sem snapshot |
| `CACHYOS_KERNEL` (**ask**), `CACHYOS_KERNEL_VARIANT` (**kernel-cachyos**) | Kernel do CachyOS no Fedora: `ask`, `1` ou `0`; a variante (`kernel-cachyos`, `-lto`, `-lts`, `-lts-lto`, `-rt` ou `-server`) |
| `MC_THEMES` (**ask**) | `1`, `0` ou `ask`, o mesmo que as opções dos temas |
| `SKIP_TERMUX_MIRROR=1`, `TERMUX_MIRROR_COUNT` (**3**) | Termux: não mexer no mirror (mantém o do `termux-change-repo`); quantos dos mirrors mais rápidos ficam no conjunto |
| `SKIP_TERMUX_UPGRADE=1`, `SKIP_TERMUX_REPOS=1` | Termux: não rodar o `pkg upgrade` completo (só atualiza o índice); não habilitar `x11-repo`, `root-repo` e `tur-repo` |
| `SKIP_TERMUX_PROOT=1`, `TERMUX_PROOT_IMAGE` (**danhunsaker/archlinuxarm:latest** em ARM, **archlinux:latest** em x86_64), `TERMUX_PROOT_NAME` (**archlinuxarm** em ARM, **archlinux** em x86_64) | Termux: não instalar o Arch no `proot-distro` (o pacote `proot-distro` continua sendo instalado); imagem que o `proot-distro install` baixa; nome local do container (o de `proot-distro login`). O Termux em x86_64 (ex.: emulador Android) usa a imagem oficial do Arch, porque a do danhunsaker só existe para ARM |
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
- **Proot.** O `proot-distro` do Alpine cai no modo proot (sem init); o `.zshrc` do root já reconhecia o Alpine e atualiza o sistema com `apk update` e `apk upgrade`.
- **`nvidia.sh`.** O driver proprietário da NVIDIA é só glibc, então o `nvidia.sh` recusa o Alpine e o postmarketOS (saída 12); no musl só o nouveau funciona.

No `--dry-run`, com o `apk` instalado, o script roda `apk add --simulate` em cada pacote e avisa os que não resolvem no índice local. É só informativo: a simulação não habilita o community e talvez não rode sem root.

**Validação:** o suporte ao apk foi testado só com `--dry-run`, com um `apk` falso e com os applets do busybox no lugar dos GNU (Alpine com e sem cache do apk, postmarketOS, proot, `doas`, as recusas, o bootstrap do bash no ash e a edição do `repositories` em vários formatos). Não foi testado num Alpine ou postmarketOS de verdade; teste lá antes de confiar, principalmente `useradd` com o `shadow`, a senha do `gustavo` e o locale no login.

## Menu

```bash
bash menu.sh
```

Um menu em tela cheia (TUI, em bash puro, sem instalar nada): caixas de bordas arredondadas, seleção destacada e confirmação antes do que altera o sistema. Cada item roda o script certo **como processo filho** e, quando ele termina (ou falha), mostra o código de saída e volta para a tela inicial.

| Tecla | O que faz |
| ----- | --------- |
| `↑` `↓` (ou `k` `j`) | Move a seleção; dá a volta nas pontas |
| `Enter` | Executa o item selecionado |
| `q` | Sai do menu |

| Item | O que roda | "Tem certeza"? |
| ---- | ---------- | -------------- |
| Setup completo | `setup.sh --sem-encerrar` | sim |
| Setup (só simular) | `setup.sh --dry-run --sem-encerrar` | não |
| Dotfiles: só aplicar | `setup.sh --dotfiles` (veja "Só os dotfiles") | sim |
| Ranquear os mirrors | `mirrors.sh` (no Arch e derivadas atualiza o sistema inteiro) | sim |
| Reverter temas Minecraft | `setup.sh --reverter-temas` | sim |
| NVIDIA: detectar GPU | `nvidia.sh` (só leitura) | não |
| NVIDIA: instalar driver | `nvidia.sh install` | sim |
| NVIDIA: simular instalação | `nvidia.sh install --dry-run` | não |
| OXWM: instalar configuração | `oxwm-setup.sh` | sim |
| Reiniciar, Desligar | `reboot`, `poweroff` (com `sudo` ou `doas`) | sim (no WSL, não: veja abaixo) |
| Fechar este terminal | Manda SIGHUP ao shell que chamou o menu. Se o menu foi chamado por `sudo`, não acha o shell com segurança e pede para você digitar `exit` | sim |
| Sair do menu | Sai só do menu; o terminal continua aberto | não |

- **"Tem certeza que deseja (ação)?"** Aparece um diálogo com os botões `Sim` e `Não`. O padrão é **Não**: `Enter` direto cancela. `←` `→` trocam o botão; `s` confirma; `n`, `q` e `Esc` cancelam. Simulações e a detecção da NVIDIA não perguntam. O `nvidia.sh install` pergunta de novo por conta própria.
- **Termux e proot: Reiniciar e Desligar não aparecem**, porque lá não há o que reiniciar. O menu detecta pelo `PREFIX` do Termux, pelo kernel com `proot` no nome ou por o processo estar sob ptrace (que é o proot; um `strace`/`gdb` também esconde os itens). `FORCE_PROOT=1` força o modo proot, e `FORCE_PROOT=0` desliga a detecção por ptrace (mesmos nomes do `setup.sh`).
- **WSL:** Reiniciar e Desligar aparecem, mas não fazem nada: mostram o comando certo, `wsl --shutdown`, para rodar no Windows (PowerShell ou CMD). Isso para todas as distros WSL; depois é só abrir a distro de novo.
- **Visual:** a largura segue o terminal (de 36 a 72 colunas, então cabe no Termux em pé). `NO_COLOR=1` ou `TERM=dumb` desligam as cores e a limpeza de tela. O menu assume terminal UTF-8 (bordas e `❯`); o console do Linux sem fonte unicode mostra as bordas quebradas. Num sistema sem locale UTF-8 (rootfs mínimo) ele usa `C.UTF-8` só para contar as colunas direito.
- **O menu escolhe o script, não cada etapa dentro dele.** O `setup.sh` continua sendo um bloco só (pacotes, usuário, dotfiles...); quem quiser pular partes usa as opções e variáveis dele (`--help`).
- **`--sem-encerrar`:** o `setup.sh` normalmente pergunta no fim "Deseja encerrar a sessão?" e fecha o shell que o chamou. Sob o menu esse shell seria o próprio menu, então o item de setup passa `--sem-encerrar` e a pergunta some; use "Fechar este terminal" quando quiser fechar o terminal.
- **Precisa do bash.** Sem ele (Alpine, por exemplo) o menu avisa e mostra o comando de instalação do gerenciador que achar (`apk add bash`, `apt-get install -y bash`...), para rodar como root; depois é só `bash menu.sh`. Com o bash instalado, `sh menu.sh` já reexecuta sozinho em bash.
- **Rode como usuário normal.** O `setup.sh` e o `oxwm-setup.sh` pedem `sudo` sozinhos; o `nvidia.sh` recusa root.
- **Testes:** `bash tests/menu.test.sh` (scripts de mentira, respostas por arquivo) e `bash tests/dotfiles.test.sh`.

### Rodar sem clonar (`curl | bash`)

```bash
curl -fsSL https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/main/menu.sh | bash
```

Abre o mesmo menu numa máquina nova, sem `git clone` antes.

- **Como funciona.** Se não há um `setup.sh` ao lado do menu (é o caso do `curl | bash`, e também de um `menu.sh` baixado sozinho), ele **não baixa nada ao abrir**: quando você escolhe um item, baixa só o script dele de `raw.githubusercontent.com` (com `curl` ou, se não houver, `wget`; **sem `git` e sem `tar`**) para uma pasta temporária (`$TMPDIR`, ou `/tmp`) e **apaga a pasta ao sair**. O que o script usa ao lado vem junto: o `mirrors.sh` traz o `setup.sh`, e o `oxwm-setup.sh` traz o `config.lua`. Cada arquivo é baixado uma vez por sessão. Rodando de um clone, nada disso acontece.
- **Fixar a versão.** Por padrão baixa a `main`, ou seja, o que estiver lá na hora. Para fixar, use um commit (ou tag) **na URL e em `MENU_REF`**, os dois iguais, porque a URL traz o `menu.sh` e `MENU_REF` traz o resto (os scripts e, por `DOTFILES_REF`, os dotfiles):

  ```bash
  curl -fsSL https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/<commit>/menu.sh | MENU_REF=<commit> bash
  ```

  Não há checksum: a garantia é o HTTPS do GitHub, e só um commit completo é imutável (branch e tag podem mudar). Como cada arquivo é baixado na hora em que é usado, se a `main` mudar no meio da sessão scripts de commits diferentes se misturam; fixar um commit evita isso.
- **É `| bash`, não `| sh`.** Com `| sh` não dá para reexecutar o script em bash; o menu avisa e mostra o comando certo. Sem bash instalado (Alpine), ele mostra o comando para instalá-lo, como no uso normal.
- **Os scripts rodam com o terminal como stdin.** No `curl | bash` o stdin é o pipe, e o `setup.sh` e o `nvidia.sh` recusam rodar sem terminal; por isso o menu entrega o `/dev/tty` a cada script que ele chama.
- **O `setup.sh` não clona mais o repo.** Ele baixa só os dotfiles de que precisa, direto de `raw.githubusercontent.com` (veja "Só os dotfiles"), então **`~/Minhas-Paradas` não existe depois do setup**. Quem quer a pasta (para editar os dotfiles e dar commit, ou para rodar o `mirrors.sh` dela) usa `--clonar-repo`.
- **Precisa de um terminal** (`/dev/tty`); sem ele o menu recusa antes de baixar qualquer coisa.

## Só os dotfiles

```bash
bash setup.sh --dotfiles            # ou o item "Dotfiles: só aplicar" do menu
bash setup.sh --dotfiles --dry-run  # só mostra as URLs e o que faria
DOTFILES_REF=<commit> bash setup.sh --dotfiles
```

Baixa só os arquivos do seu ambiente (o mesmo conjunto da etapa 6 e 7 de "O que o script faz") e copia para o `HOME` de quem roda, com backup `.bak` do que for diferente (veja "Backups"). Não instala pacote, não cria usuário e não pede `sudo`.

- **Supõe o zsh, o oh-my-zsh e o powerlevel10k já instalados**; o `.zshrc` carrega os dois. Numa máquina nova, rode o setup completo.
- **Rode como o usuário que vai usar os arquivos.** Como root o script recusa, exceto no proot (onde o root também recebe os dotfiles). `--dry-run` é aceito como root.
- **Um arquivo que falha ao baixar** (sem rede, ref inexistente) gera um aviso com a URL e aparece na lista de falhas no fim; o arquivo que já estava no `HOME` não é tocado.
- `--clonar-repo` clona o repo em `REPO_DIR` e copia de lá, em vez de baixar arquivo por arquivo.

## Ranquear os mirrors de novo

O `setup.sh` já ranqueia os mirrors na primeira execução. Mirrors mudam (ficam lentos, saem do ar), então depois você pode refazer só essa etapa:

```bash
bash mirrors.sh            # numa cópia do repo; ou: bash setup.sh --mirrors
bash mirrors.sh --dry-run  # só mostra o que faria
```

Sem uma cópia do repo (o `setup.sh` não clona mais para `~/Minhas-Paradas`), use o item "Ranquear os mirrors" do menu por `curl ... | bash` (veja "Rodar sem clonar"), que baixa o `mirrors.sh` e o `setup.sh` na hora.

- **Pacman (Arch, Arch Linux ARM, EndeavourOS, Artix, CachyOS, Manjaro; desktop e proot):** roda o ranking de novo, faz backup da `mirrorlist` em `.bak` e termina com `pacman -Syyu`, ou seja, **atualiza o sistema inteiro**. Pede root sozinho (como o `setup.sh`). Dentro do proot, rode como root.
- **Termux:** mede os mirrors de novo e roda `pkg --check-mirror update`. Não faz `pkg upgrade`. Rode como usuário normal.
- **Outras distros (apt, dnf, zypper, apk):** não há ranking para elas; o script avisa e sai sem mexer em nada.
- `SKIP_MIRRORS=1` continua mandando; `TERMUX_MIRROR_COUNT` também. O `mirrors.sh` usa o `setup.sh` da mesma pasta (o menu remoto baixa os dois).

## Simulação (--dry-run)

`bash setup.sh --dry-run` (ou `-n`) mostra o que o script faria sem alterar nada, nem precisa de root. Linhas `[dry]` são comandos que seriam executados e linhas `[sim]` são mensagens simuladas. Leituras (checar se um grupo, usuário ou repositório já existe) são feitas de verdade, então a saída reflete o estado atual da máquina. Como nada é baixado na simulação, os dotfiles aparecem como "copiaria <URL>" em vez de comparados com os existentes.

## Distros em proot (proot-distro)

O script detecta sozinho quando está dentro de um proot, em qualquer distro com `apt`, `dnf`, `zypper`, `pacman` ou `apk` (Debian, Ubuntu, Fedora, openSUSE, Arch Linux ARM, Alpine e afins). Os critérios são:

1. O nome do kernel traz `proot`. O proot-distro devolve algo como `6.17.0-PRoot-Distro` em `uname -r`, o mesmo nome que aparece no `fastfetch`.
2. Só no Arch Linux ARM: `ID=archarm` em `/etc/os-release` (ou `/etc/arch-release` em CPU ARM) e processo rastreado por ptrace.

O Arch x86_64 instalado pelo Termux em x86_64 cai no critério 1 (nome do kernel); se não for detectado, use `FORCE_PROOT=1`.

Se a detecção falhar, force com `FORCE_PROOT=1 bash setup.sh`. Rode como root (o `proot-distro login <distro>` já entra como root). Nesse modo o script:

1. Se a distro usa `pacman` (Arch Linux ARM e afins): ajusta o `/etc/pacman.conf` (com backup em `pacman.conf.bak`), comentando `CheckSpace` e `DownloadUser` e ativando a opção de desligar o sandbox do pacman (`DisableSandbox` no pacman 7.0; `DisableSandboxFilesystem` e `DisableSandboxSyscalls` no 7.1+). Inicializa o chaveiro (`archlinuxarm` no ALARM, `archlinux` nas demais), ranqueia os mirrors (ALARM, Arch e as derivadas tratadas; veja "Antes de tudo"), roda `pacman -Syu` uma vez (no ALARM o `-Syyu` do ranking já faz esse papel) e reaplica o ajuste, porque o pacman novo pode trazer outras opções.
2. Instala `zsh git curl fastfetch micro fzf zoxide` (sem `sudo`, já que está como root) e gera os locales `pt_BR.UTF-8` e `en_US.UTF-8`, usados pelo `.zshrc`, se a distro tiver `locale-gen`.
3. Cria o usuário `gustavo` (home `/home/gustavo`, shell zsh, grupos `wheel`, `audio` e `video`) e troca o shell do root para zsh. Você escolhe a senha com `passwd gustavo`; se ela já estiver definida, é mantida.
4. **Instala o `sudo`** (se faltar) e libera o `gustavo` por `/etc/sudoers.d/10-gustavo`, validado com `visudo`, como nas distros de desktop (a senha continua sendo exigida). **Isso só funciona se o proot honrar o setuid**, e em muitos proots isso não acontece (o `sudo` instala, mas falha com `effective uid is not 0`). Por isso, no fim da fase o script **testa** o `sudo` como o `gustavo` (`sudo -n true`) e avisa se ele não executa. Nesse caso, para comandos de root abra uma sessão como root (`proot-distro login <distro>`, sem `--user`). Só o setup do `gustavo` não usa `sudo`: ele continua rodando sem ele, como antes.
5. Aplica os dotfiles de `Distro Proot/` no root e, via `su -l gustavo`, no `gustavo` (oh-my-zsh, powerlevel10k, plugins, `EDITOR`).
6. **Não** instala `paru`, Kitty, `fontconfig` nem fontes. A fonte é a do próprio Termux.

Depois do setup, o `.zshrc` do root pergunta se você quer atualizar o sistema e passa a sessão para o `gustavo` com `su - gustavo`. Se a troca falhar, você continua no root.

Para escolher o gerenciador de pacotes dessa atualização, o `.zshrc` não depende só do `/etc/os-release` (algumas imagens, como o ALARM do proot-distro, não têm esse arquivo). Ele tenta, em ordem: `ID` e depois `ID_LIKE` de `/etc/os-release` e de `/usr/lib/os-release`; arquivos-marcadores como `/etc/arch-release` e `/etc/debian_version`; e, por último, o gerenciador que existir no `PATH` (`pacman`, `apt-get`, `dnf`, `zypper`, `apk`). No `--dry-run` em modo proot, o script informa qual gerenciador o `.zshrc` vai usar e por qual critério, ou avisa se ele não reconheceria a distro.

Antes disso o `.zshrc` decide se está no Termux de verdade ou numa distro em proot, porque as variáveis do Termux (`TERMUX_VERSION` e `PREFIX`) podem vazar para dentro do proot. Se ele confiasse só nelas, o root cairia no ramo do Termux (`pkg update`) e nunca atualizaria. A ordem é: sem variáveis do Termux, não é Termux; kernel com `proot` em `uname -r`, é distro; `uname -o` igual a `Android`, é Termux; arquivos de distro (`os-release`, `arch-release` etc.), é distro; senão, só é Termux se o `pkg` existir. O `--dry-run` em modo proot avisa (`[!!]`) se o `.zshrc` cairia no ramo do Termux por engano. Para ver as decisões do `.zshrc` ao vivo, abra um shell com `ZSHRC_DEBUG=1 zsh`.

O nome `gustavo` está fixo nesse `.zshrc` (no `su - gustavo`). Com `NEW_USER=outro` o usuário é criado, mas a troca automática não acontece até você ajustar essa linha.

No Termux, rodar como root continua bloqueado de propósito.

## Termux

No Termux o script segue esta ordem, sem criar usuário:

1. **Mirror mais rápido.** O `pkg` não escolhe o mais rápido: ele descarta os mirrors que não respondem e sorteia um entre os que sobraram, então você pode cair num mirror do outro lado do mundo. O script mede o tempo de resposta de cada mirror que vem com o Termux (`$PREFIX/etc/termux/mirrors`) **em paralelo** (no máximo ~5 s no total, mesmo com mirrors fora do ar; mirrors repetidos são descartados), copia os **3 mais rápidos** para `$PREFIX/etc/termux/mirrors-setup`, aponta `chosen_mirrors` para essa pasta (o mesmo mecanismo do `termux-change-repo`) e roda `pkg --check-mirror update`. Com 3 no conjunto, o `pkg` troca sozinho se um cair. Se nenhum responder, ou se a instalação não tiver a pasta `mirrors`, o mirror atual é mantido. **Isso acontece no Termux da Play Store** (build não oficial, com repositório `termux.net`): a etapa é pulada com um aviso e o resto roda normalmente. No Termux do F-Droid (1.118.3) a medição funcionou.
2. **`pkg update` + `pkg upgrade -y`.** Instalar pacotes novos em cima de um Termux desatualizado mistura bibliotecas de versões diferentes. O `upgrade` roda com `--force-confdef --force-confold` (o dpkg mantém os seus arquivos de configuração em vez de perguntar, inclusive o `sources.list` com o mirror escolhido). Se falhar, o script para e manda rodar `termux-change-repo` (mirror fora do ar) e repetir.
3. **Repositórios adicionais:** `x11-repo`, `root-repo` e `tur-repo`, seguidos de um novo `pkg update` para os pacotes deles aparecerem. Os já habilitados são pulados.
4. Os pacotes de sempre (`zsh git curl fastfetch micro fzf zoxide`).
5. **Pacotes extras do Termux:** `termux-services` e `proot-distro`. Depois de instalado o `termux-services`, feche e abra o Termux de novo para o runit subir; aí use `sv-enable <serviço>`.
6. **Arch Linux ARM no proot-distro.** O script roda `proot-distro install --name archlinuxarm danhunsaker/archlinuxarm:latest` (imagem de container do danhunsaker; o `proot-distro` atual aceita referências `usuário/imagem:tag`). Se o nome `archlinuxarm` já aparece em `proot-distro list`, pula. Se o download falhar, o script avisa, lista a falha no resumo final e segue. Para entrar: `proot-distro login archlinuxarm`; lá dentro, rode o mesmo `setup.sh` como root (modo proot, cria o usuário e aplica os dotfiles de `Distro Proot`). O script **não** roda esse segundo passo sozinho.
7. O resto do setup (oh-my-zsh, powerlevel10k, plugins, dotfiles, fonte, `EDITOR`, shell padrão).

Observações:

- **`science-repo`, `game-repo` e `unstable-repo` não são habilitados** de propósito: segundo a wiki do `termux-packages` (página *Mirrors*), esses canais foram incorporados ao repositório principal e não precisam mais ser adicionados.
- **O `tur-repo` não é oficial.** O Termux User Repository é mantido por outra organização e o time do Termux não dá suporte aos pacotes dele. Para tirá-lo, edite o array `TERMUX_REPOS` no `setup.sh`.
- Para acrescentar outros repositórios ou pacotes, edite os arrays `TERMUX_REPOS` e `TERMUX_EXTRA_PACKAGES` no começo do `setup.sh`.
- **Prefira o Termux do F-Droid ou do GitHub, não o da Play Store.** A Play Store tem uma build não oficial (fork), com repositório próprio (`termux.net`) e sem a pasta de mirrors. Nos testes do autor ela também mostrou `gitstatus failed to initialize` no powerlevel10k, o que não ocorreu no F-Droid (causa não confirmada; relato do autor, não reproduzido aqui).
- **O mirror muda a velocidade, não a segurança:** os pacotes são assinados (`termux-keyring`) e o `apt` confere a assinatura. Também não é "mais confiável" que o mirror oficial: o ganho é ficar com os mais próximos de você.
- **A medição olha latência, não banda:** ela baixa só o arquivo `Release` (pequeno) de cada mirror. Num mirror com boa latência e banda ruim o ranking pode errar; nesse caso use `TERMUX_MIRROR_COUNT=1` ou escolha à mão com `termux-change-repo` e rode com `SKIP_TERMUX_MIRROR=1`. No único teste real (F-Droid) o ganho de velocidade não ficou comprovado: os 3 mirrors escolhidos diferiam em 19 ms de latência e o download ficou na mesma faixa do mirror sorteado antes. O ranking também ignora o peso dos mirrors, então o CDN oficial pode ficar de fora do conjunto.
- **A imagem do Arch Linux ARM é de terceiros** (`danhunsaker/archlinuxarm`), não oficial do Arch Linux ARM nem do Termux, e é baixada na hora: tem tamanho considerável (use Wi-Fi) e o `proot-distro` pede a arquitetura do aparelho (o script não passa `--architecture`), então a imagem precisa ter build para ela; não verifiquei quais arquiteturas a imagem publica. O `--name` exige um `proot-distro` recente (nas versões antigas o nome saía de um alias interno); se o `pkg` do seu Termux trouxer uma versão antiga, atualize o pacote antes.
- O `--dry-run` mostra todos esses comandos sem executar nada.

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

**Antes de tudo: mirrors.** Cada distro usa a ferramenta que serve a ela. Nas que usam `pacman`, depois do ranking o script roda `pacman -Syyu`. É `-Syyu` e não só `-Syy`: atualizar o banco sem atualizar os pacotes é update parcial e quebra o sistema. `SKIP_MIRRORS=1` pula a etapa; `FORCE_MIRRORS=1` ranqueia de novo mesmo se a lista já foi gerada pelo `rate-mirrors`.

| Distro | Ferramenta | Arquivos |
| ------ | ---------- | -------- |
| Arch (`ID=arch`) | `rate-mirrors arch --max-delay=21600`, só `https` | `/etc/pacman.d/mirrorlist` |
| Arch Linux ARM (desktop ou proot) | `rate-mirrors archarm` (binário da release, abaixo) | `/etc/pacman.d/mirrorlist` |
| EndeavourOS | `rate-mirrors arch`: a `mirrorlist` dele é a do Arch | `/etc/pacman.d/mirrorlist`; a `endeavouros-mirrorlist` é do `eos-rankmirrors` e o script não mexe nela |
| Artix | `rate-mirrors artix --max-delay=21600`, só `https` | `/etc/pacman.d/mirrorlist`; a `mirrorlist-arch` não é tocada |
| CachyOS | `cachyos-rate-mirrors` (o mesmo do "Rank mirrors" do CachyOS Hello; é um wrapper do `rate-mirrors` e não aceita opções) | `/etc/pacman.d/mirrorlist` e `/etc/pacman.d/cachyos-mirrorlist`; guarda `*.bak` das duas |
| Manjaro | `pacman-mirrors --fasttrack 5` (ferramenta oficial; o `rate-mirrors` também tem subcomando `manjaro`, mas o script usa a do sistema) | `/etc/pacman.d/mirrorlist` |
| Fedora | sem ranking; liga `max_parallel_downloads=10` no `/etc/dnf/dnf.conf` (o padrão do dnf são 3). Mantém o valor se você já definiu um | `/etc/dnf/dnf.conf` |
| Debian, Ubuntu e derivadas | nada | — |
| Garuda e outras derivadas | nada: repositórios próprios, a lista do Arch não serve | — |

- **Debian e Ubuntu ficaram sem ranking de propósito.** O `rate-mirrors` não lista esses subcomandos, e o `apt` não tem o que reordenar sem fixar um mirror no `sources.list`. Fixar um mirror "mais rápido" medido uma vez é frágil (ele pode sair do ar ou ficar lento depois, e o `apt` não escolhe outro sozinho). Se você quiser mesmo assim, o caminho é `netselect-apt` (Debian) à mão, fora deste script.
- **Fedora sem `fastestmirror`.** O dnf já escolhe os mirrors por metalink, e o `fastestmirror=True` fez o dnf5 5.2.14 falhar com crash no download (bugzilla 2381859, corrigido no 5.2.15). Por isso o ajuste é só o paralelismo.
- **Manjaro:** o Pamac pode instalar um timer que reescreve a mirrorlist toda semana, desfazendo o ranking. O script não mexe nesse timer.
- **O ranking do CachyOS roda de novo a cada execução** se a `cachyos-mirrorlist` não trouxer o cabeçalho `# ARGS: ...rate-mirrors` (não conferi se o wrapper o grava). É só mais lento, não quebra nada.
- **Arch (x86_64):** o `rate-mirrors` vem do repositório oficial `extra`, e o ranking usa o subcomando `arch` com `--protocol https`. No EndeavourOS o pacote vem do `extra` do Arch, que ele também usa. No Artix não sei se o pacote existe nos repositórios dele (não conferi): se o `pacman -S` falhar, o script cai no binário da release (abaixo).
- **Arch Linux ARM (aarch64):** o pacote não existe no ARM, então o script baixa o binário estático da release `v0.34.1` do [rate-mirrors](https://github.com/westandskif/rate-mirrors/releases) (`aarch64-unknown-linux-musl`), **confere o sha256 fixado no script** e o executa de uma pasta temporária (nada é instalado no sistema). O ranking usa o subcomando `archarm` **sem** `--protocol https`, porque a lista oficial do ARM é toda `http` (os pacotes continuam assinados). No proot a etapa roda logo depois do chaveiro e **antes** do `pacman -Syu`, que vira o `-Syyu` dela (sem baixar tudo duas vezes). Em CPU que não seja aarch64 nem x86_64 (ex.: armv7), o script avisa e mantém os mirrors atuais. Se o download, o sha256 ou o ranking falharem, ele avisa e segue com a mirrorlist atual.

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
6. Baixa os dotfiles do repo, **só os arquivos necessários** (um `curl` por arquivo, de `raw.githubusercontent.com`; sem `curl`/`wget`, ou com `--clonar-repo`, clona o repo em `~/Minhas-Paradas`), e copia para o `$HOME`, cada ambiente da sua pasta:
   - Termux: `Termux/.zshrc` e `Termux/.p10k.zsh`.
   - Proot: `Distro Proot/.zshrc` e `.p10k.zsh`.
   - Distros de desktop: `Distro Normal/.zshrc`, `.p10k.zsh` e `.p10k-ascii.zsh`.
7. **Só em distros:** baixa e copia `Kitty/kitty.conf` para `~/.config/kitty/kitty.conf`.
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

O script pode ser executado várias vezes: repositórios já clonados (oh-my-zsh, powerlevel10k, plugins) só são atualizados, arquivos idênticos ao repo não são copiados de novo e fontes já instaladas são ignoradas.

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
- Os dotfiles são baixados de `raw.githubusercontent.com` sem checksum, e da `main` por padrão (`DOTFILES_REF` fixa um commit). Sem rede para o GitHub o setup não aplica os dotfiles; só o aviso aparece.
- O `setup.sh` não copia o `Termux/.zsh_history` nem os temas `*.auto.conf` do Kitty; só `.zshrc`, `.p10k.zsh` e o `kitty.conf`.
- O suporte ao `apk` não foi testado num Alpine ou postmarketOS de verdade (veja "Validação" na seção do Alpine). Wolfi e Chimera são recusados de propósito.
- Os temas Minecraft e o `--reverter-temas` foram validados com `--dry-run` e com testes em arquivos de exemplo (instalar, reverter e comparar com os originais: `/etc/default/grub`, `mkinitcpio.conf` e `/etc/grub.d`), mas não num boot de verdade. Teste primeiro no Arch com GRUB; Fedora, Debian e Ubuntu só foram escritos a partir da documentação dos dois temas.
- Encerrar a sessão fecha o shell (ou o terminal) que chamou o script; não faz logout da sessão gráfica.
- O modo proot foi escrito para qualquer distro com `apt`, `dnf`, `zypper`, `pacman` ou `apk`, mas só foi validado com `--dry-run`. Teste de verdade em cada distro antes de confiar (o `su -l gustavo` e o `useradd` dependem de como o proot emula usuários).
- Nas distros de desktop o setup é sempre aplicado ao usuário `gustavo`, e não ao usuário que rodou o script. Para rodar de novo depois, basta executar o script outra vez (por root ou por qualquer usuário com `sudo`, inclusive o próprio `gustavo`). No proot, rode de novo como root.
- Termux não cria usuário.
- O sudo do `gustavo` exige senha. A exceção é a instalação do `paru` no Arch/CachyOS, descrita acima. No proot o `gustavo` recebe o mesmo sudoers, mas o `sudo` só executa se o proot honrar o setuid (o script testa e avisa).
- No proot, a detecção por ptrace só vale para o Arch Linux ARM; nas outras distros ela depende do nome do kernel trazer `proot` (ou de `FORCE_PROOT=1`).
- O `.zshrc` do proot tem `gustavo` fixo no `su - gustavo`; veja a seção do proot.
- O `fastfetch` não existe nos repositórios do Debian 12 e do Ubuntu 22.04. Nessas versões ele aparece como falha e o `fastfetch` na primeira linha do `.zshrc` mostra "command not found" a cada terminal novo.
- O Kitty e as fontes só são instalados em distros. No Termux a fonte é trocada pelo `termux-reload-settings`, sem `fc-cache`.
- Em terminais que não sejam o Kitty, você precisa selecionar **MesloLGS NF** nas preferências do terminal. O `kitty.conf` já aponta para ela.
- O `.zshrc` define `LANG=pt_BR.UTF-8` e `LC_MESSAGES=en_US.UTF-8`. Em instalações mínimas sem esses locales gerados, alguns programas mostram avisos.

## Licença

Apache License 2.0. Veja o arquivo `LICENSE`.
