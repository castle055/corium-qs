import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Services.SystemTray


Row {
    required property var panelWindow

    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            required property var modelData

            width: 20
            height: 48

            IconImage {
                source: modelData.icon
                anchors.fill: parent
            }

            MouseArea {
                hoverEnabled: false
                anchors.fill: parent

                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    console.log("opening menu")
                    if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                            const pos = mapToItem(null, 0, height)
                            modelData.display(panelWindow, pos.x+20, pos.y)
                        }
                    } else if (mouse.button === Qt.LeftButton) {
                        modelData.activate()
                    }
                }

                ToolTip.visible: containsMouse
                //ToolTip.text: modelData.tooltipTitle
                ToolTip.delay: 500
                ToolTip.text: {
                    let text = modelData.tooltipTitle
                    if (modelData.tooltipDescription)
                    text += "\n" + modelData.tooltipDescription
                    return text
                }
            }
        }
    }
}
