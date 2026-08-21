import QtQuick
import QtQuick.Window

Window {
    id: window
    height: 450
    width: 320
    visible: true
    flags: Qt.FramelessWindowHint | Qt.Window

    //实现全局拖拽功能
    Item {
        anchors.fill: parent
        DragHandler {
            target: null
            onActiveChanged: {
                if (active) {
                    window.startSystemMove();
                }
            }
        }
    }
}
