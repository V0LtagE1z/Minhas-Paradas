# Só Quero Facilitar Ae
### Pumba Lá Pumba

Meus dotfiles de terminal em um script que monta tudo em uma máquina nova, seja uma distro Linux ou o Termux.

## Conteúdo

| Arquivo | Para que serve |
| --- | --- |
| `setup.sh` | Instala pacotes, oh-my-zsh, powerlevel10k, plugins e fontes, e aplica os dotfiles |
| `.zshrc` | Configuração do zsh (oh-my-zsh, plugins, zoxide, fastfetch) |
| `.p10k.zsh` | Configuração do prompt powerlevel10k |
| `.p10k-ascii.zsh` | Versão só ASCII do prompt, usada quando `TERM=linux` (console sem fontes especiais) |

## Como usar

Em uma máquina nova, baixe e rode o script:

```bash
git clone https://github.com/V0LtagE1z/Minhas-Paradas.git ~/Minhas-Paradas
bash ~/Minhas-Paradas/setup.sh
```
## O que o script faz

1. Detecta o gerenciador de pacotes: `pkg` (Termux), `apt`, `dnf` ou `pacman`.
2. Instala `zsh git curl fastfetch micro fzf zoxide`. Um pacote indisponível não interrompe o script, só aparece na lista de falhas no final.
3. No Arch/CachyOS, instala o `paru` (pelo repositório ou compilando o `paru-bin` do AUR).
4. Clona o oh-my-zsh, o powerlevel10k (em `~/powerlevel10k`) e os plugins `zsh-autosuggestions`, `fast-syntax-highlighting` e `zsh-history-substring-search`.
5. Copia `.zshrc`, `.p10k.zsh` e `.p10k-ascii.zsh` para o `$HOME`.
6. Define `EDITOR` e `VISUAL` como `micro` em `~/.zshenv`, se ainda não estiverem definidos.
7. Troca o shell padrão para o zsh.
8. Instala a fonte MesloLGS NF: no Termux como `~/.termux/font.ttf`, nas distros de desktop em `~/.local/share/fonts/MesloLGS-NF`.

## Backups

Se já existir um dos arquivos de configuração e ele for diferente do repo, o original é guardado ao lado dele como `.bak` (por exemplo `~/.zshrc.bak`). Se o `.bak` já existir, o script usa `.bak.1`, `.bak.2` e assim por diante, sem sobrescrever backups antigos.

O script pode ser executado várias vezes: repositórios já clonados só são atualizados, arquivos idênticos ao repo não são copiados de novo e fontes já instaladas são ignoradas.

Como o repo é a fonte da verdade, alterações feitas direto no `~/.zshrc` são sobrescritas na próxima execução (com backup). Edite os arquivos aqui.

## Limitações

- O `emerge` (Gentoo) não é suportado.
- O `fastfetch` não existe nos repositórios do Debian 12 e do Ubuntu 22.04. Nessas versões ele aparece como falha e o `fastfetch` na primeira linha do `.zshrc` mostra "command not found" a cada terminal novo.
- Em desktop, o script instala a fonte, mas você precisa selecionar **MesloLGS NF** nas preferências do seu terminal (no Kitty, `font_family MesloLGS NF`).
- O `.zshrc` define `LANG=pt_BR.UTF-8` e `LC_MESSAGES=en_US.UTF-8`. Em instalações mínimas sem esses locales gerados, alguns programas mostram avisos.

## Licença

Apache License 2.0. Veja o arquivo `LICENSE`.
