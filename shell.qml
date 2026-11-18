

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // Catppuccin Mocha theme
    // Colors use #AARRGGBB format (first two digits = opacity)
    property color barColor: "#b31e1e2e"
    property color barBorder: "#4d89b4fa"
    property color pillColor: "#cc313244"
    property color pillHover: "#e645475a"
    property color menuColor: "#f21e1e2e"
    property color textColor: "#cdd6f4"
    property color accent: "#89b4fa"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"

    // Shared system information
    property int cpu: -1
    property int mem: -1
    property string ip: "offline"
    property string vpnIp: ""

    property real lastIdle: 0
    property real lastTotal: 0

    // Clock
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // CPU monitoring
    // Calculates usage by comparing consecutive /proc/stat readings
    Process {
        id: cpuProc
        command: ["head", "-n", "1", "/proc/stat"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim()
                    .split(/\s+/)
                    .slice(1)
                    .map(Number)

                if (p.length < 8 || !p.every(Number.isFinite))
                    return

                const idle = p[3] + p[4]
                const total = p.slice(0, 8)
                    .reduce((a, b) => a + b, 0)

                if (root.lastTotal > 0 && total > root.lastTotal) {
                    const usage = 100 * (
                        1 - (idle - root.lastIdle) /
                        (total - root.lastTotal)
                    )

                    root.cpu = Math.max(
                        0,
                        Math.min(100, Math.round(usage))
                    )
                }

                root.lastIdle = idle
                root.lastTotal = total
            }
        }
    }

    // Memory monitoring
    // Used memory = total memory - available memory
   // Memory
    Rectangle {
        width: memText.implicitWidth + 20
        height: 24
        radius: 12
        color: memoryArea.containsMouse
            ? root.pillHover
            : root.pillColor

        Text {
            id: memText
            anchors.centerIn: parent

            text: "MEM " + (
                root.mem >= 0
                    ? root.mem + "%"
                    : "--"
            )

            color: root.textColor
        }

        Process {
            id: btopProc
            command: ["foot", "-e", "btop"]
        }

        MouseArea {
            id: memoryArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                btopProc.running = true
            }
        }
    }
    // Network monitoring
    // Displays the first available normal interface and VPN IP
    Process {
        id: netProc
        command: ["ip", "-brief", "-4", "addr"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let ip = "offline"
                let vpn = ""

                for (const line of this.text.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)

                    if (p.length < 3)
                        continue

                    const iface = p[0]
                    const state = p[1]

                    // Ignore inactive interfaces
                    if (state === "DOWN")
                        continue

                    // Ignore loopback and virtual interfaces
                    if (/^(lo|docker|veth|br-|virbr|vboxnet|vmnet)/.test(iface))
                        continue

                    if (p[2] === "-")
                        continue

                    const addr = p[2].split("/")[0]

                    // Identify VPN interfaces
                    if (/^(tun|tap|wg|tailscale|ppp|proton|nordlynx)/.test(iface)) {
                        if (vpn === "")
                            vpn = addr
                    } else if (ip === "offline") {
                        ip = addr
                    }
                }

                root.ip = ip
                root.vpnIp = vpn
            }
        }
    }

    // Refresh system information every 2 seconds
    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            cpuProc.running = true
            memProc.running = true
            netProc.running = true
        }
    }

    // One bar per monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            property bool powerOpen: false

            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            // Screen edge spacing
            margins {
                top: 8
                left: 12
                right: 12
            }

            implicitHeight: 36
            color: "transparent"

            Rectangle {
                id: barBg

                anchors.fill: parent
                radius: 14
                color: root.barColor

                border.width: 1
                border.color: root.barBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    // Left: Workspaces
                    Row {
                        spacing: 6

                        Repeater {
                            model: Hyprland.workspaces

                            Rectangle {
                                required property var modelData

                                width: 24
                                height: 24
                                radius: 12

                                color: modelData.focused
                                    ? root.accent
                                    : root.pillColor

                                Text {
                                    anchors.centerIn: parent

                                    text: modelData.id

                                    color: modelData.focused
                                        ? "#1e1e2e"
                                        : root.textColor
                                }

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: modelData.activate()
                                }
                            }
                        }
                    }

                    // Spacer: pushes statistics to the right
                    Item {
                        Layout.fillWidth: true
                    }

                    // Right: System statistics
                    Row {
                        spacing: 6

                        // Network
                        Rectangle {
                            width: netText.implicitWidth + 20
                            height: 24
                            radius: 12
                            color: root.pillColor

                            Text {
                                id: netText

                                anchors.centerIn: parent

                                text: root.vpnIp !== ""
                                    ? "VPN " + root.vpnIp
                                    : root.ip

                                color: root.vpnIp !== ""
                                    ? root.green
                                    : root.textColor
                            }
                        }

                        // CPU
                        Rectangle {
                            width: cpuText.implicitWidth + 20
                            height: 24
                            radius: 12
                            color: root.pillColor

                            Text {
                                id: cpuText

                                anchors.centerIn: parent

                                text: "CPU " + (
                                    root.cpu >= 0
                                        ? root.cpu + "%"
                                        : "--"
                                )

                                color: root.textColor
                            }
                        }

                        // Memory
                        Rectangle {
                            width: memText.implicitWidth + 20
                            height: 24
                            radius: 12
                            color: root.pillColor

                            Text {
                                id: memText

                                anchors.centerIn: parent

                                text: "MEM " + (
                                    root.mem >= 0
                                        ? root.mem + "%"
                                        : "--"
                                )

                                color: root.textColor
                            }

                            // Launch btop
                            Process {
                                id: btopProc

                                command: ["foot", "-e", "btop"]
                                running: false
                            }

                            MouseArea {
                                id: memoryStat

                                anchors.fill: parent

                                onClicked: {
                                    if (!btopProc.running)
                                        btopProc.running = true
                                }
                            }
                        }
                    }

                    // Power button
                    Rectangle {
                        id: powerButton

                        width: powerLabel.implicitWidth + 20
                        height: 24
                        radius: 12

                        color: bar.powerOpen
                            ? root.red
                            : root.pillColor

                        Text {
                            id: powerLabel

                            anchors.centerIn: parent

                            text: "\uf011"

                            color: bar.powerOpen
                                ? "#1e1e2e"
                                : root.red
                        }

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                bar.powerOpen = !bar.powerOpen
                            }
                        }
                    }
                }

                // Centered clock
                Text {
                    anchors.centerIn: parent

                    text: Qt.formatDateTime(
                        clock.date,
                        "ddd MMM d  HH:mm"
                    )

                    color: root.textColor
                    font.bold: true
                }
            }

            // Power dropdown menu
            PopupWindow {
                id: powerMenu

                visible: bar.powerOpen

                // Attach to bottom-right of power button
                anchor.item: powerButton
                anchor.edges: Edges.Bottom | Edges.Right
                anchor.gravity: Edges.Bottom | Edges.Left

                implicitWidth: 150
                implicitHeight: menuColumn.implicitHeight + 16

                color: "transparent"

                Rectangle {
                    anchors.fill: parent

                    radius: 12
                    color: root.menuColor

                    border.width: 1
                    border.color: root.barBorder

                    Column {
                        id: menuColumn

                        x: 8
                        y: 8

                        width: parent.width - 16
                        spacing: 4

                        Repeater {
                            model: [
                                {
                                    label: "Log out",
                                    cmd: [
                                        "hyprctl",
                                        "dispatch",
                                        "exit"
                                    ]
                                },
                                {
                                    label: "Restart",
                                    cmd: [
                                        "systemctl",
                                        "reboot"
                                    ]
                                },
                                {
                                    label: "Power off",
                                    cmd: [
                                        "systemctl",
                                        "poweroff"
                                    ]
                                }
                            ]

                            Rectangle {
                                required property var modelData

                                width: parent.width
                                height: 28
                                radius: 8

                                color: area.containsMouse
                                    ? root.pillHover
                                    : root.pillColor

                                Text {
                                    x: 12

                                    anchors.verticalCenter: parent.verticalCenter

                                    text: modelData.label
                                    color: root.textColor
                                }

                                MouseArea {
                                    id: area

                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onClicked: {
                                        bar.powerOpen = false

                                        Quickshell.execDetached(
                                            modelData.cmd
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
