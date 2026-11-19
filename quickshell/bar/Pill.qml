import "../theme"
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property color iconColor: Theme.accent
  property int maxLabelWidth: 400

  property bool shown: true

  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 180 } }

  signal clicked()
  signal rightClicked()

  implicitWidth: row.implicitWidth + 22
  implicitHeight: 33
  radius: height / 2
  color: Theme.pill

  Behavior on color { ColorAnimation { duration: 200 } }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 7

    Text {
      text: root.icon
      color: root.iconColor
      font.family: Theme.iconFont
      font.pixelSize: 15

      Behavior on color { ColorAnimation { duration: 200 } }
    }

    Text {
      text: root.label
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 16
      elide: Text.ElideRight
      Layout.maximumWidth: root.maxLabelWidth
      visible: root.label != ""

      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // Left click -> clicked(), right click -> rightClicked()
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
  }
}
