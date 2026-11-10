# Changelog

Mudanças notáveis do `setup.sh` e do repositório. Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); o projeto não usa versões, então as entradas são por data.

## Não lançado (branch `menu-tela-alternativa-claude-atalho`, a partir da `main`)

### 2026-11-09

#### Corrigido

- **`menu.sh`: o menu não pisca mais e não deixa vestígios no terminal.** Antes cada tecla limpava a tela inteira (`ESC[2J`) e desenhava tudo de novo, o que piscava, e o último quadro ficava no terminal ao sair. Agora o menu usa a **tela alternativa** do terminal (`ESC[?1049h`/`l`), a mesma do `nmtui` e do `alsamixer`: ao sair, com `q`, em "Sair do menu" ou com Ctrl+C, o terminal volta exatamente como estava. Cada quadro é montado inteiro e desenhado de uma vez por cima do anterior (cursor no canto, "apagar até o fim da linha" em cada linha e "apagar o resto" no fim), sem limpar a tela. O cursor fica escondido o tempo todo e volta ao sair. O diálogo "Tem certeza" usa o mesmo desenho.
- **Os scripts rodam na tela normal.** Ao escolher um item o menu sai da tela alternativa, roda o script e, depois do "Enter para voltar ao menu...", entra de novo. Assim a saída do `setup.sh`, do `nvidia.sh` etc. fica no terminal e no scrollback (não some com o menu), e só o menu em si não deixa rastro. `TERM=dumb` e `NO_COLOR` continuam sem nenhum código de terminal (cada quadro sai embaixo do anterior).
- **Título e linha de fim em volta de cada comando.** Como a saída dos scripts fica na tela normal, ela se misturava com o resto do terminal e não dava para ver onde um comando começava. Agora o menu imprime um título (`━━ ▶ <item> ━━━━`, na largura do menu, até 72 colunas) e, embaixo, o comando exato (`$ bash setup.sh --dry-run --sem-encerrar`); no fim, uma linha `━━ ✔ <script> terminou (código 0) ━━━━` (`✖` se o código não for 0), no lugar do antigo `[menu] <script> terminou (código N).`. Reiniciar, Desligar e o aviso de "Fechar este terminal" também mostram o título; "Sair do menu" não deixa nada. O tamanho do terminal, que só o `layout` lia, virou a função `size`, usada também pelo título.

#### Adicionado

- **Super+C abre o Claude Desktop e o Super+I abre o editor (codium).** No padrão do Caelestia o Super+C é do editor (`kbEditor = "SUPER + C"`, `editor = "codium"`, conferido no `variables.lua` e no `hyprctl binds` da sua máquina). Então são duas mudanças juntas: `.config/caelestia/hypr-vars.lua` ganha `kbEditor = "SUPER + I"` (o codium muda de tecla; nenhum atalho padrão usa Super+I) e `.config/caelestia/hypr-user.lua` ganha `hl.bind("SUPER + C", hl.dsp.exec_cmd("claude-desktop"))`. Só a bind sem mover o `kbEditor` deixaria duas binds no Super+C. Reaplique com `bash caelestia-setup.sh --so-atalhos` e entre de novo no Hyprland. Uma versão anterior desta branch tinha o `claude-desktop` no Super+I; foi trocada a seu pedido.
- **Testes.** `tests/menu.test.sh`: com `TERM=xterm`, o menu entra e sai da tela alternativa uma vez só, nunca emite `ESC[2J`, apaga só até o fim de cada linha, roda o script fora da tela alternativa e, num pty de verdade (Python), sai dela com Ctrl+C. Também confere a ordem título, comando, saída e linha de fim (✖ para o `setup.sh` de mentira, que sai com 3; ✔ para o `nvidia.sh`), o título de Reiniciar e que "Sair do menu" não imprime título. `tests/caelestia.test.sh`: confere o `kbEditor` do `hypr-vars.lua` e, contra a API `hl` de mentira, que o Super+C abre o `claude-desktop` e que o `hypr-user.lua` não faz bind no Super+I. Os testes novos falham no `menu.sh` e no `hypr-user.lua` antigos.

#### Não testado

- Nada no Hyprland real nem com o `claude-desktop` instalado. Não confirmei que a bind do `hypr-user.lua` convive com a do Caelestia no Super+C só por mover o `kbEditor`: confira com `hyprctl binds` (deve haver uma entrada `C` com Super e nenhuma duplicada) e `hyprctl configerrors`. Os terminais que você usa (Kitty, Alacritty, Termux) não foram abertos: o teste confere os códigos emitidos, não o que cada terminal desenha. Redimensionar a janela continua só tendo efeito na próxima tecla (como antes).

## Não lançado (branch `caelestia-setup`, a partir da `main`)

### 2026-11-07

#### Adicionado

- **`caelestia-setup.sh`: instala o Caelestia e aplica os seus atalhos.** Só Arch e derivadas. Instala o `caelestia-cli` (AUR, com `paru` ou `yay`) se o comando `caelestia` não existe, roda o instalador oficial `caelestia install` (interativo) e depois copia `.config/caelestia/hypr-vars.lua` e `hypr-user.lua` para `~/.config/caelestia/`. Arquivo existente que difere vira `<nome>.bak-<data>_<hora>`; igual, fica como está. Opções: `--so-atalhos` (só copia os dois arquivos, sem instalar nada) e `--dry-run`/`-n`. Confere os dois `.lua` antes de instalar qualquer coisa.
- **A sua config, em `.config/caelestia/`** (os arquivos reais que você commitou na `main`: `hypr-vars.lua`, `hypr-user.lua` e `shell.json`; o script copia os três). `hypr-vars.lua`: `kbTerminal = "SUPER + RETURN"` e o navegador `flock -n /tmp/zen.lock zen-browser || true`. `hypr-user.lua`: mouse `flat`, teclado `br` e o monitor `eDP-1` em 1920x1080@60. `shell.json`: transparência ligada e o logo `/home/gustavo/Pictures/CachyOS.svg`. Uma primeira versão minha desses arquivos (kitty, editor em Super+Alt+C, Claude em Super+C) era reconstruída de memória e foi descartada; vale a sua. O arquivo vazio `.config/caelestia/w`, que veio da `main`, não é copiado.
- **`caelestia-setup.sh` baixa o logo do shell.** O `shell.json` usa `/home/gustavo/Pictures/CachyOS.svg`, que não estava no repo: o script baixa o SVG (`https://cdn.jsdelivr.net/gh/glincker/thesvg@main/public/icons/cachyos/default.svg`, com `curl` ou `wget`) para `~/Pictures/CachyOS.svg` se ainda não existe. Falhar só avisa. Limites (marcados no script com `shortcut:`): a URL usa `@main`, que muda, e o `shell.json` fixa `/home/gustavo`, então o logo só aparece no usuário `gustavo`.
- **`menu.sh`: item "Caelestia: instalar + atalhos"** (com "Tem certeza"). Na rota sem clone (`curl | bash`) baixa o script e os três arquivos de `.config/caelestia/`; nada além disso.
- **`tests/caelestia.test.sh`.** `pacman`, `paru` e `caelestia` de mentira num `HOME` temporário: ordem das chamadas (paru, install, atalhos), backup do arquivo que o instalador deixa, `--so-atalhos`, caelestia já instalado, sem helper, sem pacman, arquivo faltando, opção desconhecida, `--dry-run` e o logo (baixado uma vez só, sem criar nada no `--dry-run`, e com o download falho só avisa e apaga o arquivo parcial). Valida o `shell.json` como JSON e, com o `lupa`, carrega os dois `.lua` contra uma API `hl` de mentira e confere os valores. Não confere os nomes das chaves do `hypr-vars.lua` (uma chave errada o Caelestia ignora em silêncio): isso era feito contra o `variables.lua` da `.config/hypr/`, que foi apagada.

#### Alterado

- `tests/menu.test.sh`: o item novo desloca Reiniciar e Desligar (índices 10 e 11), a margem de cima do menu centrado (8 linhas em 100x40) e ganha dois testes (item local e rota remota com os três arquivos).
- README: seção "Caelestia", tabela de arquivos, tabela do menu, rota sem clone, testes e limitações; sem a `.config/hypr/`, que você apagou.

#### Removido

- `.config/hypr/` (18 arquivos, apagados por você): o `caelestia install` já coloca essa config e ela não tinha nenhum dos seus atalhos.

#### Testado e não testado

- **Testado:** `bash -n` e `shellcheck` (sem avisos) nos arquivos novos e no `menu.sh`; `tests/caelestia.test.sh`, `tests/menu.test.sh` e `tests/dotfiles.test.sh`. Os testes novos foram validados com mutantes (um defeito inserido de propósito em cada comportamento faz o teste falhar: backup, ordem, checagem do pacman, `caelestia` já instalado, chave com nome errado, JSON quebrado, monitor, dependências do menu remoto, item do menu, logo baixado de novo e arquivo parcial do logo).
- **Não testado:** nada num Arch de verdade, com `paru`, com o `caelestia install` real nem com o Hyprland carregando os dois `.lua` (a API `hl` do teste é de mentira). O `kb_variant = ",abnt2"` do seu `hypr-user.lua` tem uma vírgula na frente; não mexi (o `br` puro já é ABNT2, então deve dar no mesmo). A URL do logo (jsDelivr) não foi aberta: o ambiente de desenvolvimento a bloqueia; se o download falhar, o script só avisa. O `caelestia install` não tem opção documentada para rodar sem perguntas, então fica interativo.
- **Não mexi:** nos seus arquivos de `.config/caelestia/`.

## Não lançado (branch `oxwm-wallpaper-imagens`, a partir da `menu-centralizado-wallpapers`)

### 2026-11-07

#### Corrigido

- **OXWM acha o wallpaper em `Imagens` também.** O `config.lua` fixava `/home/gustavo/Pictures/Wallpapers/Luna E Terra.jpg`; como o `setup.sh` agora copia para `Imagens/Wallpapers` em sistema em português, o `feh` falhava e o fundo ficava vazio. O autostart agora procura em `$HOME/Pictures/Wallpapers` e depois em `$HOME/Imagens/Wallpapers` (`Pictures` vence se as duas tiverem), e usa o `$HOME` de quem está logado em vez de `/home/gustavo` fixo. A variável `wallpaper` virou o caminho relativo `Wallpapers/Luna E Terra.jpg`. Sem a imagem em nenhuma das pastas, o `feh` não roda.
- README: a seção do OXWM citava `Luna E Terra.png`, mas o arquivo do repo é `.jpg`.
- **Testado:** a string do autostart, avaliada em Lua (`lupa`) a partir do próprio `config.lua` e executada com `sh -c` e um `feh` de mentira: só `Pictures`, só `Imagens`, as duas (`Pictures` vence) e nenhuma (não chama o `feh`), todas com o espaço no nome. **Não testado:** o OXWM de verdade carregando o `config.lua` e rodando o autostart (não há OXWM nem X11 aqui), e se o OXWM executa a string por `sh -c` do mesmo jeito que o comando anterior (usei o mesmo formato `sh -c`).

## Não lançado (branch `menu-centralizado-wallpapers`, a partir da `caminhos-reorganizados`)

### 2026-11-07

#### Alterado

- **`menu.sh`: a caixa do menu fica centrada no terminal.** Antes ficava colada na esquerda. Agora a margem esquerda é `(colunas - largura) / 2` e a de cima é `(linhas - altura) / 2`, para o menu e para a tela "Tem certeza"; a linha de teclas acompanha a caixa. A largura continua de 36 a 72 colunas. Terminal mais baixo que o menu começa no topo; sem tty (teste) usa `COLUMNS`/`LINES`. A posição é recalculada a cada tela desenhada (a cada tecla); o menu não trata o redimensionamento da janela na hora.

#### Adicionado

- **`setup.sh` copia os wallpapers.** No setup completo (como `gustavo`) e em `--wallpapers` (novo, só isso), copia as imagens da pasta `Wallpapers/` do repo para `<Imagens|Pictures>/Wallpapers` do `HOME`. A pasta vem do `xdg-user-dir PICTURES` se estiver configurada; senão `Imagens` ou `Pictures`, a que existir; senão `Imagens` em sistema em português e `Pictures` nos outros. Só imagens (`jpg`, `jpeg`, `png`, `webp`, `gif`, `bmp`, `avif`, `tif`, `tiff`); não sobrescreve arquivo existente; só em distros de desktop com interface gráfica (no WSL, proot e Termux não faz nada). Sem clonar, lista a pasta pela API do GitHub (60 consultas por hora por IP, sem token) e baixa cada imagem do `raw`; falha vira aviso e entra na lista do fim. `--dry-run` mostra o destino sem baixar. `--dotfiles` sozinho não copia wallpapers.

#### Testado e não testado

- **Testado:** `bash -n` em `menu.sh`, `setup.sh` e nos testes; `tests/menu.test.sh` (caixa centrada em 100x40, sem margem em 30x10) e um render real num pty de 100x30 (14 colunas de margem, 4 linhas em cima); `tests/dotfiles.test.sh` (pasta Imagens/Pictures por `LANG`, por `locale.conf`, por pasta existente e por XDG; filtro de extensão, também em maiúscula; não sobrescreve; API fora do ar; `DOTFILES_REF`; `--dry-run`; proot; e o ramo com repo clonado, usando um repo git local). Os testes novos foram validados com mutantes (um defeito inserido de propósito em cada comportamento faz o teste falhar). O teste do clone pegou um bug meu: imagem com extensão maiúscula (`.PNG`) era ignorada.
- **`shellcheck` 0.11:** sem aviso de tipo novo nos arquivos alterados. O `setup.sh` passou de 49 para 57 ocorrências do SC2031 (nota que ele já tinha) e o teste ganhou uma nota SC2012 sobre um `ls`.
- **Testado com rede real:** `setup.sh --wallpapers` como usuário comum, contra a API e o `raw` do GitHub (ref `main`): baixou `Luna E Terra.jpg` (140145 bytes, mesmo hash do git da imagem do repo) em `Pictures/Wallpapers`, e a segunda execução manteve o arquivo.
- **Não testado:** o `xdg-user-dir` de verdade (o teste usa um de mentira), o idioma pt_BR de verdade (só por arquivos e `LANG` simulados) e nenhum ambiente real (Termux, proot, Alpine, WSL, distros de desktop).
- **Não mexi (nesta branch):** o `config.lua` do OXWM continuava fixo em `Pictures`; resolvido na branch `oxwm-wallpaper-imagens`, logo abaixo.

## Não lançado (branch `caminhos-reorganizados`, a partir da `main`)

### 2026-11-06

#### Corrigido

- **Scripts acompanham a nova organização de pastas do repo.** O `Kitty/kitty.conf` passou para `.config/kitty/kitty.conf` e o `config.lua` do OXWM para `.config/oxwm/config.lua`. `setup.sh` (`DIR_KITTY`, usado por `--dotfiles` e pelo setup completo) agora baixa o `kitty.conf` do caminho novo; `oxwm-setup.sh` lê a config de `.config/oxwm/` ao lado do script (a mensagem de erro mostra o caminho esperado); `menu.sh` baixa `.config/oxwm/config.lua` na rota sem clone, criando a subpasta na pasta temporária.
- Comentários de `Termux/Backup_Termux.sh` e `Termux/Backup-Restore.sh` com os nomes atuais dos arquivos.
- Testes ajustados: `tests/dotfiles.test.sh` espera a URL `.config/kitty/kitty.conf`; `tests/menu.test.sh` confere que o OXWM baixa `.config/oxwm/config.lua`.
- **Testado:** `bash -n` em todos os `.sh`; `tests/menu.test.sh` e `tests/dotfiles.test.sh`; `oxwm-setup.sh --sem-sistema --dry-run` (acha a config; sem a pasta, para com erro claro); `setup.sh --dotfiles --dry-run` (URL nova do Kitty). **Não testado:** `shellcheck` (não instalado aqui), o download real do `kitty.conf` e do `config.lua` da `main` depois do push, Termux, proot, Alpine e WSL reais.
- **Não mexi:** `Backup-Restore.sh` ainda procura `Termux-Backup.tar.zst` por padrão, nome diferente do que o `Backup_Termux.sh` gera (já documentado no README).

## Não lançado (branch `dotfiles-sem-clone`, a partir da `main`)

### 2026-11-06

#### Alterado

- **`menu.sh` sem clone baixa só o que você escolhe, e só na hora.** Antes baixava o tarball do repo inteiro (~280 KB compactado: README, imagem, dotfiles de todos os ambientes, scripts que você nem ia usar) ao abrir. Agora **não baixa nada ao abrir**; ao escolher um item, baixa só o script dele de `raw.githubusercontent.com` para a pasta temporária (que some ao sair). O que o script usa ao lado vem junto: `mirrors.sh` traz o `setup.sh`, `oxwm-setup.sh` traz o `config.lua`. Cada arquivo é baixado uma vez por sessão. Não precisa mais de `tar`, só de `curl` ou `wget`. Download que falha: mensagem de erro e o menu continua (antes o menu saía com código 1 ao abrir); sem `curl` nem `wget`: erro antes de abrir.
- **`setup.sh` não clona mais o repo inteiro para pegar os dotfiles.** `deploy_dotfiles` e `deploy_kitty` baixam só os arquivos do ambiente (`Distro Normal/`: `.zshrc`, `.p10k.zsh`, `.p10k-ascii.zsh`; `Distro Proot/` e `Termux/`: `.zshrc`, `.p10k.zsh`; mais `Kitty/kitty.conf` em desktop) de `raw.githubusercontent.com`, com a URL derivada do `REPO_URL`. O backup `.bak`/`.bak.N` e a comparação com o arquivo existente continuam iguais. Cai no clone (como antes) com `--clonar-repo`/`DOTFILES_CLONE=1`, com `REPO_URL` fora do GitHub, ou se não houver `curl` nem `wget`.
- **`DOTFILES_REF`** (padrão `main`) escolhe a branch, tag ou commit dos dotfiles. O `menu.sh` o define igual ao `MENU_REF`, então scripts e dotfiles saem do mesmo ref. Passa pelo `sudo`/`su` junto com o `REPO_URL` (as três reexecuções do `setup.sh`).
- Em `--dry-run` nada é baixado: os dotfiles aparecem como `copiaria <URL> -> <destino>`.

#### Adicionado

- **`setup.sh --dotfiles`** (e o item **"Dotfiles: só aplicar"** do menu, com "Tem certeza"): só aplica os dotfiles e o `kitty.conf` no `HOME` de quem roda, sem pacotes, usuário nem `sudo`. Recusa root fora do proot (em `--dry-run` aceita). Um arquivo que falha ao baixar gera aviso com a URL e entra na lista de falhas; o arquivo que já estava no `HOME` não é tocado.
- **`--clonar-repo`** (`DOTFILES_CLONE=1`): o comportamento antigo, para quem quer a pasta `~/Minhas-Paradas` (editar os dotfiles e dar commit, rodar o `mirrors.sh` dela).
- `tests/dotfiles.test.sh`: `curl` de mentira que serve os arquivos da pasta do repo; confere as URLs (com `%20`), que só os arquivos do ambiente são baixados, backup `.bak` e `.bak.1`, `DOTFILES_REF`, download que falha, simulação sem escrita, recusa de root e queda no clone.
- `tests/menu.test.sh`: a rota remota agora confere que nada é baixado ao abrir, que só o script escolhido (e suas dependências) é baixado, uma vez só, com o ref certo, que `DOTFILES_REF` chega ao script, que o download que falha não derruba o menu e o erro sem `curl`/`wget`. Os índices dos itens mudaram (o item novo é o terceiro).
- `README.md`: seção "Só os dotfiles", opções e variáveis novas, menu, "Rodar sem clonar", mirrors, simulação e limitações.
- `README.md`, "Como usar": agora começa por um "Uso rápido" (`git clone` + `bash setup.sh`, e o `curl ... | bash` do menu) e deixa as opções extras (`--dry-run`, `--dotfiles`, `--mirrors`, `--clonar-repo`) numa subseção "Opções adicionais" logo abaixo.

#### Decisões e limites

- **Mudança de comportamento: `~/Minhas-Paradas` deixa de existir depois do setup.** O `mirrors.sh` ali dentro, que o README mandava rodar, some junto; sem a pasta, use o item "Ranquear os mirrors" do menu (baixa o `mirrors.sh` e o `setup.sh`) ou `--clonar-repo`.
- **A economia é pequena em bytes e maior em disco e requisições inúteis.** Medido neste repo: tarball inteiro 283 KB compactado; todos os scripts juntos 70 KB. O que muda de verdade: não baixar README (60 KB), a imagem (140 KB), os dotfiles dos outros ambientes e os scripts não usados, e não deixar um clone de ~1 MB no disco. Em troca, há uma requisição por arquivo em vez de uma só (com `--retry 3` e timeout de 20 s cada).
- **Sem checksum, e cada arquivo vem na hora em que é usado.** Se a `main` mudar no meio de uma sessão, scripts de commits diferentes se misturam. Fixar um commit em `MENU_REF`/`DOTFILES_REF` evita; o tarball antigo tinha o mesmo problema só entre a URL do `menu.sh` e o `MENU_REF`.
- **`--dotfiles` supõe zsh, oh-my-zsh e powerlevel10k já instalados** (o `.zshrc` carrega os dois): é para atualizar os arquivos, não para montar uma máquina nova.
- **O que o `setup.sh` copia continua o mesmo:** os `*.auto.conf` do Kitty e o `Termux/.zsh_history` seguem de fora, como antes.
- **Testado:** `bash -n`; `tests/menu.test.sh` e `tests/dotfiles.test.sh`; sete mutantes (sem `%20`, ref fixo, sem backup, sem a dependência do `mirrors.sh`, sem a do OXWM, sem `DOTFILES_REF` no menu, baixar tudo) e todos derrubam os testes; `setup.sh --dry-run` completo em desktop e em proot simulados; `shellcheck` sem avisos novos; download real de `Distro Proot/.zshrc` e `.p10k.zsh` de `raw.githubusercontent.com` (`main`) num `HOME` temporário, idênticos aos do repo; menu pelo pipe, com o `curl` de verdade, baixando só o `setup.sh` da `main` e apagando a pasta temporária. **Não testado:** Termux, proot real, Alpine, WSL e uma distro de desktop de verdade (o `--dotfiles` real como usuário normal foi simulado só com `--dry-run`); a queda no clone por falta de `curl`/`wget` só em simulação; o ref `DOTFILES_REF` com o menu real apontando para esta branch (só depois do push).

## Não lançado (branch `menu-remoto`, em cima da `menu-cli`)

### 2026-11-06

#### Adicionado

- **`menu.sh` roda sem `git clone`** (`curl -fsSL https://raw.githubusercontent.com/V0LtagE1z/Minhas-Paradas/main/menu.sh | bash`). Sem um `setup.sh` ao lado do menu (`curl | bash`, ou um `menu.sh` baixado sozinho), ele baixa o tarball do repo de `codeload.github.com` com `curl` (ou `wget`) e `tar`, numa pasta temporária (`$TMPDIR`, ou `/tmp`; o Termux não tem `/tmp`), usa os scripts de lá e apaga a pasta ao sair (também se o download falhar). `MENU_REF` escolhe tag, branch ou commit (padrão `main`). Rodando de um clone, nada muda.
- **Os scripts chamados pelo menu recebem o terminal como stdin** (`bash script <&3`). Sem isso o `curl | bash` não funcionava: o `setup.sh` (`[[ ! -t 0 ]]`) e o `nvidia.sh` recusam rodar sem terminal, e o stdin do menu é o pipe.
- **`curl | sh`** (sem bash, ou o binário do shell como `$0`): em vez de tentar `exec bash <o binário do sh>`, o menu avisa e mostra o comando com `| bash`. A mensagem de "bash não instalado" também mostra esse comando quando não há arquivo para rodar de novo.
- Testes em `tests/menu.test.sh`: rota remota com `curl` de mentira e o script entrando pelo pipe (confere a URL do tarball com `MENU_REF`, que o script chamado roda com o terminal como stdin, e que a pasta temporária some), download que falha (código 1, mensagem, nada sobra) e `curl | sh`.
- `README.md`: seção "Rodar sem clonar (`curl | bash`)" no lugar do "Planejado"; ajustes na tabela de arquivos e na nota sobre `curl | bash` do `setup.sh`.

#### Decisões e limites

- **Tarball em vez de `git clone`:** o pedido era não precisar de clone, e o `git` pode nem estar instalado numa máquina nova. Custo: sem histórico, e `curl`/`wget` + `tar` viram requisito só da rota remota (o Termux e as distros comuns já os têm; no Alpine o `busybox` traz `wget` e `tar`).
- **Sem checksum:** a rota remota executa o que o GitHub entregar para o `MENU_REF`. Com `main`, é o que estiver lá na hora; só um commit completo é imutável. A URL e o `MENU_REF` têm de apontar para o mesmo ref (a URL traz o `menu.sh`, `MENU_REF` traz o resto); o menu não tem como descobrir a URL de onde foi lido.
- **Enquanto o `menu.sh` não estiver na `main`**, a URL da `main` dá 404: use o nome da branch na URL e em `MENU_REF` (por exemplo `.../menu-remoto/menu.sh | MENU_REF=menu-remoto bash`).
- **O `setup.sh` continua clonando o repo para `~/Minhas-Paradas`** (dotfiles), com o `git` que ele instala; não reaproveita a pasta temporária do menu.
- **Testado:** `bash -n`; `tests/menu.test.sh`; shellcheck (só avisos informativos, um deles já existia); `bash <(curl ...)` (com `cat` no lugar do curl); download real do tarball do GitHub pelo pipe, com `curl` e sem `curl` (`wget`): rodou o `nvidia.sh` de dentro da pasta temporária, que sumiu ao sair; ref inexistente (404 → mensagem e código 1, nada sobra); `dash menu.sh` num arquivo normal reexecuta em bash. **Não testado:** Termux, proot, Alpine (`wget` do busybox) e WSL reais; o setup completo, o NVIDIA instalar e o OXWM por essa rota.

## Não lançado (branch `menu-cli`, a partir da `main`)

### 2026-11-05

#### Adicionado

- **`menu.sh`: menu em tela cheia (TUI), em bash puro.** Caixas de bordas arredondadas ("Minhas-Paradas", "Sistema", "Descrição"), seleção destacada com `❯`, cor salmão, navegação por `↑`/`↓` (ou `k`/`j`) e `Enter`; `q` sai. Cada item roda o script escolhido como processo filho e **volta sempre à tela inicial**, mostrando o código de saída. Itens: setup, simulação, mirrors, reverter temas Minecraft, NVIDIA detectar/instalar/simular, OXWM, reiniciar, desligar, fechar o terminal atual (SIGHUP no shell que chamou o menu) e sair. Sem dependência nova (nada de `dialog`/`whiptail`/`gum`: tem de funcionar no Termux e no Alpine). A largura segue o terminal (36 a 72 colunas, cabe no Termux em pé). Lê as teclas de `/dev/tty`. As teclas de letra do menu antigo (`1` a `8`, `r`, `d`, `e`) deixaram de existir.
- **"Tem certeza que deseja <ação>?"** Diálogo com botões `Sim`/`Não` (`←`/`→`, `Enter`; `s`/`y` confirma; `n`, `q` e `Esc` cancelam). **O padrão é Não**, então `Enter` direto cancela. Vale para os itens que alteram o sistema (setup, mirrors, reverter temas, instalar NVIDIA, instalar OXWM, reiniciar, desligar, fechar o terminal); simulações e a detecção da NVIDIA não perguntam.
- **Termux e proot: Reiniciar e Desligar somem do menu.** Detecção: `PREFIX` do Termux, kernel com `proot` no nome, ou processo rastreado por ptrace (`TracerPid`); `FORCE_PROOT=1` força, `FORCE_PROOT=0` desliga a parte do ptrace (mesmos nomes do `setup.sh`).
- **`setup.sh --sem-encerrar`.** Não pergunta "Deseja encerrar a sessão?" no fim. Necessário porque a pergunta fecha o primeiro shell acima do script, que sob o menu seria o próprio menu. O menu usa a flag na opção de setup; fora do menu nada muda.
- **`menu.sh` checa o bash.** O começo é POSIX puro (o ash do Alpine só lê a sintaxe de bash depois): se houver bash, reexecuta; se não houver, avisa e mostra o comando de instalação (apk, apt-get, dnf, zypper ou pacman) e sai com código 1. Teste novo em `tests/menu.test.sh` (dash com um PATH sem bash).
- **`menu.sh`: Reiniciar e Desligar no WSL.** Reiniciar/desligar por dentro do WSL não faz nada útil, então no WSL (kernel com `microsoft` ou `wsl`, a mesma detecção do `setup.sh`) os itens ficam, mas sem a pergunta e sem chamar `reboot`/`poweroff`: mostram para rodar `wsl --shutdown` no Windows.
- `tests/menu.test.sh`: roda o menu com scripts de mentira e teclas lidas de um arquivo, com `reboot`, `poweroff` e `sudo` de mentira no PATH (nunca reinicia a máquina). Confere: a flag `--sem-encerrar`; o código de saída de um filho que falha; o "Tem certeza" (padrão Não, `Esc`, setas, `Sim` chamando o `reboot` de mentira); itens ocultos no Termux/proot (3 formas de detectar) e o aviso do WSL; a largura igual de todas as linhas das caixas (rótulos com acento); e a checagem do bash.
- `README.md`: seção "Menu" (teclas, itens, confirmação, onde somem Reiniciar/Desligar) e linhas na tabela de arquivos.

#### Planejado (feito na `menu-remoto`, veja acima)

- **Menu pela internet com `curl`** (`curl -fsSL <URL> | bash`): implementado em 2026-11-06, com tarball em vez de clone.

#### Decisões e limites

- **O menu escolhe o script, não cada etapa.** O `setup.sh` é um bloco só; dividir em etapas escolhíveis exigiria mexer em ~2700 linhas e não foi feito.
- **Não há opção "só instalar os temas Minecraft":** `--temas-minecraft` só responde a pergunta e o resto do setup roda junto. Só a reversão existe como item.
- **A confirmação aparece também onde o script já pergunta** (por exemplo, o `nvidia.sh install` pede confirmação de novo). Foi escolha minha: "Tem certeza" em tudo que altera o sistema, sem olhar o que cada script faz por dentro.
- **Testado:** `bash -n`; `tests/menu.test.sh` (e o teste falha de propósito quando se quebra a ocultação de Reiniciar/Desligar, o botão padrão ou a largura das caixas); o menu real num terminal 256 cores (tmux, 56 colunas): tela inicial, diálogo, `Esc` e navegação. **Não testado:** Termux, proot, Alpine e WSL reais; a detecção do proot por ptrace (`TracerPid`); reiniciar, desligar e fechar o terminal de verdade; as opções de setup, NVIDIA instalar e OXWM em máquina real. Terminais não UTF-8 (console do Linux sem fonte unicode) mostram as bordas quebradas.

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
