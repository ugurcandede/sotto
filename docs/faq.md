---
layout: default
title: FAQ
description: Common questions about sotto
---

# FAQ

## Does sotto need any permissions?

No. Muting is a CoreAudio property write and the global shortcut is a Carbon
hotkey; neither requires a grant. The microphone key is claimed with `hidutil`,
which also needs none.

There are two exceptions, both opt-in. The **test** button opens the
microphone to measure your level, so macOS asks once and shows its orange dot
while the meter runs. **Push-to-talk** needs an event tap to see your key, so
switching that mode on asks for Accessibility.

## Does sotto collect any data?

Once a day it sends an anonymous ping to Google Analytics: a random install
id, the app version and which mode you use. **No audio, no keystrokes, no
device names.** Turn it off any time by unchecking **send anonymous usage
stats** in the menu.

## What happens to Dictation when I use the 🎤 key?

It stays quiet while sotto owns the key. The key is remapped below the layer
where macOS decides to start Dictation. Pick another key, choose **none**, or
quit sotto and Dictation works exactly as before. A logout resets the mapping
too, so nothing can get stuck.

## Is push-to-talk supported?

Yes. Pick **push to talk** in the menu and hold your key: the mic opens while
the key is down and mutes again the moment you let go. Holding a key means
knowing when it is released, and the only macOS API that reports key-up
globally is an event tap — so this one mode asks for Accessibility. Everything
else keeps working without any grant.

## Push to talk stopped working after an update

macOS ties the Accessibility grant to the exact binary it was given, and
sotto's builds are not yet notarized — so an update invalidates the grant
while System Settings still shows sotto as enabled. sotto detects this,
clears the dead record, and asks again; approve the prompt and push to talk
comes back within seconds.

## My shortcut won't record

Two keys are rejected on purpose, and one is rejected by macOS:

- **A key on its own** (a letter, a number) is ignored — binding it globally
  would swallow that key everywhere you type.
- **A bare F-key** never reaches sotto if your function row is in media mode,
  which is the default. macOS turns F1–F12 into brightness and volume before
  any app sees them. Press **fn + F7** and it records as `F7`.
- **The 🎤 key** is the exception: sotto claims it at the HID layer, so it
  records as itself.

So: a modifier combination, fn with an F-key, or the microphone key.

## Does sotto change my audio output?

No. It only touches the input side — the microphone's mute property, its input
gain, and which device is the system default input. Speakers, headphones and
output volume are untouched.

## Does it work with Zoom, Meet, Teams?

Yes, because sotto mutes the device rather than the app. The apps' own mute
buttons are separate: muting in sotto while Zoom shows you unmuted means you
are, in fact, silent.

One caveat: Zoom's *Automatically adjust microphone volume* raises input gain
behind your back. On devices where sotto has to mute by zeroing gain, it
watches that property and puts it back.

## Why is my microphone still muted after quitting?

Because sotto mutes the device, not itself. Quitting does not unmute — it would
be a surprise to have your microphone open again without asking. Unmute first,
then quit, or use System Settings.

## The menu says my device can't be muted

Some devices — Continuity microphones in particular — expose neither a mute
property nor a settable input gain. Nothing can mute them short of switching
inputs. Run `sotto probe` to see the details for every device you have.

## Why is the app not notarized?

It is ad-hoc signed. Notarization needs a paid Apple Developer account; until
then Homebrew clears the quarantine flag for you, or you can right-click →
**Open** on first launch.
