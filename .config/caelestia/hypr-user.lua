hl.config({
    input = {
        accel_profile = "flat",
        kb_layout  = "br",
     	kb_variant = ",abnt2",
    },
})
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60.00",
    position = "0x0",
    scale    = 1,
})
-- Super+I abre o Claude Desktop. O Caelestia não usa Super+I em nenhum atalho padrão.
hl.bind("SUPER + I", hl.dsp.exec_cmd("claude-desktop"))
