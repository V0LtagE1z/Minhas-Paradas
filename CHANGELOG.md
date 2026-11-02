# Changelog

Mudanças notáveis do `setup.sh` e do repositório. Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); o projeto não usa versões, então as entradas são por data.

## Não lançado (branch `termux-upgrade-repos`)

### 2026-11-01

#### Adicionado (Termux)

- **Mirror mais rápido (`termux_mirror`).** O `setup.sh` mede o tempo de resposta de cada mirror de `$PREFIX/etc/termux/mirrors`, copia os 3 mais rápidos para `$PREFIX/etc/termux/mirrors-setup`, aponta `chosen_mirrors` para essa pasta e roda `pkg --check-mirror update`. Antes o `pkg` sorteava (com peso) um mirror entre os que respondiam, sem olhar a velocidade. Roda antes do upgrade, para o upgrade já baixar do mirror escolhido. Com mirrors mortos ou sem a pasta `mirrors`, mantém o mirror atual.
- **`termux_upgrade`.** `pkg update` e `pkg upgrade -y` (com `DEBIAN_FRONTEND=noninteractive`) antes de qualquer instalação. Se falhar, o script para e sugere `termux-change-repo`.
- **`termux_repos`.** Habilita `x11-repo`, `root-repo` e `tur-repo` (pula os já habilitados) e roda `pkg update` de novo para os pacotes novos aparecerem.
- **`termux_extra_packages`.** Instala o `termux-services` (lista editável em `TERMUX_EXTRA_PACKAGES`).
- Variáveis novas: `SKIP_TERMUX_MIRROR`, `TERMUX_MIRROR_COUNT` (padrão 3), `SKIP_TERMUX_UPGRADE` e `SKIP_TERMUX_REPOS`.

#### Documentação

- `README.md`: nova seção "Termux" com a ordem dos passos e as ressalvas, e as variáveis novas na tabela.
- `CHANGELOG.md`: este arquivo.

#### Decisões e limites

- `science-repo`, `game-repo` e `unstable-repo` ficam de fora: foram incorporados ao repositório principal do Termux.
- O `tur-repo` não é oficial; o Termux não dá suporte aos pacotes dele.
- A medição de mirrors olha latência (baixa só o arquivo `Release`), não banda.
- Testes simulados: `--dry-run`, `pkg` e `curl` falsos e um `PREFIX` de mentira (mirrors vivos, mortos e lentos, nenhum mirror respondendo, sem a pasta `mirrors`, `pkg update` falhando).

#### Teste num Termux real (2026-11-01, aarch64, mirror `termux.net`)

- **Funcionou:** `pkg update` e `pkg upgrade` (nada a atualizar numa instalação nova), `x11-repo`, `root-repo` e `tur-repo` habilitados (cada um seguido do `pkg update`), `zsh`, `git`, `curl`, `fastfetch`, `micro`, `fzf`, `zoxide` e `termux-services` (com o `runit`), oh-my-zsh, powerlevel10k e plugins, dotfiles, `EDITOR`/`VISUAL` e a fonte MesloLGS NF. Nenhum pacote falhou.
- **Não exercitado:** a escolha de mirror. Esta instalação **não tem a pasta `$PREFIX/etc/termux/mirrors`**, então o script avisou, manteve o mirror atual (`termux.net`) e seguiu: só o caminho de fallback foi validado de verdade. A medição e o ranking dos mirrors continuam testados apenas com mirrors falsos. A causa de a pasta não existir não foi investigada.
- O `pkg update` extra depois de cada repositório é redundante nos repositórios que já se atualizam sozinhos na instalação (o `tur-repo` baixa a própria lista), mas é inofensivo.
