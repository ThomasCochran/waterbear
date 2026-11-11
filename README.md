# Waterbear
*Warning: about 95% of this was vibe-coded by Claude, and I’ve barely tested it.*
*In a future update I will make it more human, clean, and personalized, but for now I just want it to work.*

*Sometimes waterbear will run a system update and that update will prevent you from booting properly*
*I am not responsable for anything that happens to your mechine because of this code*
*if you are concerned about something like that happening to your mechine, set up the snapper install through waterbear first*
*its good at saving a snap before updates, and on first snapper install so you can always roll back when it breaks stuff*

**An Arch + Hyprland setup, Omarchy-style, for the Arch you already have.** No new OS: if you run Arch,
you can have Waterbear. Install the tool, open its menu, and from there get a themed, keyboard-driven
desktop with switchable color schemes (or themes made from your own wallpaper), snapshots, a status bar
of your choice, and only the apps you pick.

Named after the tardigrade (a.k.a. waterbear): tiny, and nearly impossible to kill.

| | |
|---|---|
| **Name** | Waterbear |
| **Version** | 1.2.5 |
| **Author** | Thomas Cochran ([@ThomasCochran](https://github.com/ThomasCochran)) |
| **Repository** | https://github.com/ThomasCochran/waterbear |
| **Platform** | Arch Linux + Hyprland |

## Requirements

- **Arch Linux**, the install you already have (or an Arch-based distro; the installer checks for
  `/etc/arch-release`). No reinstall and no special install profile needed
- A **normal user account with sudo** (don't run the installer as root)
- An **internet connection**
- For the full desktop: nothing more. For snapshots, **btrfs** (+ **GRUB** to boot into them); without
  btrfs, Snapper is skipped and everything else works

### What each part needs

| Part | Needs | Without it |
|---|---|---|
| The tool, installing apps | Arch + sudo + internet | — |
| The desktop | Hyprland 0.55 or newer (Waterbear installs the one in your distro's repos) | An older Hyprland can't read the config |
| Snapshots | `/` on **btrfs** | Snapper is skipped, everything else works |
| Booting into a snapshot | **GRUB** as your boot loader | Snapshots are still taken; restore them from a live USB instead |
| Text login on tty1 | **bash** as your login shell (Hyprland starts from `~/.bash_profile`), and no other login screen | Hyprland doesn't start by itself after you log in |
| hyprlock login screen | A single-user computer. It **replaces** the login screen you have (SDDM, GDM…): that one is turned off, not removed | — |


### What a snapshot does and doesn't undo

A snapshot holds the **system**: installed packages (so also the kernel and graphics driver) and `/etc`.
`waterbear update` takes one first, so a system update that breaks your desktop can be undone.

It only holds your **home folder** if `/home` is a plain folder on the same btrfs as `/`. Most installers
(archinstall, CachyOS) give `/home` its own subvolume or partition, and then a snapshot leaves it alone:
your files are safe from a rollback, but Waterbear itself and the configs it writes in `~/.config` are
*not* rolled back either. After a rollback Waterbear still shows its newest version, and that's correct.

To roll back: reboot, pick the snapshot in the GRUB menu, then **restore it with btrfs-assistant**.
Booting a snapshot only tries it out; until it's restored, the next normal boot is the broken system again.

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

## Already have a setup? No reinstall needed

Waterbear goes on top of the Arch you're already using, one step at a time, and you decide each step:

- **Installing Waterbear** adds only the tool and the `waterbear` command. Nothing else changes.
- **Installing apps** from the menu (or searching any package) works on any Arch system, with or without
  the Waterbear desktop. Apps you already have are detected and left alone.
- **Settings** like the theme, bar or keybinds are only saved until you install the Waterbear desktop;
  Waterbear doesn't write into your desktop's configs before then.
- **Installing the Waterbear desktop** (Desktop → Install) adds Hyprland and the rest, and replaces only
  these configs: `hypr`, `kitty`, `rofi`, `waybar`, `swaync`, `gtk-3.0`, `gtk-4.0`, `qt6ct`,
  `xdg-desktop-portal` and `starship.toml` in `~/.config`. You choose first: keep them as the theme
  **old_theme** (switch back to your old setup any time), or delete them. Your files, other apps and
  their settings aren't touched.

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
waterbear autoupdate ask  # off | ask | auto: check GitHub for a newer Waterbear (login + every 3 h)
waterbear autoupdate      # check now and show the result
waterbear snapshot        # take a snapshot now
waterbear apply           # rewrite all configs from your saved settings
waterbear shortcuts       # list every keyboard shortcut
waterbear shortcut off    # turn the Super + Alt + Space shortcut off (or on)
waterbear setup           # install the desktop from the command line
waterbear version         # which version you have
waterbear help
```

An update also installs anything a newer Waterbear needs (e.g. the icon set for themed folders), and its
**Refreshing configs** step lists what it rewrites as it goes. If a program it reloads doesn't respond,
it's skipped after a few seconds instead of holding up the update.

If an update fails, it says so at the end in a red **UPDATE FAILED** box (and a desktop notification)
with what went wrong and how to fix it. The last update's result is saved in `~/.cache/waterbear/last-update.log`.

**Auto-update** (menu → Update → Auto-update) checks GitHub when you log in, then every 3 hours while
you stay logged in:
- **ask** (default): if there's a newer Waterbear, a notification offers **Update now**, which runs the full update in a terminal
- **auto**: installs the new Waterbear by itself and tells you. System packages still need your password, so
  they stay with the manual Update. If the install folder has hand-made changes, it asks instead
- **off**: never checks

Every check is written to `~/.cache/waterbear/autoupdate.log` (up to date, no internet, offered, updated,
failed). **Update → Check now** checks right away and shows the last few results; so does running
`waterbear autoupdate` in a terminal.
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
