# HideBar

Hide the menu bar icons you do not want to see. A small, free macOS app —
a lightweight alternative to [Bartender](https://www.macbartender.com/).

- **No permissions.** No Accessibility, no Screen Recording, no admin password.
- **No private APIs.** Public AppKit only.
- **Tiny.** One 120 KB app, no dependencies, no background services.

## Install

There is no prebuilt download — you build it yourself, which takes a few seconds:

```bash
git clone https://github.com/smagarino/HideBar.git
cd HideBar
./bundle.sh
cp -R build/HideBar.app ~/Applications/    # or /Applications
open ~/Applications/HideBar.app
```

`bundle.sh` compiles the app and signs it ad-hoc. Because you built it locally it
is never quarantined, so Gatekeeper will not block it.

**Requirements:** macOS 13 or later, and Xcode command line tools
(`xcode-select --install`). Swift 5.9+.

## Use it

Two icons appear in your menu bar: a chevron (`‹`) and a separator (`⋯`).

1. Hold **⌘** and drag any menu bar icon to the **left of the separator**.
2. Click the chevron to hide or show everything parked on that side.

Right-click the chevron for options:

| Option | What it does |
| --- | --- |
| Auto-hide | Hide again after 5s / 10s / 30s / 1 min, or Never |
| Hide when clicking elsewhere | Hide again as soon as you click outside the menu bar |
| Open at Login | Start HideBar when you log in |
| Quit HideBar | Exit |

Your icon arrangement, the hidden/shown state, and all settings survive a restart.

## How it works

macOS draws status items from right to left. HideBar creates two `NSStatusItem`s.
To hide, it stretches the separator to an enormous width. That pushes every icon
on its left past the edge of the screen, where the system stops drawing them.
Expanding shrinks the separator back and the icons return.

This is the same public-API technique used by [Hidden Bar](https://github.com/dwarvesf/hidden)
and [Dozer](https://github.com/Mortennn/Dozer). No private APIs, so nothing here
breaks System Integrity Protection or needs elevated access.

HideBar refuses to hide while the chevron itself sits left of the separator.
Otherwise it would hide its own chevron and leave no way to bring it back.

## Reset

If icon positions or settings end up in a strange state:

```bash
defaults delete com.local.hidebar
```

Then relaunch.

## What it does not do

This covers the core hide/show feature only. Not implemented: menu bar search,
hover-to-reveal, triggered presets (show on Wi-Fi change and similar), a second
menu bar row for notched Macs, and per-item always-hidden sections.

If you want those, [Ice](https://github.com/jordanbaird/Ice) is a free and
actively maintained app that goes much further, and Bartender itself is the paid
option.

## License

MIT — see [LICENSE](LICENSE).
