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
| Reveal automatically | Show the icons when the power source changes, the battery is low, or a display is connected |
| Reveal on hover | Show the icons when the pointer rests on the chevron, with no click |
| Slim mode | Shrink both icons, from about 62 to about 40 points |
| Keyboard shortcut | Hide and show with ⌃⌥⌘B |
| Open at Login | Start HideBar when you log in |
| Quit HideBar | Exit |

### Reveal automatically

Three system events can reveal the icons for you. The auto-hide timer then hides
them again.

| Trigger | Fires when |
| --- | --- |
| Power source changes | The Mac moves between mains power and battery |
| Battery is low | The battery reaches 20 percent or less, once per discharge |
| Display is connected | A display is plugged in or unplugged |

All three read the state of this Mac through system notifications. None of them
read another app, so none need the Accessibility permission. All are off by
default.

### Reveal on hover

Turn this on and the icons appear when you rest the pointer on the chevron.
They hide again when the pointer leaves the menu bar. A reveal you clicked for
behaves as before: it stays until you click again, or until the auto-hide timer
runs out.

This setting is off by default because it watches every mouse move. It uses
mouse monitors only, so it needs no Accessibility permission.

### Slim mode and the keyboard shortcut

Every status item carries about 16 points of padding that no app can remove.
Two items therefore cost about 34 points at the very least. Slim mode uses a
smaller chevron and a hairline separator to get close to that floor, which saves
about 22 points. It does not make HideBar fit a menu bar with no room at all.

The shortcut ⌃⌥⌘B hides and shows the icons without clicking. It is useful in
slim mode, where the chevron is a small target. HideBar registers it through
Carbon, so it needs no Accessibility permission. If another app already owns the
shortcut, HideBar tells you and turns the setting back off.

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

## Troubleshooting

### Nothing appeared in my menu bar

The app is almost certainly running. Your menu bar is full.

macOS lays out status items from right to left. When no room is left, it puts new
items behind the camera notch. It never draws them there. HideBar runs correctly,
but you cannot see its icons.

MacBooks with a notch have less room than you expect. Only the strip to the right
of the notch holds status items. On a 14-inch MacBook Pro that strip is about
790 points wide. HideBar needs about 62 points of it.

First check that the app is running:

```bash
pgrep -fl HideBar
```

If it is running, free some space:

1. Open **System Settings**.
2. Go to **Control Center**.
3. Set one icon you do not need to **Don't show in Menu Bar**.

One icon is usually enough. The chevron appears at once. You do not need to
restart the app.

You can also quit a menu bar app you are not using.

### The chevron is gone and I cannot get it back

You dragged the chevron to the left of the separator, then hid the icons.
HideBar tries to stop this, but you can still reach the state in other ways.
Reset the positions with the command below.

### Icon positions or settings are wrong

Reset everything:

```bash
defaults delete com.local.hidebar
```

Then relaunch HideBar.

## What it does not do

Not implemented: menu bar search, a second menu bar row for notched Macs, and per-item always-hidden
sections.

**Menu bar search is a deliberate omission.** To read the name of another app's
menu bar icon, or to click one, an app needs the Accessibility API. That needs
the Accessibility permission, which needs an administrator password. Without it
macOS reports every system icon under one name, `Control Center`, and refuses
every click you send.

Search would therefore cost HideBar the property that makes it worth using: it
asks for no permission at all. Bartender does implement search, and it asks for
that permission to do so.

If you want those, [Ice](https://github.com/jordanbaird/Ice) is a free and
actively maintained app that goes much further, and Bartender itself is the paid
option.

## License

MIT — see [LICENSE](LICENSE).
