import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../theme"
import "./components"

PanelWindow {
  id: root

  // ── Window ───────────────────────────────────────────────────────────────
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell-launcher"
  WlrLayershell.keyboardFocus: AppLauncherState.launcherVisible
    ? WlrKeyboardFocus.Exclusive
    : WlrKeyboardFocus.None

  // Full-screen overlay: never reserve space or push other windows around
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"

  // Hidden = empty input region, so clicks fall through to what's underneath
  mask: Region { item: AppLauncherState.launcherVisible ? maskCover : null }
  Item { id: maskCover; anchors.fill: parent }

  // qs ipc call applauncher toggle|show|hide
  IpcHandler {
    target: "applauncher"
    function toggle(): void { AppLauncherState.toggle() }
    function show(): void   { AppLauncherState.show() }
    function hide(): void   { AppLauncherState.hide() }
  }

  // ── State ────────────────────────────────────────────────────────────────
  readonly property string searchQuery: searchInput.text
  readonly property bool isSearching: searchQuery.trim() !== ""
  property int selectedIndex: 0

  readonly property var filteredApps: {
    const q = searchQuery.trim().toLowerCase()
    const apps = Array.from(DesktopEntries.applications.values).filter(e => !e.noDisplay)

    if (q !== "") {
      // Search: match name / generic name / keywords, alphabetical
      return apps.filter(e => {
        if (e.name.toLowerCase().includes(q)) return true
        if (e.genericName && e.genericName.toLowerCase().includes(q)) return true
        return Array.from(e.keywords).some(k => k.toLowerCase().includes(q))
      }).sort((a, b) => a.name.localeCompare(b.name))
    }

    // Default: recently launched first, then alphabetical
    return apps.sort((a, b) => {
      const ai = AppLauncherState.recentRank(a.id)
      const bi = AppLauncherState.recentRank(b.id)
      if (ai !== -1 && bi !== -1) return ai - bi
      if (ai !== -1) return -1
      if (bi !== -1) return 1
      return a.name.localeCompare(b.name)
    })
  }

  onFilteredAppsChanged: selectedIndex = 0

  // ── Actions ──────────────────────────────────────────────────────────────
  function launchEntry(entry) {
    AppLauncherState.recordLaunch(entry.id)
    entry.execute()
    AppLauncherState.hide()
  }

  function navigate(delta) {
    if (filteredApps.length === 0) return
    selectedIndex = (selectedIndex + delta + filteredApps.length) % filteredApps.length
    listView.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  // Icon name -> image url, or "" so the letter fallback shows instead of
  // Qt's "missing icon" checkerboard
  function iconSource(name) {
    if (!name) return ""
    if (name.startsWith("/")) return "file://" + name
    return Quickshell.iconPath(name, true)
  }

  Connections {
    target: AppLauncherState
    function onLauncherVisibleChanged() {
      if (AppLauncherState.launcherVisible) {
        searchInput.text = ""
        root.selectedIndex = 0
        searchInput.forceActiveFocus()
      }
    }
  }

  // ── Geometry ─────────────────────────────────────────────────────────────
  readonly property int maxVisible: 7
  readonly property int itemH: 42
  readonly property int panelW: 440
  readonly property int pad: 12
  readonly property int searchH: 44
  readonly property int cornerRadius: 18

  // At least one row's worth of space so "No apps found" has somewhere to live
  readonly property int listH: Math.max(1, Math.min(filteredApps.length, maxVisible)) * itemH
  // pad + handle(4) + gap(8) + search + gap(8) + list + pad
  readonly property int panelH: pad + 4 + 8 + searchH + 8 + listH + pad

  // Drives the panel and both corner pieces together
  property real slideY: AppLauncherState.launcherVisible ? 0 : panelH + 6
  Behavior on slideY { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

  // ── Click outside to close ───────────────────────────────────────────────
  MouseArea {
    anchors.fill: parent
    enabled: AppLauncherState.launcherVisible
    onClicked: AppLauncherState.hide()
  }

  // Everything that slides lives in here, so one transform moves it all
  Item {
    id: sheet
    anchors.fill: parent
    transform: Translate { y: root.slideY }

    // Concave corners: the panel flows into the bottom edge. Siblings of the
    // panel (not children) so the panel's clip doesn't cut them off. The 1px
    // negative margin overlaps the panel to hide the antialiasing seam.
    ConcaveCurves {
      radius: root.cornerRadius
      color: Theme.pill
      mirrored: true
      anchors.right: panel.left
      anchors.rightMargin: -1
      anchors.bottom: panel.bottom
    }

    ConcaveCurves {
      radius: root.cornerRadius
      color: Theme.pill
      anchors.left: panel.right
      anchors.leftMargin: -1
      anchors.bottom: panel.bottom
    }

    Rectangle {
      id: panel
      width: root.panelW
      height: root.panelH
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      clip: true   // keeps rows inside while the height animates

      color: Theme.pill
      topLeftRadius: root.cornerRadius
      topRightRadius: root.cornerRadius

      Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

      // Swallows clicks on the panel's empty areas (otherwise they fall through
      // to the click-outside area and close the launcher) and scrolls the
      // selection. Declared first so everything below sits on top of it.
      MouseArea {
        anchors.fill: parent
        onWheel: wheel => root.navigate(wheel.angleDelta.y < 0 ? 1 : -1)
      }

      Column {
        anchors {
          top: parent.top
          topMargin: root.pad
          left: parent.left
          leftMargin: root.pad
          right: parent.right
          rightMargin: root.pad
        }
        spacing: 0

        // Handle
        Rectangle {
          width: 36
          height: 4
          radius: 2
          anchors.horizontalCenter: parent.horizontalCenter
          color: Qt.alpha(Theme.text, 0.22)
        }

        Item { width: 1; height: 8 }

        // ── Search box ─────────────────────────────────────────────────────
        Rectangle {
          width: parent.width
          height: root.searchH
          radius: 10
          color: Theme.pillAlt
          border.width: 1
          border.color: searchInput.activeFocus ? Qt.alpha(Theme.accent, 0.55) : "transparent"
          Behavior on border.color { ColorAnimation { duration: 150 } }

          Item {
            anchors {
              fill: parent
              leftMargin: 14
              rightMargin: 14
            }

            Text {
              anchors.fill: parent
              visible: searchInput.text === ""
              text: "Search apps…"
              color: Theme.dim
              font.pixelSize: 13
              font.family: Theme.font
              verticalAlignment: Text.AlignVCenter
            }

            TextInput {
              id: searchInput
              anchors.fill: parent
              focus: true
              clip: true
              color: Theme.text
              selectionColor: Theme.faint
              selectedTextColor: Theme.text
              font.pixelSize: 13
              font.family: Theme.font
              verticalAlignment: TextInput.AlignVCenter

              Keys.onPressed: event => {
                if (event.key === Qt.Key_Up) {
                  root.navigate(-1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                  root.navigate(1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  if (root.filteredApps.length > 0)
                    root.launchEntry(root.filteredApps[root.selectedIndex])
                  event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                  AppLauncherState.hide()
                  event.accepted = true
                }
              }
            }
          }
        }

        Item { width: 1; height: 8 }

        // ── App list ───────────────────────────────────────────────────────
        // ListView is a Flickable, so anything declared inside it lands in its
        // scrolling content; the empty-state text lives beside it instead.
        Item {
          width: parent.width
          height: root.listH

          ListView {
            id: listView
            anchors.fill: parent
            model: root.filteredApps
            clip: true
            interactive: false   // selection is driven by keys / wheel

            delegate: Item {
              id: appRow

              required property var modelData
              required property int index

              width: listView.width
              height: root.itemH

              readonly property bool sel: root.selectedIndex === index
              readonly property int recentRank: AppLauncherState.recentRank(modelData.id)
              readonly property bool isRecent: !root.isSearching && recentRank >= 0 && recentRank < 5

              Rectangle {
                anchors {
                  fill: parent
                  topMargin: 2
                  bottomMargin: 2
                }
                radius: 10
                color: appRow.sel ? Theme.pillAlt : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                  anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                  }
                  spacing: 12

                  // Icon bubble
                  Rectangle {
                    width: 36
                    height: 36
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: appRow.sel ? Theme.faint : Qt.alpha(Theme.faint, 0.5)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                      id: appIcon
                      anchors.centerIn: parent
                      width: 22
                      height: 22
                      sourceSize: Qt.size(44, 44)
                      source: root.iconSource(appRow.modelData.icon)
                      smooth: true
                      mipmap: true
                    }

                    // Letter fallback when there's no usable icon
                    Text {
                      anchors.centerIn: parent
                      visible: appIcon.status !== Image.Ready
                      text: appRow.modelData.name.charAt(0).toUpperCase()
                      font.pixelSize: 15
                      font.family: Theme.font
                      font.weight: Font.Bold
                      color: appRow.sel ? Theme.accent : Theme.dim
                      Behavior on color { ColorAnimation { duration: 100 } }
                    }
                  }

                  // Name + subtitle
                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48
                    spacing: 2

                    Text {
                      width: parent.width
                      text: appRow.modelData.name
                      elide: Text.ElideRight
                      font.pixelSize: 13
                      font.family: Theme.font
                      font.weight: appRow.sel ? Font.Medium : Font.Normal
                      color: appRow.sel ? Theme.text : Qt.alpha(Theme.text, 0.65)
                      Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Row {
                      spacing: 6
                      visible: appRow.isRecent || appRow.modelData.genericName !== ""

                      Rectangle {
                        visible: appRow.isRecent
                        width: recentLabel.width + 8
                        height: 14
                        radius: 4
                        color: Qt.alpha(Theme.accent, 0.22)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          id: recentLabel
                          anchors.centerIn: parent
                          text: "recent"
                          font.pixelSize: 9
                          font.family: Theme.font
                          color: Theme.accent
                        }
                      }

                      Text {
                        visible: appRow.modelData.genericName !== ""
                        text: appRow.modelData.genericName
                        font.pixelSize: 11
                        font.family: Theme.font
                        color: Theme.text
                        opacity: 0.4
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  // positionChanged, not entered: when the keyboard scrolls the
                  // list under a still mouse, `entered` fires and steals the
                  // selection back. This only reacts to real mouse movement.
                  onPositionChanged: root.selectedIndex = appRow.index
                  onClicked: root.launchEntry(appRow.modelData)
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.filteredApps.length === 0
            text: "No apps found"
            color: Theme.dim
            font.pixelSize: 13
            font.family: Theme.font
          }
        }
      }
    }
  }
}
