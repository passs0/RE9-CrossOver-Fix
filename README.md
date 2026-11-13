<h1 align="center">RE9-CrossOver-Fix</h1>

<p align="center">
  <strong>Graphics, Stability, Audio Popping, DualSense Bluetooth, Window Auto-Focus & Cursor Hide Fix for <em>Resident Evil Requiem</em> on CrossOver macOS (Apple Silicon)</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-Apple%20Silicon-black?logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/target-CrossOver%20%7C%20Resident%20Evil%20Requiem-007AFF" alt="Target" />
  <img src="https://img.shields.io/badge/pipeline-D3DMetal%20%7C%20DX12%20%7C%20FSR1-blue" alt="Pipeline" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" /></a>
</p>

---

> [!NOTE]
> **AI-Generated Tool Disclosure**
> **RE9-CrossOver-Fix** is an AI-generated configuration and launcher patcher created with **Antigravity** (Google DeepMind) for reported D3DMetal/MetalFX instability, DX12 swapchain black screens, 16 GB Unified Memory swap stutters, CoreAudio buffer underrun pops, Bluetooth PS5 DualSense detection, and macOS window focus/cursor capture issues when running *Resident Evil Requiem* (`re9.exe`) in CodeWeavers CrossOver. The MetalFX/ANE explanation below is a troubleshooting hypothesis, not a confirmed root cause for every system.

---

## 🔍 What Problems Does This Solve?

### 1. MetalFX/ANE Log Correlation (Causality Unconfirmed)
This project records `AppleH11ANEInterface` and `IOSurface` messages observed while running *Resident Evil Requiem* under CrossOver, alongside frame-time spikes or crashes. Example messages include:
```text
AppleH11ANEInterface: processDeviceChainingEvent: Got invalidate event
AppleH11ANEInterface: sharedEventNotification: Request not found
IOSurface: buffer->fClientTask = 0x0 not found
```

These messages alone do not establish that MetalFX caused the messages, that they cause the observed stutter/crash, or that the same issue affects every Mac, macOS, CrossOver, or game version. Apple describes MetalFX as a Metal upscaling framework; its current documentation specifically calls out Neural Engine acceleration for a redesigned temporal upscaler on M5 Pro and M5 Max. That does not confirm Neural Engine use by CrossOver's MetalFX path on other chips. See [Apple's MetalFX overview](https://developer.apple.com/documentation/MetalFX) and [Metal release notes](https://developer.apple.com/metal/whats-new/).

Treat the settings below as a conservative workaround to try when the issue is reproducible, not as a proven universal fix. Record the game, macOS, CrossOver/GPTK version, chip, selected upscaler, and logs when comparing enabled and disabled settings.

**How `RE9-CrossOver-Fix` solves it:**
- Sets `"D3DM_ENABLE_METALFX" = "0"` in `cxbottle.conf` to opt out of the D3DMetal MetalFX path used by the affected configuration.
- Configures `UpscalingAlgorithm=FSR1` (`UpscalingQuality_FSR1=Quality`, `UpscalingSharpness=8`) paired with `AntiAliasing=TAA` in `config.ini`. This selects the game's FSR 1 upscaler instead of its DLSS option. Do not infer from this setting alone that ANE faults are prevented or that FSR 1 is faster on every system.

The environment variable is separate from CrossOver's Metal Performance HUD: `MTL_HUD_ENABLED=1` can remain enabled for performance monitoring. Also, a different game sharing a bottle with `D3DM_ENABLE_METALFX=1` is not an A/B test for Requiem; it may use a different rendering or upscaling path.

---

### 2. Black Screen After RE Engine Logo & 16 GB Unified Memory Stutters
- **DLSS Frame Generation + VSync Deadlock:** Combining `FrameGeneration=DLSS 2x` with `VSync=True` deadlocks the RE Engine DX12 swapchain immediately after the opening logo video, leaving the game stuck on a black screen. Setting `FrameGeneration=Off` and `VSync=True` prevents both the hang and screen tearing.
- **Invalid `TextureQuality=Normal` Enum Trap:** In *Resident Evil Requiem*'s config parser, `Normal` is not a valid enum for `TextureQuality`—the engine silently resets it to `High`, overflowing 16 GB Unified Memory into macOS SSD swap. Setting `TextureQuality=Low` paired with `TextureSamplerQuality=Anisotropic8` keeps memory usage well within 16 GB while preserving sharp surface detail.
- **Hair Strands & Shader Bottlenecks:** Sets `StrandsEnable=False`, `ShadowQuality=Normal`, `ShadowCacheEnable=True`, `ContactShadowEnable=False`, and `EcoShaderCache=True` for fast shader compilation and smooth frame pacing.

---

### 3. Audio Popping & Crackling (`coreaudiod` Overload)
During heavy DX12 scene streaming, macOS `coreaudiod` logs `HALS_OverloadMessage: Overload possibly due to client timeout` for `com.codeweavers.CrossOver.wineloader` when `RenderWorkerThreadPriorityAboveNormal=Enable` is active, because elevated DX12 worker threads starve Wine's real-time audio thread.
- **How it's resolved:** Sets `RenderWorkerThreadPriorityAboveNormal=Disable` and `ParallelBuildProcessorCount=8` in `config.ini` so Wine's audio thread always meets CoreAudio's deadline.

---

### 4. Launcher Black Screen, Background Window Focus & Stuck macOS Cursor
- **CrossOver `.lnk` Working Directory Bug:** Launching via a standard Windows `.lnk` shortcut (`wine --start`) starts `re9.exe` in the wrong working directory, causing a black screen on boot.
- **Window Focus & Visible Cursor:** When launched from the CrossOver UI, `CrossOver.app` stays in the foreground on top of the borderless game window, and `winemac.drv` leaves the macOS system cursor visible over the center of the screen until the physical mouse is manually moved.
- **How it's resolved:**
  - Configures `cxmenu.conf` with `"Type" = "raw"` to invoke `re9.exe` directly from its game directory via `wine --bottle ... --check --wait-children` and locks `"MenuMode" = "frozen"` in `cxbottle.conf`.
  - Runs `focus_and_hide_cursor.sh` in the background on launch, which brings `re9.exe` to the front and dispatches a 1-pixel CoreGraphics `kCGEventMouseMoved` nudge so `winemac.drv` registers and hides the macOS cursor automatically.

---

### 5. Bluetooth PS5 DualSense Controller Not Recognized
By default, Wine's `winebus.sys` attempts raw HID access (`hidraw`) which fails to bind the DualSense controller properly over Bluetooth on macOS.
- **How it's resolved:** Sets `"DisableHidraw"=dword:00000001` under `[System\\CurrentControlSet\\Services\\winebus]` in `system.reg` and `"ButtonIconType=PS"` in `config.ini`, routing controller input cleanly through macOS IOHID/SDL with native PlayStation button prompts.

---

## 🚀 Installation

```zsh
git clone https://github.com/passs0/RE9-CrossOver-Fix.git
cd RE9-CrossOver-Fix
chmod +x install.sh
./install.sh
```

`install.sh` automatically detects the CrossOver bottle containing `re9.exe` (or you can specify a bottle name explicitly: `./install.sh "Resident Evil Requiem"`). No game binaries or DLLs are modified.

---

## 📁 Repository Structure

- [`install.sh`](install.sh) — Automated installer that locates your *Resident Evil Requiem* bottle, applies the tuned `config.ini` (while preserving your display/adapter enumeration), updates `cxbottle.conf`, `system.reg`, `user.reg`, and configures the `cxmenu` launcher.
- [`config/config.ini`](config/config.ini) — Tuned RE Engine configuration profile for Apple Silicon Macs (16 GB+ Unified Memory, 120Hz ProMotion / Retina displays).
- [`scripts/focus_and_hide_cursor.sh`](scripts/focus_and_hide_cursor.sh) — Background launch helper that brings `re9.exe` in front of CrossOver and nudges the cursor by 1px via CoreGraphics so `winemac.drv` hides the macOS cursor automatically.

---

## 📄 License

Released under the [MIT License](LICENSE).
