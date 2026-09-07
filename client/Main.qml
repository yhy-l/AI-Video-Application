import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
// import QtGraphicalEffects
import "./component"
import "qml/Video_Playback"
import "qml/Login"
import "qml/Send_Videos"
import "qml/Settings"
import "qml/Tools_Left"

FrameLessWindow {
    id: root
    width: 1100
    height: 800

    property string globalAvatarUrl: userController && userController.avatarUrl
                                     ? userController.avatarUrl
                                     : "https://i0.hdslb.com/bfs/face/member/noface.jpg"
    property bool isLoggedIn: userController ? userController.isLoggedIn : false
    property string username: userController && userController.currentUser
                              ? (userController.currentUser.nickname || "") : ""
    property string userAccount: userController && userController.currentUser
                                 ? (userController.currentUser.account || "") : ""
    property string currentLeftMenuItem: ""
    property bool showPersonInfo: false
    property string apiBaseUrl: "http://localhost:3000"       //服务器基网址
    property bool isSearching: false
    property bool showSearchResults: false
    // 搜索结果（普通数组，与首页视频列表同构，
    // 保证视频卡片组件里 modelData 能直接取到条目）
    property var searchResults: []
    property bool coverUrlStatue:false
    property bool isDarkMode: appSettings ? appSettings.darkMode : false
    property alias videoLoad: videoLoaders
    property var aiPet: null   // 置顶桌面宠物窗口引用

    property var currentVideoPlayer:null

    // VideoController
    // {
    //     id:videoController
    // }



    Connections {
        target: userController

        function onVideoLiked(videoId) {
            console.log("点赞视频:", videoId)
            // 更新视频点赞状态
        }

        function onVideoUnliked(videoId) {
            console.log("取消点赞视频:", videoId)
            // 更新视频点赞状态
        }

    }

    // 视频数据模型
    ListModel {
        id: videoModel
    }


    // 加载视频列表
    function loadVideos() {
        console.log("开始加载视频列表...");
        videoController.loadVideos()
    }

    Component.onCompleted: {
        console.log("Main 组件初始化完成，开始加载视频列表")
        videoController.loadVideos()
        // 启动置顶桌面宠物（AI 智能助手）
        var petComp = Qt.createComponent("qml/AI_Pet/PetWindow.qml")
        if (petComp.status === Component.Ready) {
            root.aiPet = petComp.createObject(null)
        } else {
            petComp.statusChanged.connect(function() {
                if (petComp.status === Component.Ready)
                    root.aiPet = petComp.createObject(null)
            })
        }
    }

    // 全局提示 Toast
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12
        height: 40
        width: toastText.implicitWidth + 44
        radius: 20
        color: "#E6000000"
        visible: false
        opacity: 0
        z: 999

        Text {
            id: toastText
            anchors.centerIn: parent
            color: "#FFFFFF"
            font.pixelSize: 13
        }

        NumberAnimation on opacity {
            id: toastFade
            running: false
            duration: 220
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: hideToastTimer
        interval: 2400
        onTriggered: {
            toastFade.from = 1
            toastFade.to = 0
            toastFade.start()
        }
    }

    function showError(message) {
        console.error("错误提示:", message)
        toastText.text = message
        toast.visible = true
        root.raise()
        root.requestActivate()
        toastFade.from = 0
        toastFade.to = 1
        toastFade.start()
        hideToastTimer.restart()
    }

    // 加载指示器
    Rectangle {
        id: loadingIndicator
        anchors.centerIn: parent
        width: 100
        height: 100
        color: "#ccffffff"
        radius: 8
        visible: false
        z: 2

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: true
                width: 40
                height: 40
            }

            Text {
                text: "加载中..."
                font.pixelSize: 14
                color: "#666666"
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // 空状态提示
    Text {
        id: emptyText
        anchors.centerIn: parent
        text: "暂无视频内容\n点击刷新按钮加载视频"
        font.pixelSize: 16
        color: "#999999"
        horizontalAlignment: Text.AlignHCenter
        visible: false
    }

    LoginPage {
            id: loginPage
            visible: false
            onLoginSuccess: function(username, avatarUrl, userAccount) {
                loginPage.close()
            }
        }

    function openLoginDialog() {
        root.raise()
        root.requestActivate()
        loginPage.open()
    }


    // 头像路径处理函数
    function processAvatarUrl(url) {
        if (!url || url === "") { return "https://i0.hdslb.com/bfs/face/member/noface.jpg" }

        console.log("原始头像URL:", url)

        if (url.startsWith("file:///")) {
            console.log("已经是file:///格式，直接使用")
            return url
        }

        if (url.startsWith("http://") || url.startsWith("https://")) {
            console.log("网络URL，直接使用")
            return url
        }

        var processedUrl = "file:///" + url
        console.log("本地路径处理后URL:", processedUrl)
        return processedUrl
    }

    // 当全局头像URL改变时，强制更新侧边栏头像


    // 左侧边栏
    Rectangle {
        id: leftSideBar
        width: 212
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        color: root.isDarkMode ? "#202124" : "#FFFFFF"
        z: 100

        // 右侧分隔线
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: root.isDarkMode ? "#3c4043" : "#E3E5E7"
        }

        ColumnLayout {
            spacing: 4
            anchors.fill: parent

            // 用户信息区域
            Rectangle {
                id: userInfoArea
                Layout.fillWidth: true
                Layout.preferredHeight: 86
                Layout.topMargin: 12
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                radius: 10
                color: userHover.hovered ? "#F6F7F8" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: 46
                        height: 46
                        radius: 23
                        color: "#F1F2F3"
                        border.color: "#E3E5E7"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: userController.avatarUrl
                                    ? userController.avatarUrl + "?t=" + userController.avatarTimestamp
                                    : "https://i0.hdslb.com/bfs/face/member/noface.jpg"
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            id: usernameText
                            text: root.isLoggedIn ? root.username : "点击登录"
                            font.pixelSize: 14
                            font.bold: true
                            color: root.isLoggedIn ? "#18191C" : "#FB7299"
                            elide: Text.ElideRight
                            width: 112
                        }

                        Text {
                            text: root.isLoggedIn ? ("账号: " + root.userAccount) : "登录后享受更多功能"
                            font.pixelSize: 12
                            color: "#9499A0"
                            elide: Text.ElideRight
                            width: 112
                        }
                    }
                }

                HoverHandler {
                    id: userHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (!root.isLoggedIn) {
                            console.log("用户未登录，打开登录对话框")
                            root.openLoginDialog()
                        } else {
                            console.log("点击用户信息")
                            root.currentLeftMenuItem = "用户信息"
                            root.showPersonInfo = true
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // 分组标题
            Text {
                text: "常用功能"
                font.pixelSize: 12
                color: "#9499A0"
                Layout.leftMargin: 24
                Layout.topMargin: 12
                Layout.bottomMargin: 4
            }

            Repeater {
                model: [
                    {text: "首页", icon: "🏠"},
                    {text: "我的", icon: "👤"}
                ]

                delegate: Rectangle {
                    id: menuItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    radius: 8
                    color: getBackgroundColor()

                    property bool isActive: root.currentLeftMenuItem === modelData.text

                    function getBackgroundColor() {
                        if (isActive) return "#FFF0F3"
                        if (menuHover.hovered) return "#F6F7F8"
                        return "transparent"
                    }

                    // 选中指示条
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 18
                        radius: 1.5
                        color: "#FB7299"
                        visible: isActive
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: modelData.icon
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.text
                            color: isActive ? "#FB7299" : "#18191C"
                            font.pixelSize: 14
                            font.bold: isActive
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler {
                        id: menuHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            console.log("点击菜单项:", modelData.text)
                            root.currentLeftMenuItem = modelData.text
                            if (modelData.text === "我的") {
                                if (!root.isLoggedIn) {
                                    console.log("用户未登录，打开登录对话框")
                                    root.openLoginDialog()
                                } else {
                                    root.showPersonInfo = true
                                }
                            }
                            if (modelData.text === "首页") {
                                root.showPersonInfo = false
                                root.currentLeftMenuItem = ""
                            }
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }
            }

            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                color: "#F1F2F3"
            }

            Text {
                text: "更多功能"
                font.pixelSize: 12
                color: "#9499A0"
                Layout.leftMargin: 24
                Layout.bottomMargin: 4
            }

            Repeater {
                model: [
                    {text: "上传视频", icon: "📹"},
                    {text: "下载", icon: "📥"},
                    {text: "上传记录", icon: "🗂️"},
                    {text: "消息", icon: "✉️"},
                    {text: "夜间模式", icon: "🌙"},
                    {text: "设置", icon: "⚙️"}
                ]

                delegate: Rectangle {
                    id: bottomMenuItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    radius: 8
                    color: getBackgroundColor()

                    property bool isActive: root.currentLeftMenuItem === modelData.text

                    function getBackgroundColor() {
                        if (isActive) return "#FFF0F3"
                        if (bottomMenuHover.hovered) return "#F6F7F8"
                        return "transparent"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 18
                        radius: 1.5
                        color: "#FB7299"
                        visible: isActive
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: modelData.icon
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.text
                            color: isActive ? "#FB7299" : "#18191C"
                            font.pixelSize: 14
                            font.bold: isActive
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler {
                        id: bottomMenuHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            if (modelData.text === "夜间模式") appSettings.darkMode = !appSettings.darkMode
                            if (modelData.text === "上传视频") videoUploadPopup.open()
                            if (modelData.text === "下载") {
                                root.showPersonInfo = false
                                root.currentLeftMenuItem = "下载"
                            }
                            if (modelData.text === "上传记录") uploadRecordsPopup.open()
                            if (modelData.text === "消息") messagePopup.open()
                            if (modelData.text === "设置") {
                                root.showPersonInfo = false
                                root.currentLeftMenuItem = "设置"
                                settingsLoader.active = true
                            }
                            root.showPersonInfo = false
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
            }

            // 返回按钮（置于侧边栏底部）
            Button {
                id: backButton
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 12
                flat: true
                padding: 0
                background: Rectangle {
                    color: backButton.hovered ? "#F6F7F8" : "transparent"
                    radius: 8
                }
                contentItem: Text {
                    text: "← 返回"
                    font.pixelSize: 13
                    color: backButton.hovered ? "#FB7299" : "#61666D"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    console.log("点击返回按钮")
                    root.showPersonInfo = false
                    root.currentLeftMenuItem = ""
                }
            }
        }
    }

    // 视频上传弹窗
    FrameLessWindow {
       id: videoUploadPopup
       width: 900
       height: 800
       visible: false
       flags: Qt.Dialog
       title: "视频上传页面"

       // 加载视频上传页面
       Loader {
           id: videoLoader
           anchors.fill: parent
           source: "qml/Send_Videos/VideoLode.qml"

           onLoaded: {
               // 连接关闭信号
               if (item && item.closeRequested) {
                   item.closeRequested.connect(function() {
                       videoUploadPopup.close()
                   })
               }
               if (item)
                   item.mainWindow = root
           }
       }

       // 打开时居中显示
       function open() {
           videoUploadPopup.show()
           videoUploadPopup.x = (Screen.width - width) / 2
           videoUploadPopup.y = (Screen.height - height) / 2
           // 上传页为每次打开重置"临时状态提示"（上传记录在侧栏独立页查看）
           if (videoLoader.item && videoLoader.item.resetSessionStatus)
               videoLoader.item.resetSessionStatus()
       }
    }

    // 上传记录弹窗（转码进度，本次运行）
    FrameLessWindow {
        id: uploadRecordsPopup
        width: 940
        height: 760
        visible: false
        flags: Qt.Dialog
        title: "上传记录"

        Loader {
            id: uploadRecordsLoader
            anchors.fill: parent
            source: "qml/Tools_Left/UploadRecordsPage.qml"

            onLoaded: {
                if (item && item.closeRequested) {
                    item.closeRequested.connect(function() {
                        uploadRecordsPopup.close()
                    })
                }
            }
        }

        function open() {
            uploadRecordsPopup.show()
            uploadRecordsPopup.x = (Screen.width - width) / 2
            uploadRecordsPopup.y = (Screen.height - height) / 2
        }
    }

    // 消息弹窗
    FrameLessWindow {
        id: messagePopup
        width: 1200
        height: 800
        visible: false
        flags: Qt.Dialog
        title: "消息中心"

        // 加载消息页面
        Loader {
            id: messageLoader
            anchors.fill: parent
            source: "qml/Tools_Left/Message_Page.qml"

            onLoaded: {
                // 连接关闭信号
                if (item && item.closeRequested) {
                    item.closeRequested.connect(function() {
                        messagePopup.close()
                    })
                }
            }
        }

        // 打开时居中显示
        function open() {
            messagePopup.show()
            messagePopup.x = (Screen.width - width) / 2
            messagePopup.y = (Screen.height - height) / 2
        }
    }

    // 顶部区域
    Rectangle {
        id: topBar
        width: parent.width - leftSideBar.width
        height: 64
        color: root.isDarkMode ? "#202124" : "#FFFFFF"

        anchors {
            top: parent.top
            left: leftSideBar.right
        }

        // 底部分隔线
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.isDarkMode ? "#3c4043" : "#E3E5E7"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 8
            spacing: 10

            // bilibili Logo
            Text {
                id: bili_icon
                text: "bilibili"
                color: "#FB7299"
                font.pixelSize: 22
                font.bold: true
                font.letterSpacing: 1
            }

            Item {
                Layout.preferredWidth: 6
            }

            // 顶部导航（静态标题）
            Text {
                id: funcRegion
                text: "视频大厅"
                font.pixelSize: 15
                font.bold: true
                color: "#18191C"
                Layout.fillWidth: true
                opacity: (!root.showPersonInfo && root.currentLeftMenuItem !== "设置") ? 1.0 : 0.0
                enabled: opacity > 0.5
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // 搜索框
            Rectangle {
                Layout.preferredWidth: 280
                Layout.preferredHeight: 38
                radius: 19
                color: search.focus ? "#FFFFFF" : "#F1F2F3"
                border.color: search.focus ? "#FB7299" : "#E3E5E7"
                border.width: 1

                Text {
                    text: "🔍"
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 14
                    color: "#9499A0"
                }

                TextField {
                    id: search
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.right: parent.right
                    anchors.rightMargin: 34
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    verticalAlignment: Text.AlignVCenter
                    background: Item {}
                    placeholderText: "搜索视频..."
                    placeholderTextColor: "#9499A0"
                    font.pixelSize: 13
                    color: "#18191C"

                    // 添加防抖定时器
                    property var searchTimer: null

                    onTextChanged: {
                        // 清除之前的定时器
                        if (searchTimer) {
                            searchTimer.stop();
                        }

                        if (text.length > 0) {
                            // 延迟500ms执行搜索
                            searchTimer = Qt.createQmlObject("import QtQml 2.15; Timer { interval: 500; onTriggered: searchVideos(search.text) }", search);
                            searchTimer.start();
                        } else {
                            // 如果搜索框为空，显示正常视频列表
                            showSearchResults = false;
                            searchResults = [];
                        }
                    }
                }

                Button {
                    id: clearButton
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    padding: 0
                    background: Rectangle {
                        color: clearButton.hovered ? "#E3E5E7" : "transparent"
                        radius: 11
                    }
                    contentItem: Text {
                        text: "×"
                        font.pixelSize: 15
                        color: "#61666D"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        search.text = ""
                        showSearchResults = false;
                        searchResults = [];
                    }
                    opacity: search.text.length > 0 ? 1 : 0
                }
            }

            // 刷新按钮
            Button {
                id: refreshButton
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                padding: 0
                background: Rectangle {
                    color: refreshButton.hovered ? "#F1F2F3" : "transparent"
                    radius: 17
                }
                contentItem: Text {
                    text: "⟳"
                    font.pixelSize: 18
                    color: "#61666D"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    console.log("手动刷新视频列表");
                    videoController.loadVideos()
                }
            }

            // 窗口控制
            RowLayout {
                id: controls
                spacing: 2
                visible: true

                Button {
                    id: minimizeButton
                    flat: true
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    background: Rectangle {
                        color: minimizeButton.hovered ? "#F1F2F3" : "transparent"
                        radius: 6
                    }
                    contentItem: Text {
                        text: "—"
                        font.pixelSize: 16
                        color: "#18191C"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.showMinimized()
                }

                Button {
                    id: maximizeButton
                    flat: true
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    background: Rectangle {
                        color: maximizeButton.hovered ? "#F1F2F3" : "transparent"
                        radius: 6
                    }
                    contentItem: Text {
                        text: root.visibility === Window.Maximized ? "❐" : "□"
                        font.pixelSize: 15
                        color: "#18191C"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (root.visibility === Window.Maximized)
                            root.showNormal()
                        else
                            root.showMaximized()
                    }
                }

                Button {
                    id: closeButton
                    flat: true
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    background: Rectangle {
                        color: closeButton.hovered ? "#FB7299" : "transparent"
                        radius: 6
                    }
                    contentItem: Text {
                        text: "×"
                        font.pixelSize: 18
                        color: closeButton.hovered ? "#FFFFFF" : "#18191C"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: Qt.quit()
                }
            }
        }
    }

    // 内容区域
    Item {
        id: contentContainer
        anchors {
            top: topBar.bottom
            left: leftSideBar.right
            right: parent.right
            bottom: parent.bottom
        }

        property var videoManager: videoController ? videoController : null

        // 背景
        Rectangle {
            anchors.fill: parent
            color: root.isDarkMode ? "#17181a" : "#f6f7f8"
            z: -1
        }

        // 正常视频列表
        ScrollView {
            id: contentScrollView
            anchors.fill: parent
            visible: !root.showSearchResults && !root.showPersonInfo
                     && root.currentLeftMenuItem !== "设置" && root.currentLeftMenuItem !== "下载"
            contentWidth: availableWidth
            clip: true
            padding: 20

            ColumnLayout {
                width: root.width - leftSideBar.width - 15
                spacing: 18

                // 内容标题
                RowLayout {
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.topMargin: 4
                    spacing: 10

                    Text {
                        text: "为你推荐"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#18191C"
                    }

                    Text {
                        text: videoGrid.count > 0 ? videoGrid.count + " 个视频" : ""
                        font.pixelSize: 12
                        color: "#9499A0"
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 3
                    }
                }

                GridView {
                    id: videoGrid
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20

                    property int columns: Math.max(2, Math.floor(width / 240))
                    Layout.preferredHeight: Math.max(280, Math.ceil(count / columns) * cellHeight)
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 210
                    model: contentContainer.videoManager ? contentContainer.videoManager.videos : []
                    delegate: videoDelegate // 使用下面的组件
                }

                // 加载更多按钮
                Button {
                    id: loadMoreButton
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    Layout.bottomMargin: 16
                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 40
                    flat: true
                    background: Rectangle {
                        color: loadMoreButton.hovered ? "#FFF0F3" : "#FFFFFF"
                        radius: 20
                        border.color: loadMoreButton.hovered ? "#FB7299" : "#E3E5E7"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "加载更多"
                        font.pixelSize: 14
                        color: "#FB7299"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        console.log("加载更多视频")
                        videoController.loadMoreVideos(15)
                    }
                }
            }
        }

        // 搜索结果视图
        ScrollView {
            id: searchScrollView
            anchors.fill: parent
            visible: root.showSearchResults && !root.showPersonInfo
                     && root.currentLeftMenuItem !== "设置" && root.currentLeftMenuItem !== "下载"
            contentWidth: availableWidth
            clip: true
            padding: 20

            ColumnLayout {
                width: root.width - leftSideBar.width - 15
                spacing: 20

                // 搜索标题
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "搜索结果"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#18191C"
                    }

                    Text {
                        text: "(" + searchResults.length + "个视频)"
                        font.pixelSize: 14
                        color: "#9499A0"
                    }

                    Button {
                        text: "返回首页"
                        font.pixelSize: 12
                        flat: true
                        padding: 8
                        background: Rectangle {
                            color: parent.hovered ? "#F6F7F8" : "transparent"
                            radius: 6
                        }
                        contentItem: Text {
                            text: "返回首页"
                            font.pixelSize: 12
                            color: parent.hovered ? "#FB7299" : "#61666D"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            showSearchResults = false;
                            search.text = "";
                            searchResults = [];
                        }
                    }
                }

                // 搜索结果列表
                GridView {
                    id: searchResultGrid
                    Layout.fillWidth: true
                    property int columns: Math.max(2, Math.floor(width / 240))
                    Layout.preferredHeight: Math.max(280, Math.ceil(searchResults.length / columns) * cellHeight)
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 210
                    clip: true
                    model: searchResults

                    delegate: videoDelegate // 复用视频组件

                    // 空状态
                    Loader {
                        anchors.centerIn: parent
                        active: searchResults.length === 0 && !root.isSearching
                        sourceComponent: emptySearchComponent
                    }
                }
            }
        }

        // 搜索加载状态
        Rectangle {
            anchors.centerIn: searchScrollView
            width: 220
            height: 56
            color: "#E6FFFFFF"
            radius: 28
            border.color: "#E3E5E7"
            border.width: 1
            visible: root.isSearching
            z: 10

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                BusyIndicator {
                    running: true
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }

                Text {
                    text: "搜索中..."
                    font.pixelSize: 13
                    color: "#61666D"
                }
            }
        }

        Loader {
            id: videoLoaders
            // 初始状态为空，不加载任何组件
            sourceComponent: undefined

            // 异步加载
            asynchronous: true

            // 组件加载完成后的处理
            onLoaded: {
                if (item) {
                    console.log("视频播放器加载完成")
                    // 显示视频播放窗口
                    item.show()

                    // 连接关闭信号，当播放器关闭时清理Loader
                    item.closing.connect(function() {
                        console.log("视频播放器关闭，清理资源")
                        videoLoaders.sourceComponent = undefined
                    })
                }
            }

            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("加载视频播放器失败:", sourceComponent.errorString())
                }
            }
        }

        Loader {
            id: personInfoLoader
            anchors.fill: parent
            visible: root.showPersonInfo && root.currentLeftMenuItem !== "设置"
            source: root.showPersonInfo ? "qml/Tools_Left/PersonInfo.qml" : ""
            active: root.showPersonInfo

            onLoaded: {
                console.log("个人信息界面加载完成")
                // 退出登录后关闭个人中心，回到首页登录入口
                if (personInfoLoader.item && personInfoLoader.item.logoutRequested) {
                    personInfoLoader.item.logoutRequested.connect(function() {
                        root.showPersonInfo = false
                        root.currentLeftMenuItem = ""
                    })
                }
            }
        }

        Loader {
            id: settingsLoader
            anchors.fill: parent
            visible: root.currentLeftMenuItem === "设置"
            source: "qml/Settings/SettingsPage.qml"
            // active: false
            active: root.currentLeftMenuItem === "设置"
        }

        Loader {
            id: downloadPageLoader
            anchors.fill: parent
            visible: root.currentLeftMenuItem === "下载"
            source: "qml/Tools_Left/DownloadPage.qml"
            active: root.currentLeftMenuItem === "下载"
        }
    }
    // 修改后的搜索函数
    function searchVideos(keyword) {
        console.log("🔍 开始搜索关键词:", keyword);
        isSearching = true;
        showSearchResults = true;
        searchResults = [];
        videoController.searchVideos(keyword);
    }

    Connections {
        target: videoController
        function onErrorOccurred(message) {
            showError(message)
        }
    }

    Connections {
        target: clientHandler
        function onNewMessage(message) {
            showError("新消息: " + message)
        }
    }

    Connections {
        target: userController
        function onErrorOccurred(message) {
            showError(message)
        }
    }

    Connections {
        target: videoController
        function onSearchFinished(results) {
            isSearching = false;
            searchResults = results.slice();
        }
    }

    // 可复用的视频组件
    Component {
        id: videoDelegate

        Rectangle {
            id: videoCard
            width: GridView.view.cellWidth - 10
            height: GridView.view.cellHeight - 10
            color: "#FFFFFF"
            radius: 10

            property bool hoveredCard: false

            // 封面区域
            Rectangle {
                id: coverArea
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent.height - 68
                radius: 8
                color: "#F1F2F3"
                clip: true

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: modelData.coverUrl ? modelData.coverUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                // 加载中
                BusyIndicator {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    running: coverImage.status === Image.Loading
                    visible: coverImage.status === Image.Loading
                }

                // 无封面 / 加载失败占位
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: coverImage.status === Image.Error || !modelData.coverUrl

                    Text {
                        text: "🎬"
                        font.pixelSize: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "暂无封面"
                        font.pixelSize: 11
                        color: "#9499A0"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // 悬停遮罩 + 播放按钮
                Rectangle {
                    anchors.fill: parent
                    color: "#66000000"
                    opacity: videoCard.hoveredCard ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 42
                        height: 42
                        radius: 21
                        color: "#E6FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                        }
                    }
                }
            }

            // 文字信息
            Column {
                anchors {
                    top: coverArea.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 8
                }
                spacing: 4

                Text {
                    width: parent.width
                    text: modelData.title || "无标题"
                    font.pixelSize: 14
                    color: "#18191C"
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    lineHeight: 1.25
                }

                RowLayout {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: modelData.author || ""
                        font.pixelSize: 12
                        color: "#9499A0"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "·"
                        font.pixelSize: 12
                        color: "#C9CCD0"
                    }

                    Text {
                        text: modelData.formattedViewCount
                              ? modelData.formattedViewCount + "播放"
                              : (modelData.viewCount !== undefined ? modelData.viewCount + "播放" : "")
                        font.pixelSize: 12
                        color: "#9499A0"
                    }
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: videoCard.hoveredCard = hovered
            }

            TapHandler {
                onTapped: {
                    console.log("点击视频:", modelData.id, modelData.title, modelData.videoUrl, modelData.viewCount)

                    userController.addWatchHistory(modelData.id)

                    var videoData = videoController.getVideo(modelData.id)
                    // 搜索结果可能不在已加载的首页列表中，此时直接用点击的条目本身
                    if (!videoData || !videoData.id)
                        videoData = modelData

                    openVideo(modelData.id, videoData, index)
                }
            }
        }
    }

    // 空搜索结果组件
    Component {
        id: emptySearchComponent

        Column {
            spacing: 20
            anchors.centerIn: parent

            Text {
                text: "🔍"
                font.pixelSize: 48
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "没有找到相关视频"
                font.pixelSize: 16
                color: "#666666"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "试试其他关键词"
                font.pixelSize: 14
                color: "#999999"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    function openVideo(videoId, videoData, index)
    {

        if (root.currentVideoPlayer) {
            console.log("清理已有视频播放器")
            root.currentVideoPlayer.destroy()
            root.currentVideoPlayer = null
        }

        var component = Qt.createComponent("qml/Video_Playback/Video.qml")
        if(component.status === Component.Ready)
        {
            var videoModel = component.createObject(null,
                                                    {
                                                        videoId: videoId,
                                                        videoData: videoData,
                                                        videoManager: videoController,
                                                        index: index,
                                                        mainWindow:root,
                                                    }
                                                        )
            root.currentVideoPlayer = videoModel
        }

    }

    signal openNewVideoRequest(string videoId, var videoData, int index)

    onOpenNewVideoRequest:
    {
        openVideo(videoId,videoData,index)
    }
}
