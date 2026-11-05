-- ~/.config/hypr/binds.lua — Waterbear keybinds (generated). Cheat sheet: Super+H. Search: Super+Shift+K.
-- Add or change binds in ~/.config/hypr/user.lua, not here.

local mainMod  = "SUPER"
local terminal = "kitty"
local browser  = "firefox"
local files    = "thunar"
local bin      = "~/.local/bin/"

local function key(combo) return mainMod .. " + " .. combo end

---------------
---- APPS -----
---------------
hl.bind(key("Return"),         hl.dsp.exec_cmd(terminal))
hl.bind(key("SHIFT + Return"), hl.dsp.exec_cmd(bin .. "dropterm.sh"))                -- dropdown terminal
hl.bind(key("B"),              hl.dsp.exec_cmd(browser))
hl.bind(key("E"),              hl.dsp.exec_cmd(files))
hl.bind(key("D"),              hl.dsp.exec_cmd("pkill -x rofi || rofi -show drun"))
hl.bind(key("ALT + C"),        hl.dsp.exec_cmd("pkill -x rofi || rofi -show calc -modi calc -no-show-match -no-sort"))
hl.bind(key("S"),              hl.dsp.exec_cmd(bin .. "rofi-websearch.sh"))          -- Google search
hl.bind(key("ALT + E"),        hl.dsp.exec_cmd("pkill -x rofi || rofi -modi emoji -show emoji"))
hl.bind(key("ALT + V"),        hl.dsp.exec_cmd(bin .. "clipboard.sh"))               -- clipboard history
hl.bind(key("H"),              hl.dsp.exec_cmd("kitty --class keyhelp -e less ~/.config/hypr/KEYBINDS.md"))
hl.bind(key("SHIFT + K"),      hl.dsp.exec_cmd(bin .. "keybind-search.sh"))
hl.bind(key("I"),              hl.dsp.exec_cmd(bin .. "status.sh"))                  -- time/battery/wifi popup
hl.bind(key("T"),              hl.dsp.exec_cmd("kitty --class waterbear-menu -e waterbear theme"))  -- theme picker
hl.bind(key("W"),              hl.dsp.exec_cmd("pkill -SIGUSR1 -x waybar || ([ -f ~/.config/waybar/config.jsonc ] && waybar)"))  -- show/hide the bar

-----------------
---- WINDOWS ----
-----------------
hl.bind(key("Q"),          hl.dsp.window.close())
hl.bind(key("SHIFT + Q"),  hl.dsp.window.kill())
hl.bind(key("space"),      hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("SHIFT + F"),  hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(key("CTRL + F"),   hl.dsp.window.fullscreen({ mode = "maximized" }))        -- "fake" fullscreen

local dirs = { left = "left", right = "right", up = "up", down = "down" }
local resizeStep = {
    left  = { x = -40, y = 0 },
    right = { x =  40, y = 0 },
    up    = { x = 0,   y = -40 },
    down  = { x = 0,   y =  40 },
}
for arrow, dir in pairs(dirs) do
    hl.bind(key(arrow),            hl.dsp.focus({ direction = dir }))
    hl.bind(key("CTRL + " .. arrow),  hl.dsp.window.move({ direction = dir }))
    hl.bind(key("ALT + " .. arrow),   hl.dsp.window.swap({ direction = dir }))
    hl.bind(key("SHIFT + " .. arrow),
        hl.dsp.window.resize({ x = resizeStep[arrow].x, y = resizeStep[arrow].y, relative = true }),
        { repeating = true })
end

-- Mouse: Super + left-drag moves, Super + right-drag resizes
hl.bind(key("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Alt+Tab cycles windows and raises the one it lands on
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)

hl.bind(key("CTRL + S"),   hl.dsp.exec_cmd("pkill -x rofi || rofi -show window"))   -- window switcher
hl.bind(key("G"),          hl.dsp.group.toggle())
hl.bind(key("CTRL + Tab"), hl.dsp.group.next())

--------------------
---- WORKSPACES ----
--------------------
for i = 1, 10 do
    local k = i % 10   -- workspace 10 is on the 0 key
    hl.bind(key(k),              hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. k), hl.dsp.window.move({ workspace = i, follow = true }))   -- move and follow
    hl.bind(key("CTRL + " .. k),  hl.dsp.window.move({ workspace = i, follow = false }))  -- move and stay
end

hl.bind(key("Tab"),         hl.dsp.focus({ workspace = "m+1" }))   -- next / previous workspace
hl.bind(key("SHIFT + Tab"), hl.dsp.focus({ workspace = "m-1" }))
hl.bind(key("period"),      hl.dsp.focus({ workspace = "e+1" }))   -- next / previous workspace with windows
hl.bind(key("comma"),       hl.dsp.focus({ workspace = "e-1" }))
hl.bind(key("mouse_down"),  hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key("mouse_up"),    hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad
hl.bind(key("U"),         hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(key("SHIFT + U"), hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

---------------------
---- SCREENSHOTS ----
---------------------
-- Saved to ~/Pictures/Screenshots and copied to the clipboard
hl.bind(key("Print"),                hl.dsp.exec_cmd(bin .. "screenshot.sh full"))
hl.bind(key("SHIFT + Print"),        hl.dsp.exec_cmd(bin .. "screenshot.sh area"))
hl.bind("ALT + Print",               hl.dsp.exec_cmd(bin .. "screenshot.sh window"))
hl.bind(key("SHIFT + S"),            hl.dsp.exec_cmd(bin .. "screenshot.sh edit"))      -- area → swappy
hl.bind(key("CTRL + Print"),         hl.dsp.exec_cmd(bin .. "screenshot.sh delay 5"))
hl.bind(key("CTRL + SHIFT + Print"), hl.dsp.exec_cmd(bin .. "screenshot.sh delay 10"))

----------------
---- SYSTEM ----
----------------
hl.bind("CTRL + ALT + L",      hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))
hl.bind("CTRL + ALT + P",      hl.dsp.exec_cmd(bin .. "powermenu.sh"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(key("SHIFT + N"),      hl.dsp.exec_cmd("swaync-client -t -sw"))                -- notification panel
hl.bind(key("N"),              hl.dsp.exec_cmd("pkill -x hyprsunset || hyprsunset -t 4500"))  -- night light
-- Left Alt + Left Shift = switch keyboard layout (set by kb_options in hyprland.lua)

-- Media / volume / brightness keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
