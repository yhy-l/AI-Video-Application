import QtQuick
import QtQuick.Controls
import QtMultimedia

Item {
    id: root
    anchors.fill: parent
    z: 100 // 确保在视频上方

    // 弹幕设置
    property bool danmakuEnabled: true
    property int fontSize: 20
    property int maxCount: 50
    property int rowCount: 8
    property int speed: 100 // 像素/秒

    // 弹幕数据
    property var danmuList: []

    // 视频播放器引用
    property MediaPlayer mediaPlayer

    // 当前弹幕列表
    property var activeDanmus: []

    // 初始化
    Component.onCompleted: {
        mediaPlayer.positionChanged.connect(updateDanmu);
    }

    // 更新弹幕
    function updateDanmu() {
        if (!danmakuEnabled) return;

        var currentTime = mediaPlayer.position / 1000; // 转换为秒

        // 添加新弹幕
        for (var i = 0; i < danmuList.length; i++) {
            var danmu = danmuList[i];
            if (danmu.time <= currentTime && !danmu.displayed) {
                addDanmu(danmu);
                danmu.displayed = true;
            }
        }

        // 移除已完全离开屏幕的弹幕（按位置判断，而不是按时间，
        // 否则弹幕还没走到头就会被提前销毁）
        for (var j = activeDanmus.length - 1; j >= 0; j--) {
            var activeDanmu = activeDanmus[j];
            if (activeDanmu.x + activeDanmu.width <= 0) {
                activeDanmu.destroy();
                activeDanmus.splice(j, 1);
            }
        }
    }

    // 添加弹幕
    function addDanmu(danmuData) {
        if (activeDanmus.length >= maxCount) return;

        var danmu = danmuComponent.createObject(root, {
            "text": danmuData.text,
            "color": danmuData.color,
            "fontSize": fontSize,
            "speed": speed,
            "duration": danmuData.duration,
            "startTime": mediaPlayer.position / 1000
        });

        activeDanmus.push(danmu);
    }

    // 弹幕组件
    Component {
        id: danmuComponent

        Text {
            id: danmuItem
            color: parent.color
            font.pixelSize: parent.fontSize
            font.bold: true
            text: parent.text
            style: Text.Outline
            styleColor: "black"

            property int speed: parent.speed
            property int duration: parent.duration
            property double startTime: parent.startTime
            property int row: Math.floor(Math.random() * rowCount)
            property int trackHeight: parent.height / rowCount

            x: parent.width
            y: row * trackHeight + (trackHeight - height) / 2

            // 弹幕移动动画
            NumberAnimation on x {
                from: parent.width
                to: -danmuItem.width
                duration: (parent.width + danmuItem.width) * 1000 / speed
                running: true
            }
        }
    }

    // 清空所有弹幕
    function clearAll() {
        for (var i = 0; i < activeDanmus.length; i++) {
            activeDanmus[i].destroy();
        }
        activeDanmus = [];

        // 重置显示状态
        for (var j = 0; j < danmuList.length; j++) {
            danmuList[j].displayed = false;
        }
    }

    // 添加新弹幕
    function addNewDanmu(text, color) {
        var currentTime = mediaPlayer.position / 1000;

        // 添加到弹幕列表
        danmuList.push({
            time: currentTime,
            text: text,
            color: color || "#FFFFFF",
            duration: 5,
            displayed: true   // 已经立即显示，避免 updateDanmu 再补一条造成重复
        });

        // 立即显示
        addDanmu({
            time: currentTime,
            text: text,
            color: color || "#FFFFFF",
            duration: 5
        });
    }
}
