# Só Quero Facilitar Ae

### Pumba Lá Pumba

Meus dotfiles de terminal em um script que monta tudo em uma máquina nova, seja uma distro Linux ou o Termux.

## Conteúdo

| Caminho | Para que serve |
| ------- | -------------- |
| `setup.sh` | Cria o usuário `gustavo` (distros e proot), instala pacotes, oh-my-zsh, powerlevel10k, plugins, Kitty e fontes, e aplica os dotfiles |
| `Distro Normal/` | Dotfiles para distros Linux de desktop |
| `Distro Proot/` | Dotfiles para distros rodando em proot (proot-distro) |
| `Termux/` | Dotfiles para o Termux |
| `Kitty/` | Configuração do terminal Kitty (só distros de desktop) |

Arquivos de cada pasta:

| Arquivo | Onde existe | O que é |
| ------- | ----------- | ------- |
| `.zshrc` | `Distro Normal/`, `Distro Proot/`, `Termux/` | Configuração do zsh (oh-my-zsh, plugins, zoxide, fastfetch). No proot, quando o root abre um shell, ele pergunta se quer atualizar o sistema e repassa a sessão para o `gustavo` |
| `.p10k.zsh` | `Distro Normal/`, `Distro Proot/`, `Termux/` | Configuração do prompt powerlevel10k |
| `.p10k-ascii.zsh` | `Distro Normal/` | Versão só ASCII do prompt, usada quando `TERM=linux` (console sem fontes especiais) |
| `kitty.conf` | `Kitty/` | Fonte, opacidade e tamanho da janela do Kitty |

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
| Distro em proot (qualquer uma) | Como root (o script detecta o ambiente) | Cria o usuário `gustavo` sem sudo e aplica o setup nele e no root (veja abaixo) |

O script precisa estar salvo em arquivo (`git clone` e `bash setup.sh`). Rodar via `curl ... | bash` não funciona nas distros, porque a segunda fase reexecuta o próprio arquivo.

Para ver tudo o que seria feito sem alterar nada, use `bash setup.sh --dry-run`.

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

## Simulação (--dry-run)

`bash setup.sh --dry-run` (ou `-n`) mostra o que o script faria sem alterar nada, nem precisa de root. Linhas `[dry]` são comandos que seriam executados e linhas `[sim]` são mensagens simuladas. Leituras (checar se um grupo, usuário ou repositório já existe) são feitas de verdade, então a saída reflete o estado atual da máquina. Como o repo não é clonado na simulação, os arquivos de dotfiles aparecem como "copiaria" em vez de comparados com os existentes.

## Distros em proot (proot-distro)

O script detecta sozinho quando está dentro de um proot, em qualquer distro com `apt`, `dnf` ou `pacman` (Debian, Ubuntu, Fedora, Arch Linux ARM e afins). Os critérios são:

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

O nome `gustavo` está fixo nesse `.zshrc` (no `su - gustavo`). Com `NEW_USER=outro` o usuário é criado, mas a troca automática não acontece até você ajustar essa linha.

No Termux, rodar como root continua bloqueado de propósito.

## O que o script faz

Nas distros de desktop, as etapas 1 a 3 rodam como root; depois o script cria o usuário `gustavo` (seção acima) e as etapas 4 a 10 rodam como ele. A etapa 11 (temas Minecraft) e a pergunta final da etapa 12 voltam a rodar como root. No Termux tudo roda direto, sem criar usuário. No proot o fluxo é o da seção anterior (as etapas abaixo se aplicam, menos `paru`, Kitty e fontes).

**Antes de tudo, só no Arch puro (`ID=arch`) de desktop:** instala o `rate-mirrors` (está no repositório oficial `extra`), ranqueia os mirrors, guarda a mirrorlist antiga em `/etc/pacman.d/mirrorlist.bak` (ou `.bak.1`, `.bak.2`...) e roda `pacman -Syyu`. É `-Syyu` e não só `-Syy`: atualizar o banco sem atualizar os pacotes é update parcial e quebra o sistema. CachyOS, EndeavourOS e Arch ARM mantêm a mirrorlist deles. `SKIP_MIRRORS=1` pula a etapa; `FORCE_MIRRORS=1` ranqueia de novo mesmo se a lista já veio do `rate-mirrors`.

1. Detecta o gerenciador de pacotes: `pkg` (Termux), `apt`, `dnf` ou `pacman`.
2. Instala `zsh git curl fastfetch micro fzf zoxide`. Um pacote indisponível não interrompe o script, só aparece na lista de falhas no final.
3. **Só em distros:** instala `kitty` e `fontconfig`.
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

Só em distros de desktop. O script pergunta no começo se você quer instalar; `--temas-minecraft` (ou `MC_THEMES=1`) aceita sem perguntar e `--sem-temas-minecraft` (ou `MC_THEMES=0`) pula. Sem terminal para perguntar, o padrão é não instalar.

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

## Limitações

- O `emerge` (Gentoo) ainda não é suportado.
- Os temas Minecraft e o `--reverter-temas` foram validados com `--dry-run` e com testes em arquivos de exemplo (instalar, reverter e comparar com os originais: `/etc/default/grub`, `mkinitcpio.conf` e `/etc/grub.d`), mas não num boot de verdade. Teste primeiro no Arch com GRUB; Fedora, Debian e Ubuntu só foram escritos a partir da documentação dos dois temas.
- Encerrar a sessão fecha o shell (ou o terminal) que chamou o script; não faz logout da sessão gráfica.
- O modo proot foi escrito para qualquer distro com `apt`, `dnf` ou `pacman`, mas só foi validado com `--dry-run`. Teste de verdade em cada distro antes de confiar (o `su -l gustavo` e o `useradd` dependem de como o proot emula usuários).
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
