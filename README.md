<h1 align="center">RE9-CrossOver-Fix</h1>

<p align="center">
  <strong>Graphics, Stability, Audio Popping, DualSense Bluetooth, Window Auto-Focus & Cursor Hide Fix for <em>Resident Evil Requiem</em> on CrossOver macOS (Apple Silicon)</strong>
</p>

---

> [!NOTE]
> **AI-Generated Tool Disclosure**
> **RE9-CrossOver-Fix** is an AI-generated configuration and launcher patcher created with **Antigravity** (Google DeepMind) to resolve D3DMetal/Apple Neural Engine crashes, DX12 swapchain black screens, 16 GB Unified Memory swap stutters, CoreAudio buffer underrun pops, Bluetooth PS5 DualSense detection, and macOS window focus/cursor capture issues when running *Resident Evil Requiem* (`re9.exe`) in CodeWeavers CrossOver.

---

## 🔍 What Problems Does This Solve?

### 1. Mid-Game Crashes & 11 ms Micro-Stutters (`AppleH11ANEInterface` / MetalFX)
When running *Resident Evil Requiem* with `D3DM_ENABLE_METALFX=1` and `UpscalingAlgorithm=DLSS`, D3DMetal translates DLSS calls into MetalFX temporal upscaling routed through the Apple Neural Engine (`AppleH11ANEInterface`). On Apple Silicon Macs, the macOS kernel logs continuous event invalidations every single frame (~11 ms):
```text
AppleH11ANEInterface: processDeviceChainingEvent: Got invalidate event
AppleH11ANEInterface: sharedEventNotification: Request not found
IOSurface: buffer->fClientTask = 0x0 not found
```
This per-frame kernel synchronization failure causes persistent frame-time spikes and eventually crashes the game.

**How `RE9-CrossOver-Fix` solves it:**
- Sets `"D3DM_ENABLE_METALFX" = "0"` in `cxbottle.conf`.
- Configures `UpscalingAlgorithm=FSR1` (`UpscalingQuality_FSR1=Quality`, `UpscalingSharpness=8`) paired with `AntiAliasing=TAA` in `config.ini`. Upscaling runs 100% on GPU shaders without touching the Apple Neural Engine, delivering crisp image quality and zero ANE faults.

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
