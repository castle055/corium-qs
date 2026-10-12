import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../services"

Row {
    spacing: 0

    Repeater {
        model: 5

        Rectangle {
            required property int index

            width: 40
            height: 48
            radius: 0

            property int workspaceId: index + 1

            // Find the real Hyprland workspace, if it exists.
            property var workspace: {
                for (const ws of Hyprland.workspaces.values) {
                    if (ws.id == workspaceId)
                        return ws
                }
                return null
            }

            // Empty vs occupied
            property bool occupied: workspace !== null &&
                                    workspace.toplevels.values.length > 0

            // Currently selected workspace
            property bool focused: workspace !== null &&
                                   workspace.focused

            color: focused
                ? "#555555"
                : occupied
                    ? "black"
                    : "black"

            Text {
                anchors.centerIn: parent
                text: workspaceId
                color: focused? "#000000": occupied? "#888888": "#333333"
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    //workspace.activate()
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })")
                }
            }
        }
    }
}
