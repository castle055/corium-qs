import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../services"

Item {
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        ScriptModel {
            id: specialWorkspaces

            values: {
                const result = [];

                for (const ws of Hyprland.workspaces.values) {
                    if (ws.name.startsWith("doc:")) {
                        result.push(ws)
                    }
                }

                return result
            }

            objectProp: "id"
        }

        Repeater {
            model: specialWorkspaces

            Rectangle {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter

                width: 120
                height: 28
                radius: 8

                property int workspaceId: modelData.id

                // Empty vs occupied
                property bool occupied: modelData.toplevels.values.length > 0

                // Currently selected workspace
                color: modelData.focused
                ? "#555555"
                : occupied
                ? "#222222"
                : "#111111"

                Text {
                    anchors.centerIn: parent
                    text: {
                        let name = modelData.toplevels.values[0].title
                        name = name.substring(0, name.indexOf("."))
                        return name;
                    }
                    color: modelData.focused? "#000000": occupied? "#888888": "#333333"
                    font.pointSize: 10
                    font.bold: modelData.focused
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        modelData.activate()
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter

                    x: parent.width - width - 4
                    width: 20
                    height: 20
                    radius: width/2

                    color: closeButton.containsMouse? "#CC0000": "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: closeButton.containsMouse? "#000000": "#444444"
                        font.pointSize: 10
                        font.bold: modelData.focused
                    }

                    MouseArea {
                        id: closeButton
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            if (modelData.focused) {
                                Hyprland.dispatch("hl.dsp.focus({workspace = \"previous_per_monitor\"})")
                            }
                            Hyprland.dispatch("hl.dsp.window.close({window = \"address:0x" + modelData.toplevels.values[0].address + "\"})")
                        }
                    }
                }
            }
        }
    }
}
