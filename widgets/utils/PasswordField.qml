import QtQuick

// An InputField whose text is hidden, with an eye button to show it.
InputField {
    id: field

    property bool revealed: false

    echoMode: revealed ? TextInput.Normal : TextInput.Password
    rightPadding: 44

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter

        text: String.fromCodePoint(field.revealed ? 0xF0209 : 0xF0208)
        color: "#aaaaaa"
        font.pixelSize: 18

        MouseArea {
            anchors.fill: parent
            anchors.margins: -10
            onClicked: field.revealed = !field.revealed
        }
    }
}
