---@module 'oxwm'
-------------------------------------------------------------------------------
-- OXWM — atalhos migrados do Caelestia (Hyprland)
-- Local: ~/.config/oxwm/config.lua   |   Recarregar: Super+Shift+R
--
-- Tags: 1-8 = workspaces normais | 9-12 = "especiais" (música, comunicação,
-- todo, monitor do sistema). Não há scratchpad no OXWM, então os especiais são
-- tags comuns que você alterna com Super+M / D / R / Ctrl+Shift+Esc.
-------------------------------------------------------------------------------

local modkey = "Mod4" -- Super
local alt = "Mod1"
local ctrl = "Control"
local shift = "Shift"

-- Comando do atalho Super+C: app nativo do Claude (pacote claude-desktop).
-- Se ele já estiver aberto, apps Electron costumam só trazer a janela existente.
-- Para abrir sempre uma conversa nova, troque por:
--   claude-desktop "claude://claude.ai/new?surface=chat&source=desktop_action"
local claude_cmd = "claude-desktop"

-- Wallpaper (aplicado no autostart com o feh)
local wallpaper = "/home/gustavo/Pictures/Wallpapers/Luna E Terra.png"

local scripts = "~/.config/oxwm/scripts/"
local function sh(cmd)
    return oxwm.spawn({ "sh", "-c", cmd })
end

-- Roda um comando no autostart só se o processo (nome exato) ainda não existe,
-- evitando duplicatas quando o OXWM é recarregado.
local function once(proc, cmd)
    oxwm.autostart("sh -c 'pgrep -x " .. proc .. " >/dev/null || exec " .. cmd .. "'")
end

local colors = {
    fg = "#cdd6f4",
    bg = "#1e1e2e",
    grey = "#585b70",
    blue = "#89b4fa",
    cyan = "#94e2d5",
    green = "#a6e3a1",
    purple = "#cba6f7",
    red = "#f38ba8",
}

-------------------------------------------------------------------------------
-- Básico
-------------------------------------------------------------------------------
oxwm.set_terminal("kitty")
oxwm.set_modkey(modkey) -- Super+botão esquerdo = mover, Super+botão direito = redimensionar
oxwm.set_tags({ "1", "2", "3", "4", "5", "6", "7", "8", "mus", "com", "todo", "sys" })
oxwm.set_floating_position("center")

oxwm.border.set_width(2)
oxwm.border.set_focused_color(colors.blue)
oxwm.border.set_unfocused_color(colors.grey)

oxwm.gaps.set_smart(true)
oxwm.gaps.set_inner(5, 5)
oxwm.gaps.set_outer(5, 5)

oxwm.set_layout_symbol("tiling", "[T]")
oxwm.set_layout_symbol("normie", "[F]")
oxwm.set_layout_symbol("tabbed", "[=]")

-------------------------------------------------------------------------------
-- Regras de janela
-------------------------------------------------------------------------------
-- O número da tag nas regras parece ser 1-based (tag = 9 é a 9ª tag).
-- Descubra a classe de um app com: xprop WM_CLASS (clique na janela).
oxwm.rule.add({ class = "Spotify", tag = 9, focus = false })
oxwm.rule.add({ class = "discord", tag = 10, focus = false })
oxwm.rule.add({ class = "vesktop", tag = 10, focus = false })
oxwm.rule.add({ class = "Todoist", tag = 11, focus = false })
oxwm.rule.add({ class = "sysmon", tag = 12, focus = false })
oxwm.rule.add({ class = "pwvucontrol", floating = true })

-------------------------------------------------------------------------------
-- Barra
-------------------------------------------------------------------------------
oxwm.bar.set_font("JetBrainsMono Nerd Font:style=Bold:size=10")
oxwm.bar.set_blocks({
    oxwm.bar.block.ram({
        format = "Ram: {used}/{total} GB",
        interval = 5,
        color = colors.blue,
        underline = true,
    }),
    oxwm.bar.block.battery({
        format = "Bat: {}%",
        charging = "⚡ Bat: {}%",
        discharging = "- Bat: {}%",
        full = "✓ Bat: {}%",
        interval = 30,
        color = colors.green,
        underline = true,
    }),
    oxwm.bar.block.datetime({
        format = "{}",
        date_format = "%a, %d %b - %H:%M",
        interval = 1,
        color = colors.cyan,
        underline = true,
    }),
    oxwm.bar.block.systray({ color = colors.bg, underline = false }),
})
oxwm.bar.set_scheme_normal(colors.fg, colors.bg, "#444444")
oxwm.bar.set_scheme_occupied(colors.cyan, colors.bg, colors.cyan)
oxwm.bar.set_scheme_selected(colors.cyan, colors.bg, colors.purple)
oxwm.bar.set_scheme_urgent(colors.red, colors.bg, colors.red)

-------------------------------------------------------------------------------
-- Controle do OXWM (mantidos do padrão do OXWM por segurança)
-------------------------------------------------------------------------------
oxwm.key.bind({ modkey, shift }, "R", oxwm.restart()) -- recarregar config
oxwm.key.bind({ modkey, shift }, "Q", oxwm.quit())
oxwm.key.bind({ modkey, shift }, "Slash", oxwm.show_keybinds())
-- Caelestia: Ctrl+Super+Alt+R = reiniciar o shell -> aqui recarrega o OXWM
oxwm.key.bind({ ctrl, modkey, alt }, "R", oxwm.restart())

-------------------------------------------------------------------------------
-- Launcher
-- Caelestia: tocar em Super abre o launcher. No OXWM um bind precisa de tecla,
-- então o xcape (autostart) converte "toque em Super" em Super+Space.
-- Se o xcape falhar, Super+Space continua funcionando manualmente.
-------------------------------------------------------------------------------
oxwm.key.bind({ modkey }, "Space", oxwm.spawn({ "rofi", "-show", "drun" }))

-------------------------------------------------------------------------------
-- Workspaces (tags 1-8)
-------------------------------------------------------------------------------
for i = 1, 8 do
    local key = tostring(i)
    oxwm.key.bind({ modkey }, key, oxwm.tag.view(i - 1)) -- ir para o workspace
    oxwm.key.bind({ modkey, alt }, key, oxwm.tag.move_to(i - 1)) -- mover janela
    -- Bônus (grupos de workspace do Caelestia não existem aqui):
    oxwm.key.bind({ modkey, ctrl }, key, oxwm.tag.toggleview(i - 1)) -- ver várias tags
    oxwm.key.bind({ modkey, ctrl, alt }, key, oxwm.tag.toggletag(i - 1)) -- janela em várias tags
end

-- Próximo/anterior
oxwm.key.bind({ modkey }, "Page_Down", oxwm.tag.view_next())
oxwm.key.bind({ modkey }, "Page_Up", oxwm.tag.view_previous())
oxwm.key.bind({ modkey, ctrl }, "Right", oxwm.tag.view_next())
oxwm.key.bind({ modkey, ctrl }, "Left", oxwm.tag.view_previous())

-- "Workspaces especiais" -> tags 9-12
oxwm.key.bind({ modkey }, "M", oxwm.tag.view(8)) -- música
oxwm.key.bind({ modkey }, "D", oxwm.tag.view(9)) -- comunicação
oxwm.key.bind({ modkey }, "R", oxwm.tag.view(10)) -- todo
oxwm.key.bind({ ctrl, shift }, "Escape", oxwm.tag.view(11)) -- monitor do sistema

-------------------------------------------------------------------------------
-- Ações de janela
-------------------------------------------------------------------------------
oxwm.key.bind({ modkey }, "Q", oxwm.client.kill())
oxwm.key.bind({ modkey }, "F", oxwm.client.toggle_fullscreen())
oxwm.key.bind({ modkey, alt }, "Space", oxwm.client.toggle_floating())
-- Caelestia: Super+Alt+F = maximizar. Aproximação: alterna entre layouts
-- (tiling/normie/monocle/grid/tabbed...)
oxwm.key.bind({ modkey, alt }, "F", oxwm.layout.cycle())

-- Foco e movimento (OXWM segue a ordem da pilha, não a direção física)
oxwm.key.bind({ modkey }, "Left", oxwm.client.focus_stack(-1))
oxwm.key.bind({ modkey }, "Up", oxwm.client.focus_stack(-1))
oxwm.key.bind({ modkey }, "Right", oxwm.client.focus_stack(1))
oxwm.key.bind({ modkey }, "Down", oxwm.client.focus_stack(1))
oxwm.key.bind({ modkey, shift }, "Left", oxwm.client.move_stack(-1))
oxwm.key.bind({ modkey, shift }, "Up", oxwm.client.move_stack(-1))
oxwm.key.bind({ modkey, shift }, "Right", oxwm.client.move_stack(1))
oxwm.key.bind({ modkey, shift }, "Down", oxwm.client.move_stack(1))

-- Alt+Tab (próxima/anterior janela)
oxwm.key.bind({ alt }, "Tab", oxwm.client.focus_stack(1))
oxwm.key.bind({ alt, shift }, "Tab", oxwm.client.focus_stack(-1))

-- "Split" do Caelestia -> largura da área master (só horizontal)
oxwm.key.bind({ modkey }, "minus", oxwm.set_master_factor(-5))
oxwm.key.bind({ modkey }, "equal", oxwm.set_master_factor(5))
oxwm.key.bind({ modkey, alt }, "Left", oxwm.set_master_factor(-5))
oxwm.key.bind({ modkey, alt }, "Right", oxwm.set_master_factor(5))

-------------------------------------------------------------------------------
-- Aplicativos
-------------------------------------------------------------------------------
oxwm.key.bind({ modkey }, "Return", oxwm.spawn_terminal()) -- kitty
oxwm.key.bind({ modkey }, "W", sh("flock -n /tmp/zen.lock zen-browser || true"))
oxwm.key.bind({ modkey }, "C", sh(claude_cmd)) -- Claude
oxwm.key.bind({ modkey, alt }, "C", oxwm.spawn({ "kitty", "micro" })) -- editor (era Super+C)
oxwm.key.bind({ modkey }, "E", oxwm.spawn("thunar"))
oxwm.key.bind({ ctrl, alt }, "V", oxwm.spawn("pwvucontrol"))

-------------------------------------------------------------------------------
-- Utilitários
-------------------------------------------------------------------------------
oxwm.key.bind({}, "Print", sh(scripts .. "screenshot.sh full"))
oxwm.key.bind({ modkey, shift }, "S", oxwm.spawn({ "flameshot", "gui" })) -- "freeze"
oxwm.key.bind({ modkey, shift, alt }, "S", sh(scripts .. "screenshot.sh region"))
oxwm.key.bind({ ctrl, alt }, "R", sh(scripts .. "record.sh full"))
oxwm.key.bind({ modkey, alt }, "R", sh(scripts .. "record.sh sound"))
oxwm.key.bind({ modkey, shift, alt }, "R", sh(scripts .. "record.sh region"))
oxwm.key.bind({ modkey, shift }, "C",
    sh('c=$(xcolor) && printf %s "$c" | xclip -selection clipboard && notify-send "Cor copiada" "$c"'))

-------------------------------------------------------------------------------
-- Mídia, volume e brilho
-------------------------------------------------------------------------------
oxwm.key.bind({ ctrl, modkey }, "Space", sh("playerctl play-pause"))
oxwm.key.bind({}, "XF86AudioPlay", sh("playerctl play-pause"))
oxwm.key.bind({}, "XF86AudioPause", sh("playerctl pause"))
oxwm.key.bind({ ctrl, modkey }, "equal", sh("playerctl next"))
oxwm.key.bind({}, "XF86AudioNext", sh("playerctl next"))
oxwm.key.bind({ ctrl, modkey }, "minus", sh("playerctl previous"))
oxwm.key.bind({}, "XF86AudioPrev", sh("playerctl previous"))
oxwm.key.bind({ ctrl, modkey }, "BackSpace", sh("playerctl stop"))
oxwm.key.bind({}, "XF86AudioStop", sh("playerctl stop"))

oxwm.key.bind({ modkey, shift }, "M", sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
oxwm.key.bind({}, "XF86AudioMute", sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
oxwm.key.bind({}, "XF86AudioMicMute", sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
oxwm.key.bind({}, "XF86AudioRaiseVolume", sh("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
oxwm.key.bind({}, "XF86AudioLowerVolume", sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
oxwm.key.bind({}, "XF86MonBrightnessUp", sh("brightnessctl set 5%+"))
oxwm.key.bind({}, "XF86MonBrightnessDown", sh("brightnessctl set 5%-"))

-------------------------------------------------------------------------------
-- Sessão, bloqueio e notificações
-------------------------------------------------------------------------------
oxwm.key.bind({ modkey }, "L", sh("i3lock -c 1e1e2e")) -- bloquear tela
oxwm.key.bind({ modkey, shift }, "L", sh("systemctl suspend")) -- suspender
oxwm.key.bind({ ctrl, alt }, "Delete", sh(scripts .. "powermenu.sh")) -- menu de sessão
oxwm.key.bind({ modkey }, "N", sh("dunstctl history-pop")) -- última notificação
oxwm.key.bind({ ctrl, alt }, "C", sh("dunstctl close-all")) -- limpar notificações

-------------------------------------------------------------------------------
-- Clipboard e emoji
-------------------------------------------------------------------------------
oxwm.key.bind({ modkey }, "V", sh("CM_LAUNCHER=rofi clipmenu"))
oxwm.key.bind({ ctrl, alt, shift }, "V",
    sh('sleep 0.3; xdotool type --clearmodifiers "$(xclip -o -selection clipboard)"'))
oxwm.key.bind({ modkey }, "Period", oxwm.spawn({ "rofi", "-modi", "emoji", "-show", "emoji" }))

-------------------------------------------------------------------------------
-- Autostart
-------------------------------------------------------------------------------
oxwm.autostart("setxkbmap -layout br")
oxwm.autostart("sh -c \"feh --bg-fill '" .. wallpaper .. "'\"")
once("dunst", "dunst")
once("nm-applet", "nm-applet")
once("xcape", 'xcape -e "Super_L=Super_L|space"')
once("clipmenud", "clipmenud")
once("xss-lock", "xss-lock --transfer-sleep-lock -- i3lock -n -c 1e1e2e")
once("btop", "kitty --class sysmon --name sysmon btop") -- vai para a tag "sys"
-- Descomente e ajuste o que quiser:
-- once("picom", "picom")
-- once("spotify", "spotify")
-- once("discord", "discord")
