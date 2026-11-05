# Waterbear
*Warning: about 90% of this was vibe-coded by Claude, and I’ve barely tested it.*
*In a future update I will make it more human, clean, and personalized, but for now I just want it to work.*

**An Arch + Hyprland setup.** Run one installer on a fresh Arch install and get a themed,
keyboard-driven desktop with switchable color schemes, snapshots, a status bar of your choice,
and only the apps you pick.

Named after the tardigrade (a.k.a. waterbear): tiny, and nearly impossible to kill.

| | |
|---|---|
| **Name** | Waterbear |
| **Version** | 1.1.0 |
| **Author** | Thomas Cochran ([@ThomasCochran](https://github.com/ThomasCochran)) |
| **Repository** | https://github.com/ThomasCochran/waterbear |
| **Platform** | Arch Linux + Hyprland |

## Requirements

Before you install, you need:

- **Arch Linux**, freshly installed (other distros aren't supported; the installer checks for `/etc/arch-release`)
- Installed with archinstall's **Minimal** profile, using:
  - **btrfs** as the filesystem (needed for Snapper snapshots)
  - **GRUB** as the bootloader (needed for snapshots in the boot menu)
  - **NetworkManager** for networking
- A **normal user account with sudo** (don't run the installer as root)
- An **internet connection** (packages are downloaded during setup)
- **git**, to clone the repo (`sudo pacman -S git`). Not needed if you use the single-file `Installer.sh`


## Install

On a fresh Arch install (archinstall → **Minimal** profile, **btrfs**, **GRUB**, **NetworkManager**),
logged in as your normal user:

```bash
sudo pacman -S git
git clone https://github.com/ThomasCochran/waterbear
cd waterbear
./install.sh
```

Or use the single-file `Installer.sh` from the releases (no clone needed, works from a USB stick):

```bash
chmod +x Installer.sh && ./Installer.sh
```

The setup wizard is laid out like the Waterbear menu: one line per setting (theme, background, bar, prompt, shell,
keybinds, apps, screensaver, firewall, login, system, old configs) showing what it is set to;
pick one to change it, then **Install**. Arrow keys move, **x** or **Tab** ticks a checkbox, **Enter** confirms, **Esc** goes back one question.
`./install.sh --yes` skips the questions and uses the defaults.
Nothing you pick is final: everything can be changed later in the Waterbear menu (**Super + Alt + Space**).

## After installing

> **Press `Super + Alt + Space` to open the Waterbear menu.** It's where you change your theme,
> background, bar, prompt, shell (bash or fish), apps, screensaver, firewall, login and keybind set, arrange your **monitors**
> (swap left/right, pick which workspaces go on which), take or restore snapshots, update,
> and see **Shortcuts**: a list of every keyboard shortcut for the keybind set you picked.
> It works with either keybind set.

| | |
|---|---|
| `Super + Alt + Space` | Waterbear menu (both keybind sets) |
| `Super + H` | Keybind cheat sheet (Waterbear keybinds; with stock keybinds use the menu → Shortcuts) |
| `Super + W` | Show / hide the status bar (Waterbear keybinds) |

The same things from a terminal (works in a TTY too):

```bash
waterbear                 # the menu
waterbear theme matrix    # switch color scheme
waterbear bar islands     # dashboard | islands | terminal | none
waterbear shell fish      # bash | fish: the shell your terminals open
waterbear apps            # install / remove optional apps
waterbear monitors        # monitor order (left → right) and which workspaces go on which
waterbear update          # snapshot → system update → newest Waterbear → refresh configs
waterbear autoupdate ask  # off | ask | auto: check GitHub for a newer Waterbear at every login
waterbear snapshot        # take a snapshot now
waterbear apply           # rewrite all configs from your saved settings
waterbear shortcuts       # list every keyboard shortcut
waterbear version         # which version you have
waterbear help
```

If an update fails, it says so at the end in a red **UPDATE FAILED** box (and a desktop notification)
with what went wrong and how to fix it. The last update's result is saved in `~/.cache/waterbear/last-update.log`.

**Auto-update** (menu → Auto-update, right under Update) checks GitHub each time you log in:
- **ask** (default): if there's a newer Waterbear, a notification offers **Update now**, which runs the full update in a terminal
- **auto**: installs the new Waterbear by itself and tells you. System packages still need your password, so
  they stay with the manual Update. If the install folder has hand-made changes, it asks instead
- **off**: never checks
If files in `~/.local/share/waterbear` were changed by hand, the update offers to set them aside
(`git stash`) first, since they'd block it.

## What's included

- **Hyprland** (0.57+ Lua config) with Waterbear's shortcuts or Hyprland's stock ones
- **Color schemes:** Abyss, Noir, Matrix, Nebula, Hearth, applied to Hyprland, kitty, rofi, the bar,
  the Thunar file manager, the lock screen, the Starship prompt, fish's syntax colors, btop and Neovim
  at once
- **Shell:** bash or fish in your terminals (fish gets themed highlighting, plus the same prompt, aliases
  and fastfetch). Your login shell stays bash, since that's what starts Hyprland on tty1
- **Backgrounds:** solid color, Grid horizon, Orbit, the waterbear logo (all drawn in your theme's colors),
  or live ones: cmatrix rain or cava sound bars running behind your windows (solid on battery by default)
- **Status bars:** Dashboard, Islands, Terminal, or none
- **Lock screen** (hyprlock) and an optional **screensaver** (cmatrix or a big terminal clock)
- **Snapper** snapshots in the GRUB boot menu, plus an optional weekly automatic snapshot
- **Firewall** (ufw): incoming blocked except what you allow (SSH, Steam Remote Play, dev servers…)
- **Optional apps:** Neovim + LazyVim, VS Code, Python, Node.js, Docker, lazygit, btop, power tools,
  Discord, Obsidian, Spotify, LibreOffice, GIMP, OBS, LocalSend, Steam (+ GPU drivers, Proton-GE,
  GameMode, MangoHud) and more
- Dark mode everywhere, clipboard history, screenshots, night light, dropdown terminal

## Your own changes

Waterbear regenerates its config files when you switch themes or update. Your own settings go in
files it never touches:

- `~/.config/hypr/user.lua`: extra keybinds, any Hyprland setting (loads last, so it wins). For monitor
  order and workspaces use the menu's **Monitors** instead; anything you put here overrides it
- `~/.config/kitty/user.conf`: terminal settings
- `~/.config/gtk-3.0/user.css`: your own GTK 3 CSS (loads after Waterbear's Thunar colors)
- `~/.bashrc`: anything outside the `# >>> waterbear >>>` block
- `~/.config/fish/config.fish`: your fish settings (Waterbear's are in `conf.d/waterbear.fish`, which loads first, so yours win)

Your choices are saved in `~/.config/waterbear/state.conf`.

## Your own logo as a background

Draw it in **black and white** (black background, white logo, grays for shading or glow) and save it as
`~/.config/waterbear/logo.svg`, `logo.png` or `logo.jpg` (it replaces the bundled waterbear). Pick **logo** as your background: black becomes the theme's
background color, white becomes its accent, grays land in between. Big PNGs (3840×2160) stay sharpest.

## Layout

```
waterbear            the command (menu, setup, theme, update…)
install.sh           installs from a clone
lib/                 core · apply (writes configs) · apps · system (snapper, firewall, login, update) · monitors
schemes/             one file per color scheme
templates/           config templates (colors filled in from the scheme), incl. wallpaper drawings
wallpapers/          the bundled waterbear artwork (black and white, recolored per theme)
bin/                 helper scripts (screenshots, clipboard, power menu, clock, screensaver, steam setup…)
system/              snapshot script/service, login screen config
tools/build-installer.sh   bundles everything into dist/Installer.sh
```

## Adding a color scheme

Copy a file in `schemes/`, change `DESC` and the 21 colors in `PALETTE`
(background, text, accent, accent 2, dim, then the 16 terminal colors), then run `waterbear theme NAME`.

To let people pick the accent (like Noir), also set `ACCENTS="name:hex ..."` and `ACCENT_DEFAULT=name`.
The picked color replaces accent 2. `ACCENT_SLOTS="C1:0 C9:25"` makes terminal colors follow it too
(slot:percent lighter), so the scheme doesn't keep its default accent anywhere.
