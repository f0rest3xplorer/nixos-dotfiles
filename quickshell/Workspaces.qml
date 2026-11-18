import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  property int minCount: 5
  property int maxIcons: 3

  // Workspaces 1..minCount, plus any higher ones that exist (ignores special workspaces)
  readonly property var ids: {
    const set = new Set()
    for (let i = 1; i <= minCount; i++) set.add(i)
    for (const w of Hyprland.workspaces.values) if (w.id > 0) set.add(w.id)
    return Array.from(set).sort((a, b) => a - b)
  }

  // One entry per app class on a workspace, so duplicates collapse into a single icon
  function appsOn(id) {
    const seen = new Set()
    return Hyprland.toplevels.values.filter(t => {
      if (!t.workspace || t.workspace.id !== id) return false
      const cls = (t.lastIpcObject?.class ?? "").toLowerCase()
      if (seen.has(cls)) return false
      seen.add(cls)
      return true
    })
  }

  function iconFor(t) {
    const cls = t.lastIpcObject?.class ?? ""
    const entry = DesktopEntries.heuristicLookup(cls)
    return Quickshell.iconPath(entry?.icon ?? cls.toLowerCase(), "application-x-executable")
  }

  implicitWidth: row.implicitWidth + 16
  implicitHeight: 33
  radius: height / 2
  color: "#0f1f22"

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Repeater {
      model: root.ids

      Rectangle {
        id: ws
        required property int modelData

        readonly property int wsId: modelData
        readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
        readonly property var apps: root.appsOn(wsId)

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: content.implicitWidth + 14
        implicitHeight: 25
        radius: height / 2
        color: focused ? "#1f3d3a" : "transparent"
        border.width: focused ? 1 : 0
        border.color: "#3dd1b0"

        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on implicitWidth {
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: 4

          // Empty workspace: a small dot
          Rectangle {
            visible: ws.apps.length === 0
            width: 7
            height: 7
            radius: 3.5
            anchors.verticalCenter: parent.verticalCenter
            color: ws.focused ? "#3dd1b0" : "#1c2f31"
          }

          // Occupied workspace: one icon per app
          Repeater {
            model: ws.apps.slice(0, root.maxIcons)

            IconImage {
              required property var modelData
              implicitSize: 16
              source: root.iconFor(modelData)
              opacity: ws.focused ? 1.0 : 0.7
            }
          }

          // Overflow indicator (counts distinct apps, not windows)
          Text {
            visible: ws.apps.length > root.maxIcons
            text: "+" + (ws.apps.length - root.maxIcons)
            color: "#f5e2c5"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: Hyprland.dispatch("workspace " + ws.wsId)
        }
      }
    }
  }
}
