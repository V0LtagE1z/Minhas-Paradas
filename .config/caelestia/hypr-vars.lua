-- Overrides do Caelestia: o caelestia-setup.sh copia este arquivo para ~/.config/caelestia/hypr-vars.lua.
-- O hyprland.lua do Caelestia mescla esta tabela por cima do hypr/variables.lua; só entra aqui o que difere do padrão.
-- Os nomes das chaves são os do variables.lua do Caelestia (uma chave errada é ignorada em silêncio).
return {
    -- Apps (os atalhos de navegador, explorador de arquivos e áudio ficam nos padrões: Super+W, Super+E, Ctrl+Alt+V)
    terminal   = "kitty",
    browser    = "flock -n /tmp/zen.lock zen-browser", -- o flock evita abrir duas janelas ao apertar o atalho de novo
    editor     = "kitty micro",

    -- Atalhos
    kbTerminal = "SUPER + Return",     -- o padrão do Caelestia é Super+T
    kbEditor   = "SUPER + ALT + C",    -- o Super+C passa a abrir o Claude (hypr-user.lua)
}
