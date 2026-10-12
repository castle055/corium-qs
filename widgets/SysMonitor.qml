import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: 85
    implicitHeight: 48

    property real cpuUsage: 0
    property real ramUsage: 0
    property real swapUsage: 0

    property var previousCpu: null

    Process {
        id: cpuProcess

        command: ["sh", "-c", "head -n1 /proc/stat"]

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(/\s+/)

                if (fields.length < 5)
                    return

                // user, nice, system, idle, iowait, irq, softirq, steal
                const user = Number(fields[1])
                const nice = Number(fields[2])
                const system = Number(fields[3])
                const idle = Number(fields[4])
                const iowait = Number(fields[5])
                const irq = Number(fields[6])
                const softirq = Number(fields[7])
                const steal = Number(fields[8])

                const idleTime = idle + iowait
                const totalTime =
                    user + nice + system + idle +
                    iowait + irq + softirq + steal

                if (root.previousCpu !== null) {
                    const totalDelta =
                        totalTime - root.previousCpu.total

                    const idleDelta =
                        idleTime - root.previousCpu.idle

                    if (totalDelta > 0) {
                        root.cpuUsage =
                            100 * (1 - idleDelta / totalDelta)
                    }
                }

                root.previousCpu = {
                    total: totalTime,
                    idle: idleTime
                }
            }
        }
    }

    Process {
        id: memoryProcess

        command: [
            "sh",
            "-c",
            "grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let memTotal = 0
                let memAvailable = 0
                let swapTotal = 0
                let swapFree = 0

                const lines = text.trim().split("\n")

                for (const line of lines) {
                    const parts = line.trim().split(/\s+/)
                    const value = Number(parts[1])

                    switch (parts[0]) {
                    case "MemTotal:":
                        memTotal = value
                        break

                    case "MemAvailable:":
                        memAvailable = value
                        break

                    case "SwapTotal:":
                        swapTotal = value
                        break

                    case "SwapFree:":
                        swapFree = value
                        break
                    }
                }

                if (memTotal > 0) {
                    root.ramUsage =
                        100 * (1 - memAvailable / memTotal)
                }

                if (swapTotal > 0) {
                    root.swapUsage =
                        100 * (1 - swapFree / swapTotal)
                } else {
                    root.swapUsage = 0
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            cpuProcess.running = true
            memoryProcess.running = true
        }
    }

    Row {
        //anchors.centerIn: parent
        spacing: 10

        Row {
            spacing: 0
            Text {
                Layout.fillHeight: true
                text: "CPU "
                color: "white"
                y: (30 - implicitHeight)/2
            }
            Rectangle {
                id: cpu_indicator
                implicitHeight: 30 * root.cpuUsage / 100
                implicitWidth: 10
                //y: 30 - ram_indicator.implicitHeight
                color: "red"
            }
        }


        Row {
            spacing: 0
            Text {
                Layout.fillHeight: true
                text: "MEM "
                color: "white"
                y: (30 - implicitHeight)/2
            }
            Rectangle {
                id: ram_indicator
                implicitHeight: 30 * root.ramUsage / 100
                implicitWidth: 10
                //y: 30 - ram_indicator.implicitHeight
                color: "red"
            }
            Rectangle {
                id: swap_indicator
                implicitHeight: 30 * root.swapUsage / 100
                implicitWidth: 5
                //y: 30 - swap_indicator.implicitHeight
                color: "cyan"
            }
        }
    }

    Component.onCompleted: {
        cpuProcess.running = true
        memoryProcess.running = true
    }
}
