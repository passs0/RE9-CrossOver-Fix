#!/bin/sh
# Brings the Resident Evil Requiem (re9.exe) window to the front and nudges
# the cursor by 1px via CoreGraphics so winemac.drv hides the macOS cursor.

for i in 1 2 3 4 5 6 7 8 9 10 12 15 18 22; do
  sleep 1
  osascript -e 'tell application "System Events" to set frontmost of (every process whose name is "re9.exe" or name contains "wine") to true' >/dev/null 2>&1
  osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); var p1 = {x: 756 + ('"$i"' % 2), y: 491}; $.CGWarpMouseCursorPosition(p1); var e = $.CGEventCreateMouseEvent(null, $.kCGEventMouseMoved, p1, 0); $.CGEventPost($.kCGHIDEventTap, e);' >/dev/null 2>&1
done
