import QtQuick

Canvas {
    id: root

    property var rxValues: []
    property var txValues: []
    property int maxSamples: 72
    property color rxColor: "#58D8FF"
    property color txColor: "#B98AFF"
    property color gridColor: "#2234414F"
    property color textColor: "#99D1D5DB"

    implicitWidth: 720
    implicitHeight: 250
    antialiasing: true

    function pushSample(rx, tx) {
        var r = rxValues.slice(0)
        var t = txValues.slice(0)
        r.push(Math.max(0, Number(rx) || 0))
        t.push(Math.max(0, Number(tx) || 0))
        while (r.length > maxSamples) r.shift()
        while (t.length > maxSamples) t.shift()
        rxValues = r
        txValues = t
        requestPaint()
    }

    function clearSamples() {
        rxValues = []
        txValues = []
        requestPaint()
    }

    function maxValue() {
        var max = 1
        for (var i = 0; i < rxValues.length; ++i) max = Math.max(max, rxValues[i])
        for (var j = 0; j < txValues.length; ++j) max = Math.max(max, txValues[j])
        return max
    }

    function drawSeries(ctx, values, color, max) {
        if (values.length < 2) return

        var padX = 18
        var padTop = 16
        var padBottom = 20
        var graphW = width - padX * 2
        var graphH = height - padTop - padBottom
        var step = graphW / Math.max(1, maxSamples - 1)
        var start = maxSamples - values.length

        ctx.beginPath()
        for (var i = 0; i < values.length; ++i) {
            var x = padX + (start + i) * step
            var y = padTop + graphH - (values[i] / max) * graphH
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
        ctx.lineWidth = 2
        ctx.strokeStyle = color
        ctx.stroke()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        var padX = 18
        var padTop = 16
        var padBottom = 20
        var graphH = height - padTop - padBottom

        ctx.lineWidth = 1
        ctx.strokeStyle = gridColor
        for (var row = 0; row <= 4; ++row) {
            var gy = padTop + graphH * row / 4
            ctx.beginPath()
            ctx.moveTo(padX, gy)
            ctx.lineTo(width - padX, gy)
            ctx.stroke()
        }

        var max = maxValue()
        drawSeries(ctx, rxValues, rxColor, max)
        drawSeries(ctx, txValues, txColor, max)
    }
}
