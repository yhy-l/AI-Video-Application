// SimpleLoadingIndicator.qml
import QtQuick
import QtQuick.Controls

Item {
    id: loadingIndicator
    width: 100
    height: 100

    // 属性
    property bool running: false
    property color primaryColor: "#FF6699"

    opacity: running ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: 300 }
    }

    // 使用 BusyIndicator 样式的旋转圆环
    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            var centerX = width / 2
            var centerY = height / 2

            // 清空画布
            ctx.clearRect(0, 0, width, height)

            // 绘制外层圆环
            ctx.beginPath()
            ctx.strokeStyle = loadingIndicator.primaryColor
            ctx.lineWidth = 6
            ctx.lineCap = "round"

            var radius1 = Math.min(width, height) * 0.4
            var startAngle1 = canvas.rotation * Math.PI / 180
            var endAngle1 = startAngle1 + Math.PI * 1.5

            ctx.arc(centerX, centerY, radius1, startAngle1, endAngle1, false)
            ctx.stroke()

            // 绘制中间圆环
            ctx.beginPath()
            ctx.strokeStyle = Qt.lighter(loadingIndicator.primaryColor, 1.3)
            ctx.lineWidth = 5

            var radius2 = radius1 * 0.7
            var startAngle2 = (canvas.rotation + 120) * Math.PI / 180
            var endAngle2 = startAngle2 + Math.PI * 1.2

            ctx.arc(centerX, centerY, radius2, startAngle2, endAngle2, false)
            ctx.stroke()

            // 绘制内层圆环
            ctx.beginPath()
            ctx.strokeStyle = Qt.lighter(loadingIndicator.primaryColor, 1.6)
            ctx.lineWidth = 4

            var radius3 = radius2 * 0.7
            var startAngle3 = (canvas.rotation + 240) * Math.PI / 180
            var endAngle3 = startAngle3 + Math.PI * 0.9

            ctx.arc(centerX, centerY, radius3, startAngle3, endAngle3, false)
            ctx.stroke()
        }

        // 旋转动画
        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 2000
            loops: Animation.Infinite
            running: loadingIndicator.running
        }

        // 旋转时重绘画布
        onRotationChanged: requestPaint()
    }
}
