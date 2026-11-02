# Changelog

Mudanças notáveis do `setup.sh` e do repositório. Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); o projeto não usa versões, então as entradas são por data.

## Não lançado (branch `termux-upgrade-repos`)

### 2026-11-01

#### Adicionado (Termux)

- **Mirror mais rápido (`termux_mirror`).** O `setup.sh` mede o tempo de resposta de cada mirror de `$PREFIX/etc/termux/mirrors`, copia os 3 mais rápidos para `$PREFIX/etc/termux/mirrors-setup`, aponta `chosen_mirrors` para essa pasta e roda `pkg --check-mirror update`. Antes o `pkg` sorteava (com peso) um mirror entre os que respondiam, sem olhar a velocidade. Roda antes do upgrade, para o upgrade já baixar do mirror escolhido. Com mirrors mortos ou sem a pasta `mirrors`, mantém o mirror atual.
- **`termux_upgrade`.** `pkg update` e `pkg upgrade -y` antes de qualquer instalação, com `--force-confdef --force-confold` (o `pkg` repassa os argumentos ao `apt full-upgrade`) para o dpkg manter os seus arquivos de configuração em vez de parar numa pergunta. Se falhar, o script para e sugere `termux-change-repo`.
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

#### Teste 1: Termux da Play Store (`googleplay.2026.10.09`, aarch64, repositório `termux.net`)

- **Funcionou:** `pkg update` e `pkg upgrade` (nada a atualizar numa instalação nova), `x11-repo`, `root-repo` e `tur-repo` habilitados (cada um seguido do `pkg update`), `zsh`, `git`, `curl`, `fastfetch`, `micro`, `fzf`, `zoxide` e `termux-services` (com o `runit`), oh-my-zsh, powerlevel10k e plugins, dotfiles, `EDITOR`/`VISUAL` e a fonte MesloLGS NF. Nenhum pacote falhou.
- **Mirror não exercitado:** esta build **não tem a pasta `$PREFIX/etc/termux/mirrors`** (o `termux-tools` dela é o 3.0.9 e o repositório é o `termux.net`, diferentes dos do F-Droid). O script avisou, manteve o mirror atual e seguiu: só o caminho de fallback foi validado aí.
- **Erro do powerlevel10k:** no primeiro `zsh`, `fetching gitstatusd` terminou em `gitstatus failed to initialize`. Causa **não confirmada**. A hipótese é que o `gitstatusd` baixado em `~/.cache/gitstatus` não executa nessa build: o anúncio oficial de 2024 (discussão #4000 do `termux-app`) diz que ela usa um contorno (`system_linker_exec`) para as restrições de execução do Android 10+, com problemas não resolvidos. Não ocorreu no F-Droid.
- A build da Play Store é um **fork não oficial** (organização `termux-play-store`); pelo mesmo anúncio, as fontes oficiais são o F-Droid e o GitHub.
- O `pkg update` extra depois de cada repositório é redundante nos repositórios que já se atualizam sozinhos na instalação (o `tur-repo` baixa a própria lista), mas é inofensivo.

#### Teste 2: Termux do F-Droid (1.118.3, aarch64)

- **O mirror funcionou num aparelho real:** mediu os mirrors, deixou `mirror.mwt.me`, `mirrors.krnk.org` e `tmx.xvx.my.id` (0,065 a 0,084 s) em `mirrors-setup`, e o `pkg` escolheu `mirrors.krnk.org`.
- **Ganho de velocidade não comprovado:** antes da etapa o `pkg` tinha sorteado `mirrors.cbrx.io` (7,5 MB em 7 s, cerca de 1,1 MB/s); depois, `mirrors.krnk.org` baixou 22,6 MB em 27 s (cerca de 0,8 MB/s). Foi uma execução só, e a diferença de latência entre os 3 escolhidos (19 ms) é ruído.
- **Mirror oficial fora do conjunto:** o CDN oficial (`packages-cf.termux.dev`, peso 10) respondeu "ok", mas não ficou entre os 3 mais rápidos; o conjunto ficou só com mirrors de voluntários. O script ignora o `WEIGHT`.
- **Bug encontrado:** o `pkg upgrade` parou nas perguntas do dpkg sobre `openssl.cnf`, `sources.list` e `bash.bashrc`, porque `DEBIAN_FRONTEND=noninteractive` não cobre arquivos de configuração. O log recebido termina na terceira pergunta, então **não se sabe como essa execução terminou**.

#### Corrigido

- `termux_upgrade` passa `--force-confdef --force-confold` ao `apt`; o `--force-confold` também preserva o `sources.list` com o mirror escolhido.
- README e CHANGELOG afirmavam que o `DEBIAN_FRONTEND=noninteractive` bastava para não haver perguntas do dpkg. Não bastava.
