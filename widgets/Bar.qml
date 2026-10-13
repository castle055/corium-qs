import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../services"
import "notebooks"
import "utils"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            //WlrLayershell.layer: WlrLayer.Overlay

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 48

            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            RowLayout {
                anchors.fill: parent
                spacing: 10

                RowLayout {
                    Layout.fillHeight: true
                    spacing: 0

                    NotebookLauncher {
                        Layout.fillHeight: true
                        screen: bar.screen
                    }

                    AppLauncher {
                        screen: bar.screen
                    }
                }

                Workspaces {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 30
                }
                OpenNotebooks {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                }
              //Clock {
              //    //anchors.centerIn: parent
              //    //Layout.minimumHeight: 30
              //    Layout.fillHeight: true
              //    Layout.fillWidth: true
              //}

                RowLayout {
                    ScreenshotTool {
                    }
                    OnScreenKeyboardToggle {
                    }
                }

                RowLayout {
                    Wifi {
                        Layout.fillHeight: true
                    }
                    Brightness {
                        Layout.fillHeight: true
                    }
                    Audio {
                        Layout.fillHeight: true
                    }
                    Battery {
                        Layout.fillHeight: true
                    }
                    SysMonitor {
                        Layout.fillHeight: true
                        screen: bar.screen
                    }
                }

                SysTray {
                    Layout.fillHeight: true
                    panelWindow: bar
                }

                Clock {
                    Layout.fillHeight: true
                }
            }
        }
    }
  //PanelWindow {
  //    id: test_win
  //    anchors {
  //        left: true
  //    }
  //    implicitWidth: 1270/3
  //    implicitHeight: screen.height - 48
  //    color: "black"

  //    NotebookManager {
  //        basePath: Quickshell.env("HOME") + "/Notes/Notebooks"
  //        implicitWidth: test_win.implicitWidth
  //    }
  //}
}
