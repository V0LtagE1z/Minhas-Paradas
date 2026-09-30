# Só Quero Facilitar Ae

### Pumba Lá Pumba

Meus dotfiles de terminal em um script que monta tudo em uma máquina nova, seja uma distro Linux ou o Termux.

## Conteúdo

| Caminho | Para que serve |
| ------- | -------------- |
| `setup.sh` | Cria o usuário `gustavo` (só em distros), instala pacotes, oh-my-zsh, powerlevel10k, plugins, Kitty e fontes, e aplica os dotfiles |
| `Distro Normal/` | Dotfiles para distros Linux de desktop |
| `Termux/` | Dotfiles para o Termux |
| `Kitty/` | Configuração do terminal Kitty (só distros) |

Arquivos de cada pasta:

| Arquivo | Onde existe | O que é |
| ------- | ----------- | ------- |
| `.zshrc` | `Distro Normal/`, `Termux/` | Configuração do zsh (oh-my-zsh, plugins, zoxide, fastfetch) |
| `.p10k.zsh` | `Distro Normal/`, `Termux/` | Configuração do prompt powerlevel10k |
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
| Distro de desktop | Como root (`su -`) ou como usuário com `sudo` | Cria o usuário `gustavo` e aplica todo o setup nele (veja abaixo) |
| Termux | Como usuário normal | Aplica o setup direto no seu usuário |
| Arch Linux ARM no proot | Como root (o script detecta o ambiente) | Aplica o setup direto, sem criar usuário (veja abaixo) |

O script precisa estar salvo em arquivo (`git clone` e `bash setup.sh`). Rodar via `curl ... | bash` não funciona nas distros, porque a segunda fase reexecuta o próprio arquivo.

Para ver tudo o que seria feito sem alterar nada, use `bash setup.sh --dry-run`.

## Usuário gustavo (distros de desktop)

Nas distros de desktop o script trabalha em duas fases:

1. **Como root:** instala os pacotes do sistema (incluindo `sudo`, se faltar) e cria o usuário:
   - nome `gustavo`, home `/home/gustavo`, shell zsh (registrado em `/etc/shells` se preciso);
   - grupos `wheel`, `audio` e `video` (o `wheel` é criado nas distros que não o têm, como o Debian);
   - sudo liberado por `/etc/sudoers.d/10-gustavo`, validado com `visudo` antes de instalar (a senha continua sendo exigida);
   - `passwd gustavo` para você escolher a senha. Se a senha já estiver definida, ela é mantida.
2. **Como `gustavo`:** o script reexecuta a si mesmo e faz o setup tradicional (paru, oh-my-zsh, powerlevel10k, plugins, dotfiles, Kitty, `EDITOR` e fontes), tudo dentro de `/home/gustavo`.

No Arch/CachyOS, o `gustavo` recebe sudo **sem senha apenas durante a instalação do `paru`** (o `makepkg` precisa disso). O arquivo temporário `/etc/sudoers.d/99-setup-tmp` é removido assim que a fase termina, mesmo se ela falhar.

Se o usuário já existir, o script só ajusta grupos e shell. Para usar outro nome: `NEW_USER=nome bash setup.sh`.

## Simulação (--dry-run)

`bash setup.sh --dry-run` (ou `-n`) mostra o que o script faria sem alterar nada, nem precisa de root. Linhas `[dry]` são comandos que seriam executados e linhas `[sim]` são mensagens simuladas. Leituras (checar se um grupo, usuário ou repositório já existe) são feitas de verdade, então a saída reflete o estado atual da máquina. Como o repo não é clonado na simulação, os arquivos de dotfiles aparecem como "copiaria" em vez de comparados com os existentes.

## Arch Linux ARM no proot (proot-distro)

O script detecta sozinho quando está no Arch Linux ARM rodando dentro de um proot (`ID=archarm` em `/etc/os-release` e processo rastreado por ptrace). Nesse modo ele:

1. Aceita rodar como root e não usa `sudo`.
2. Ajusta o `/etc/pacman.conf` (com backup em `pacman.conf.bak`): comenta `CheckSpace` e `DownloadUser` e ativa a opção de desligar o sandbox do pacman (`DisableSandbox` no pacman 7.0; `DisableSandboxFilesystem` e `DisableSandboxSyscalls` no 7.1+).
3. Inicializa o chaveiro (`pacman-key --init` e `--populate archlinuxarm`), se ainda não estiver inicializado.
4. Roda `pacman -Syu` uma vez (rootfs de ARM costuma ser antigo) e reaplica o ajuste do `pacman.conf`, porque o pacman novo pode trazer outras opções.
5. Gera os locales `pt_BR.UTF-8` e `en_US.UTF-8`, usados pelo `.zshrc`.
6. **Não** instala `paru`, Kitty, `fontconfig` nem fontes. A fonte é a do próprio Termux.
7. Aplica os dotfiles de `Distro Normal/`.

O proot não cria o usuário `gustavo`: tudo é aplicado ao próprio root.

Se a detecção falhar, force com `FORCE_ALARM_PROOT=1 bash setup.sh`.

No Termux, rodar como root continua bloqueado de propósito.

## O que o script faz

Nas distros de desktop, as etapas 1 a 3 rodam como root; depois o script cria o usuário `gustavo` (seção acima) e as etapas 4 a 10 rodam como ele. No Termux e no proot tudo roda direto, sem criar usuário.

1. Detecta o gerenciador de pacotes: `pkg` (Termux), `apt`, `dnf` ou `pacman`.
2. Instala `zsh git curl fastfetch micro fzf zoxide`. Um pacote indisponível não interrompe o script, só aparece na lista de falhas no final.
3. **Só em distros:** instala `kitty` e `fontconfig`.
4. No Arch/CachyOS, instala o `paru` (pelo repositório ou compilando o `paru-bin` do AUR).
5. Clona o oh-my-zsh, o powerlevel10k (em `~/powerlevel10k`) e os plugins `zsh-autosuggestions`, `fast-syntax-highlighting` e `zsh-history-substring-search`.
6. Copia os dotfiles para o `$HOME`, cada ambiente da sua pasta:
   - Termux: `Termux/.zshrc` e `Termux/.p10k.zsh`.
   - Distros: `Distro Normal/.zshrc`, `.p10k.zsh` e `.p10k-ascii.zsh`.
7. **Só em distros:** copia `Kitty/kitty.conf` para `~/.config/kitty/kitty.conf`.
8. Define `EDITOR` e `VISUAL` como `micro` em `~/.zshenv`, se ainda não estiverem definidos.
9. Troca o shell padrão para o zsh. Nas distros de desktop isso já foi feito ao criar o usuário (`usermod -s`).
10. Instala a fonte MesloLGS NF:
    - Termux: baixa só a Regular, como `~/.termux/font.ttf`.
    - Distros: baixa Regular, Bold, Italic e Bold Italic (do repo `romkatv/powerlevel10k-media`) para `~/.local/share/fonts/MesloLGS-NF` e atualiza o cache com `fc-cache`.

## Backups

Se já existir um dos arquivos de configuração e ele for diferente do repo, o original é guardado ao lado dele como `.bak` (por exemplo `~/.zshrc.bak`). Se o `.bak` já existir, o script usa `.bak.1`, `.bak.2` e assim por diante, sem sobrescrever backups antigos. Isso vale também para o `kitty.conf`.

O script pode ser executado várias vezes: repositórios já clonados só são atualizados, arquivos idênticos ao repo não são copiados de novo e fontes já instaladas são ignoradas.

Como o repo é a fonte da verdade, alterações feitas direto no `~/.zshrc` ou no `kitty.conf` são sobrescritas na próxima execução (com backup). Edite os arquivos aqui.

## Limitações

- O `emerge` (Gentoo) ainda não é suportado.
- O modo proot foi feito para o Arch Linux ARM. Outras distros em proot (Debian, Ubuntu etc.) não têm modo próprio: o script as trata como distro de desktop, o que não foi testado.
- Nas distros de desktop o setup é sempre aplicado ao usuário `gustavo`, e não ao usuário que rodou o script. Para rodar de novo depois, basta executar o script outra vez (por root ou por qualquer usuário com `sudo`, inclusive o próprio `gustavo`).
- Termux e proot não criam usuário.
- O sudo do `gustavo` exige senha. A exceção é a instalação do `paru` no Arch/CachyOS, descrita acima.
- O `fastfetch` não existe nos repositórios do Debian 12 e do Ubuntu 22.04. Nessas versões ele aparece como falha e o `fastfetch` na primeira linha do `.zshrc` mostra "command not found" a cada terminal novo.
- O Kitty e as fontes só são instalados em distros. No Termux a fonte é trocada pelo `termux-reload-settings`, sem `fc-cache`.
- Em terminais que não sejam o Kitty, você precisa selecionar **MesloLGS NF** nas preferências do terminal. O `kitty.conf` já aponta para ela.
- O `.zshrc` define `LANG=pt_BR.UTF-8` e `LC_MESSAGES=en_US.UTF-8`. Em instalações mínimas sem esses locales gerados, alguns programas mostram avisos.
- O `Termux/.zshrc` roda `pkg update` e `pkg upgrade` a cada terminal novo, o que deixa a abertura lenta.

## Licença

Apache License 2.0. Veja o arquivo `LICENSE`.
