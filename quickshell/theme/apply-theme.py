#!/usr/bin/env python3
"""Render the current Quickshell palette into other apps' config files.

Called by Theme.qml whenever the theme changes:

    apply-theme.py '<palette json>'

For every entry in targets.json it fills in templates/<template>, writes the
result to <output>, and (only if the file actually changed) runs the entry's
"reload" command.

Output files live in $XDG_STATE_HOME/qs-theme/ (default ~/.local/state/qs-theme),
a writable place that works even when ~/.config is managed read-only (Nix /
home-manager). Link each file into the app's config folder (see
home-manager/qs-theme.nix). An absolute or ~ output path is used as-is.

Template syntax:   {{key}}  or  {{key.modifier.modifier}}
  keys:      any palette color (accent, red, pill, ...), plus the aliases
             bg (= pill), bgAlt (= pillAlt) and fg (= text);
             also {{name}} and {{scheme}} (prefer-dark / prefer-light)
  modifiers: bare    rrggbb         (no leading #)
             rgb     r, g, b        (0-255)
             bright  a more prominent shade: lighter on dark themes, darker
                     on light ones
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "qs-theme"
ALIASES = {"bg": "pill", "bgAlt": "pillAlt", "fg": "text"}
TOKEN = re.compile(r"\{\{\s*([A-Za-z0-9_]+)((?:\.[a-z]+)*)\s*\}\}")
HEX = re.compile(r"^#(?:[0-9a-fA-F]{2})?([0-9a-fA-F]{6})$")


def to_rgb(value):
    m = HEX.match(value)
    h = m.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(rgb, target, amount):
    return tuple(round(c + (t - c) * amount) for c, t in zip(rgb, target))


def render_value(key, mods, palette):
    raw = palette.get(ALIASES.get(key, key))
    if raw is None:
        raise KeyError(f"unknown palette key '{key}'")
    if key == "scheme":
        return raw
    if isinstance(raw, bool):
        return "true" if raw else "false"
    if not isinstance(raw, str) or not HEX.match(raw):
        if mods:
            raise ValueError(f"'{key}' is not a color, can't apply modifiers")
        return str(raw)

    rgb = to_rgb(raw)
    fmt = "hex"
    for mod in mods:
        if mod == "bright":
            rgb = mix(rgb, (255, 255, 255) if palette["dark"] else (0, 0, 0), 0.18)
        elif mod in ("bare", "rgb"):
            fmt = mod
        else:
            raise ValueError(f"unknown modifier '.{mod}' on '{key}'")
    if fmt == "bare":
        return "%02x%02x%02x" % rgb
    if fmt == "rgb":
        return "%d, %d, %d" % rgb
    return "#%02x%02x%02x" % rgb


def render(template, palette):
    def sub(m):
        mods = [x for x in m.group(2).split(".") if x]
        return render_value(m.group(1), mods, palette)
    return TOKEN.sub(sub, template)


def write_if_changed(path, content):
    """Atomic write. Returns True if the file's contents changed."""
    try:
        if path.read_text() == content:
            return False
    except FileNotFoundError:
        pass
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(content)
    os.replace(tmp, path)
    return True


def run(cmd):
    try:
        r = subprocess.run(cmd, shell=True, timeout=10, check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if r.returncode == 127:   # shell couldn't find the program: PATH problem
            print(f"command not found on PATH: {cmd}", file=sys.stderr)
    except subprocess.TimeoutExpired:
        print(f"command timed out: {cmd}", file=sys.stderr)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    palette = json.loads(sys.argv[1])
    palette["scheme"] = "prefer-dark" if palette.get("dark", True) else "prefer-light"

    config = json.loads((HERE / "targets.json").read_text())
    errors = 0
    reloads = []   # ordered, de-duplicated

    for target in config.get("targets", []):
        name = target["template"]
        out = STATE / os.path.expanduser(target["output"])
        try:
            out.parent.mkdir(parents=True, exist_ok=True)
            text = render((HERE / "templates" / name).read_text(), palette)
            if write_if_changed(out, text):
                print(f"wrote {out}")
                cmd = target.get("reload")
                if cmd and cmd not in reloads:
                    reloads.append(cmd)
        except Exception as e:   # keep going; one bad target shouldn't block the rest
            errors += 1
            print(f"{name} -> {out}: {e}", file=sys.stderr)

    for cmd in reloads:
        run(cmd)

    # Hooks run every time (they're cheap and idempotent), e.g. light/dark preference
    for cmd in config.get("hooks", []):
        run(render(cmd, palette))

    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
