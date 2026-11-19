pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property bool launcherVisible: false
  property var recentIds: []
  readonly property int maxRecents: 12

  function toggle() { launcherVisible = !launcherVisible }
  function show()   { launcherVisible = true }
  function hide()   { launcherVisible = false }

  // 0 = most recent, -1 = never launched
  function recentRank(id) { return recentIds.indexOf(id) }

  function recordLaunch(id) {
    const list = recentIds.filter(r => r !== id)
    list.unshift(id)
    recentIds = list.slice(0, maxRecents)
    save()
  }

  function clearRecents() {
    recentIds = []
    save()
  }

  function save() { store.setText(JSON.stringify(recentIds)) }

  // Same persistence approach as Theme: a small file under ~/.local/state
  FileView {
    id: store
    path: Quickshell.env("HOME") + "/.local/state/qs-launcher-recents.json"
    onLoaded: {
      try {
        const ids = JSON.parse(text())
        if (Array.isArray(ids)) root.recentIds = ids.slice(0, root.maxRecents)
      } catch (e) {
        console.warn("app launcher: ignoring unreadable recents file:", e)
      }
    }
  }
}
