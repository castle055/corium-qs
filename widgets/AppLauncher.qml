import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "utils"
import "../services"

BarPopupButton {
    id: root

    implicitWidth: 48
    implicitHeight: 48

    leftSide: true
    fullHeight: true
    // Let the search field take keyboard focus, including from the on-screen keyboard.
    keyboardFocus: true

    property var screen

    // Start every opening with an empty search.
    onPopupVisibleChanged: {
        if (!popupVisible)
            searchField.text = ""
    }

    Row {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󱓟"
            color: "white"
            font.pixelSize: 18
        }
    }

    popup: Rectangle {
        id: launcherPanel

        implicitWidth: 800
        implicitHeight: root.screen.height-48

        color: "transparent"

        MouseArea {
            anchors.fill: parent

            // Prevent clicks inside the launcher from reaching
            // the background MouseArea.
            onClicked: function(mouse) {
                //root.dismissed()
                mouse.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Text {
                text: "Applications"

                color: "white"
                font.pixelSize: 24
                font.bold: true

                Layout.fillWidth: true
            }

            TextField {
                id: searchField

                Layout.fillWidth: true
                Layout.preferredHeight: 52

                placeholderText: "Search applications..."
                font.pixelSize: 18

                color: "white"
                placeholderTextColor: "#999999"

                background: Rectangle {
                    radius: 10
                    color: "#303030"
                    border.color: searchField.activeFocus
                    ? "#80bfff"
                    : "#484848"
                    border.width: 1
                }

                // Results start right under the field, above the on-screen keyboard.
                onTextChanged: applicationsScroll.contentItem.contentY = 0
            }

            //PersistentProperties {
                //    id: launcherState

                //    property list<string> favorites: []
                //    property list<string> recents: []

                //    function launchApplication(app) {
                //        app.execute()

                //        recents = [
                //            app.id,
                //            ...recents.filter(id => id !== app.id)
                //        ].slice(0, 10)
                //    }

                //    function toggleFavorite(app) {
                //        if (favorites.includes(app.id)) {
                //            favorites = favorites.filter(id => id !== app.id)
                //        } else {
                //            favorites = [...favorites, app.id]
                //        }
                //    }
                //}

                ScriptModel {
                    id: favoriteApplications

                    values: LauncherState.favorites
                    .map(id => DesktopEntries.byId(id))
                    .filter(app => app !== null)
                }

                ScriptModel {
                    id: recentApplications

                    values: LauncherState.recents
                    .map(id => DesktopEntries.byId(id))
                    .filter(app => app !== null)
                }

                ScriptModel {
                    id: filteredApplications

                    values: DesktopEntries.applications.values.filter(
                        app => {
                            const query = searchField.text.toLowerCase().trim()


                            const name = (app.name || "").toLowerCase()
                            const genericName = (app.genericName || "").toLowerCase()
                            const comment = (app.comment || "").toLowerCase()

                            return (name.includes(query)
                            || genericName.includes(query)
                            || comment.includes(query))
                            && !app.runInTerminal
                        }).sort(function(a, b) {
                            var textA = a.name.toUpperCase();
                            var textB = b.name.toUpperCase();
                            return (textA < textB) ? -1 : (textA > textB) ? 1 : 0;
                        }
                    )
                }

                ScrollView {
                    id: applicationsScroll

                    // While searching, only the matches are shown.
                    readonly property bool searching: searchField.text.trim() !== ""

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: parent.width
                            spacing: 16
                            visible: !applicationsScroll.searching

                            Text {
                                text: "Favorites"

                                color: "white"
                                font.pixelSize: 24
                                font.bold: true

                                Layout.fillWidth: true
                            }

                            Grid {
                                id: favApplicationsGrid

                                columns: 5
                                width: parent.width

                                Repeater {
                                    model: favoriteApplications

                                    delegate: Item {
                                        id: favApplicationDelegate

                                        required property var modelData

                                        width: Math.max(10, Math.floor(parent.width / favApplicationsGrid.columns))
                                        height: 120


                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 6

                                            radius: 12

                                            color: applicationMouseArea.pressed
                                            ? "#505050"
                                            : applicationMouseArea.containsMouse
                                            ? "#383838"
                                            : "#292929"

                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 12

                                                spacing: 8

                                                Image {
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    width: 48
                                                    height: 48

                                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                                    //fillMode: Image.PreserveAspectFit

                                                    //visible: source !== ""
                                                }

                                                Text {
                                                    width: parent.width

                                                    text: modelData.name || "Unnamed application"

                                                    color: "white"
                                                    font.pixelSize: 15

                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WordWrap
                                                }
                                            }

                                            MouseArea {
                                                id: applicationMouseArea

                                                anchors.fill: parent

                                                onClicked: {
                                                    LauncherState.launchApplication(modelData)
                                                    root.dismissed()
                                                }
                                            }
                                        }
                                    }
                                }

                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 16
                            visible: !applicationsScroll.searching

                            Text {
                                text: "Recent"

                                color: "white"
                                font.pixelSize: 24
                                font.bold: true

                                Layout.fillWidth: true
                            }

                            Grid {
                                id: recentApplicationsGrid

                                columns: 5
                                width: parent.width

                                Repeater {
                                    model: recentApplications

                                    delegate: Item {
                                        id: recentApplicationDelegate

                                        required property var modelData

                                        width: Math.max(10, Math.floor(parent.width / recentApplicationsGrid.columns))
                                        height: 120


                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 6

                                            radius: 12

                                            color: applicationMouseArea.pressed
                                            ? "#505050"
                                            : applicationMouseArea.containsMouse
                                            ? "#383838"
                                            : "#292929"

                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 12

                                                spacing: 8

                                                Image {
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    width: 48
                                                    height: 48

                                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                                    //fillMode: Image.PreserveAspectFit

                                                    //visible: source !== ""
                                                }

                                                Text {
                                                    width: parent.width

                                                    text: modelData.name || "Unnamed application"

                                                    color: "white"
                                                    font.pixelSize: 15

                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WordWrap
                                                }
                                            }

                                            MouseArea {
                                                id: applicationMouseArea

                                                anchors.fill: parent

                                                onClicked: {
                                                    LauncherState.launchApplication(modelData)
                                                    root.dismissed()
                                                }
                                            }
                                        }
                                    }
                                }

                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 16

                            Text {
                                text: applicationsScroll.searching
                                      ? (filteredApplications.values.length > 0 ? "Results" : "No applications found")
                                      : "All Applications"

                                color: "white"
                                font.pixelSize: 24
                                font.bold: true

                                Layout.fillWidth: true
                            }

                            Grid {
                                id: applicationsGrid

                                columns: 6
                                width: parent.width

                                Repeater {
                                    model: filteredApplications

                                    delegate: Item {
                                        id: applicationDelegate

                                        required property var modelData

                                        width: Math.max(10, Math.floor(parent.width / applicationsGrid.columns))
                                        height: 120


                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 6

                                            radius: 12

                                            color: applicationMouseArea.pressed
                                            ? "#505050"
                                            : applicationMouseArea.containsMouse
                                            ? "#383838"
                                            : "#292929"

                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 12

                                                spacing: 10

                                                Image {
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    width: 30
                                                    height: 30

                                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                                    //fillMode: Image.PreserveAspectFit

                                                    //visible: source !== ""
                                                }

                                                Text {
                                                    width: parent.width

                                                    text: modelData.name || "Unnamed application"

                                                    color: "white"
                                                    font.pixelSize: 12

                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WordWrap
                                                }
                                            }

                                            // Favorite button
                                            Rectangle {
                                                id: favoriteButton

                                                anchors.top: parent.top
                                                anchors.right: parent.right

                                                anchors.topMargin: 4
                                                anchors.rightMargin: 4

                                                width: 28
                                                height: 28

                                                radius: 14

                                                color: favoriteMouseArea.pressed
                                                ? "#606060"
                                                : favoriteMouseArea.containsMouse
                                                ? "#484848"
                                                : "#00000000"

                                                Text {
                                                    //anchors.centerIn: parent
                                                    x: 5
                                                    y: -9

                                                    text: LauncherState.favorites.includes(modelData.id) ? "★" : "☆"
                                                    color: LauncherState.favorites.includes(modelData.id)
                                                    ? "#ffd166"
                                                    : "#b0b0b0"

                                                    font.pixelSize: 28
                                                }

                                                MouseArea {
                                                    id: favoriteMouseArea

                                                    anchors.fill: parent

                                                    onClicked: {
                                                        LauncherState.toggleFavorite(modelData)
                                                        mouse.accepted = true
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: applicationMouseArea

                                                anchors.fill: parent
                                                z: -1

                                                onClicked: {
                                                    LauncherState.launchApplication(modelData)
                                                    root.dismissed()
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
    }
}
//Item {
//    id: root
//
//    property bool open: false
//    property var screen
//
//    Layout.fillHeight: true
//    Layout.preferredWidth: 40
//    Layout.minimumWidth: 40
//
//    implicitWidth: 40
//    implicitHeight: 30
//
//    Rectangle {
//        anchors.fill: parent
//        color: mouseArea.pressed
//            ? "#404040"
//            : mouseArea.containsMouse
//                ? "#252525"
//                : "transparent"
//
//        Text {
//            anchors.centerIn: parent
//
//            text: "☷"
//            color: "white"
//            font.pixelSize: 24
//        }
//    }
//
//    MouseArea {
//        id: mouseArea
//
//        anchors.fill: parent
//
//        onClicked: root.open = !root.open
//    }
//
//    LauncherWindow {
//        visible: root.open
//        screen: root.screen
//
//        onDismissed: root.open = false
//    }
//}
