# Changelog

Mudanças notáveis do `setup.sh` e do repositório. Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); o projeto não usa versões, então as entradas são por data.

## Não lançado (branch `rate-mirrors-alarm`)

### 2026-11-03

#### Adicionado (Arch Linux ARM)

- **`rate-mirrors` no Arch Linux ARM (aarch64), desktop e proot.** Antes a etapa só rodava no Arch puro x86_64 (`ID=arch`). Agora `optimize_mirrors` também roda quando `IS_ALARM=1` e usa o subcomando `archarm`. O pacote não existe no ARM, então `download_rate_mirrors` baixa o binário estático `rate-mirrors-v0.34.1-aarch64-unknown-linux-musl` da release do GitHub, confere o sha256 (fixado em `RATE_MIRRORS_SHA256_AARCH64`) e o executa de um diretório temporário, removido ao sair. Sem `--protocol https` (a lista do ARM é toda `http`) e sem `--max-delay` (opção só do subcomando `arch`).
- **No proot** (`prepare_proot_pacman`) o ranking roda depois do chaveiro e antes do upgrade; o `-Syyu` dele substitui o `-Syu` (pulado quando `PACMAN_SYNCED=1`). Se o `-Syyu` falhar no proot, só avisa (como o `-Syu` já fazia); no desktop continua parando o script.
- Constantes novas: `RATE_MIRRORS_VERSION`, `RATE_MIRRORS_SHA256_AARCH64`, `RATE_MIRRORS_SHA256_X86_64` (as duas últimas só servem a quem rodar o fluxo de download em x86_64; no Arch x86_64 o pacote do `extra` continua sendo usado). `SKIP_MIRRORS=1` e `FORCE_MIRRORS=1` valem para o ARM também.
- `README.md`: seção "Antes de tudo", passo 1 do proot e tabela de variáveis atualizados.

#### Corrigido

- A checagem "a mirrorlist já foi gerada pelo rate-mirrors" procurava `# ARGS: rate-mirrors`, mas o binário da release se chama `rate_mirrors` (com `_`) e aparece com o caminho completo no cabeçalho. Agora casa `# ARGS: .*rate[-_]mirrors`; sem isso o ranking refaria tudo a cada execução no ARM.

#### Decisões e limites

- **Versão e sha256 fixos** de propósito: o binário roda como root, então o download não segue "latest". Para atualizar, troque a versão e os dois hashes (`sha256sum` dos `.tar.gz` da release).
- **Não foi testado num Arch Linux ARM real.** Foi testado com `--dry-run` (ALARM em proot, Arch x86_64, CachyOS que pula, armv7 que avisa) e com um `pacman` falso, baixando e executando de verdade o binário x86_64 da mesma release (download, sha256, extração, subcomando `archarm`, backup da mirrorlist, segunda rodada que pula, sha256 adulterado que recusa, `-Syyu` falhando no proot e no desktop). O binário aarch64 só teve o sha256 conferido, não foi executado. Nessa simulação o teste de velocidade não alcançou os mirrors, então o ranking real (ordem por velocidade) não foi visto.
- Derivadas do Arch que o `rate-mirrors` também suporta (CachyOS, EndeavourOS, Manjaro, Artix) **não** foram incluídas: seguem mantendo a mirrorlist delas.
- O `rate-mirrors` imprime o resultado inteiro no terminal durante o ranking (comportamento dele, já era assim no Arch).

## Antes (branch `termux-proot-archlinuxarm`, PR #10)

### 2026-11-03

#### Adicionado (Termux)

- **`proot-distro` em `TERMUX_EXTRA_PACKAGES`** (junto com o `termux-services`).
- **`termux_proot_distro`.** Depois dos pacotes extras, roda `proot-distro install --name archlinuxarm danhunsaker/archlinuxarm:latest`. Pula se `archlinuxarm` já aparece em `proot-distro list` ou se o `proot-distro` não ficou instalado; se o `install` falhar, avisa e registra a falha no resumo final em vez de parar o script.
- Variáveis novas: `SKIP_TERMUX_PROOT=1`, `TERMUX_PROOT_IMAGE` (padrão `danhunsaker/archlinuxarm:latest`) e `TERMUX_PROOT_NAME` (padrão `archlinuxarm`). Documentadas no `--help` e no README.

- **`sudo` no proot.** Nas distros em proot o `gustavo` agora entra no grupo `wheel`, o `sudo` é instalado (`ensure_sudo`) e liberado por `/etc/sudoers.d/10-gustavo` (`configure_sudo`, mesmo caminho das distros de desktop, validado com `visudo`). Antes o script pulava tudo isso porque o setuid não funciona no proot.
- **`check_proot_sudo`.** No fim da fase do sistema, roda `sudo -n true` como o `gustavo` (via `su`): se executar, ou se só pedir senha, loga sucesso; se falhar por outro motivo (ex.: `effective uid is not 0`), avisa com a mensagem do sudo e manda abrir uma sessão como root. O setup do `gustavo` (`--user-phase`) continua rodando sem `sudo`.

#### Decisões e limites

- **Não foi verificado num proot real se o `sudo` executa**; a documentação do `proot-distro` não fala de setuid. Por isso o teste automático no fim em vez de prometer que funciona. Se falhar, o `sudo` fica instalado e sem uso.
- O `proot-distro` atual instala qualquer imagem OCI por referência (`usuário/imagem:tag`), por isso o "codinome" do danhunsaker é passado direto, com `--name` fixando o nome local. Versões antigas do `proot-distro` não têm `--name`.
- O script não entra no container nem roda o `setup.sh` lá dentro: esse passo continua manual (`proot-distro login archlinuxarm` e `bash setup.sh`).
- Testes simulados: `--dry-run` com `pkg` falso como usuário comum, e a função com um `proot-distro` falso (instala, já instalado, `install` falhando, ausente, `SKIP_TERMUX_PROOT=1`, imagem e nome personalizados). Para o sudo: `--dry-run` com `FORCE_PROOT=1` e `check_proot_sudo` com um `su` falso nos três desfechos (executa, pede senha, `effective uid is not 0`). Nada disso rodou num Termux real nem baixou a imagem de verdade.

## Antes (branch `termux-upgrade-repos`, PR #9)

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
