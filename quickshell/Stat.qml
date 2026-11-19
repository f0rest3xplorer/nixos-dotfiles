import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property string icon: ""
  property string label: ""
  property color iconColor: Theme.accent
  property int maxLabelWidth: 400
  property bool compact: false   // icon only, label appears on hover

  signal clicked()
  signal rightClicked()

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 7

    Text {
      text: root.icon
      color: root.iconColor
      font.family: Theme.iconFont
      font.pixelSize: 17
    }

    Text {
      text: root.label
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 15
      elide: Text.ElideRight
      Layout.maximumWidth: root.maxLabelWidth
      visible: root.label != "" && (!root.compact || hover.hovered)
    }
  }

  HoverHandler { id: hover }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
  }
}
