import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../theme"

PanelWindow {
  id: bar

  property bool vpnDown: vpn.value === "Not Connected"
  property int cpuPercent: 0
  property var lastCpu: null
  property string memUsed: "0.0"

  // Prefer a player that's currently playing, otherwise fall back to the first one
  readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0]

  // "Artist -- Title", skipping the separator if either part is missing
  readonly property string nowPlaying: {
    if (!player) return "Nothing Playing"
    const parts = [player.trackArtist, player.trackTitle].filter(s => s)
    return parts.length > 0 ? parts.join(" -- ") : "Unknown"
  }

  property int slant: 24
  property int slantRadius: 14

  anchors { top: true; left: true; right: true }
  margins { top: 0; left: 30; right: 30 }
  implicitHeight: 36
  color: "transparent"

  // ---- Command pollers ----

  Poller {
    id: vol
    command: "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf\"%d\", $2*100}'"
    interval: 1000
  }

  Poller {
    id: net
    command: "dev=$(ip route show default | awk '{print $5; exit}'); a=$(awk -v d=\"$dev:\" '$1==d{print $2}' /proc/net/dev); sleep 1; b=$(awk -v d=\"$dev:\" '$1==d{print $2}' /proc/net/dev); echo \"↓ $(( (b-a)/1024 )) KB/s\""
    interval: 3000
  }

  Poller {
    id: vpn
    command: "ip -4 -o addr show tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep . || echo 'Not Connected'"
    interval: 5000
  }

  // ---- CPU and memory, read straight from /proc ----

  FileView {
    id: statFile
    path: "/proc/stat"
    onLoaded: {
      const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
      const idle = f[3] + f[4]
      const total = f.reduce((a, b) => a + b, 0)
      if (bar.lastCpu) {
        const dt = total - bar.lastCpu.total
        const di = idle - bar.lastCpu.idle
        if (dt > 0) bar.cpuPercent = Math.round(100 * (dt - di) / dt)
      }
      bar.lastCpu = { idle: idle, total: total }
    }
  }

  FileView {
    id: memFile
    path: "/proc/meminfo"
    onLoaded: {
      const t = text()
      const total = Number(t.match(/MemTotal:\s+(\d+)/)[1])
      const avail = Number(t.match(/MemAvailable:\s+(\d+)/)[1])
      bar.memUsed = ((total - avail) / 1048576).toFixed(1)
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { statFile.reload(); memFile.reload() }
  }

  // ---- Layout ----

  SystemClock { id: sysClock; precision: SystemClock.Minutes }

  // One continuous bar with softened bottom corners
  Shape {
    id: bg
    anchors.fill: parent
    antialiasing: true

    // Length of a slanted edge, used to step back along it
    readonly property real edge: Math.sqrt(bar.slant * bar.slant + height * height)
    readonly property real dx: bar.slantRadius * bar.slant / edge
    readonly property real dy: bar.slantRadius * height / edge

    ShapePath {
      fillColor: Theme.pillGlass
      strokeColor: "transparent"
      strokeWidth: -1

      // Top edge, left to right
      startX: 0; startY: 0
      PathLine { x: bg.width; y: 0 }

      // Right slant, then rounded corner into the bottom edge
      PathLine { x: bg.width - bar.slant + bg.dx; y: bg.height - bg.dy }
      PathQuad {
        x: bg.width - bar.slant - bar.slantRadius; y: bg.height
        controlX: bg.width - bar.slant;            controlY: bg.height
      }

      // Bottom edge, then rounded corner into the left slant
      PathLine { x: bar.slant + bar.slantRadius; y: bg.height }
      PathQuad {
        x: bar.slant - bg.dx; y: bg.height - bg.dy
        controlX: bar.slant;  controlY: bg.height
      }

      // Left slant back up to the start
      PathLine { x: 0; y: 0 }

      Behavior on fillColor { ColorAnimation { duration: 200 } }
    }
  }

  // Left: workspace dots straight on the bar
  Workspaces {
    framed: false
    anchors.left: parent.left
    anchors.leftMargin: bar.slant /2 + 20
    anchors.verticalCenter: parent.verticalCenter
  }

  // Center: raised tab with date, inset clock, month
  Rectangle {
    id: tab
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    height: parent.height
    width: tabRow.implicitWidth + 56
    radius: 16
    color: Theme.pillAlt
    Behavior on color { ColorAnimation { duration: 200 } }

    // Squares off the top corners so only the bottom is rounded
    Rectangle {
      anchors.top: parent.top
      width: parent.width
      height: parent.radius
      color: parent.color
    }

    RowLayout {
      id: tabRow
      anchors.centerIn: parent
      spacing: 14

      Text {
        text: Qt.formatDateTime(sysClock.date, "dddd")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 15
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 120
      }

      Rectangle {
        implicitWidth: clockRow.implicitWidth + 28
        implicitHeight: 26
        radius: 13
        color: Theme.pill

        RowLayout {
          id: clockRow
          anchors.centerIn: parent
          spacing: 8

          Rectangle { Layout.preferredWidth: 22; Layout.preferredHeight: 1; color: Theme.dim }
          Text {
            text: Qt.formatDateTime(sysClock.date, "HH : mm")
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 15
            font.bold: true
          }
          Rectangle { Layout.preferredWidth: 22; Layout.preferredHeight: 1; color: Theme.dim }
        }
      }

      Text {
        text: Qt.formatDateTime(sysClock.date, "MMMM, d")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 15
        Layout.preferredWidth: 120
      }
    }
  }

  // Right: icon-only status, label on hover
  RowLayout {
    anchors.right: parent.right
    anchors.rightMargin: bar.slant / 2 + 20
    anchors.verticalCenter: parent.verticalCenter
    spacing: 16

    Stat {
      compact: true
      icon: "music_note"
      label: bar.nowPlaying
      maxLabelWidth: 240
      visible: bar.player !== undefined
    }
    Stat { compact: true; icon: "memory"; label: bar.cpuPercent + "%" }
    Stat { compact: true; icon: "storage"; label: bar.memUsed + " GB"; iconColor: Theme.warn }
    Stat { compact: true; icon: "volume_up"; label: vol.value + "%"; iconColor: Theme.cool }
    Stat { compact: true; icon: "speed"; label: net.value; iconColor: Theme.cool }
    Stat {
      compact: true
      icon: "vpn_key"
      label: vpn.value
      visible: vpn.value !== "" && !bar.vpnDown
    }
    Stat {
      compact: true
      icon: "palette"
      label: Theme.name
      onClicked: Theme.next()
      onRightClicked: Theme.prev()
    }
  }
}
