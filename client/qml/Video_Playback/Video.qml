import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Qt.labs.platform
import "../../component"
import "../"

FrameLessWindow{
    id: videoPlayerPage
    color: "transparent"
    width: 1300
    height: 800
    visible: true
    title: "B站视频播放器"



    property bool titleWindow : false

    property string currentView:"info"  //获取当前简介或者评论状态
    property string currentCommit: "close"  //获取当前展开或者关闭
    property bool attention: false;     //获取关注的up
    property bool forceControlBarVisible: false //状态栏打开或者关闭

    property var mainWindow: null

    // 评论数量：直接绑定 C++ 控制器（Q_PROPERTY 带 NOTIFY），
    // 发布评论后 loadComments 刷新会触发 commentCountChanged 自动 +1。
    // 不依赖指向后创建子组件的 Connections（那种写法绑不到目标）。
    property int realTimeCommitCount:
        (videoManager && videoManager.commentVideoId === videoId)
            ? videoManager.commentCount
            : (videoData.commentCount || 0)

    // 点赞/投币状态与计数（由用户操作后的信号驱动刷新）
    property bool likeState: false
    property int coinState: 0
    property int likeCountDisplay: videoData.likeCount || 0
    property int coinCountDisplay: videoData.coinCount || 0

    function refreshActionStates() {
        if (!userController)
            return
        var logged = userController.isLoggedIn
        likeState = logged && userController.isVideoLiked(videoData.id)
        coinState = userController.getUserVideoCoinCount(videoData.id)
    }

    function showVideoToast(message) {
        videoToastText.text = message
        videoToast.visible = true
        videoToastFade.from = 0
        videoToastFade.to = 1
        videoToastFade.start()
        videoToastTimer.restart()
    }

    onClosing:
    {
        mediaPlayer.stop()
        mediaPlayer.source = ""
        // root.currentVideoPlayer.destroy()
        // mainWindow.currentVideoPlayer= null
    }

    property var danmuList: []

    // 从服务端加载的真实弹幕 -> 渲染格式
    function refreshDanmu() {
        var arr = []
        var list = videoManager ? (videoManager.danmaku || []) : []
        for (var i = 0; i < list.length; i++) {
            arr.push({time: list[i].time, text: list[i].content,
                      color: list[i].color || "#FFFFFF", duration: 8})
        }
        danmuList = arr
    }


    property bool isAlwaysOnTop: false   //置顶窗口
    property var videoData: ({})    //vo数据
    property var videoManager       //视频控制器
    property var videoId            //视频id
    property var index             //视频索引

    Connections
    {
       target: videoManager

       function onVideosChanged()
       {
           updateVideoData();
           refreshActionStates();
       }
       function onDanmakuChanged()
       {
           refreshDanmu();
       }
       function onErrorOccurred(message) {
           showVideoToast(message)
       }
    }

    Connections
    {
        target: userController

        function onVideoLiked(videoId) { refreshActionStates() }
        function onVideoUnliked(videoId) { refreshActionStates() }
        function onVideoCoined(videoId, coinCount) { refreshActionStates() }
        function onLoginStatusChanged() { refreshActionStates() }
        function onErrorOccurred(message) { showVideoToast(message) }
    }

    Connections
    {
        target: downloadManager

        function onDownloadFinished(videoId, filePath) {
            showVideoToast("下载完成，已保存到下载目录")
        }
    }

    function updateVideoData() {
            if (videoManager && videoId) {
                var data = videoManager.getVideo(videoId)
                // getVideo 只在已加载列表里找；搜索结果可能不在其中，
                // 未命中时保留传入的数据
                if (data && data.id)
                    videoData = JSON.parse(JSON.stringify(data))
            }
        }

    flags: {
            var baseFlags = Qt.Window | Qt.FramelessWindowHint;
            if (isAlwaysOnTop) {
                return baseFlags | Qt.WindowStaysOnTopHint;
            } else {
                return baseFlags;
            }
        }//用于固定窗口

    Component.onCompleted: {
        mediaPlayer.play()
        updateVideoData()
        refreshActionStates()
        mainWindow.currentVideoPlayer = this
        if (videoManager && videoId) {
            videoManager.loadDanmaku(videoId)
            videoManager.recordView(videoId)   // 打开即上报播放量（服务端防刷）
        }
    }

    // 主容器 - 添加圆角效果
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        radius: 10
        color: "#121212"
        clip: true

        // 置顶提示 Toast（显示在播放器窗口顶部）
        Rectangle {
            id: videoToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            height: 38
            width: videoToastText.implicitWidth + 48
            radius: 19
            color: "#E6000000"
            visible: false
            opacity: 0
            z: 9999

            Text {
                id: videoToastText
                anchors.centerIn: parent
                color: "#FFFFFF"
                font.pixelSize: 13
            }

            NumberAnimation on opacity {
                id: videoToastFade
                running: false
                duration: 220
                easing.type: Easing.OutQuad
            }
        }

        Timer {
            id: videoToastTimer
            interval: 2400
            onTriggered: {
                videoToastFade.from = 1
                videoToastFade.to = 0
                videoToastFade.start()
            }
        }

        // 顶部标题栏
        Rectangle {
            id: titleBar
            visible:videoPlayerPage.visibility !== Window.FullScreen
            width: parent.width;     height:60
            topLeftRadius: 10
            topRightRadius: 10
            bottomLeftRadius: 0
            bottomRightRadius: 0
            anchors.top: parent.top
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#3A3A3A" }
                GradientStop { position: 1.0; color: "#2D2D2D" }
            }   //渐变，从左到右

            TapHandler
            {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped:
                {
                    if (videoPlayerPage.visibility === Window.Maximized) {
                                    videoPlayerPage.visibility = Window.Windowed
                                } else {
                                    videoPlayerPage.visibility = Window.Maximized
                                }
                }
            }  //双击窗口放大或缩小

            RowLayout
            {
                anchors.fill: parent
                anchors.margins: 10

                spacing: 8

                Button
                {
                    id:backButton
                    text:"回到主界面"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.preferredWidth: parent.width * 0.12
                    Layout.preferredHeight: parent.height

                    HoverHandler {
                             cursorShape: Qt.PointingHandCursor
                         }

                    contentItem: Text {
                        text:backButton.text
                        font: backButton.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }  //自定义字体格式

                    background:Rectangle
                    {
                        id:buttonBackground
                        radius: 10
                        color: backButton.hovered ? "#6A6A6A"  :  "#4A4A4A"
                        opacity:backButton.down? 0.5 : 1

                    }  //设置按钮背景

                    onClicked:
                    {
                        // stackView.pop()
                        videoPlayerPage.close()
                    }
                }

                Item {
                     Layout.fillWidth: true
                 }


            }


            // 窗口控制按钮
            RowLayout {
                id:f
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                anchors.margins: 10
                height: parent.height

                Button {
                    id: pinButton
                    Layout.preferredWidth: titleBar.width * 0.04
                    Layout.preferredHeight: parent.height * 0.7
                    text: videoPlayerPage.isAlwaysOnTop ? "📌" : "📍"
                    font.pixelSize: 20
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter // 添加垂直居中

                    HoverHandler {
                             cursorShape: Qt.PointingHandCursor
                         }

                    contentItem: Text {
                        text:pinButton.text
                        font: pinButton.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }  //自定义字体格式

                    background: Rectangle {
                        radius: 5
                        color: pinButton.down ? "#6A6A6A":"#7A7A7A"
                        opacity:pinButton.hovered? 0.5 : 0
                    }
                    onClicked: {
                        videoPlayerPage.isAlwaysOnTop = !videoPlayerPage.isAlwaysOnTop
                    }
                }

                    // 分隔线
                    Rectangle {
                        width: 1
                        height: parent.height * 0.6
                        color: "#666666"
                        Layout.alignment: Qt.AlignVCenter
                        opacity: 0.7
                    }

                // 最小化按钮
                Button {
                    id: minimizeButton
                    Layout.preferredWidth: titleBar.width * 0.04
                    Layout.preferredHeight: parent.height * 0.7
                    text: "—"
                    font.pixelSize: 20
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter // 添加垂直居中

                    HoverHandler {
                             cursorShape: Qt.PointingHandCursor
                         }

                    contentItem: Text {
                        text:minimizeButton.text
                        font: minimizeButton.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }  //自定义字体格式

                    background: Rectangle {
                        radius: 5
                        color: minimizeButton.down ? "#6A6A6A":"#7A7A7A"
                        opacity:minimizeButton.hovered? 0.5 : 0
                    }
                    onClicked: {
                        videoPlayerPage.visibility = Window.Minimized
                    }
                }

                // 最大化/还原按钮
                Button {
                    id: maximizeButton
                    Layout.preferredWidth: titleBar.width * 0.04
                    Layout.preferredHeight: parent.height * 0.7
                    text: videoPlayerPage.visibility === Window.Maximized ? "❐" : "□"
                    font.pixelSize: 25
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter // 添加垂直居中

                    HoverHandler {
                             cursorShape: Qt.PointingHandCursor
                         }

                    contentItem: Text {
                        text:maximizeButton.text
                        font: maximizeButton.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }  //自定义字体格式
                    background: Rectangle {
                        radius: 5
                        color: maximizeButton.down ? "#6A6A6A":"#7A7A7A"
                        opacity:maximizeButton.hovered? 0.5 : 0
                    }
                    onClicked: {
                        if (videoPlayerPage.visibility === Window.Maximized) {
                            videoPlayerPage.visibility = Window.Windowed
                        } else {
                            videoPlayerPage.visibility = Window.Maximized
                        }
                    }


                }

                // 关闭按钮
                Button {
                    id: closeButton
                    Layout.preferredWidth: titleBar.width * 0.04
                    Layout.preferredHeight: parent.height * 0.7
                    font.pixelSize: 25
                    font.bold: true
                    text: "×"
                    Layout.alignment: Qt.AlignVCenter // 添加垂直居中

                    HoverHandler {
                             cursorShape: Qt.PointingHandCursor
                         }

                    contentItem: Text {
                        text:closeButton.text
                        font: closeButton.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }  //自定义字体格式
                    background: Rectangle {
                        radius: 5
                        color: closeButton.down ? "#6A6A6A":"#7A7A7A"
                        opacity:closeButton.hovered? 0.5 : 0
                    }
                    onClicked: {
                        // stackView.pop()
                        videoPlayerPage.close()
                    }

                 }
            }

          } //标题栏部分

        //=======内容部分=========
        Rectangle
        {
            id:content
            anchors
            {
                top:titleBar.bottom
                left:parent.left
                right:parent.right
                bottom:parent.bottom
            }
            color: "transparent"

            RowLayout
            {
                anchors.fill: parent
                //==================================视频区域====================================//
                Rectangle
                {
                    id:vedio
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 5/7
                    color: "transparent"

                    property bool isLoading: false


                    // 弹幕层
                    DamuSystem {
                        id: damuLayer
                        anchors.fill: parent
                        mediaPlayer: mediaPlayer
                        danmuList: videoPlayerPage.danmuList
                    }

                    // 媒体播放器
                    MediaPlayer {
                        id: mediaPlayer
                        source: videoData.videoUrl
                        videoOutput: videoOutput
                        audioOutput: AudioOutput
                        {
                            id:audio
                            volume:0.5
                        }
                    }


                    VideoOutput
                    {
                        id: videoOutput
                        anchors.fill: parent

                        property bool showLoading: false

                        // 初始加载检测
                        Timer {
                            id: initialLoadingTimer
                            interval: 500
                            running: true
                            onTriggered: {
                                // 如果没有视频，显示加载指示器
                                if (!mediaPlayer.hasVideo) {
                                    videoOutput.showLoading = true;
                                }
                            }
                        }

                        // 检测卡顿的计时器
                        Timer {
                            id: stuckDetectionTimer
                            interval: 2000
                            running: mediaPlayer.playbackState === MediaPlayer.PlayingState || videoOutput.showLoading
                            repeat: true
                            onTriggered: {
                                // 如果正在播放但位置没变化，显示加载指示器
                                if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                                    videoOutput.showLoading = true;
                                }
                            }
                        }

                        // 监听位置变化
                        Connections {
                            target: mediaPlayer

                            function onPositionChanged() {
                                // 只要有位置变化，就隐藏加载指示器
                                videoOutput.showLoading = false;

                                // 重置计时器
                                if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                                    stuckDetectionTimer.restart();
                                }
                            }

                            function onPlaybackStateChanged() {
                                if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                                    // 开始播放，启动卡顿检测
                                    stuckDetectionTimer.restart();
                                } else {
                                    // 暂停或停止，隐藏加载指示器
                                    videoOutput.showLoading = false;
                                    stuckDetectionTimer.stop();
                                }
                            }

                            // 监听视频画面变化
                            function onHasVideoChanged() {
                                if (mediaPlayer.hasVideo) {
                                    videoOutput.showLoading = false;
                                } else if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                                    // 播放中但没有视频，显示加载
                                    videoOutput.showLoading = true;
                                }
                            }

                            // 监听错误
                            function onErrorOccurred() {
                                videoOutput.showLoading = false;
                            }
                        }

                        // 视频遮罩层
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: videoOutput.showLoading ? 0.8 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation { duration: 300 }
                            }
                        }


                        // 使用新的三层旋转加载指示器
                        ModernLoadingIndicator {
                            anchors.centerIn: parent
                            running: videoOutput.showLoading

                            // 可选：自定义颜色
                            // primaryColor: "#00BFFF"  // 蓝色

                            // 可选：调整速度
                            // speed: 2
                        }

                        // HoverHandler{ cursorShape: Qt.PointingHandCursor }
                        TapHandler
                        {
                            acceptedButtons: Qt.LeftButton
                            onTapped:
                            {
                                if(mediaPlayer.playbackState === MediaPlayer.PlayingState) mediaPlayer.pause()
                                else  mediaPlayer.play()
                                buttonAnimation.start()
                            }
                        }
                    }


                    TapHandler
                        {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.WithinBounds

                            onDoubleTapped: {
                                if (videoPlayerPage.visibility === Window.FullScreen) {
                                    videoPlayerPage.visibility = Window.Windowed
                                } else {
                                    videoPlayerPage.visibility = Window.FullScreen
                                }
                            }
                        }

                    HoverHandler {
                        id: videoHoverHandler
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onHoveredChanged: {

                            if (hovered) {
                                controlBar.opacity = 1.0
                                hideTimer.interval = 2000
                                hideTimer.restart()
                            } else {
                                hideTimer.interval = 300
                                hideTimer.restart();
                            }
                        }
                    }

                    MouseArea
                    {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton  // 不拦截点击事件
                        cursorShape: Qt.ArrowCursor

                        onPositionChanged: {
                            if (videoHoverHandler.hovered) {
                                mouseArea.cursorShape = Qt.ArrowCursor
                                controlBar.opacity = 1.0
                                hideTimer.interval = 2000
                                hideTimer.restart()
                            }
                        }
                    }


                    // 添加延迟隐藏计时器
                    Timer {
                        id: hideTimer
                        interval: 300
                        onTriggered: {
                            controlBar.opacity = 0.0;
                            if (videoHoverHandler.hovered) {
                                mouseArea.cursorShape = Qt.BlankCursor
                            } else {
                                mouseArea.cursorShape = Qt.ArrowCursor
                            }
                        }
                    }

                    Rectangle
                    {
                        id:video_progress
                        anchors
                        {
                            left:parent.left
                            right:parent.right
                            bottom:parent.bottom
                        }
                        visible: controlBar.opacity === 0.0 ? true : false
                        color: "grey"
                        height: 7
                        Rectangle
                            {
                                width: mediaPlayer.duration > 0 ?
                                       (mediaPlayer.position / mediaPlayer.duration) * parent.width : 0
                                height: parent.height
                                color: "#FF6699" // 粉色进度条
                            }    //播放进度条

                    }

                    Rectangle
                    {
                        id:controlBar
                        anchors
                        {
                            left:parent.left
                            right:parent.right
                            bottom:parent.bottom
                        }
                        height:70
                        color: "transparent"
                        z:5

                        Behavior on opacity {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.InOutQuad
                                    }
                                }

                        MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.AllButtons
                                propagateComposedEvents: false

                                // 正确声明参数
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                }
                                onDoubleClicked: function(mouse) {
                                    mouse.accepted = true
                                }
                                onPressed: function(mouse) {
                                    mouse.accepted = true
                                }
                                onReleased: function(mouse) {
                                    mouse.accepted = true
                                }
                            } //TapHandler使用会变复杂

                        ColumnLayout
                        {
                           anchors.fill: parent

                           Rectangle
                           {
                               id:none_name
                               Layout.preferredWidth: parent.width
                               height: hoverHandler.hovered ? 5 + 4 : 5
                               color: "grey"

                               signal playRequested()

                               Rectangle
                                   {
                                       id: progressBar
                                       width: mediaPlayer.duration > 0 ?
                                              (mediaPlayer.position / mediaPlayer.duration) * parent.width : 0
                                       height: parent.height
                                       color: "#FF6699" // 粉色进度条


                                       Behavior on width {
                                           NumberAnimation { duration: 100 }
                                       }
                                   }    //播放进度条

                               Behavior on height {
                                        NumberAnimation { duration: 150 }
                                            }

                               HoverHandler {
                                       id: hoverHandler
                                       cursorShape: Qt.PointingHandCursor
                                   }

                               TapHandler {
                                      id: tapHandler
                                      acceptedButtons: Qt.LeftButton
                                      gesturePolicy: TapHandler.ReleaseWithinBounds
                                      onTapped: {
                                          // 计算点击位置对应的播放时间
                                          var newPosition = (point.position.x / parent.width) * mediaPlayer.duration
                                          mediaPlayer.position = newPosition
                                      }
                                  }

                               DragHandler {
                                       id: dragHandler
                                       acceptedButtons: Qt.LeftButton
                                       target: null

                                       onActiveChanged: {
                                           if (active) {
                                               // 拖动开始
                                               var newPosition = (centroid.position.x / parent.width) * mediaPlayer.duration
                                               mediaPlayer.position = newPosition
                                           }
                                       }

                                       onCentroidChanged: {
                                           if (active) {
                                               // 拖动中
                                               var newPosition = (centroid.position.x / parent.width) * mediaPlayer.duration
                                               mediaPlayer.position = newPosition
                                           }
                                       }
                                   }  //拖动控制

                                   Rectangle
                                   {
                                       id: dragHandle
                                       visible: dragHandler.active || tapHandler.pressed
                                       x: progressBar.width - width/2
                                       y: (parent.height - height)/2
                                       width: 16
                                       height: 16
                                       radius: width/2
                                       color: "#FF6699" // 粉色滑块
                                       border.color: "#FFFFFF"
                                       border.width: 2

                                   }

                           }//进度条

                           RowLayout
                           {
                               Layout.fillWidth: true
                               Layout.preferredHeight: 40
                               Layout.margins: 10
                               Button {
                                               id: playPauseButton
                                               Layout.preferredWidth: 40
                                               Layout.preferredHeight: 40
                                               Layout.alignment: Qt.AlignVCenter
                                               Layout.bottomMargin: 7

                                               // 根据播放状态显示不同图标
                                               text: mediaPlayer.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                                               font.pixelSize:25

                                               HoverHandler {
                                                   cursorShape: Qt.PointingHandCursor
                                               }

                                               background:Rectangle
                                               {
                                                   color:"transparent"
                                               }

                                               contentItem: Text {
                                                   text: playPauseButton.text
                                                   font: playPauseButton.font
                                                   color: "white"
                                                   horizontalAlignment: Text.AlignHCenter
                                                   verticalAlignment: Text.AlignVCenter
                                               }

                                               onClicked: {
                                                   if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                                                       mediaPlayer.pause()
                                                   } else {
                                                       mediaPlayer.play()
                                                   }
                                                   buttonAnimation.start()
                                               }

                                               SequentialAnimation {
                                                       id: buttonAnimation

                                                       // 放大动画
                                                       PropertyAnimation {
                                                           target: playPauseButton
                                                           property: "scale"
                                                           to: 1.2
                                                           duration: 300
                                                           easing.type: Easing.OutCubic
                                                       }

                                                       // 恢复动画
                                                       PropertyAnimation {
                                                           target: playPauseButton
                                                           property: "scale"
                                                           to: 1.0
                                                           duration: 300
                                                           easing.type: Easing.OutBack
                                                       }
                                                   }
                               } //暂停按钮

                               Text {
                                   text:formatTime(mediaPlayer.position) + "/" + formatTime(mediaPlayer.duration)
                                   color: "white"
                                   font.pixelSize: 15
                                   Layout.alignment: Qt.AlignVCenter
                                   Layout.leftMargin: 10

                                   function formatTime(milliseconds) {
                                               if (milliseconds <= 0) return "00:00";
                                               var seconds = Math.floor(milliseconds / 1000);
                                               var minutes = Math.floor(seconds / 60);
                                               seconds = seconds % 60;
                                               return minutes.toString().padStart(2, '0') + ":" + seconds.toString().padStart(2, '0');
                                           }
                               }

                               Button {
                                               id: dm
                                               Layout.preferredWidth: 40
                                               Layout.preferredHeight: 40
                                               Layout.alignment: Qt.AlignVCenter
                                               Layout.bottomMargin: 6
                                               Layout.leftMargin: widthNum.width * 0.2

                                               // 显示当前弹幕开关状态
                                               text: damuLayer.danmakuEnabled ? "弹幕:开" : "弹幕:关"
                                               font.pixelSize:15

                                               HoverHandler {
                                                   cursorShape: Qt.PointingHandCursor
                                               }

                                               background:Rectangle
                                               {
                                                   color:"transparent"
                                               }

                                               contentItem: Text {
                                                   text: dm.text
                                                   font: dm.font
                                                   color: "white"
                                                   horizontalAlignment: Text.AlignHCenter
                                                   verticalAlignment: Text.AlignVCenter
                                               }

                                               onClicked: {
                                                   damuLayer.danmakuEnabled = !damuLayer.danmakuEnabled
                                               }

                               } //弹幕打开关闭按钮

                               TextField
                               {
                                   id: danmuInput
                                   Layout.preferredWidth: widthNum.width * 0.4
                                   Layout.preferredHeight: 30
                                   Layout.leftMargin: 15
                                   Layout.bottomMargin: 6
                                   placeholderText: "点击发送弹幕"
                                   placeholderTextColor: "grey"
                                   color: "white"

                                   HoverHandler {
                                            cursorShape: Qt.IBeamCursor
                                        }

                                   background: Rectangle {
                                           id: commentInputBg
                                           color: "#2D2D2D"
                                           radius: 5
                                           border.width: 1
                                           border.color: "transparent" // 初始透明边框

                                           // 添加边框颜色动画
                                           Behavior on border.color {
                                               ColorAnimation { duration: 200 }
                                           }
                                       }

                                       // 聚焦变化处理
                                       onFocusChanged: {
                                           if (focus) {
                                               commentInputBg.border.color = "#FF6699"; // 粉色边框
                                           } else {
                                               commentInputBg.border.color = "transparent";
                                           }
                                       }

                                       Keys.onPressed: (event) => {
                                               if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                   var content = text.trim();
                                                   if (content !== "" && videoManager && videoId) {
                                                       videoManager.addDanmaku(videoId, content,
                                                                              mediaPlayer.position / 1000, "#FFFFFF");
                                                   }
                                                   // 清除文字
                                                   text = "";
                                                   // 取消焦点
                                                   focus = false;
                                               }
                                           }
                               }  //发送弹幕

                               Item {
                                   Layout.fillWidth: true
                               }

                               Button {
                                               id: multipe
                                               Layout.preferredWidth: 40
                                               Layout.preferredHeight: 40
                                               Layout.alignment: Qt.AlignVCenter
                                               Layout.bottomMargin: 6
                                               Layout.leftMargin: 40

                                               // 根据播放状态显示不同图标
                                               text: "倍数"
                                               font.pixelSize:15

                                               HoverHandler {
                                                   cursorShape: Qt.PointingHandCursor
                                               }

                                               background:Rectangle
                                               {
                                                   color:"transparent"
                                               }

                                               contentItem: Text {
                                                   text: multipe.text
                                                   font: multipe.font
                                                   color: "white"
                                                   horizontalAlignment: Text.AlignHCenter
                                                   verticalAlignment: Text.AlignVCenter
                                               }

                                               onClicked: {
                                                   if(multipe_set.opened)
                                                        multipe_set.close()
                                                   else
                                                       multipe_set.open()

                                               }

                               } //倍数设置

                               Popup
                               {
                                   id:multipe_set
                                   x: multipe.x + multipe.width/2 - width/2
                                   y: multipe.y - height - 10
                                   width: 90
                                   height: contentItem.implicitHeight + 20
                                   padding: 5
                                   closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent

                                   onOpened:
                                   {
                                       forceControlBarVisible = true
                                   }

                                   onClosed:
                                   {
                                       forceControlBarVisible = false
                                       if (!videoHoverHandler.hovered) {
                                                   controlBar.opacity = 0.0
                                               }
                                   }

                                   // 弹出动画
                                   enter: Transition {
                                       NumberAnimation { property: "opacity"; from: 0.0; to: 0.9; duration: 150 }
                                       NumberAnimation { property: "scale"; from: 0.5; to: 1.0; duration: 100 }
                                   }

                                   exit: Transition {
                                       NumberAnimation { property: "opacity"; from: 0.9; to: 0.0; duration: 100 }
                                       NumberAnimation { property: "scale"; from: 1.0; to: 0.5; duration: 150 }
                                   }

                                   background: Rectangle {
                                       color: "black"
                                       radius: 5
                                   }

                                   contentItem: ColumnLayout {
                                           spacing: 5

                                           // 倍速选项
                                           Repeater {
                                               model: [2.0,1.5,1.25,1.0,0.75,0.5]

                                               Button {
                                                   Layout.fillWidth: true
                                                   Layout.preferredHeight: 40
                                                   text: {
                                                           // 将数字转换为字符串
                                                           let str = modelData.toString();

                                                           // 如果字符串不包含小数点，添加".0"
                                                           if (!str.includes('.')) {
                                                               str += ".0";
                                                           }
                                                           // 如果包含小数点
                                                           else {
                                                               // 移除末尾多余的零
                                                               str = str.replace(/0+$/, '');
                                                               // 如果小数点后没有数字了，添加"0"
                                                               if (str.endsWith('.')) {
                                                                   str += "0";
                                                               }
                                                           }

                                                           return str + "x";
                                                       }
                                                   font.bold: true
                                                   font.pixelSize: 14

                                                   HoverHandler
                                                   {
                                                       cursorShape: Qt.PointingHandCursor
                                                   }

                                                   background: Rectangle {
                                                       color: parent.hovered ? "#3D3D40" : "transparent"
                                                       radius: 3
                                                   }

                                                   contentItem: Text {
                                                       text: parent.text
                                                       font: parent.font
                                                       color: Math.abs(mediaPlayer.playbackRate - modelData) < 0.01 ? "#FF6699" : "white"
                                                       horizontalAlignment: Text.AlignHCenter
                                                       verticalAlignment: Text.AlignVCenter
                                                   }

                                                   onClicked: {
                                                       mediaPlayer.playbackRate = modelData
                                                       multipe_set.close()
                                                   }
                                               }

                                           }
                                   }

                               }

                               Button {
                                               id: volumn
                                               Layout.preferredWidth: 40
                                               Layout.preferredHeight: 40
                                               Layout.alignment: Qt.AlignVCenter
                                               Layout.bottomMargin: 6
                                               Layout.leftMargin: 15

                                               // 根据播放状态显示不同图标
                                               text: "音量"
                                               font.pixelSize:15

                                               HoverHandler {
                                                   cursorShape: Qt.PointingHandCursor
                                               }

                                               background:Rectangle
                                               {
                                                   color:"transparent"
                                               }

                                               contentItem: Text {
                                                   text: volumn.text
                                                   font: volumn.font
                                                   color: "white"
                                                   horizontalAlignment: Text.AlignHCenter
                                                   verticalAlignment: Text.AlignVCenter
                                               }

                                               onClicked: {
                                                   if(volume_set.opened)
                                                        volume_set.close()
                                                   else
                                                       volume_set.open()
                                               }

                               } //音量设置

                               Popup
                               {
                                   id:volume_set
                                   x:volumn.x + volumn.width/2 - width/2
                                   y:volumn.y - height -10
                                   width: 50
                                   height: 135
                                   padding: 1
                                   closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent

                                   onOpened:
                                   {
                                       forceControlBarVisible = true
                                   }

                                   onClosed:
                                   {
                                       forceControlBarVisible = false
                                       if (!videoHoverHandler.hovered) {
                                                   controlBar.opacity = 0.0
                                               }
                                   }

                                   // 弹出动画
                                   enter: Transition {
                                       NumberAnimation { property: "opacity"; from: 0.0; to: 0.9; duration: 150 }
                                       NumberAnimation { property: "scale"; from: 0.5; to: 1.0; duration: 100 }
                                   }

                                   exit: Transition {
                                       NumberAnimation { property: "opacity"; from: 0.9; to: 0.0; duration: 100 }
                                       NumberAnimation { property: "scale"; from: 1.0; to: 0.5; duration: 150 }
                                   }

                                   background: Rectangle {
                                       color: "black"
                                       radius: 5
                                   }

                                   contentItem: ColumnLayout {
                                       anchors.fill: parent
                                       anchors.margins: 10
                                       spacing: 10

                                       // 添加一个容器包裹文本和滑块
                                       ColumnLayout {
                                           Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                           spacing: 10

                                           // 音量值显示 - 居中
                                           Text {
                                               id: volumeValue
                                               text: Math.round(volumn_slider.value * 100)
                                               color: "white"
                                               font.bold: true
                                               font.pixelSize: 13
                                               Layout.alignment: Qt.AlignHCenter
                                           }

                                           // 垂直滑块
                                           Slider {
                                               id: volumn_slider
                                               Layout.fillHeight: true
                                               Layout.preferredWidth: 30 // 设置固定宽度使滑块更窄
                                               orientation: Qt.Vertical
                                               from: 0.0
                                               to: 1.0
                                               value: mediaPlayer.audioOutput.volume

                                               WheelHandler {
                                                       id: wheelHandler
                                                       acceptedDevices: PointerDevice.Mouse
                                                       orientation: Qt.Vertical
                                                       onWheel: function(event) {
                                                           // 计算步长 (每次滚轮滚动改变5%音量)
                                                           var step = 0.1;
                                                           // 根据滚轮方向调整音量
                                                           if (event.angleDelta.y > 0) {
                                                               // 向上滚动增加音量
                                                               volumn_slider.value = Math.min(1.0, volumn_slider.value + step);
                                                           } else {
                                                               // 向下滚动减小音量
                                                               volumn_slider.value = Math.max(0.0, volumn_slider.value - step);
                                                           }
                                                           event.accepted = true;
                                                       }
                                                   }

                                               HoverHandler {
                                                   cursorShape: Qt.PointingHandCursor
                                               }

                                               background: Rectangle {
                                                   x: parent.leftPadding + (parent.availableWidth - width) / 2
                                                   y: parent.topPadding
                                                   width: 6
                                                   height: parent.availableHeight
                                                   radius: 3
                                                   color: "white" // 未拖动部分为白色

                                                   // 已拖动部分（粉色）
                                                   Rectangle {
                                                       width: parent.width
                                                       height: volumn_slider.value * parent.height
                                                       color: "#FF6699" // 粉色
                                                       radius: 3
                                                       anchors.bottom: parent.bottom // 从底部开始填充
                                                   }
                                               }

                                               handle: Rectangle {
                                                   x: volumn_slider.leftPadding + volumn_slider.availableWidth / 2 - width / 2
                                                   y: parent.topPadding + volumn_slider.visualPosition * (parent.availableHeight - height)
                                                   width: 15
                                                   height: 15
                                                   radius: width / 2
                                                   color: "#FF6699"
                                                   z:3
                                               }

                                               onValueChanged:
                                               {
                                                   audio.volume = value
                                               }
                                           }
                                       }
                                   }
                               }

                               Button {
                                               id: qp
                                               Layout.preferredWidth: 40
                                               Layout.preferredHeight: 40
                                               Layout.alignment: Qt.AlignVCenter
                                               Layout.bottomMargin: 6
                                               Layout.rightMargin: 10
                                               Layout.leftMargin: 15

                                               // 根据播放状态显示不同图标
                                               text: "全屏"
                                               font.pixelSize:15

                                               HoverHandler {
                                                   cursorShape: Qt.PointingHandCursor
                                               }

                                               background:Rectangle
                                               {
                                                   color:"transparent"
                                               }

                                               contentItem: Text {
                                                   text: qp.text
                                                   font: qp.font
                                                   color: "white"
                                                   horizontalAlignment: Text.AlignHCenter
                                                   verticalAlignment: Text.AlignVCenter
                                               }

                                               onClicked: {
                                                   if (videoPlayerPage.visibility === Window.FullScreen) {
                                                       videoPlayerPage.visibility = Window.Windowed
                                                   } else {
                                                       videoPlayerPage.visibility = Window.FullScreen
                                                   }
                                               }

                               } //全屏



                           } //下方状态栏

                        }   //ColumnLayout

                    }  //视频控制栏


                }

                //==================================视频区域====================================//


                //==================================评论简介区域=================================//
                Rectangle
                {

                    id:info
                    visible:videoPlayerPage.visibility !== Window.FullScreen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 2/7
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2A2A2A" }
                        GradientStop { position: 1.0; color: "#1D1D1D" }
                    }

                    ColumnLayout
                    {
                        anchors.fill: parent

                        RowLayout
                        {
                            id:widthNum
                            Layout.preferredWidth: parent.width
                            Layout.preferredHeight: parent.height * 0.08
                            spacing: 25

                            Button {
                                id: infoButton
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 35
                                Layout.leftMargin:20
                                font.pixelSize: 18
                                text: "简介"
                                Layout.alignment: Qt.AlignVCenter // 添加垂直居中

                                HoverHandler {
                                         cursorShape: Qt.PointingHandCursor
                                     }

                                contentItem: Text {
                                    text:infoButton.text
                                    font: infoButton.font
                                    color:
                                    {
                                        if(videoPlayerPage.currentView === "info" || infoButton.hovered)
                                            "pink"
                                          else
                                            "#F0F0F0"
                                    }

                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }  //自定义字体格式
                                background: Rectangle {
                                    radius: 5
                                    color:"transparent"
                                    // Rectangle {
                                    //             anchors {
                                    //                 bottom: parent.bottom
                                    //                 horizontalCenter: parent.horizontalCenter
                                    //             }
                                    //             width: parent.width * 0.8
                                    //             height: 3
                                    //             color: "pink"
                                    //             visible: videoPlayerPage.currentView === "info"
                                    //         }

                                }
                                onClicked: {
                                    videoPlayerPage.currentView = "info"
                                    //操作
                                }

                             }

                            Row {
                                spacing: 1  // 按钮和标签之间的间距
                                Layout.alignment: Qt.AlignVCenter

                                Button {
                                    id: commitButton
                                    // width: parent.parent.width * 0.15  // 注意：现在父级是Row，需要调整引用
                                    // height: parent.parent.height * 0.7
                                    Layout.preferredWidth: widthNum.width * 0.15
                                        Layout.preferredHeight: widthNum.height * 0.7
                                    font.pixelSize: 18
                                    text: "评论"

                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    contentItem: Text {
                                        text: commitButton.text
                                        font: commitButton.font
                                        color: {
                                            if(videoPlayerPage.currentView === "commit" || commitButton.hovered)
                                                "pink"
                                            else
                                                "#F0F0F0"
                                        }
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        radius: 5
                                        color: "transparent"
                                    }

                                    onClicked: {
                                        videoPlayerPage.currentView = "commit"
                                    }
                                }

                                Rectangle {
                                    radius: 10
                                    height: commitButton.height * 0.7
                                    width: te.implicitWidth + 20
                                    y: +commitButton.height * 0.1
                                    color: "#3A3A3A"

                                    Text {
                                        id: te
                                        text: realTimeCommitCount
                                        color: "#F0F0F0"
                                        anchors.centerIn: parent
                                    }
                                }
                            }

                            Button {
                                id: aButton
                                Layout.preferredWidth: 35
                                Layout.preferredHeight: 35
                                font.pixelSize: 18
                                Layout.rightMargin: 15
                                text: "*"
                                Layout.alignment: Qt.AlignVCenter // 添加垂直居中

                                HoverHandler {
                                         cursorShape: Qt.PointingHandCursor
                                     }

                                contentItem: Text {
                                    text: aButton.text
                                    font:  aButton.font
                                    color: "#F0F0F0"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }  //自定义字体格式
                                background: Rectangle {
                                    radius: 5
                                    color:  aButton.down ? "#6A6A6A":"#7A7A7A"
                                    opacity: aButton.hovered? 0.5 : 0
                                }
                                onClicked: {
                                    settingsPopup.open()
                                    //操作
                                }

                             }

                            Popup {
                                id: settingsPopup
                                x: aButton.x - width + aButton.width
                                y: aButton.y + aButton.height
                                width: parent.width * 0.4
                                height: contentItem.implicitHeight + padding * 2
                                padding: 5
                                closePolicy: Popup.CloseOnPressOutside

                                background: Rectangle {
                                    color: "#2A2A2A"
                                    radius: 5
                                    border.color: "#4A4A4A"
                                }

                                contentItem: ColumnLayout {
                                    spacing: 5

                                    // 第一个设置按钮
                                    Button {
                                        id:button1
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: titleBar.height * 0.8
                                        text: "稍后观看"
                                        HoverHandler {
                                                 cursorShape: Qt.PointingHandCursor
                                             }
                                        background: Rectangle {
                                            color:
                                            {
                                                if(parent.hovered)
                                                    return "#6A6A6A"
                                                else if(parent.down)
                                                    return "#4A4A4A"
                                                else
                                                    return "transparent"
                                            }
                                            radius: 3
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 10
                                        }

                                        onClicked: {
                                            console.log("设置1被点击")
                                            settingsPopup.close()
                                        }
                                    }

                                    // 第二个设置按钮
                                    Button {
                                        id:button2
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: titleBar.height * 0.8
                                        text:"重新加载"
                                        HoverHandler {
                                                 cursorShape: Qt.PointingHandCursor
                                             }
                                        background: Rectangle {
                                            color:
                                            {
                                                if(parent.hovered)
                                                    return "#6A6A6A"
                                                else if(parent.down)
                                                    return "#4A4A4A"
                                                else
                                                    return "transparent"
                                            }
                                            radius: 3
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 10
                                        }
                                        onClicked: {
                                            console.log("设置2被点击")
                                            settingsPopup.close()
                                        }
                                    }

                                    // 第三个设置按钮
                                    Button {
                                        id:button3
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: titleBar.height * 0.8
                                        text:"稿件举报"
                                        HoverHandler {
                                                 cursorShape: Qt.PointingHandCursor
                                             }
                                        background: Rectangle {
                                            color:
                                            {
                                                if(parent.hovered)
                                                    return "#6A6A6A"
                                                else if(parent.down)
                                                    return "#4A4A4A"
                                                else
                                                    return "transparent"
                                            }

                                            radius: 3
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 10
                                        }
                                        onClicked: {
                                            console.log("设置3被点击")
                                            settingsPopup.close()
                                        }
                                    }
                                }
                            }

                        }

                        // Rectangle {
                        //             id:currentRect
                        //             width: infoButton.width * 0.8
                        //             height: infoButton.height * 0.2
                        //             color: "pink"
                        //             visible: true
                        //             z:500
                        //             x: {
                        //                 if (videoPlayerPage.currentView === "info") {
                        //                     return infoButton.x + (infoButton.width - width) / 2
                        //                 } else {
                        //                     return commitButton.x + (commitButton.width - width) / 2
                        //                 }
                        //             }
                        //             // 添加动画效果
                        //             Behavior on x {
                        //                 NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                        //             }
                        //         }  //简介和评论下标

         // 简介部分===================//========================
                        Item {
                            visible: videoPlayerPage.currentView === "info"
                            Layout.fillHeight: true // 填充可用高度
                            Layout.fillWidth: true  // 填充可用宽度

                    ColumnLayout
                    {
                        anchors.fill: parent

                        RowLayout
                        {
                            Layout.topMargin: 15
                            Layout.fillWidth: true
                            Rectangle
                            {
                                 Layout.leftMargin: 15
                                width:videoPlayerPage.height/16
                                height: width
                                radius: width/2
                                color: "grey"
                            }


                            ColumnLayout
                            {
                                Layout.leftMargin: 10
                                Text {
                                    text: videoData.author
                                    color:"white"
                                }
                            }


                            Item {
                                 Layout.fillWidth: true
                             } //填充


                            // Button {
                            //     id:bButton
                            //     Layout.rightMargin: 20
                            //     Layout.preferredWidth: 80
                            //     Layout.preferredHeight: 35
                            //     font.pixelSize: 18
                            //     font.bold: true

                            //     HoverHandler {
                            //              cursorShape: Qt.PointingHandCursor
                            //          }

                            //     text:
                            //     {
                            //         if(videoPlayerPage.attention)
                            //             return "已关注"
                            //         else
                            //             return "+关注"
                            //     }

                            //     Layout.alignment: Qt.AlignVCenter // 添加垂直居中
                            //     contentItem: Text {
                            //         text: bButton.text
                            //         font:  bButton.font
                            //         color: "white"
                            //         horizontalAlignment: Text.AlignHCenter
                            //         verticalAlignment: Text.AlignVCenter
                            //     }  //自定义字体格式
                            //     background: Rectangle {
                            //         radius: 5
                            //         color:
                            //         {
                            //             if(videoPlayerPage.attention)
                            //                 return "black"
                            //             else
                            //                 return bButton.down ? "#6A6A6A":"#FF5252"
                            //         }

                            //                 Behavior on color {
                            //                     ColorAnimation {
                            //                         duration: 300
                            //                         easing.type: Easing.InOutQuad
                            //                     }
                            //                 }

                            //     }
                            //     onClicked: {
                            //         buttonAnime.start()
                            //         videoPlayerPage.attention = !videoPlayerPage.attention;
                            //         //操作
                            //     }

                            //     SequentialAnimation
                            //     {
                            //         id:buttonAnime
                            //         PropertyAnimation
                            //         {
                            //             target: bButton
                            //             property: "scale"
                            //             to: 1.1
                            //             duration: 300
                            //             easing.type: Easing.OutCubic
                            //         }

                            //         PropertyAnimation
                            //         {
                            //             target: bButton
                            //             property: "scale"
                            //             to:1.0
                            //             duration: 300
                            //             easing.type: Easing.OutBack
                            //         }
                            //     }

                            //  }

                            // 关注按钮部分修改
                            Button {
                                id: bButton
                                Layout.rightMargin: 20
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 35
                                font.pixelSize: 18
                                font.bold: true

                                // 自己看自己的视频时不需要关注按钮
                                visible: !userController || !userController.currentUser
                                         || (userController.currentUser.id || "") !== (getAuthorUserId() || "")

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }

                                text: {
                                    if (!userController || !userController.currentUser || !userController.isLoggedIn) {
                                        return "+关注"
                                    }
                                    // 引用关注列表属性，让按钮在关注/取关后自动刷新
                                    var followingList = userController.followingUsers
                                    // 检查是否已经关注了该视频作者
                                    var isFollowing = false
                                    try {
                                        isFollowing = userController.isFollowing(getAuthorUserId())
                                    } catch (e) {
                                        console.log("检查关注状态失败:", e)
                                    }
                                    return isFollowing ? "已关注" : "+关注"
                                }

                                Layout.alignment: Qt.AlignVCenter
                                contentItem: Text {
                                    text: bButton.text
                                    font: bButton.font
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    radius: 5
                                    color: {
                                        if (bButton.text === "已关注") {
                                            return "#666666"  // 已关注时显示灰色
                                        } else {
                                            return bButton.down ? "#6A6A6A" : "#FF5252"  // 未关注时显示红色
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 300
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }

                                onClicked: {
                                    buttonAnime.start()
                                    handleFollowAction()
                                }

                                SequentialAnimation {
                                    id: buttonAnime
                                    PropertyAnimation {
                                        target: bButton
                                        property: "scale"
                                        to: 1.1
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }
                                    PropertyAnimation {
                                        target: bButton
                                        property: "scale"
                                        to: 1.0
                                        duration: 300
                                        easing.type: Easing.OutBack
                                    }
                                }

                                // 辅助函数：获取作者的用户ID
                                function getAuthorUserId() {
                                    // 服务端关注接口按用户 id 识别；author 只是昵称，
                                    // 用它调关注会返回“用户不存在”
                                    return videoData.userId || ""
                                }

                                // 处理关注/取消关注逻辑
                                function handleFollowAction() {
                                    if (!userController) {
                                        console.log("userController 未初始化")
                                        return
                                    }

                                    if (!userController.isLoggedIn) {
                                        console.log("请先登录")
                                        // 可以在这里触发登录对话框
                                        return
                                    }

                                    var authorUserId = getAuthorUserId()
                                    if (!authorUserId) {
                                        console.log("无法获取作者用户ID，无法关注")
                                        return
                                    }

                                    // 关注/取关是异步接口，成功后刷新关注列表，
                                    // 按钮文字通过 followingUsers 绑定自动更新
                                    if (userController.isFollowing(authorUserId)) {
                                        console.log("取消关注作者:", authorUserId)
                                        userController.unfollowUser(authorUserId)
                                    } else {
                                        console.log("关注作者:", authorUserId)
                                        userController.followUser(authorUserId)
                                    }
                                    userController.loadFollowingUsers()
                                }
                            }

                        }

                        RowLayout
                        {
                            Layout.topMargin: 15
                            width:parent.width

                            ColumnLayout
                            {
                                Layout.leftMargin: 15
                                Text {
                                    text: videoData.title
                                    color:"white"
                                    font.bold: true;
                                    font.pixelSize: 18
                                }

                                RowLayout
                                {
                                    Layout.topMargin: 5
                                    spacing: 20

                                    Text {
                                        text: "播放: " +videoData.viewCount
                                        color: "#C0C0C0"
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: "评论" + realTimeCommitCount
                                        color: "#C0C0C0"
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: videoData.uploadDate
                                        color: "#C0C0C0"
                                        font.pixelSize: 12
                                    }
                                }
                            }


                            Item {
                                 Layout.fillWidth: true
                             } //填充

                            Button {
                                id:cButton
                                Layout.rightMargin: 20
                                Layout.preferredWidth: parent.width * 0.15
                                Layout.preferredHeight: parent.height * 0.5
                                HoverHandler {
                                         cursorShape: Qt.PointingHandCursor
                                     }
                                text:
                                {
                                    if(videoPlayerPage.currentCommit=== "open")
                                    {
                                         return "关闭"
                                    }else
                                    {
                                       return "展开"
                                    }
                                }

                                font.pixelSize: 15
                                Layout.alignment: Qt.AlignVCenter // 添加垂直居中
                                contentItem: Text {
                                    text: cButton.text
                                    font:  cButton.font
                                    color  :cButton.hovered ?  "#FF5252" : "grey"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }  //自定义字体格式
                                background: Rectangle {
                                    color: "transparent"
                                    // opacity: bButton.hovered? 0.5 : 0
                                }
                                onClicked: {
                                    if(videoPlayerPage.currentCommit === "open")
                                    {
                                        videoPlayerPage.currentCommit = "close"
                                    }else
                                    {
                                        videoPlayerPage.currentCommit = "open"
                                    }
                                    //操作
                                }

                             }

                        }

                        // 可展开的内容区域
                            Rectangle {
                                Layout.leftMargin: 15
                                Layout.topMargin: 5
                                id: expandableContent
                                Layout.fillWidth: true
                                Layout.preferredHeight: videoPlayerPage.currentCommit==="open" ? 200 : 0   //200改成具体的简介数量
                                color: "transparent"
                                clip: true

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                                }

                                // 这里添加展开后的内容
                                Text {
                                    text: videoData.description
                                    color: "grey"
                                    }
                        }

                            RowLayout
                            {
                              width: parent.width
                              Layout.topMargin: 20
                              Layout.fillWidth: true
                              ColumnLayout
                              {
                                Layout.leftMargin: 25
                                spacing: 12
                                Layout.alignment: Qt.AlignHCenter

                                Button
                                    {
                                        id: likeButton
                                        Layout.preferredHeight: 44
                                        Layout.preferredWidth: 44

                                        background: Rectangle {
                                            color: likeButton.hovered ? "#2D2D2D" : "transparent"
                                            radius: 22
                                        }

                                        contentItem: Image {
                                            anchors.centerIn: parent
                                            source: videoPlayerPage.likeState
                                                    ? "qrc:/icons/heart.svg"
                                                    : "qrc:/icons/heart_outline.svg"
                                            sourceSize.width: 26
                                            sourceSize.height: 26
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        onClicked: {
                                            if (!userController.isLoggedIn) {
                                                console.log("请先登录")
                                                if (videoPlayerPage.mainWindow && videoPlayerPage.mainWindow.openLoginDialog)
                                                    videoPlayerPage.mainWindow.openLoginDialog()
                                                return
                                            }

                                            console.log("切换点赞状态，视频ID:", videoData.id)
                                            // 计数本地先行更新，状态由服务端信号刷新
                                            videoPlayerPage.likeCountDisplay += videoPlayerPage.likeState ? -1 : 1
                                            userController.toggleLikeVideo(videoData.id)
                                        }
                                    }


                                  Text {
                                      text: videoPlayerPage.likeCountDisplay
                                      color: "white"
                                      horizontalAlignment: Text.AlignHCenter
                                      Layout.alignment: Qt.AlignHCenter
                                  }

                              }
                              Item {
                                   Layout.fillWidth: true
                               } //填充

                              ColumnLayout
                              {
                                  spacing: 12
                                  Button
                                  {
                                      id: coinButton
                                      Layout.preferredHeight: 44
                                      Layout.preferredWidth: 44

                                      background: Rectangle {
                                          color: coinButton.hovered ? "#2D2D2D" : "transparent"
                                          radius: 22
                                      }

                                      contentItem: Image {
                                          anchors.centerIn: parent
                                          source: "qrc:/icons/coin.svg"
                                          sourceSize.width: 26
                                          sourceSize.height: 26
                                          fillMode: Image.PreserveAspectFit
                                          opacity: videoPlayerPage.coinState > 0 ? 1.0 : 0.55
                                      }

                                      onClicked: {
                                          if (!userController.isLoggedIn) {
                                              console.log("请先登录")
                                              if (videoPlayerPage.mainWindow && videoPlayerPage.mainWindow.openLoginDialog)
                                                  videoPlayerPage.mainWindow.openLoginDialog()
                                              return
                                          }

                                          console.log("投币，视频ID:", videoData.id)
                                          videoPlayerPage.coinCountDisplay += 1
                                          userController.addVideoCoin(videoData.id)
                                      }
                                  }
                                  Text {
                                      text: videoPlayerPage.coinCountDisplay
                                      color: "white"
                                      horizontalAlignment: Text.AlignHCenter
                                      Layout.alignment: Qt.AlignHCenter
                                  }
                              }

                              Item {
                                   Layout.fillWidth: true
                               } //填充

                              ColumnLayout
                              {
                                  Layout.rightMargin: 25
                                  spacing: 12
                                  Button {
                                      id: downloadButton
                                      Layout.preferredHeight: 44
                                      Layout.preferredWidth: 44

                                      background: Rectangle {
                                          color: downloadButton.hovered ? "#2D2D2D" : "transparent"
                                          radius: 22
                                      }

                                      contentItem: Image {
                                          anchors.centerIn: parent
                                          source: "qrc:/icons/download.svg"
                                          sourceSize.width: 26
                                          sourceSize.height: 26
                                          fillMode: Image.PreserveAspectFit
                                      }

                                      onClicked: {
                                          if (!videoData.videoUrl) {
                                              videoPlayerPage.showVideoToast("该视频没有可下载的地址")
                                              return
                                          }
                                          downloadManager.startDownload(videoData.videoUrl,
                                                                        videoData.id,
                                                                        videoData.title || "未命名视频")
                                          videoPlayerPage.showVideoToast("已加入下载队列，可在“下载”页查看进度")
                                      }
                                  }
                                  Text {
                                      text: "下载"
                                      color: "#AAAAAA"
                                      horizontalAlignment: Text.AlignHCenter
                                      Layout.alignment: Qt.AlignHCenter
                                      font.pixelSize: 11
                                  }
                              }

                            }

                            Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    Layout.topMargin: 15
                                    Layout.bottomMargin: 10
                                    color: "#333333"
                                }

                            ScrollView
                            {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.topMargin: 1

                                contentWidth: parent.width // 内容宽度与父组件相同
                                contentHeight: videoColumn.height // 内容高度由视频列表决定

                                // 视频列表容器
                                Column {
                                    id: videoColumn
                                    width: parent.width
                                    spacing: 20 // 视频项之间的间距
                                    padding: 10

                                    Repeater {
                                        model: videoManager ? videoManager.videos : []

                                        // 单个视频项
                                        Rectangle {
                                            id:father
                                            width: videoColumn.width - 2 * videoColumn.padding
                                            height: titleBar.height * 1.5
                                            color: "transparent"


                                            layer.enabled: true

                                            // 鼠标悬停效果
                                            property real hoverScale: 1.0
                                            property real borderWidth: 0
                                            property color borderColor: "#333333"
                                            property bool isHovered: false

                                            // 平滑动画
                                            Behavior on hoverScale {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.OutQuad
                                                }
                                            }

                                            // 应用变换
                                            scale: hoverScale

                                            HoverHandler {
                                                cursorShape: Qt.PointingHandCursor

                                                onHoveredChanged: {
                                                    if (hovered) {
                                                        // 鼠标移入：轻微放大，边框变粉色
                                                        father.hoverScale = 1.05
                                                        father.isHovered = true
                                                    } else {
                                                        // 鼠标移出：恢复
                                                        father.hoverScale = 1.0
                                                        father.isHovered = false
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: rightBorder
                                                anchors {
                                                    right: parent.right
                                                    top: parent.top
                                                    bottom: parent.bottom
                                                }
                                                width: father.isHovered ? 2 : 0
                                                color: "#FF6699"

                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: 200
                                                        easing.type: Easing.OutQuad
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 10

                                                Rectangle {
                                                    Layout.preferredWidth: father.width * 0.4
                                                    Layout.preferredHeight: father.height
                                                    radius: 5
                                                    color: "#2A2A2A"

                                                    Image {
                                                        id: coverImage
                                                        anchors.fill: parent
                                                        source: modelData.coverUrl
                                                        z:1
                                                    }

                                                }

                                                // 视频信息
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    spacing: 5

                                                    // 视频标题
                                                    Text {
                                                        id:titleText
                                                        Layout.bottomMargin: 10
                                                        Layout.fillWidth: true
                                                        text: modelData.title
                                                        color: "white"
                                                        font.pixelSize: 16
                                                        wrapMode: Text.Wrap    //单词边界换行
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight  //超出部分右边使用...
                                                    }

                                                    Item {
                                                         Layout.fillHeight: true
                                                     } //填充

                                                    Text {
                                                        text: modelData.author
                                                        color: "#AAAAAA"
                                                        font.pixelSize: 12
                                                    }

                                                    RowLayout
                                                    {
                                                        spacing: 10
                                                        Text {
                                                            text: modelData.viewCount
                                                            color: "#AAAAAA"
                                                            font.pixelSize: 12
                                                        }

                                                        Text {
                                                            text: modelData.commentCount || 0
                                                            color: "#AAAAAA"
                                                            font.pixelSize: 12
                                                        }
                                                    }

                                                }
                                            }

                                            // 点击
                                            TapHandler {
                                                onTapped: {
                                                    console.log("点击视频:", modelData.id, modelData.title, modelData.videoUrl, modelData.viewCount)

                                                    userController.addWatchHistory(modelData.id)

                                                    var videoData_new = videoController.getVideo(modelData.id)

                                                    videoPlayerPage.close()

                                                    mainWindow.openNewVideoRequest(modelData.id, videoData_new, index)

                                                }
                                            }

                                        }
                                    }
                                }
                            }

                        Item {
                             Layout.fillHeight: true
                         } //填充


                        } //Column  简介的父

                    }  //Item

        //简介部分============================//==================================


                        Commit{
                            id:commitComponent
                            visible: videoPlayerPage.currentView === "commit"
                            videoManager: videoPlayerPage.videoManager
                            videoData: videoPlayerPage.videoData
                            mainWindow: videoPlayerPage.mainWindow
                        }  //评论部分


                    }  //Column  父

                }

                //==================================评论简介区域=================================//
            }

        }

    }

}
