import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
   SystemClock{
	   id: clock
	   precision: SystemClock.Seconds
   }

   // one bar per monitor
   Variants {
	   model: Quickshell.screens

	   PanelWindow {
		   required property var modelData
		   screen: modelData

		   anchors {
			   top: true
			   left: true
			   right: true
		   }
		   implicitHeight: 32
		   color: "#1e1e2e"

		   RowLayout {
			   anchors.fill: parent
			   anchors.leftMargin: 10
			   anchors.rightMargin: 10

			   // Left: workspaces
			   Row {
				   spacing: 6

				   Repeater {
					   model: Hyprland.workspaces

					   Rectangle {
						   required property var modelData
						   width: 24
						   height: 22
						   radius: 4
						   color: modelData.focused ? "#89b4fa" : "#3132244"

						   Text {
							   anchors.centerIn: parent
							   text: modelData.id
							   color: modelData.focused ? "#1e1e2e" : "#cdd6f4"
						   }

						   MouseArea {
							   anchors.fill: parent
							   onClicked: modelData.activate()
						   }
					   }
				   }
			   }

			   // push clock to the right
			   Item { Layout.fillWidth: true }

			   Text {
				   text: Qt.formatDateTime(clock.date, "ddd MMM d HH:mm")
				   color: "#cdd6f4"
			   }
		   }
	   }
   }
}

   
