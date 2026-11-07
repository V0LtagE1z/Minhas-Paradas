-- Config própria do Caelestia: o caelestia-setup.sh copia este arquivo para ~/.config/caelestia/hypr-user.lua.
-- O hyprland.lua do Caelestia o carrega por último, então o que está aqui vence o padrão.

-- Teclado ABNT2 e mouse sem aceleração
hl.config({
    input = {
        kb_layout     = "br",
        kb_variant    = "abnt2",
        accel_profile = "flat",
    },
})

-- Super+C abre o app nativo do Claude (pacote claude-desktop do AUR); o editor ficou em Super+Alt+C (hypr-vars.lua)
hl.bind("SUPER + C", hl.dsp.exec_cmd("claude-desktop"))
