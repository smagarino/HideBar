# HideBar

A free, local alternative to Bartender for hiding macOS menu bar icons.

Installed at `~/Applications/HideBar.app` (no admin rights required).

## How to use

1. Two new icons appear in your menu bar: a **chevron** (`‹`) and a **separator** (`⋯`).
2. Hold **⌘** and drag any menu bar icon to the **left of the separator**.
3. Click the chevron to show/hide everything parked on that side.

Right-click the chevron for options:

| Option | What it does |
| --- | --- |
| Auto-hide | Re-hide automatically after 5s / 10s / 30s / 1min, or Never |
| Hide when clicking elsewhere | Re-hide as soon as you click outside the menu bar |
| Open at Login | Start HideBar automatically |
| Quit HideBar | Exit |

Your arrangement, the show/hide state, and all settings persist across restarts.

## Permissions

None. No Accessibility, no Screen Recording, no admin password.

## How it works

macOS lays out status items right-to-left. HideBar creates two `NSStatusItem`s and,
to hide, stretches the separator to an enormous width — pushing everything to its
left off the edge of the screen, where the system stops drawing it. Expanding
shrinks the separator back and the icons return. This is the same public-API
technique used by the open-source Hidden Bar and Dozer. No private APIs.

## Reset

If anything ends up in a strange state (icon positions, settings), reset everything:

```
defaults delete com.local.hidebar
```

Then relaunch. HideBar also refuses to hide when the chevron itself has been
dragged left of the separator, so it can't make itself disappear.

## Building from source

```
./bundle.sh          # builds build/HideBar.app
```

Requires Xcode command line tools. Swift 5.9+, macOS 13+.

## Known limits (vs. paid Bartender)

Not implemented: menu bar search, hover-to-reveal, triggered presets
(show on Wi-Fi change, etc.), a secondary "Bartender Bar" row, and per-item
always-hidden sections. This covers the core hide/show feature only.
