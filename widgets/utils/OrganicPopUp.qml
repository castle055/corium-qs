import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: backdrop

    signal dismissed()

    default property alias content: contentColumn.data

    property real radius: 28
    property bool leftSide: false
    property bool fullHeight: false
    // Let text fields inside the popup take keyboard focus when clicked.
    property bool keyboardFocus: false

    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: keyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
        left: true
        bottom: true
    }

    //color: "#4400ff00"
    color: "transparent"


    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            backdrop.dismissed()
        }
    }

    Shape {
        id: panelShape
        x: backdrop.leftSide? 0: backdrop.width - contentColumn.implicitWidth
        y: 48
        transform: Scale { origin.x: panelShape.width/2; origin.y: 0; xScale: backdrop.leftSide?-1:1}

        ShapePath {
            fillColor: "black"
            strokeWidth: 0
            //strokeColor: "green"
            //strokeColor: "#555555"

            // top-left concave
            startX: -backdrop.radius
            startY: 0

            PathLine {
                x: contentColumn.implicitWidth //+1 //- backdrop.radius
                y: 0
            }

            PathLine {
                x: contentColumn.implicitWidth //+1
                y: backdrop.fullHeight? backdrop.height-48: (contentColumn.implicitHeight + backdrop.radius)
            }

            // bottom-right convex
            PathArc {
                x: contentColumn.implicitWidth - backdrop.radius
                y: backdrop.fullHeight? backdrop.height-48: contentColumn.implicitHeight
                radiusX: backdrop.fullHeight? 0: backdrop.radius
                radiusY: backdrop.fullHeight? 0: backdrop.radius
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: backdrop.fullHeight? -backdrop.radius: backdrop.radius
                y: backdrop.fullHeight? backdrop.height-48: contentColumn.implicitHeight
            }

            // bottom-left convex
            PathArc {
                x: 0
                y: (backdrop.fullHeight? backdrop.height-48: contentColumn.implicitHeight) - backdrop.radius
                radiusX: backdrop.radius
                radiusY: backdrop.radius
                direction: backdrop.fullHeight? PathArc.Counterclockwise: PathArc.Clockwise
            }

            PathLine {
                x: 0
                y: backdrop.radius
            }

            // top-left concave
            PathArc {
                x: -backdrop.radius
                y: 0
                radiusX: backdrop.radius
                radiusY: backdrop.radius
                direction: PathArc.Counterclockwise
            }
        }
    }

    MouseArea {
        z: -1
        x: backdrop.leftSide? 0: backdrop.width - contentColumn.implicitWidth
        y: 48
        implicitWidth: contentColumn.implicitWidth
        implicitHeight: backdrop.fullHeight? backdrop.height-48: contentColumn.implicitHeight
        onClicked: (mouse) => {
            // Mask clicks inside the content before they dismiss the popup
            mouse.accepted = true
        }
    }

    Column {
        id: contentColumn

        //anchors.fill: parent
        //anchors.x: 10
        x: backdrop.leftSide? 0: backdrop.width - contentColumn.implicitWidth
        y: 48

        spacing: 8
    }
}
