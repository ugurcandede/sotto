---
layout: default
title: Download
description: Install sotto on macOS
---

# Download

## Homebrew

```bash
brew tap ugurcandede/tap
brew install --cask sotto
```

## Direct download

<div class="btn-row" style="justify-content:flex-start;margin-bottom:24px">
  <a class="btn btn-accent" href="https://github.com/ugurcandede/sotto/releases/latest/download/sotto-macos.zip">Download sotto-macos.zip</a>
  <a class="btn btn-ghost" href="https://github.com/ugurcandede/sotto/releases/latest">All releases</a>
</div>

That link always points at the newest build. Unzip it and move `sotto.app` to
your Applications folder.

The app is ad-hoc signed rather than notarized, so the first launch needs a
right-click → **Open**, or:

```bash
xattr -cr /Applications/sotto.app
```

The Homebrew cask does this for you.

## Build from source

Requires Swift 6.0 or later.

```bash
git clone https://github.com/ugurcandede/sotto.git
cd sotto
swift build -c release
./scripts/bundle.sh .build/release/sotto
open sotto.app
```

`scripts/bundle.sh` wraps the binary in an `.app` and ad-hoc signs it, which is
what makes the menu bar item and login item work.

## Requirements

macOS 14 (Sonoma) or later · Apple Silicon or Intel

## Uninstall

```bash
brew uninstall --cask sotto
```

Installed by hand? Quit sotto, drag `sotto.app` to the Trash, and if you want
its settings gone too:

```bash
defaults delete com.ugurcandede.sotto
```

Quitting restores the microphone key to Dictation on its own — sotto removes
the remap as it exits, and the remap never survives a logout anyway.
