---
layout: default
title: Home
---

<div class="beta-banner">
  <span class="tag">Beta</span>
  <span>Early release. Tested on built-in microphones and AirPods — if yours behaves differently, please <a href="https://github.com/ugurcandede/sotto/issues">open an issue</a>.</span>
</div>

<div class="hero">
  <img src="assets/images/icon.png" alt="sotto" class="hero-icon hero-icon--lg">
  <h1>sotto</h1>
  <p style="margin-bottom: 0 !important;">Mute your microphone system-wide — one key, every app, instantly.</p>
  <p><strong>No permissions required</strong> — push-to-talk is the one opt-in exception.</p>

  <div style="margin: 16px 0 24px; display: flex; gap: 6px; justify-content: center; align-items: center; flex-wrap: wrap;">
    <a href="https://github.com/ugurcandede/sotto/releases/latest"><img src="https://img.shields.io/github/v/release/ugurcandede/sotto?label=version&style=flat-square" alt="Version" height="20"></a>
    <a href="https://support.apple.com/en-us/105113"><img src="https://img.shields.io/badge/macOS-14.0%2B-000?style=flat-square&logo=apple&logoColor=white" alt="macOS" height="20"></a>
    <a href="https://www.swift.org/install/macos/"><img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift" height="20"></a>
  </div>

  <div class="hero-install">
    <span class="comment"># Install via Homebrew</span><br>
    brew tap ugurcandede/tap<br>
    brew install --cask sotto
  </div>

  <div class="btn-row">
    <a class="btn btn-accent" href="{{ '/download' | relative_url }}">Download sotto</a>
    <a class="btn btn-ghost" href="https://github.com/ugurcandede/sotto">View on GitHub</a>
  </div>
</div>

---

<div class="features">
  <h2>Features</h2>
  <div class="features-grid">
    <div class="feature-card">
      <div class="icon">🎙️</div>
      <h3>System-wide mute</h3>
      <p>Writes the device's own mute property through CoreAudio. Every app goes silent, not just the one you're in.</p>
    </div>
    <div class="feature-card">
      <div class="icon">🗣️</div>
      <h3>Push to talk</h3>
      <p>Flip the mode and the mic rests muted — open only while you hold your key. Let go and you're silent again.</p>
    </div>
    <div class="feature-card">
      <div class="icon">🔴</div>
      <h3>An icon that can't lie</h3>
      <p>The glyph follows the device, not the app's memory of it. Mute from System Settings and sotto agrees within a second.</p>
    </div>
    <div class="feature-card">
      <div class="icon">🎤</div>
      <h3>The microphone key</h3>
      <p>Claim the 🎤 key on your keyboard and it mutes instead of starting Dictation. Give it back whenever you like.</p>
    </div>
    <div class="feature-card">
      <div class="icon">🔄</div>
      <h3>Input switching</h3>
      <p>Choose the microphone from the menu. Your mute state travels with you when the default input changes.</p>
    </div>
    <div class="feature-card">
      <div class="icon">🎚️</div>
      <h3>Gain and level test</h3>
      <p>Set input gain, then press Test for a five second meter. The microphone opens only for those seconds.</p>
    </div>
    <div class="feature-card">
      <div class="icon">💬</div>
      <h3>On-screen feedback</h3>
      <p>A brief HUD says which way you just went, so you never wonder whether the shortcut landed.</p>
    </div>
  </div>
</div>

---

<div class="screenshots">
  <h2>In the menu bar</h2>
  <div class="screenshots-row screenshots-row--top">
    <img src="assets/images/menu-unmuted.png" alt="Menu" width="220">
    <img src="assets/images/menu-muted.png" alt="Muted" width="220">
    <img src="assets/images/menu-devices.png" alt="Input devices" width="220">
    <img src="assets/images/menu-ptt.png" alt="Push to talk" width="220">
  </div>
  <p class="screenshot-label">Status, input device, gain, level test, the mode and the key — one panel, no settings window.</p>
</div>

---

<div class="screenshots">
  <h2>On-screen feedback</h2>
  <div class="screenshots-row screenshots-row--lg">
    <img src="assets/images/hud-unmuted.png" alt="Unmuted HUD">
    <img src="assets/images/hud-muted.png" alt="Muted HUD">
  </div>
  <p class="screenshot-label">Green when you're live, red when you're not. Fades on its own.</p>
</div>

---

<div class="home-cta">
  <span class="cta-pill">No permissions</span>
  <h2>Nothing to grant, nothing to trust</h2>
  <p>Muting is a CoreAudio property write. The global shortcut is a Carbon hotkey. The microphone key is claimed at the HID layer with <code>hidutil</code>. None of those ask you for anything, so sotto installs and works before it has earned any trust — which is the right order for an app that sits on your microphone. The one exception is push-to-talk: seeing and swallowing your talk key needs an event tap, so switching that mode on asks for Accessibility — the only grant in the app, and only if you use it.</p>
  <div class="btn-row">
    <a class="btn btn-accent" href="{{ '/guide' | relative_url }}">Read the guide</a>
    <a class="btn btn-ghost" href="{{ '/faq' | relative_url }}">FAQ</a>
  </div>
</div>

---

<div class="features">
  <h2>How it mutes</h2>
  <div class="features-grid" style="grid-template-columns: 1fr 1fr;">
    <div class="feature-card">
      <div class="icon">🔇</div>
      <h3>The device, not the app</h3>
      <p>sotto sets <code>kAudioDevicePropertyMute</code> on the input device, and falls back to zeroing input gain on devices that don't expose it. Zoom's automatic gain control tries to undo that; sotto puts it back.</p>
      <pre style="background:#1a1a2e;color:#e8e8e8;padding:12px;border-radius:8px;font-size:0.85em;margin-top:12px;">/Applications/sotto.app/Contents/MacOS/sotto probe</pre>
    </div>
    <div class="feature-card">
      <div class="icon">⌨️</div>
      <h3>The key, before Dictation</h3>
      <p>macOS turns the 🎤 key into a Dictation trigger before any app sees it. sotto gets underneath by remapping the key itself — and hands it back when you unbind it, quit, or log out.</p>
      <pre style="background:#1a1a2e;color:#e8e8e8;padding:12px;border-radius:8px;font-size:0.85em;margin-top:12px;">🎤  →  F13  →  sotto</pre>
    </div>
  </div>
</div>

---

<div style="text-align:center; padding: 40px 0 20px;">
  <h2>Links</h2>
  <div style="margin: 16px 0 24px; display: flex; gap: 6px; justify-content: center; align-items: center; flex-wrap: wrap;">
    <a href="https://github.com/ugurcandede/sotto"><img src="https://img.shields.io/badge/Repo-000?style=flat-square&logo=github&logoColor=white" alt="Repo" height="22"></a>
    <a href="https://github.com/ugurcandede/homebrew-tap"><img src="https://img.shields.io/badge/Homebrew%20Tap-FBB040?style=flat-square&logo=homebrew&logoColor=000" alt="Homebrew" height="22"></a>
    <a href="https://github.com/ugurcandede"><img src="https://img.shields.io/badge/ugurcandede-000?style=flat-square&logo=github&logoColor=white" alt="ugurcandede" height="22"></a>
  </div>
</div>

---

<div style="text-align:center; padding: 40px 0 20px;">
  <h2>Requirements</h2>
  <p style="color: var(--text-secondary);">macOS 14.0 (Sonoma) or later · Apple Silicon or Intel · no permissions (Accessibility for push-to-talk only)</p>
</div>
