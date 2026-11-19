// Theme.qml
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property var palettes: ({
    teal: {
      accent: "#3dd1b0", warn: "#ffa478", cool: "#7cc4e0",
      pill: "#040e0d", pillAlt: "#0f1f22",
      text: "#f5e2c5", dim: "#3a5a57", faint: "#1c2f31"
    },
    nord: {
      accent: "#88c0d0", warn: "#ebcb8b", cool: "#81a1c1",
      pill: "#2e3440", pillAlt: "#3b4252",
      text: "#eceff4", dim: "#4c566a", faint: "#434c5e"
    },
    rose: {
      accent: "#f38ba8", warn: "#fab387", cool: "#89b4fa",
      pill: "#1e1e2e", pillAlt: "#313244",
      text: "#cdd6f4", dim: "#585b70", faint: "#45475a"
    },
    sunset: {
      accent: "#f5a24d", warn: "#e0674a", cool: "#8fb4cc",
      pill: "#16100d", pillAlt: "#261a14",
      text: "#f7e6cc", dim: "#7a5a45", faint: "#33261d",
      wallpaper: "sunrise.jpeg"
    },
    eclipse: {
      accent: "#d9d3c7", warn: "#e8a76a", cool: "#8aa8d6",
      pill: "#07080b", pillAlt: "#14161b",
      text: "#ece7dd", dim: "#4a4c52", faint: "#1d1f24",
      wallpaper: "artemis.jpg"
    },
    frost: {
      accent: "#8fb8a0", warn: "#d98b5f", cool: "#8fb0c8",
      pill: "#101a18", pillAlt: "#1b2a27",
      text: "#e8eeea", dim: "#4d6560", faint: "#26332f",
      wallpaper: "snowytrees.JPG"
    },
    frostLight: {
      accent: "#3f6b57", warn: "#c0612f", cool: "#4a7a9a",
      pill: "#eef2ef", pillAlt: "#dde5e0",
      text: "#1a2622", dim: "#8da39a", faint: "#c9d4ce",
      wallpaper: "snowytrees.JPG"
    }
  })

  property string name: "teal"
  readonly property var current: palettes[name] ?? palettes.teal

  readonly property color accent:  current.accent
  readonly property color warn:    current.warn
  readonly property color cool:    current.cool
  readonly property color pill:    current.pill
  readonly property color pillAlt: current.pillAlt
  readonly property color text:    current.text
  readonly property color dim:     current.dim
  readonly property color faint:   current.faint

  readonly property string font: "JetBrainsMono Nerd Font"
  readonly property string iconFont: "Material Symbols Rounded"

  // ---- Wallpaper ----

  property string wallpaperDir: Quickshell.env("HOME") + "/Pictures"
  property string defaultWallpaper: "artemis.jpg"

  readonly property string wallpaperPath:
    wallpaperDir + "/" + (current.wallpaper ?? defaultWallpaper)

  Process { id: wpProc }

  // Starts the new swaybg first, then kills the old one, so there's no blank flash
  function applyWallpaper() {
    wpProc.command = [
      "sh", "-c",
      'old=$(pgrep -x swaybg); setsid swaybg -i "$1" -m fill >/dev/null 2>&1 & sleep 0.3; [ -n "$old" ] && kill $old',
      "sh", wallpaperPath
    ]
    wpProc.running = true
  }

  // Debounced, so the startup default -> saved-theme change only applies once
  Timer {
    id: wpTimer
    interval: 150
    onTriggered: root.applyWallpaper()
  }

  onNameChanged: wpTimer.restart()
  Component.onCompleted: wpTimer.restart()

  // ---- Switching ----

  function set(n) {
    if (!palettes[n]) return
    name = n
    saveFile.setText(n)
  }

  function next() {
    const keys = Object.keys(palettes)
    set(keys[(keys.indexOf(name) + 1) % keys.length])
  }

  function prev() {
    const keys = Object.keys(palettes)
    set(keys[(keys.indexOf(name) - 1 + keys.length) % keys.length])
  }

  IpcHandler {
    target: "theme"
    function set(name: string): void { root.set(name) }
    function next(): void { root.next() }
    function prev(): void { root.prev() }
    function get(): string { return root.name }
  }

  // Remember the choice across restarts
  FileView {
    id: saveFile
    path: Quickshell.env("HOME") + "/.local/state/qs-theme"
    onLoaded: {
      const n = text().trim()
      if (root.palettes[n]) root.name = n
    }
  }
}
