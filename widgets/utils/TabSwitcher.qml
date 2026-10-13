import QtQuick

// A row of equally wide tabs for switching between the pages of a popup.
// (Not called TabBar so it doesn't clash with QtQuick.Controls' TabBar.)
//
//   TabSwitcher {
//       model: [{ value: "calendar", label: "Calendar" }, { value: "timers", label: "Timers" }]
//       current: root.page
//       onActivated: value => root.page = value
//   }
Rectangle {
    id: switcher

    // [{ value, label }]
    property var model: []
    // The value of the selected tab.
    property string current

    signal activated(string value)

    implicitHeight: 44
    radius: 12
    color: "#1c1c1c"

    Row {
        id: tabs

        anchors.fill: parent
        anchors.margins: 4

        Repeater {
            model: switcher.model

            delegate: Rectangle {
                id: tab

                required property var modelData
                readonly property bool selected: switcher.current === modelData.value

                width: tabs.width / Math.max(1, switcher.model.length)
                height: tabs.height
                radius: 9
                color: selected ? "#353535" : tabMouse.pressed ? "#262626" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: tab.modelData.label
                    color: tab.selected ? "white" : "#aaaaaa"
                    font.pixelSize: 14
                    font.bold: tab.selected
                }

                MouseArea {
                    id: tabMouse

                    anchors.fill: parent
                    onClicked: switcher.activated(tab.modelData.value)
                }
            }
        }
    }
}
