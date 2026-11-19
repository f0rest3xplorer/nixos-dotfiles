import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property string command: ""
  property int interval: 5000
  property string value: ""

  Process {
    id: proc
    command: ["sh", "-c", root.command]
    stdout: StdioCollector {
      onStreamFinished: root.value = text.trim()
    }
  }

  Timer {
    interval: root.interval
    running: true
    repeat: true
    triggeredOnStart: true
    // Skip the tick if the last run hasn't finished (the net poller sleeps 1s)
    onTriggered: if (!proc.running) proc.running = true
  }
}
