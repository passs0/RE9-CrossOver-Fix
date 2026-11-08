#!/bin/zsh
set -euo pipefail

BOTTLES_DIR="$HOME/Library/Application Support/CrossOver/Bottles"
CX_BIN="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================================"
echo "  RE9-CrossOver-Fix — Resident Evil Requiem on macOS"
echo "========================================================"

if [[ ! -d "$CX_BIN" ]]; then
  echo "❌ Error: CrossOver.app not found at /Applications/CrossOver.app"
  exit 1
fi

# 1. Auto-detect the bottle containing Resident Evil Requiem (re9.exe)
TARGET_BOTTLE=""
RE9_EXE=""

if [[ $# -ge 1 ]]; then
  TARGET_BOTTLE="$BOTTLES_DIR/$1"
  if [[ -d "$TARGET_BOTTLE" ]]; then
    RE9_EXE="$(find "$TARGET_BOTTLE/drive_c" -maxdepth 4 -iname "re9.exe" 2>/dev/null | head -n 1)"
  fi
else
  for b in "$BOTTLES_DIR"/*(/N); do
    found="$(find "$b/drive_c" -maxdepth 4 -iname "re9.exe" 2>/dev/null | head -n 1)"
    if [[ -n "$found" ]]; then
      TARGET_BOTTLE="$b"
      RE9_EXE="$found"
      break
    fi
  done
fi

if [[ -z "$TARGET_BOTTLE" || -z "$RE9_EXE" || ! -f "$RE9_EXE" ]]; then
  echo "❌ Error: Could not locate re9.exe in any CrossOver bottle."
  echo "Usage: ./install.sh \"<Bottle Name>\""
  exit 1
fi

BOTTLE_NAME="$(basename "$TARGET_BOTTLE")"
RE9_DIR="$(dirname "$RE9_EXE")"

echo "✅ Found Resident Evil Requiem in bottle: $BOTTLE_NAME"
echo "   Game directory: $RE9_DIR"

# 2. Install focus_and_hide_cursor.sh
cp "$SCRIPT_DIR/scripts/focus_and_hide_cursor.sh" "$TARGET_BOTTLE/focus_and_hide_cursor.sh"
chmod +x "$TARGET_BOTTLE/focus_and_hide_cursor.sh"
echo "✅ Installed focus_and_hide_cursor.sh (auto-focus window & auto-hide cursor)"

# 3. Configure cxbottle.conf (D3DM_ENABLE_METALFX=0, WINEMSYNC=1, ROSETTA_ADVERTISE_AVX=1)
if [[ -f "$TARGET_BOTTLE/cxbottle.conf" ]]; then
  python3 - "$TARGET_BOTTLE/cxbottle.conf" <<'PY'
import sys, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

env_Settings = {
    "D3DM_ENABLE_METALFX": "0",
    "WINEMSYNC": "1",
    "ROSETTA_ADVERTISE_AVX": "1",
}

if "[EnvironmentVariables]" not in text:
    text += "\n[EnvironmentVariables]\n"

for k, v in env_Settings.items():
    pattern = rf'^"{re.escape(k)}"\s*=\s*".*?"'
    replacement = f'"{k}" = "{v}"'
    if re.search(pattern, text, flags=re.MULTILINE):
        text = re.sub(pattern, replacement, text, flags=re.MULTILINE)
    else:
        text = text.replace("[EnvironmentVariables]", f'[EnvironmentVariables]\n"{k}" = "{v}"', 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
  echo "✅ Updated cxbottle.conf (D3DM_ENABLE_METALFX=0, WINEMSYNC=1, ROSETTA_ADVERTISE_AVX=1)"
fi

# 4. Configure Bluetooth DualSense controller support in system.reg (DisableHidraw=1)
if [[ -f "$TARGET_BOTTLE/system.reg" ]]; then
  python3 - "$TARGET_BOTTLE/system.reg" <<'PY'
import sys, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

section = r"[System\\CurrentControlSet\\Services\\winebus]"
if section in text:
    idx = text.index(section)
    next_sec = text.find("\n[", idx + len(section))
    block = text[idx:next_sec] if next_sec != -1 else text[idx:]
    if '"DisableHidraw"' in block:
        new_block = re.sub(r'"DisableHidraw"=dword:[0-9a-fA-F]+', '"DisableHidraw"=dword:00000001', block)
    else:
        new_block = block.rstrip() + '\n"DisableHidraw"=dword:00000001\n\n'
    text = (text[:idx] + new_block + text[next_sec:]) if next_sec != -1 else (text[:idx] + new_block)
else:
    text += f'\n{section} 1700000000\n"DisableHidraw"=dword:00000001\n'

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
  echo "✅ Enabled Bluetooth PS5 DualSense controller in system.reg (DisableHidraw=1)"
fi

# 5. Ensure RetinaMode="n" in user.reg for clean borderless scaling
if [[ -f "$TARGET_BOTTLE/user.reg" ]]; then
  python3 - "$TARGET_BOTTLE/user.reg" <<'PY'
import sys, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

section = r"[Software\\Wine\\Mac Driver]"
if section in text:
    idx = text.index(section)
    next_sec = text.find("\n[", idx + len(section))
    block = text[idx:next_sec] if next_sec != -1 else text[idx:]
    block = re.sub(r'^"CaptureDisplaysForFullscreen"=".*?"\n?', '', block, flags=re.MULTILINE)
    if '"RetinaMode"' in block:
        block = re.sub(r'"RetinaMode"=".*?"', '"RetinaMode"="n"', block)
    else:
        block = block.rstrip() + '\n"RetinaMode"="n"\n\n'
    text = (text[:idx] + block + text[next_sec:]) if next_sec != -1 else (text[:idx] + block)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
  echo "✅ Verified Wine Mac Driver settings in user.reg (RetinaMode=\"n\")"
fi

# 6. Apply tuned graphics, upscaling & worker-thread settings in config.ini
CONFIG_INI="$RE9_DIR/config.ini"
if [[ -f "$CONFIG_INI" ]]; then
  python3 - "$CONFIG_INI" "$SCRIPT_DIR/config/config.ini" <<'PY'
import sys

target_path, ref_path = sys.argv[1], sys.argv[2]

def parse_sections(path):
    sections = {}
    order = []
    cur = None
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("[") and line.endswith("]"):
                cur = line
                if cur not in sections:
                    sections[cur] = []
                    order.append(cur)
            elif cur is not None and "=" in line:
                k, v = line.split("=", 1)
                sections[cur].append((k, v))
    return order, sections

t_order, t_sec = parse_sections(target_path)
r_order, r_sec = parse_sections(ref_path)

# Replace [GameOption], [Render], [RenderConfig], [RenderDeviceDirectX12] from reference
# while preserving hardware-specific [Render/Adapter] and [Render/Display]
for sec in ["[GameOption]", "[Render]", "[RenderConfig]", "[RenderDeviceDirectX12]"]:
    if sec in r_sec:
        t_sec[sec] = r_sec[sec]
        if sec not in t_order:
            t_order.append(sec)

out_lines = []
for sec in t_order:
    out_lines.append(sec)
    for k, v in t_sec[sec]:
        out_lines.append(f"{k}={v}")

with open(target_path, "w", encoding="utf-8", newline="\r\n") as f:
    f.write("\n".join(out_lines) + "\n")
PY
  echo "✅ Applied optimized graphics & stability profile in config.ini"
else
  cp "$SCRIPT_DIR/config/config.ini" "$CONFIG_INI"
  echo "✅ Installed default optimized config.ini"
fi

# 7. Configure CrossOver bottle launcher (cxmenu.conf & cxmenu_macosx.plist)
ICON_PATH="$(find "$TARGET_BOTTLE/windata/cxmenu/icons/hicolor/256x256" -name "*re9*.png" 2>/dev/null | head -n 1)"
[[ -z "$ICON_PATH" ]] && ICON_PATH="24AE_re9.0"

RAW_CMD="sh -c 'sh \\\"$TARGET_BOTTLE/focus_and_hide_cursor.sh\\\" & cd \\\"$RE9_DIR\\\" && exec \\\"$CX_BIN/wine\\\" --bottle \\\"$BOTTLE_NAME\\\" --check --wait-children \\\"$RE9_EXE\\\"'"

cat > "$TARGET_BOTTLE/cxmenu.conf" <<EOF
[Desktop.C^3A_users_crossover_Desktop/Resident Evil Requiem.lnk]
"Type" = "raw"
"Command" = "$RAW_CMD"
"Icon" = "$ICON_PATH"
"Shortcut" = "re9"
"Mode" = "install"
"StartupWMClass" = "re9.exe"

[StartMenu.C^3A_users_crossover_AppData_Roaming_Microsoft_Windows_Start+Menu/Resident Evil Requiem.lnk]
"Type" = "raw"
"Command" = "$RAW_CMD"
"Icon" = "$ICON_PATH"
"Shortcut" = "re9"
"Mode" = "install"
"StartupWMClass" = "re9.exe"
EOF

if [[ -f "$TARGET_BOTTLE/cxbottle.conf" ]]; then
  sed -i '' 's/"MenuMode" = "frozen"/"MenuMode" = "install"/g' "$TARGET_BOTTLE/cxbottle.conf"
fi

"$CX_BIN/cxmenu" --bottle "$BOTTLE_NAME" --install >/dev/null 2>&1 || true

if [[ -f "$TARGET_BOTTLE/cxbottle.conf" ]]; then
  sed -i '' 's/"MenuMode" = "install"/"MenuMode" = "frozen"/g' "$TARGET_BOTTLE/cxbottle.conf"
fi

echo "✅ Configured CrossOver launcher ('Resident Evil Requiem' + Auto-Focus + Cursor Hide)"
echo ""
echo "🎉 Done! Launch 'Resident Evil Requiem' directly from CrossOver."
