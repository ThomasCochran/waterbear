# Waterbear
*Warning: about 95% of this was vibe-coded by Claude, and I’ve barely tested it.*
*In a future update I will make it more human, clean, and personalized, but for now I just want it to work.*

**An Arch + Hyprland setup, Omarchy-style, for the Arch you already have.** No new OS: if you run Arch,
you can have Waterbear. Install the tool, open its menu, and from there get a themed, keyboard-driven
desktop with switchable color schemes (or themes made from your own wallpaper), snapshots, a status bar
of your choice, and only the apps you pick.

Named after the tardigrade (a.k.a. waterbear): tiny, and nearly impossible to kill.

| | |
|---|---|
| **Name** | Waterbear |
| **Version** | 1.2.4 |
| **Author** | Thomas Cochran ([@ThomasCochran](https://github.com/ThomasCochran)) |
| **Repository** | https://github.com/ThomasCochran/waterbear |
| **Platform** | Arch Linux + Hyprland |

## Requirements

- **Arch Linux** (or an Arch-based distro; the installer checks for `/etc/arch-release`)
- A **normal user account with sudo** (don't run the installer as root)
- An **internet connection**
- For the full desktop: nothing more. For snapshots, **btrfs** (+ **GRUB** to boot into them); without
  btrfs, Snapper is skipped and everything else works

## Install

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

The installer **only installs Waterbear itself** (plus `gum`, `git` and `fzf`, which its menus use) and
the `waterbear` command. Your desktop isn't touched. It asks one question: whether to add the
**Super + Alt + Space** shortcut that opens the menu (to your own Hyprland config if you have one, or to
Waterbear's once you install its desktop). Then open the menu:

- type **`waterbear`** in any terminal (or a TTY), or
- press **Super + Alt + Space**

From the menu you can install apps straight away, and the whole Waterbear desktop (Hyprland, bar, kitty,
Rofi, lock screen, notifications, themes) from **Desktop → Install**. Before it installs, it asks what to
do with the configs you already have: save them as a theme called **old_theme** (switch back to them any
time in Look & feel → Theme), or delete them.

`./install.sh --yes` skips the shortcut question. `./install.sh --desktop` also installs the desktop
right away (add `--yes` for no questions, plus any setup options from `waterbear help`).

## The menu

Arrow keys all the way: **↑ ↓** move, **→** (or Enter) opens / picks, **←** (or Esc) goes back.
In checklists, **Space**, **x** or **Tab** ticks a box and **→** / Enter is done.

| | |
|---|---|
| **Desktop** | install the Waterbear desktop · re-apply configs · login style |
| **Look & feel** | theme · dark mode · background · bar · prompt · shell |
| **Install** | apps by category (Browsers, Editors, Dev tools, Terminal, Media & creative, Office, Sharing, Gaming, Extras) · web apps · search any package (official repos, or the AUR) · remove packages |
| **Keyboard** | keybind set (Waterbear, **Omarchy** or Hyprland stock) · every shortcut · the menu shortcut on/off |
| **System** | snapshots · firewall · screensaver & lock · monitors · Snapper / yay |
| **Update** | update now · auto-update |

Apps you already have show **✓ installed** and come pre-ticked, so you're never asked to install
something twice. Apps that only exist in the AUR (like LocalSend on plain Arch) install yay first if
you say yes.

### Themes

- **Built-in schemes:** Abyss, Ember, Hearth, Matrix, Nebula, Noir (pick its accent color)
- **From a picture** (like Aether): pick any image and Waterbear makes a theme in its colors: background,
  accents and all 16 terminal colors. Then **save it to your themes** under a name, or **just try it**
  (save it later). It also asks if you want the picture as your background; you can say no
- **Your own colors:** type a background, text color and two accents; Waterbear works out the rest
- **old_theme:** the setup you had before Waterbear, if you chose to keep it
- **Manage your themes:** rename, change colors, delete
- **Transparency:** four numbers in % (0 = solid, 100 = fully see-through): apps you're on / not on, and
  terminals you're on / not on. Apps fade as a whole, text included; terminals only fade their background,
  so their text stays solid and 100 gives floating text

Theme and background are separate: changing one never changes the other.

A theme recolors Hyprland, kitty, Rofi, the bar and its tray, notifications (swaync), the lock screen,
GTK 3 and GTK 4 apps, Qt apps (qt6ct), **folder icons** (Papirus, recolored to your accent), Thunar,
the Starship prompt, fish, btop and Neovim at once.

**Dark mode** is on by default; turn it off in Look & feel for light GTK / Qt apps and Firefox.

## After installing the desktop

| | |
|---|---|
| `Super + Alt + Space` | Waterbear menu (every keybind set) |
| `Super + H` | Keybind cheat sheet (Waterbear keys; `Super + K` with Omarchy keys) |
| `Super + W` | Show / hide the status bar (Waterbear keys; `Super + Shift + Space` with Omarchy keys) |

The same things from a terminal (works in a TTY too):

```bash
waterbear                 # the menu
waterbear theme matrix    # switch color scheme (no name = the theme menu)
waterbear background      # pick your background (a generated one or your own picture)
waterbear dark off        # light mode (on / off; no argument switches)
waterbear transparency 0 10 40 70   # apps on / not on, terminals on / not on (in %: 0 = solid, 100 = clear)
waterbear bar islands     # dashboard | islands | terminal | none
waterbear shell fish      # bash | fish: the shell your terminals open
waterbear apps            # install apps, web apps, search any package
waterbear monitors        # monitor order (left → right) and which workspaces go on which
waterbear update          # snapshot → system update → newest Waterbear → refresh configs
waterbear autoupdate ask  # off | ask | auto: check GitHub for a newer Waterbear at every login
waterbear snapshot        # take a snapshot now
waterbear apply           # rewrite all configs from your saved settings
waterbear shortcuts       # list every keyboard shortcut
waterbear shortcut off    # turn the Super + Alt + Space shortcut off (or on)
waterbear setup           # install the desktop from the command line
waterbear version         # which version you have
waterbear help
```

If an update fails, it says so at the end in a red **UPDATE FAILED** box (and a desktop notification)
with what went wrong and how to fix it. The last update's result is saved in `~/.cache/waterbear/last-update.log`.

**Auto-update** (menu → Update → Auto-update) checks GitHub each time you log in:
- **ask** (default): if there's a newer Waterbear, a notification offers **Update now**, which runs the full update in a terminal
- **auto**: installs the new Waterbear by itself and tells you. System packages still need your password, so
  they stay with the manual Update. If the install folder has hand-made changes, it asks instead
- **off**: never checks
If files in `~/.local/share/waterbear` were changed by hand, the update offers to set them aside
(`git stash`) first, since they'd block it.

## What's included

- **Hyprland** (0.57+ Lua config) with Waterbear's shortcuts, Omarchy-style ones, or Hyprland's stock ones
- **Themes:** six built-in schemes, themes made from a picture or your own colors, and your old setup
- **Shell:** bash or fish in your terminals (fish gets themed highlighting, plus the same prompt, aliases
  and fastfetch). Your login shell stays bash, since that's what starts Hyprland on tty1
- **Backgrounds:** solid color, your own picture, Grid horizon, Orbit, the waterbear logo (drawn in your theme's colors),
  or live ones: cmatrix rain or cava sound bars running behind your windows (solid on battery by default)
- **Status bars:** Dashboard, Islands, Terminal (each with a system tray), or none
- **Lock screen** (hyprlock) and an optional **screensaver** (cmatrix or a big terminal clock)
- **Snapper** snapshots in the GRUB boot menu, plus an optional weekly automatic snapshot
- **Firewall** (ufw): incoming blocked except what you allow (SSH, Steam Remote Play, dev servers…)
- **Apps by category:** Firefox, Chromium, Brave, Zen, Tor Browser, DuckDuckGo (as a web app + Super+S search) · Neovim + LazyVim, VS Code, Zed, Helix · Python,
  Node.js, Rust, Go, Docker, lazygit, lazydocker, GitHub CLI · btop, power tools, yazi, tmux · Discord,
  Signal, Spotify, mpv, GIMP, OBS · LibreOffice, Obsidian · LocalSend, KDE Connect · Steam (+ GPU drivers,
  Proton-GE, GameMode, MangoHud) · and anything else from the repos or the AUR through package search
- **Web apps:** add any website as an app with its own window and launcher entry (opens in a
  Chromium-based browser if you have one, otherwise Firefox)
- Dark mode (optional), clipboard history, screenshots, night light, dropdown terminal

## Your own changes

Waterbear regenerates its config files when you switch themes or update. Your own settings go in
files it never touches:

- `~/.config/hypr/user.lua`: extra keybinds, any Hyprland setting (loads last, so it wins). For monitor
  order and workspaces use the menu's **Monitors** instead; anything you put here overrides it
- `~/.config/kitty/user.conf`: terminal settings
- `~/.config/gtk-3.0/user.css` and `~/.config/gtk-4.0/user.css`: your own GTK CSS (loads after Waterbear's colors)
- `~/.bashrc`: anything outside the `# >>> waterbear >>>` block
- `~/.config/fish/config.fish`: your fish settings (Waterbear's are in `conf.d/waterbear.fish`, which loads first, so yours win)

Your choices are saved in `~/.config/waterbear/state.conf`, your own themes in `~/.config/waterbear/schemes/`,
your background pictures in `~/.config/waterbear/wallpapers/`, and old_theme in `~/.config/waterbear/old-theme/`.

## Your own logo as a background

Draw it in **black and white** (black background, white logo, grays for shading or glow) and save it as
`~/.config/waterbear/logo.svg`, `logo.png` or `logo.jpg` (it replaces the bundled waterbear). Pick **logo** as your background: black becomes the theme's
background color, white becomes its accent, grays land in between. Big PNGs (3840×2160) stay sharpest.

## Layout

```
waterbear            the command (menu, setup, theme, update…)
install.sh           installs the waterbear tool from a clone
lib/                 core · menu (the arrow-key menus) · apply (writes configs) · apps · palette (themes from
                     pictures / your colors) · system (snapper, firewall, login, update) · monitors
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
(Or skip the file: Look & feel → Theme → Your own colors.)

To let people pick the accent (like Noir), also set `ACCENTS="name:hex ..."` and `ACCENT_DEFAULT=name`.
The picked color replaces accent 2. `ACCENT_SLOTS="C1:0 C9:25"` makes terminal colors follow it too
(slot:percent lighter), so the scheme doesn't keep its default accent anywhere.
