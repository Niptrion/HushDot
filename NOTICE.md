# NOTICE

**HushDot (formerly TrayMute) is an unofficial fork of [MuteGuard](https://github.com/xionraj/MuteGuard) by xionraj (Raja Mukherjee).**
It is not affiliated with, maintained by, or endorsed by the original author.

## Origin of the source code

The source (first published as TrayMute) was extracted from the compiled MuteGuard **v4.0** release binary.
`MuteGuard.exe` is an AutoHotkey v2 script compiled with Ahk2Exe, and the script is
stored as plain text in the PE resource `RCDATA #1`. The script was extracted byte for
byte, with no decompilation, and then modified as listed below.

| Artifact | SHA256 |
|---|---|
| MuteGuard v4.0 release zip | `B6D43E9F323C2BE942DAEFA9C862BFDB7A46AF6E3BE3D0F685C0ADE77AB7EB19` |
| Original embedded script (RCDATA #1, 58,669 bytes) | `A7A21961CCC5DF4DC8386D9F0F91263FD421758FC21329648A1FA7646E74835E` |
| First TrayMute.ahk (after the changes below) | `7E2A9E217316D55BA6B05D8FA94AE0A5DB72C8BD384144279C2FC97A83D6B39C` |

## Changes from the original

- Renamed MuteGuard to TrayMute: app name, window titles, settings file (`TrayMute.ini`),
  `%APPDATA%\TrayMute` folder and startup shortcut (`TrayMute.lnk`).
- **v2.0: renamed TrayMute to HushDot — Privacy Signals**: script `HushDot.ahk`, settings
  `HushDot.ini`, `%APPDATA%\HushDot`, startup shortcut `HushDot.lnk`, helper
  `HushDot.Sensors.exe`, temporary file prefix `~hd_`. On first start HushDot copies TrayMute's
  settings, replaces its startup shortcut and closes a running TrayMute.
- Version reset to v1.0, and "Pro" removed from the About page.
- Temporary write-test file prefix changed from `~mg_` to `~tm_`.
- Removed the original author's "Donate" and "App Website" buttons.
- Replaced the "GitHub Repository" button with a "Créditos" (credits) button that links to the original MuteGuard repository.
- Added a "Sponsor" button for this fork's maintainer.
- New tray icons (red microphone, blue speaker, grey when muted), created for TrayMute
  and released under the same MIT License. Light and dark sets in `icons/`.
- The tray icon set now follows the Windows taskbar theme (read-only registry lookup)
  instead of the app's own dark-mode setting.
- Fixed relative icon paths saved in the settings file not switching between the
  light and dark icon sets.
- Added "Mute all microphones" (on by default). Muting silences every active capture
  device through the Windows Core Audio API (`IMMDeviceEnumerator` and
  `IAudioEndpointVolume`, called with `ComObject`/`ComCall`; the original script used
  neither). Unmuting restores only the devices that were live before. The restore list
  is kept in the settings file, so it survives a restart. Devices are handled one by one
  (one failing device does not stop the others), devices added while muted are muted too,
  and devices unplugged while muted are restored when they come back.
- Added "Mute all speakers" (on by default), the same logic for output devices. While it
  is not engaged, the speaker icon follows the selected output.
- Input and output devices are now told apart by the data flow Windows reports instead
  of English words in the device name, so localized names (e.g. "Fones de ouvido") and
  Bluetooth headset outputs are listed correctly, and disconnected devices are skipped.
- The startup shortcut now launches the script through the AutoHotkey interpreter, so it
  works even when `.ahk` files are not associated with AutoHotkey. When compiled, it points
  at `TrayMute.exe` itself.
- Added a microphone in-use indicator: an orange dot on the mic tray icon (new
  `*_inuse.ico` icons, MIT License) whenever any app is using a microphone, with the app
  names in the tooltip. It reads the Windows microphone privacy records (read-only registry
  access) and the active capture sessions.
- Added a camera tray icon (new `cam_*.ico` icons, MIT License): it opens the Windows Camera
  app, turns violet while that app is open and shows a green dot when an app is using a
  camera. Camera use is detected through the Windows sensor activity API
  (`MFCreateSensorActivityMonitor`) by a new companion program, `TrayMute.Sensors.exe`
  (source in `helper/`, MIT License, built with the C# compiler included with Windows), which
  reports to TrayMute via `WM_COPYDATA`. Without it, TrayMute falls back to the Windows
  camera privacy records.
- Added a choice of which tray icons to show (microphone, speaker, camera; at least one).
  The speaker and camera icons now share one tray-icon helper, which also restores them after
  Explorer restarts. Messages fall back to a tooltip when the microphone icon is hidden.
- A small "TrayMute is running" box above the clock appears when TrayMute is started by hand
  (not when Windows starts it, which the startup shortcut marks with `--autostart`). It is a
  window of its own because Windows notifications may be turned off; it can be disabled.
  Error messages also fall back to a tooltip when Windows notifications are off.
- Picking a speaker now also makes it the Windows default output (console and multimedia
  roles; the communication device used for calls is left alone). The original
  only changed which device the mute button controlled, although the option was labelled
  as the default output. Uses the `IPolicyConfig` interface, which Windows does not
  document officially.
- Added an application icon (`icons/app.ico`, MIT License like the tray icons) and Ahk2Exe
  directives (name, version, description, icon) so the script can be released as a
  standalone `TrayMute.exe`.

No other functional changes were made.

## License

MuteGuard is distributed under the MIT License, Copyright (c) 2026 Raja Mukherjee.
That license, with its copyright notice, is kept unchanged in [`LICENSE`](LICENSE) and applies to this fork.
