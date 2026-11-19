import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  property int minCount: 5
  property bool framed: true

  readonly property var ids: {
    const set = new Set()
    for (let i = 1; i <= minCount; i++) set.add(i)
    for (const w of Hyprland.workspaces.values) if (w.id > 0) set.add(w.id)
    return Array.from(set).sort((a, b) => a - b)
  }

  implicitWidth: row.implicitWidth + (framed ? 22 : 0)
  implicitHeight: 33
  radius: height / 2
  color: framed ? Theme.pillAlt : "transparent"

  Behavior on color { ColorAnimation { duration: 200 } }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 8

    Repeater {
      model: root.ids

      Rectangle {
        required property int modelData

        readonly property int wsId: modelData
        readonly property bool exists: Hyprland.workspaces.values.some(w => w.id === wsId)
        readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: focused ? 22 : 9
        implicitHeight: 9
        radius: height / 2
        color: focused ? Theme.accent : (exists ? Theme.dim : Theme.faint)

        Behavior on implicitWidth {
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on color { ColorAnimation { duration: 160 } }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          // cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached([
            "hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + parent.wsId + " })"
          ])
        }
      }
    }
  }
}
