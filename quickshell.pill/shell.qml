import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: bar

  property bool vpnDown: vpn.value === "Not Connected"
  property int cpuPercent: 0
  property var lastCpu: null
  property string memUsed: "0.0"

  // Prefer a player that's currently playing, otherwise fall back to the first one
  // readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0]

  // "Artist -- Title", skipping the separator if either part is missing
  // readonly property string nowPlaying: {
  //   if (!player) return "Nothing Playing"
  //   const parts = [player.trackArtist, player.trackTitle].filter(s => s)
  //   return parts.length > 0 ? parts.join(" -- ") : "Unknown"
  // }

  anchors { top: true; left: true; right: true }
  margins { top: 8; left: 20; right: 20 }
  implicitHeight: 36
  color: "transparent"

  // ---- Command pollers ----

  Poller {
    id: clock
    command: "date +%H:%M"
    interval: 60000
  }

  // Poller {
  //   id: vol
  //   command: "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf\"%d\", $2*100}'"
  //   interval: 1000
  // }

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

  // RowLayout {
  //   id: leftGroup
  //   anchors.left: parent.left
  //   anchors.verticalCenter: parent.verticalCenter
  //   anchors.leftMargin: 14
  //   spacing: 8

  //   Pill {
  //     icon: "music_note"
  //     label: bar.nowPlaying
  //     maxLabelWidth: 200
  //   }
  // }
  
  RowLayout {
    id: leftGroup
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 14
    spacing: 8

      Pill {
        icon: "palette"
        label: Theme.name
        onClicked: Theme.next()
        onRightClicked: Theme.prev()
      }
  }

  RowLayout {
    id: centerGroup
    anchors.centerIn: parent
    spacing: 8

    Pill { icon: "nest_clock_farsight_analog"; label: clock.value }
    Workspaces { Layout.alignment: Qt.AlignVCenter }
  }

  RowLayout {
    id: rightGroup
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: 24
    spacing: 8

    Pill { icon: "memory"; label: bar.cpuPercent + "%"; shown: bar.cpuPercent > 70 }
    Pill { icon: "storage"; label: bar.memUsed + " GB"; iconColor: Theme.warn }
    // Pill { icon: "volume_up"; label: vol.value + "%"; iconColor: Theme.cool }
    Pill { icon: "speed"; label: net.value; iconColor: Theme.cool }

    Pill {
      icon: bar.vpnDown ? "key_off" : "vpn_key"
      label: vpn.value
      iconColor: bar.vpnDown ? Theme.warn : Theme.accent
      shown: vpn.value !== "" && !bar.vpnDown
    }


  }
}
