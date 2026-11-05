# Changelog

Mudanças notáveis do `setup.sh` e do repositório. Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); o projeto não usa versões, então as entradas são por data.

## Não lançado (branch `menu-cli`, a partir da `main`)

### 2026-11-05

#### Adicionado

- **`menu.sh`: menu de linha de comando.** Mostra as opções (setup, simulação, mirrors, reverter temas Minecraft, NVIDIA detectar/instalar/simular, OXWM), roda o script escolhido como processo filho e **volta sempre à tela inicial**, mostrando o código de saída. Também tem reiniciar, desligar (com confirmação; `sudo` ou `doas`) e fechar o terminal atual (SIGHUP no shell que chamou o menu). Lê as respostas de `/dev/tty`.
- **`setup.sh --sem-encerrar`.** Não pergunta "Deseja encerrar a sessão?" no fim. Necessário porque a pergunta fecha o primeiro shell acima do script, que sob o menu seria o próprio menu. O menu usa a flag na opção de setup; fora do menu nada muda.
- `tests/menu.test.sh`: roda o menu com scripts de mentira e confere a flag, o código de saída de um filho que falha, a opção inválida e a recusa do reinício.
- `README.md`: seção "Menu" e linhas na tabela de arquivos.

#### Planejado (não implementado)

- **Menu pela internet com `curl`** (`curl -fsSL <URL> | bash`). O menu já lê de `/dev/tty`, mas ainda acha os scripts pela pasta dele e o `setup.sh` precisa estar em arquivo; a entrada remota terá de clonar o repo (ou baixar o tarball) e rodar o `menu.sh` de dentro dele. Sem URL definida ainda; o ideal é fixar uma tag ou commit. Detalhes no README, em "Planejado".

#### Decisões e limites

- **O menu escolhe o script, não cada etapa.** O `setup.sh` é um bloco só; dividir em etapas escolhíveis exigiria mexer em ~2700 linhas e não foi feito.
- **Não há opção "só instalar os temas Minecraft":** `--temas-minecraft` só responde a pergunta e o resto do setup roda junto. Só a reversão existe como item.
- **Testado:** `bash -n`, `tests/menu.test.sh` e `setup.sh --dry-run --sem-encerrar` num Debian de teste. **Não testado:** reiniciar, desligar e fechar o terminal de verdade; o menu num Termux, Alpine ou WSL reais; as opções 1, 6 e 8 em máquina real.

## Não lançado (branch `mirrors-sh`, em cima da `termux-mirror-rapido`)

### 2026-11-04

#### Adicionado

- **`mirrors.sh` e `setup.sh --mirrors`.** Refazem só a etapa de mirrors depois do setup inicial (pacman: ranking + `pacman -Syyu`; Termux: medição + `pkg --check-mirror update`), sem instalar nem alterar mais nada. O `mirrors.sh` é um atalho de 1 linha para o `setup.sh --mirrors`, então a lógica continua em um lugar só. `--mirrors` liga `FORCE_MIRRORS=1`; aceita `--dry-run`. Outros gerenciadores (apt, dnf, zypper, apk): avisa e sai.
- `README.md`: seção "Ranquear os mirrors de novo", tabelas de arquivos e de opções.

#### Decisões e limites

- **Não duplica código:** extrair as funções para um arquivo à parte exigiria mexer em ~250 linhas do `setup.sh` (que depende de `run`, `log`, `SUDO`, detecção de proot/ALARM). Por isso o `mirrors.sh` só chama o `setup.sh`.
- **Testado:** `bash -n` e `--dry-run` em apt (avisa e sai), Termux simulado e Arch Linux ARM em proot simulado (fluxo completo do rate-mirrors em `[dry]`). **Não testado:** Arch desktop real (a reexecução com sudo repassa `--mirrors`, mas não foi exercitada) nem os ramos de root em máquina real.

## Antes (branch `termux-mirror-rapido`, em cima da `termux-proot-x86_64`)

### 2026-11-04

#### Corrigido (Termux)

- **A escolha do mirror era lenta e parecia travar.** `termux_mirror` testava os mirrors um por vez, com até 8 s de espera cada: com vários fora do ar ou lentos a etapa levava minutos. Agora os testes rodam **em paralelo** (`--connect-timeout 3`, `-m 5`), então a etapa leva no máximo ~5 s.
- O ranking usava `sort -n` no locale do usuário; com `pt_BR` a vírgula decimal ordenava os tempos errado. Agora é `LC_ALL=C sort -n`.
- Mirrors repetidos (a pasta `mirrors` tem links como `default` apontando para um que já está lá) eram contados duas vezes e ocupavam vagas dos 3 do conjunto; agora são deduplicados pela URL.

#### Decisões e limites

- **Testado:** `bash -n` e a função isolada contra servidores locais (um rápido, um lento, um link duplicado, um recusando conexão), com `LANG=pt_BR.UTF-8`: ~1,6 s no total e ordem correta. **Não testado:** o Termux real (a causa dos travamentos que você viu é inferida do código; se continuar travando, mande a saída do script) nem um mirror que descarta pacotes sem responder (o timeout de 3 s cobre, mas não foi simulado).
- Continua medindo latência e não banda (veja o README).

## Antes (branch `termux-proot-x86_64`, em cima da `rate-mirrors-derivadas`)

### 2026-11-04

#### Adicionado (Termux em x86_64)

- **`termux_proot_distro` por arquitetura.** O `danhunsaker/archlinuxarm` só existe para ARM, então num Termux x86_64 (ex.: celular Android emulado) o `proot-distro install` falhava. Agora, se `uname -m` for `x86_64` (ou `amd64`), o padrão vira a imagem oficial `archlinux:latest` com o nome local `archlinux`; em ARM nada muda (`danhunsaker/archlinuxarm:latest`, `archlinuxarm`). `TERMUX_PROOT_IMAGE` e `TERMUX_PROOT_NAME` continuam mandando.
- `README.md`: tabela de variáveis e seção de proot atualizadas.

#### Decisões e limites

- **Só x86_64 ganhou imagem própria.** i686 e ARM de 32 bits seguem com a imagem de ARM (comportamento de antes): se o `install` falhar, o script avisa e registra no resumo final.
- **Testado:** `bash -n` e `--dry-run` simulando o Termux (`TERMUX_VERSION`, `UNAME_M=x86_64` e `aarch64`, e com os dois overrides). **Não testado:** o download e o `login` reais no Termux x86_64, nem se o `setup.sh` dentro do Arch x86_64 do proot é detectado como proot (deve cair no critério do nome do kernel; se não, `FORCE_PROOT=1`).

## Antes (branch `rate-mirrors-derivadas`)

### 2026-11-04

#### Adicionado (mirrors por distro)

- **CachyOS:** `mirrors_cachyos` roda o `cachyos-rate-mirrors` (instala o pacote se faltar), com backup `*.bak` da `mirrorlist` e da `cachyos-mirrorlist`, e fecha com `pacman -Syyu`. Roda sem opções: o script do CachyOS é um wrapper do `rate-mirrors` com opções fixas.
- **EndeavourOS** e **Artix:** passam pelo mesmo fluxo do Arch (`rate-mirrors`), com os subcomandos `arch` e `artix` (`--protocol https --max-delay=21600`). A `endeavouros-mirrorlist` e a `mirrorlist-arch` do Artix não são tocadas.
- **Manjaro:** `mirrors_manjaro` usa o `pacman-mirrors --fasttrack 5` do sistema e fecha com `pacman -Syyu`.
- **Fedora:** `tune_dnf` grava `max_parallel_downloads=10` no `/etc/dnf/dnf.conf` (mantém o valor se já existir). Não liga `fastestmirror`.
- **Plano B do binário:** se `pacman -S rate-mirrors` falhar mesmo depois do `-Syu`, usa `download_rate_mirrors` (versão e sha256 fixos), em vez de desistir.
- Funções auxiliares `mirrors_backup_once` e `mirrors_upgrade` (o `-Syyu` deixou de ser repetido em cada fluxo). Variáveis de teste `CACHYOS_MIRRORLIST_FILE` e `DNF_CONF`.
- `README.md`: seção "Antes de tudo" virou uma tabela por distro; tabela de gerenciadores, de variáveis e proot atualizadas.

#### Corrigido

- `SKIP_MIRRORS` e `FORCE_MIRRORS` não atravessavam o `sudo` na reexecução como root (o `sudo env` só repassava uma lista fixa de variáveis); agora são repassadas.

#### Mudou de comportamento

- No **proot**, `prepare_proot_pacman` também ranqueia mirrors em EndeavourOS, Artix, CachyOS e Manjaro (antes só ALARM e Arch).

#### Decisões e limites

- **Debian e Ubuntu: nada foi implementado, de propósito.** O `rate-mirrors` não lista subcomando para eles e o `apt` não tem o que reordenar sem fixar um mirror. Se quiser, dá para fazer um `netselect-apt` opcional (Debian), mas é decisão sua.
- **Testado:** `bash -n`; `--dry-run` em Arch, EndeavourOS, Artix, CachyOS, Manjaro, Garuda e Fedora; fluxos reais (sem `--dry-run`) com `pacman`, `cachyos-rate-mirrors` e `pacman-mirrors` falsos (backup uma vez só, pulo na segunda rodada, `FORCE_MIRRORS=1`, falha da ferramenta sem `-Syyu`, pacote ausente, `SKIP_MIRRORS=1`); `tune_dnf` em `dnf.conf` com `[main]`, sem `[main]`, vazio, inexistente e com valor já definido; e a linha de comando `artix`/`arch` aceita pelo binário real v0.34.1.
- **Não foi testado em sistema real** (CachyOS, Manjaro, Artix, EndeavourOS, Fedora). O ranking de verdade não foi visto: o ambiente de teste não alcança os mirrors.
- **Não conferi:** o nome do pacote `cachyos-rate-mirrors` nos repositórios do CachyOS (só uso se o comando não existir), se o wrapper grava o cabeçalho `# ARGS:` (sem ele o ranking refaz a cada execução) e se o `rate-mirrors` existe nos repositórios do Artix (se não existir, cai no binário da release).
- O Pamac do Manjaro pode reescrever a mirrorlist toda semana por um timer próprio; o script não mexe nele.

## Antes (branch `rate-mirrors-alarm`)

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
