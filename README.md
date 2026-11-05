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
| **Version** | 1.0.2 |
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

The setup wizard is laid out like the Waterbear menu: one line per setting (theme, background, bar, prompt,
keybinds, apps, screensaver, firewall, login, system, old configs) showing what it is set to;
pick one to change it, then **Install**. Arrow keys move, **x** or **Tab** ticks a checkbox, **Enter** confirms, **Esc** goes back one question.
`./install.sh --yes` skips the questions and uses the defaults.
Nothing you pick is final: everything can be changed later in the Waterbear menu (**Super + Alt + Space**).

## After installing

> **Press `Super + Alt + Space` to open the Waterbear menu.** It's where you change your theme,
> background, bar, prompt, apps, screensaver, firewall, login and keybind set, take or restore snapshots,
> update, and see **Shortcuts**: a list of every keyboard shortcut for the keybind set you picked.
> It works with either keybind set.

| | |
|---|---|
| `Super + Alt + Space` | Waterbear menu (both keybind sets) |
| `Super + T` | Theme picker (Waterbear keybinds) |
| `Super + H` | Keybind cheat sheet (Waterbear keybinds; with stock keybinds use the menu → Shortcuts) |
| `Super + W` | Show / hide the status bar (Waterbear keybinds) |

The same things from a terminal (works in a TTY too):

```bash
waterbear                 # the menu
waterbear theme matrix    # switch color scheme
waterbear bar islands     # dashboard | islands | terminal | none
waterbear apps            # install / remove optional apps
waterbear update          # snapshot → system update → newest Waterbear → refresh configs
waterbear snapshot        # take a snapshot now
waterbear version         # which version you have
waterbear help
```

## What's included

- **Hyprland** (0.55+ Lua config) with Waterbear's shortcuts or Hyprland's stock ones
- **Color schemes:** Abyss, Noir, Matrix, Nebula, Hearth, applied to Hyprland, kitty, rofi, the bar,
  the lock screen, the Starship prompt, btop and Neovim at once
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

- `~/.config/hypr/user.lua`: extra keybinds, monitor setup, any Hyprland setting (loads last, so it wins)
- `~/.config/kitty/user.conf`: terminal settings
- `~/.bashrc`: anything outside the `# >>> waterbear >>>` block

Your choices are saved in `~/.config/waterbear/state.conf`.

## Your own logo as a background

Draw it in **black and white** (black background, white logo, grays for shading or glow) and save it as
`~/.config/waterbear/logo.svg`, `logo.png` or `logo.jpg` (it replaces the bundled waterbear). Pick **logo** as your background: black becomes the theme's
background color, white becomes its accent, grays land in between. Big PNGs (3840×2160) stay sharpest.

## Layout

```
waterbear            the command (menu, setup, theme, update…)
install.sh           installs from a clone
lib/                 core · apply (writes configs) · apps · system (snapper, firewall, login, update)
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
