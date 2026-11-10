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
-- Super+C abre o Claude Desktop. O Super+C era do editor no Caelestia (kbEditor); o hypr-vars.lua o move para o Super+I.
hl.bind("SUPER + C", hl.dsp.exec_cmd("claude-desktop"))
