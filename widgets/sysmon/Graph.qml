import QtQuick

// A filled line graph of percentages (0–100), newest on the right. The x axis
// always spans `capacity` samples, so a short history fills from the right.
Canvas {
    id: graph

    // Each series: { values: [...], color: "#rrggbb" }. Drawn in order.
    property var series: []
    property int capacity: 300

    onSeriesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        // Guide lines at 25%, 50% and 75%.
        ctx.strokeStyle = "#2a2a2a"
        ctx.lineWidth = 1
        for (const fraction of [0.25, 0.5, 0.75]) {
            const y = Math.round(height * fraction) + 0.5
            ctx.beginPath()
            ctx.moveTo(0, y)
            ctx.lineTo(width, y)
            ctx.stroke()
        }

        const step = width / Math.max(1, graph.capacity - 1)

        for (const s of graph.series) {
            const values = s.values
            if (values.length < 2)
                continue

            const x0 = width - (values.length - 1) * step
            const yOf = v => height - Math.max(0, Math.min(100, v)) / 100 * (height - 2) - 1

            ctx.beginPath()
            ctx.moveTo(x0, height)
            for (let i = 0; i < values.length; i++)
                ctx.lineTo(x0 + i * step, yOf(values[i]))
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.globalAlpha = 0.18
            ctx.fillStyle = s.color
            ctx.fill()

            ctx.beginPath()
            for (let i = 0; i < values.length; i++)
                ctx.lineTo(x0 + i * step, yOf(values[i]))
            ctx.globalAlpha = 1
            ctx.lineWidth = 1.5
            ctx.strokeStyle = s.color
            ctx.stroke()
        }
    }
}
