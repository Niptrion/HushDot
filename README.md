# TrayMute — One-click microphone mute from the Windows system tray

Windows 11 has no permanent microphone icon in the system tray. The mic indicator appears
only while an app is using it, and muting means digging through Sound Settings or relying
on each app's own button. TrayMute adds a fixed microphone icon to the tray. It shows at a
glance whether your mic is live or muted, and one click toggles it.

<!-- TODO: add a screenshot or GIF of the tray icons and the settings window, then use:
![TrayMute in the Windows system tray](docs/screenshot.png) -->


## Features

- **Permanent tray icons** for the microphone and the speaker, showing live/muted status
- **One-click mute**: left-click the tray icon to toggle the mic (or the speaker)
- **Mute every microphone at once** (on by default): one click silences all audio inputs,
  including virtual ones such as NVIDIA RTX Voice and microphones plugged in while muted.
  Unmuting restores each microphone to the state it was in before, and a microphone unplugged
  while muted is restored when you plug it back in. Can be turned off in Settings.
- **Mute every speaker at once** (on by default): the same for audio outputs (headphones,
  Bluetooth earbuds, monitor speakers), so audio stops wherever Windows or an app is playing
  it. Outputs connected while muted start muted. Has its own switch in Settings.
- **Global hotkeys** that also work in full-screen apps and games
  (defaults: `Win+Alt+M` for the mic, `Win+Alt+S` for the speaker; configurable)
- **Floating mini window** with mic/speaker buttons that you can drag anywhere
- **Device selection** with automatic detection when devices are plugged in or removed.
  Inputs and outputs are told apart by what Windows reports, so device names in any
  language are listed correctly.
- **Custom tray icons** picked from any `.ico`, `.exe` or `.dll`
- **Optional start with Windows**, off by default

## Getting started

Requirements: Windows 11. Choose one of the two options below.

### Option A: ready-to-run executable (no AutoHotkey needed)

1. **Download** `TrayMute-v1.0.zip` from the [latest release](https://github.com/Niptrion/TrayMute/releases/latest)
   and extract it to a folder you own (for example `Documents\TrayMute`). Keep `TrayMute.exe`
   and the `icons` folder together.
2. **Run** `TrayMute.exe`. The executable is not code-signed, so Windows SmartScreen may show
   "Windows protected your PC". Choose **More info → Run anyway**.
3. **Optional: verify the download.** Compare its SHA256 with the one in the release notes:
   ```powershell
   Get-FileHash .\TrayMute-v1.0.zip -Algorithm SHA256
   ```

`TrayMute.exe` is this repository's `TrayMute.ahk` compiled with Ahk2Exe. It contains the
AutoHotkey v2 interpreter, which is licensed under the GPL v2; see `THIRD-PARTY-NOTICES.md`
in the zip.

### Option B: run the script with AutoHotkey v2

1. **Install [AutoHotkey v2](https://www.autohotkey.com/)**, either from the website or with winget:
   ```powershell
   winget install --id AutoHotkey.AutoHotkey --exact --source winget
   ```
2. **Download TrayMute**: clone this repository, or use *Code → Download ZIP* and extract it
   to a folder you own (for example `Documents\TrayMute`).
3. **Run it**: double-click `TrayMute.ahk`. The microphone and speaker icons appear in the
   system tray. If they are hidden, drag them from the `^` overflow area onto the taskbar.
   If double-clicking does nothing (some per-user AutoHotkey installs don't associate `.ahk`
   files), create a shortcut whose target is the interpreter followed by the script, e.g.
   `"%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe" "C:\path\to\TrayMute.ahk"`.
### Using it

Left-click an icon to mute or unmute it. Right-click it for the menu (Settings, Show
Controls, Exit).

To start TrayMute with Windows, open **Settings → System & About** and tick
*Run TrayMute on Windows Startup*. This creates a shortcut in your Startup folder (for the
script version it launches the script through AutoHotkey, so it works even without a `.ahk`
file association), and unticking the box removes it.

Settings are saved to `TrayMute.ini` next to the program. If that folder is not writable,
for example inside `Program Files`, they go to `%APPDATA%\TrayMute\` instead.

### Choosing the right microphone

On first run TrayMute selects the first microphone it finds (in alphabetical order),
not necessarily your Windows default. Open **Settings** and pick the microphone you
actually use.

With **Mute all microphones** turned on (the default), every input is muted together, so
the choice below only matters if you turn that option off.

If you use a virtual microphone such as NVIDIA RTX Voice or NVIDIA Broadcast, select
the **physical** microphone that the virtual one uses as its input. Some virtual audio
drivers ignore the Windows mute: the tray icon changes, but the audio keeps flowing.
Muting the physical microphone silences every app.

The virtual microphone only works while its app is running. If you close RTX Voice or
Broadcast, apps set to its microphone get no audio, and the physical microphone on its own
may sound much quieter, because the noise removal and level boost are gone.

Tip: the level meter in Windows Sound settings may keep moving even when the mic is
muted. To check, record a few seconds (for example with the Voice Recorder app) and
play it back.

## Known issues

- **Some USB webcam microphones stop capturing after being muted and unmuted.** Windows
  reports them as active and unmuted, but no sound comes through. This was seen with a
  Logitech C922. Unplugging and replugging the webcam (or restarting the PC) brings it back.
  If it happens often, turn off *Mute all microphones* so only your selected microphone is
  toggled.
- **"Mute all speakers" also mutes virtual outputs** such as VB-Cable or Voicemeeter, which
  silences anything you stream or record through them. If you use those, turn the option off.

## Privacy and safety

- **No telemetry and no network access.** TrayMute never connects to the internet. The only
  links (Credits and Sponsor) open in your browser when you click them.
- **No registry changes, services or background installers.** It writes only its own
  `TrayMute.ini` and, if you enable it, the startup shortcut.
- **Muted stays muted.** If you exit TrayMute while all microphones are muted, they stay
  muted. Start TrayMute again and click the icon to restore them.
- **Readable source.** TrayMute is a single plain-text AutoHotkey script. The full script was
  reviewed line by line before this fork was published; see [`NOTICE.md`](NOTICE.md) for the
  details and file hashes.

## Credits and license

TrayMute is an unofficial fork of [**MuteGuard**](https://github.com/xionraj/MuteGuard) by
xionraj (Raja Mukherjee). All the core functionality is their work. TrayMute is not affiliated
with or endorsed by the original author.

Released under the [MIT License](LICENSE), Copyright (c) 2026 Raja Mukherjee.
See [`NOTICE.md`](NOTICE.md) for where the source came from and what changed.

---

💖 Like TrayMute? [Sponsor this fork on GitHub](https://github.com/sponsors/Niptrion).
