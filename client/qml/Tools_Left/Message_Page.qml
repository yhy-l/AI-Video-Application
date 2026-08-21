import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: messageWindow
    width: 1200
    height: 800

    property string activeChatTarget: ""
    property bool connected: clientHandler ?
                               clientHandler.connected : false
    property bool connecting: clientHandler ?
                                clientHandler.connecting : false
    // 新增：关注的用户列表
    property var followingUsers: []
    property var filteredContactList: []  // 过滤后的联系人列表
    property bool filterInitialized: false

    signal closeRequested()

    // 自动连接
    Component.onCompleted: {
        if (clientHandler) {
            // 不再生成随机用户名，等待用户登录后设置
            if (userController && userController.isLoggedIn) {
                setChatUserName()
            }
            // 聊天模块暂未正式上线，不自动“连接”，减少启动期噪音；
            // 需要时可通过消息页的连接按钮手动启用
            // autoConnectToServer()
            loadFollowingUsers()  // 加载关注的用户
        } else {
            console.error("msgHandler is not available")
        }
    }

    // 新增：设置聊天用户名
    function setChatUserName() {
        if (userController && userController.isLoggedIn) {
            var currentUser = userController.currentUser
            var nickname = currentUser.nickname || currentUser.account || "用户"
            console.log("设置聊天用户名:", nickname)
            clientHandler.setName(nickname)
        }
    }

    // 自动连接到服务器
    function autoConnectToServer() {
        var serverAddress = "127.0.0.1" // 默认服务器地址（本地）
        var serverPort = 8080

        console.log("尝试自动连接到服务器:", serverAddress + ":" + serverPort)
        clientHandler.connectToServer(serverAddress, serverPort)
    }

    // 新增：加载关注的用户
    function loadFollowingUsers() {
        if (userController && userController.isLoggedIn) {
            console.log("开始加载关注用户...")
            userController.loadFollowingUsers()
        }
    }

    // 新增：过滤联系人列表，只显示关注的用户
    function updateFilteredContactList() {
        var allUsers = clientHandler.clientList
        var filtered = []

        console.log("=== 更新过滤联系人列表 ===")
        console.log("当前用户是否登录:", userController && userController.isLoggedIn)
        console.log("所有在线用户数量:", allUsers ? allUsers.length : 0)
        console.log("所有在线用户:", JSON.stringify(allUsers))
        console.log("关注用户数量:", followingUsers ? followingUsers.length : 0)

        if (!allUsers || allUsers.length === 0) {
            console.log("没有在线用户")
            filteredContactList = []
            filterInitialized = true
            return
        }

        if (!followingUsers || followingUsers.length === 0) {
            console.log("没有关注任何用户")
            filteredContactList = []
            filterInitialized = true
            return
        }

        // 获取当前用户的昵称，用于过滤掉自己
        var currentUserNickname = ""
        if (userController && userController.isLoggedIn) {
            var currentUser = userController.currentUser
            currentUserNickname = currentUser.nickname || currentUser.account || ""
        }

        // 将关注用户列表转换为昵称数组
        var followingNicknames = []
        for (var i = 0; i < followingUsers.length; i++) {
            var user = followingUsers[i]
            if (user && user.nickname && user.nickname !== currentUserNickname) {
                followingNicknames.push(user.nickname)
            }
        }

        console.log("关注的用户昵称列表（排除自己）:", JSON.stringify(followingNicknames))

        // 过滤：只显示关注的且在线的用户
        for (var j = 0; j < allUsers.length; j++) {
            var userName = allUsers[j]
            // 过滤掉自己
            if (userName === currentUserNickname) {
                console.log("跳过自己:", userName)
                continue
            }

            console.log("检查用户 '" + userName + "':",
                       "是否在关注列表中:", followingNicknames.indexOf(userName) !== -1)
            if (followingNicknames.indexOf(userName) !== -1) {
                filtered.push(userName)
                console.log("✓ 添加用户到过滤列表:", userName)
            }
        }

        console.log("过滤后的联系人列表:", JSON.stringify(filtered))
        console.log("过滤后的联系人数量:", filtered.length)

        // 使用赋值而不是直接修改，确保QML能检测到变化
        filteredContactList = filtered.slice()  // 创建新数组
        filterInitialized = true
    }

    // 监听关注列表变化
    Connections {
        target: userController
        enabled: userController

        function onFollowingChanged() {
            console.log("关注列表发生变化")
            followingUsers = userController.followingUsers
            updateFilteredContactList()
        }

        function onLoginStatusChanged() {
            if (userController.isLoggedIn) {
                console.log("用户登录状态变化: 已登录")
                setChatUserName()  // 设置聊天用户名
                loadFollowingUsers()
            } else {
                console.log("用户登录状态变化: 未登录")
                followingUsers = []
                filteredContactList = []
            }
        }

        function onLoginSuccess(userId) {
            console.log("用户登录成功:", userId)
            setChatUserName()  // 设置聊天用户名
            loadFollowingUsers()
        }
    }

    // 监听在线用户列表变化
    Connections {
        target: clientHandler

        function onClientListChanged() {
            console.log("在线用户列表发生变化")
            updateFilteredContactList()
        }

        function onConnected() {
            console.log("已连接到聊天服务器")
            // 连接成功后设置用户名
            if (userController && userController.isLoggedIn) {
                setChatUserName()
            }
        }
    }

    // ... 中间的大量布局代码保持不变 ...

    // // 联系人列表部分需要修改
    // ListView {
    //     id: contactListView
    //     Layout.fillWidth: true
    //     Layout.fillHeight: true
    //     // 修改这里：使用 filteredContactList 而不是 clientHandler.clientList
    //     model: filteredContactList
    //     clip: true

    //     delegate: Rectangle {
    //         width: contactListView.width
    //         height: 70
    //         color: contactListView.currentIndex === index ? "#e3f2fd" :
    //                (modelData === rightContent.activeChatTarget ? "#e8f5e9" : "transparent")
    //         border.color: "#f0f0f0"
    //         border.width: 1

    //         RowLayout {
    //             anchors.fill: parent
    //             anchors.margins: 10
    //             spacing: 10

    //             // 用户头像
    //             Rectangle {
    //                 Layout.preferredWidth: 40
    //                 Layout.preferredHeight: 40
    //                 radius: 20
    //                 color: "#" + Math.floor(Math.random()*16777215).toString(16)

    //                 Text {
    //                     anchors.centerIn: parent
    //                     text: modelData ? modelData.charAt(0) : "?"
    //                     font.pixelSize: 16
    //                     color: "white"
    //                     font.bold: true
    //                 }
    //             }

    //             // 用户信息
    //             ColumnLayout {
    //                 Layout.fillWidth: true
    //                 Layout.fillHeight: true
    //                 spacing: 4

    //                 Text {
    //                     text: modelData
    //                     font.bold: true
    //                     font.pixelSize: 14
    //                     color: "#333333"
    //                     Layout.fillWidth: true
    //                     elide: Text.ElideRight
    //                 }

    //                 Text {
    //                     text: "已关注 · 在线"
    //                     font.pixelSize: 12
    //                     color: "#2ecc71"
    //                 }
    //             }
    //         }

    //         MouseArea {
    //             anchors.fill: parent
    //             onClicked: {
    //                 contactListView.currentIndex = index
    //                 rightContent.activeChatTarget = modelData
    //                 clientHandler.setActiveChat(modelData)
    //             }
    //         }
    //     }

    //     // 空白状态提示
    //     Rectangle {
    //         visible: contactListView.count === 0
    //         anchors.centerIn: parent
    //         width: 300
    //         height: 120
    //         color: "transparent"

    //         ColumnLayout {
    //             anchors.centerIn: parent
    //             spacing: 10

    //             Text {
    //                 text: userController && userController.isLoggedIn ?
    //                       "暂无关注的在线用户" : "请先登录"
    //                 font.pixelSize: 16
    //                 color: "#999999"
    //                 Layout.alignment: Qt.AlignHCenter
    //                 horizontalAlignment: Text.AlignHCenter
    //             }

    //             Text {
    //                 text: {
    //                     if (!userController || !userController.isLoggedIn) {
    //                         return "登录后查看关注的好友"
    //                     } else if (followingUsers.length === 0) {
    //                         return "您还没有关注任何用户"
    //                     } else {
    //                         return "您关注的用户当前不在线"
    //                     }
    //                 }
    //                 font.pixelSize: 12
    //                 color: "#cccccc"
    //                 Layout.alignment: Qt.AlignHCenter
    //                 horizontalAlignment: Text.AlignHCenter
    //                 wrapMode: Text.Wrap
    //             }

    //             // 添加登录按钮（如果未登录）
    //             Button {
    //                 visible: !userController || !userController.isLoggedIn
    //                 text: "去登录"
    //                 Layout.alignment: Qt.AlignHCenter
    //                 onClicked: {
    //                     // 这里需要触发主窗口的登录功能
    //                     console.log("跳转到登录页面")
    //                     // 可以添加打开登录对话框的逻辑
    //                 }
    //             }
    //         }
    //     }
    // }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左侧菜单
        ColumnLayout {
            Layout.preferredWidth: 100
            Layout.fillHeight: true
            spacing: 0

            // 标题
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#f8f9fa"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    spacing: 8

                    Text { text: "✈️"; font.pixelSize: 20 }
                    Text {
                        text: "消息中心"
                        font.bold: true
                        font.pixelSize: 16
                    }
                }
            }

            // 消息列表
            ListView {
                id: leftMenu
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: ListModel {
                    ListElement { name: "我的消息" }
                    ListElement { name: "回复我的" }
                    ListElement { name: "@我的" }
                    ListElement { name: "收到的赞" }
                    ListElement { name: "系统通知" }
                    ListElement { name: "separator" }
                    ListElement { name: "消息设置" }
                }
                currentIndex: 0
                delegate: Item {
                    width: ListView.view.width
                    height: model.name === "separator" ? 20 : 50

                    Rectangle {
                        visible: model.name === "separator"
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: "#e0e0e0"
                        }
                    }

                    Rectangle {
                        visible: model.name !== "separator"
                        width: parent.width
                        height: 50
                        color: leftMenu.currentIndex === index ? "#e3f2fd" : "transparent"

                        Text {
                            text: model.name
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                            font.pixelSize: 14
                            color: leftMenu.currentIndex === index ? "#1976d2" : "black"
                        }

                        Button{
                            anchors.fill: parent
                            background: Rectangle{ color:"transparent" }

                            onClicked: {
                                leftMenu.currentIndex = index
                                if (model.name === "我的消息") rightContent.visible=true
                                    else rightContent.visible=false
                                if (model.name==="回复我的")  replyContent.visible=true
                                    else replyContent.visible=false
                                if (model.name==="@我的")  atMeContent.visible=true
                                    else atMeContent.visible=false
                                if (model.name==="收到的赞")  likesContent.visible=true
                                    else likesContent.visible=false
                                if (model.name==="系统通知")  systemNotificationContent.visible=true
                                    else systemNotificationContent.visible=false
                                if (model.name==="消息设置")  messageSettingsContent.visible=true
                                    else messageSettingsContent.visible=false
                            }
                        }
                    }
                }
            }
            // === 底部返回按钮 ===
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#f8f9fa"
                border.color: "#e0e0e0"
                border.width: 1

                Button {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: 40
                    text: "← 返回"
                    background: Rectangle {
                        color: parent.down ? "#e0e0e0" : "#ffffff"
                        border.color: "#d0d0d0"
                        border.width: 1
                        radius: 6
                    }

                    onClicked: {
                        console.log("返回按钮被点击")
                        //messageWindow.close()
                        onClicked: {
                            closeRequested() // 发出关闭信号
                        }
                    }
                }
            }
        }

        // 右侧内容区域 - 集成聊天功能
                Rectangle {
                    id: rightContent
                    Layout.preferredWidth: 1000
                    Layout.fillHeight: true
                    visible: true
                    color: "#ffffff"

                    property string activeChatTarget: ""
                    property bool connected:  clientHandler.connected
                    property bool connecting:  clientHandler.connecting

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // 顶部状态栏
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            color: "#f5f5f5"
                            border.color: "#e0e0e0"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                spacing: 15
                                anchors.margins: 10

                                // 连接状态指示器
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 30
                                    radius: 15
                                    color: {
                                        if (rightContent.connecting) return "#f39c12"
                                        else if (rightContent.connected) return "#2ecc71"
                                        else return "#e74c3c"
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: {
                                                if (rightContent.connecting) return "🔄"
                                                else if (rightContent.connected) return "✅"
                                                else return "❌"
                                            }
                                            font.pixelSize: 12
                                            color: "white"
                                        }

                                        Text {
                                            text: {
                                                if (rightContent.connecting) return "连接中"
                                                else if (rightContent.connected) return "已连接"
                                                else return "未连接"
                                            }
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: "white"
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (!rightContent.connected && !rightContent.connecting) {
                                                autoConnectToServer()
                                            }
                                        }
                                    }
                                }

                                // 当前用户信息
                                Text {
                                    text: "用户: " +  clientHandler.name
                                    font.pixelSize: 14
                                    color: "#666666"
                                }

                                // 服务器信息
                                Text {
                                    text: "服务器: " + ( clientHandler.connected ?
                                        ( clientHandler.serverIp + ":" +  clientHandler.serverPort) : "未连接")
                                    font.pixelSize: 14
                                    color: "#666666"
                                }

                                Item { Layout.fillWidth: true } // 占位

                                // 手动连接按钮
                                Button {
                                    text: rightContent.connected ? "已连接" : "重新连接"
                                    enabled: !rightContent.connecting
                                    onClicked: {
                                        if (!rightContent.connected) {
                                            autoConnectToServer()
                                        }
                                    }
                                }
                            }
                        }

                        // 主要内容区域
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 0

                            // 左侧联系人列表
                            Rectangle {
                                Layout.preferredWidth: 300
                                Layout.fillHeight: true
                                color: "#fafafa"
                                border.color: "#e0e0e0"
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // 联系人列表标题
                                    Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 50
                                            color: "#f0f0f0"

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 10
                                                anchors.margins: 10

                                                Text {
                                                    text: {
                                                        var followingCount = followingUsers ? followingUsers.length : 0
                                                        var filteredCount = filteredContactList ? filteredContactList.length : 0
                                                        return "关注的好友 (" + filteredCount + "/" + followingCount + "在线)"
                                                    }
                                                    font.bold: true
                                                    font.pixelSize: 16
                                                    color: "#333333"
                                                    Layout.fillWidth: true
                                                }

                                                // 调试按钮
                                                Button {
                                                    text: "调试"
                                                    flat: true
                                                    onClicked: {
                                                        console.log("=== 调试信息 ===")
                                                        console.log("1. 当前用户:", userController ? userController.currentUser : "无")
                                                        console.log("2. 在线用户列表:", JSON.stringify(clientHandler.clientList))
                                                        console.log("3. 关注用户列表:", JSON.stringify(followingUsers))
                                                        console.log("4. 过滤后列表:", JSON.stringify(filteredContactList))
                                                        console.log("5. 聊天用户名:", clientHandler.name)

                                                        // 手动触发更新
                                                        updateFilteredContactList()
                                                    }
                                                }
                                            }
                                        }

                                    // 联系人列表
                                    // ListView {
                                    //     id: contactListView
                                    //     Layout.fillWidth: true
                                    //     Layout.fillHeight: true
                                    //     model:  clientHandler.clientList
                                    //     clip: true

                                    //     delegate: Rectangle {
                                    //         width: contactListView.width
                                    //         height: 70
                                    //         color: contactListView.currentIndex === index ? "#e3f2fd" :
                                    //                (modelData === rightContent.activeChatTarget ? "#e8f5e9" : "transparent")
                                    //         border.color: "#f0f0f0"
                                    //         border.width: 1

                                    //         RowLayout {
                                    //             anchors.fill: parent
                                    //             anchors.margins: 10
                                    //             spacing: 10

                                    //             // 用户头像
                                    //             Rectangle {
                                    //                 Layout.preferredWidth: 40
                                    //                 Layout.preferredHeight: 40
                                    //                 radius: 20
                                    //                 color: "#" + Math.floor(Math.random()*16777215).toString(16)

                                    //                 Text {
                                    //                     anchors.centerIn: parent
                                    //                     text: modelData ? modelData.charAt(0) : "?"
                                    //                     font.pixelSize: 16
                                    //                     color: "white"
                                    //                     font.bold: true
                                    //                 }
                                    //             }

                                    //             // 用户信息
                                    //             ColumnLayout {
                                    //                 Layout.fillWidth: true
                                    //                 Layout.fillHeight: true
                                    //                 spacing: 4

                                    //                 Text {
                                    //                     text: modelData
                                    //                     font.bold: true
                                    //                     font.pixelSize: 14
                                    //                     color: "#333333"
                                    //                     Layout.fillWidth: true
                                    //                     elide: Text.ElideRight
                                    //                 }

                                    //                 Text {
                                    //                     text: "在线"
                                    //                     font.pixelSize: 12
                                    //                     color: "#2ecc71"
                                    //                 }
                                    //             }
                                    //         }

                                    //         MouseArea {
                                    //             anchors.fill: parent
                                    //             onClicked: {
                                    //                 contactListView.currentIndex = index
                                    //                 rightContent.activeChatTarget = modelData
                                    //                  clientHandler.setActiveChat(modelData)
                                    //             }
                                    //         }
                                    //     }

                                    //     // 空白状态提示
                                    //     Rectangle {
                                    //         visible: contactListView.count === 0
                                    //         anchors.centerIn: parent
                                    //         width: 200
                                    //         height: 100
                                    //         color: "transparent"

                                    //         ColumnLayout {
                                    //             anchors.centerIn: parent
                                    //             spacing: 10

                                    //             Text {
                                    //                 text: "暂无在线用户"
                                    //                 font.pixelSize: 14
                                    //                 color: "#999999"
                                    //                 Layout.alignment: Qt.AlignHCenter
                                    //             }

                                    //             Text {
                                    //                 text: "等待其他用户加入..."
                                    //                 font.pixelSize: 12
                                    //                 color: "#cccccc"
                                    //                 Layout.alignment: Qt.AlignHCenter
                                    //             }
                                    //         }
                                    //     }
                                    // }

                                    ListView {
                                            id: contactListView
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            model: filteredContactList
                                            clip: true

                                            delegate: Rectangle {
                                                width: contactListView.width
                                                height: 70
                                                color: contactListView.currentIndex === index ? "#e3f2fd" :
                                                       (modelData === rightContent.activeChatTarget ? "#e8f5e9" : "transparent")
                                                border.color: "#f0f0f0"
                                                border.width: 1

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    spacing: 10

                                                    // 用户头像
                                                    Rectangle {
                                                        Layout.preferredWidth: 40
                                                        Layout.preferredHeight: 40
                                                        radius: 20
                                                        color: {
                                                            // 根据用户名生成一致的颜色
                                                            var hash = 0
                                                            for (var i = 0; i < modelData.length; i++) {
                                                                hash = modelData.charCodeAt(i) + ((hash << 5) - hash)
                                                            }
                                                            var colors = ["#e3f2fd", "#f3e5f5", "#e8f5e8", "#fff3e0", "#fce4ec", "#f1f8e9"]
                                                            var index = Math.abs(hash) % colors.length
                                                            return colors[index]
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData ? modelData.charAt(0).toUpperCase() : "?"
                                                            font.pixelSize: 16
                                                            color: "#333333"
                                                            font.bold: true
                                                        }
                                                    }

                                                    // 用户信息
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        spacing: 4

                                                        Text {
                                                            text: modelData || "未知用户"
                                                            font.bold: true
                                                            font.pixelSize: 14
                                                            color: "#333333"
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }

                                                        Text {
                                                            text: "已关注 · 在线"
                                                            font.pixelSize: 12
                                                            color: "#2ecc71"
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        console.log("点击联系人:", modelData)
                                                        contactListView.currentIndex = index
                                                        rightContent.activeChatTarget = modelData
                                                        clientHandler.setActiveChat(modelData)
                                                    }
                                                }
                                            }

                                            // 空白状态提示
                                            Rectangle {
                                                visible: contactListView.count === 0
                                                anchors.centerIn: parent
                                                width: 300
                                                height: 140
                                                color: "transparent"

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 10

                                                    Text {
                                                        text: {
                                                            if (!userController || !userController.isLoggedIn) {
                                                                return "请先登录"
                                                            } else if (!followingUsers || followingUsers.length === 0) {
                                                                return "您还没有关注任何用户"
                                                            } else if (!filteredContactList || filteredContactList.length === 0) {
                                                                return "关注的用户不在线"
                                                            } else {
                                                                return "在线用户列表为空"
                                                            }
                                                        }
                                                        font.pixelSize: 16
                                                        color: "#999999"
                                                        Layout.alignment: Qt.AlignHCenter
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }

                                                    Text {
                                                        text: {
                                                            if (!userController || !userController.isLoggedIn) {
                                                                return "登录后查看关注的好友"
                                                            } else if (!followingUsers || followingUsers.length === 0) {
                                                                return "先去发现并关注一些用户吧"
                                                            } else if (!filteredContactList || filteredContactList.length === 0) {
                                                                var followingCount = followingUsers ? followingUsers.length : 0
                                                                return "您关注的 " + followingCount + " 个用户当前不在线"
                                                            } else {
                                                                return "但模型显示有 " + filteredContactList.length + " 个用户"
                                                            }
                                                        }
                                                        font.pixelSize: 12
                                                        color: "#cccccc"
                                                        Layout.alignment: Qt.AlignHCenter
                                                        horizontalAlignment: Text.AlignHCenter
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                            }
                                        }
                                }
                            }

                            // 右侧聊天区域
                            Rectangle {
                                id: chatArea
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: true
                                color: "#ffffff"

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // 聊天标题栏
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        color: "#f8f9fa"
                                        border.color: "#e0e0e0"
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 15
                                            spacing: 10

                                            Text {
                                                text: rightContent.activeChatTarget ? "💬 与 " + rightContent.activeChatTarget + " 的对话" : "💬 选择联系人开始聊天"
                                                font.bold: true
                                                font.pixelSize: 16
                                                Layout.fillWidth: true
                                            }

                                            // 聊天操作按钮
                                            RowLayout {
                                                spacing: 5
                                                visible: rightContent.activeChatTarget

                                                Button {
                                                    text: "清除记录"
                                                    flat: true
                                                    onClicked: {
                                                         clientHandler.chatHistory = ""
                                                    }
                                                }

                                                Button {
                                                    text: "历史记录"
                                                    flat: true
                                                    onClicked: {
                                                        if (rightContent.activeChatTarget) {
                                                             clientHandler.loadChatHistory(rightContent.activeChatTarget)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 聊天消息区域
                                    ScrollView {
                                        id: chatScrollView
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        background: Rectangle { color: "#f5f5f5" }

                                        TextArea {
                                            id: messageDisplay
                                            readOnly: true
                                            text:  clientHandler.chatHistory ||
                                                  (rightContent.activeChatTarget ?
                                                   "与 " + rightContent.activeChatTarget + " 的对话\n\n等待消息..." :
                                                   "欢迎使用聊天功能！\n\n请从左侧选择一个联系人开始聊天。")
                                            wrapMode: TextArea.Wrap
                                            background: null
                                            font.pixelSize: 14
                                            color: "#333333"
                                            textFormat: Text.PlainText

                                            // 自动滚动到底部
                                            onTextChanged: {
                                                if ( clientHandler.chatHistory) {
                                                    chatScrollView.ScrollBar.vertical.position = 1.0
                                                }
                                            }
                                        }
                                    }

                                    // 消息输入区域
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 80
                                        color: "#ffffff"
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        visible: rightContent.activeChatTarget && rightContent.connected

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 15
                                            spacing: 10

                                            TextField {
                                                id: messageInput
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                placeholderText: "输入消息..."
                                                font.pixelSize: 14
                                                selectByMouse: true

                                                onAccepted: {
                                                    if (rightContent.activeChatTarget && text.trim() !== "") {
                                                         clientHandler.sendToClient(rightContent.activeChatTarget, text.trim())
                                                        messageInput.clear()
                                                    }
                                                }
                                            }

                                            Button {
                                                text: "发送"
                                                Layout.preferredHeight: 40
                                                Layout.preferredWidth: 80
                                                enabled: messageInput.text.trim() !== "" && rightContent.connected
                                                onClicked: {
                                                    if (rightContent.activeChatTarget && messageInput.text.trim() !== "") {
                                                         clientHandler.sendToClient(rightContent.activeChatTarget, messageInput.text.trim())
                                                        messageInput.clear()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 未选择联系人或未连接提示
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        visible: !rightContent.activeChatTarget || !rightContent.connected
                                        color: "#fafafa"

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 20
                                            width: parent.width * 0.6

                                            Text {
                                                text: {
                                                    if (!rightContent.connected) return "尚未连接到服务器"
                                                    else if (!rightContent.activeChatTarget) return "请选择聊天对象"
                                                    else return "准备聊天"
                                                }
                                                font.pixelSize: 16
                                                color: "#666666"
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            Text {
                                                text: {
                                                    if (!rightContent.connected) return "点击顶部\"重新连接\"按钮连接到聊天服务器"
                                                    else if (!rightContent.activeChatTarget) return "从左侧用户列表中选择一个联系人开始聊天"
                                                    else return "可以在下方输入框中输入消息"
                                                }
                                                font.pixelSize: 14
                                                color: "#999999"
                                                Layout.alignment: Qt.AlignHCenter
                                                wrapMode: Text.Wrap
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            Button {
                                                text: "重新连接"
                                                visible: !rightContent.connected
                                                Layout.alignment: Qt.AlignHCenter
                                                onClicked: autoConnectToServer()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

        // === 新增：回复我的内容区域 ===
        Rectangle {
            id: replyContent
            Layout.preferredWidth: 1000
            Layout.fillHeight: true
            visible: false
            color: "#ffffff"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 顶部标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#f5f5f5"
                    border.color: "#e0e0e0"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "回复我的"
                        font.bold: true
                        font.pixelSize: 18
                        color: "#333333"
                    }
                }

                // 回复列表
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: "#fafafa" }

                    ColumnLayout {
                        width: parent.width
                        spacing: 1

                        // 回复项1
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#e3f2fd"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👦"
                                        font.pixelSize: 20
                                    }
                                }

                                // 回复内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和操作类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "张三"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "回复了我的评论"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // 评论内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#f8f9fa"
                                        radius: 6

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "这个视频拍得真棒！景色太美了，我也想去那里旅行。"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-01 14:30"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Button {
                                            text: "回复"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("回复按钮被点击")
                                            }
                                        }

                                        Button {
                                            text: "♥ 12"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 70
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("点赞按钮被点击")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 回复项2
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#ffeef0"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👧"
                                        font.pixelSize: 20
                                    }
                                }

                                // 回复内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和操作类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "李四"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "回复了我的视频"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // 评论内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#f8f9fa"
                                        radius: 6

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "视频里的配乐很好听，和画面很搭配！请问是什么音乐？"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-11-28 09:15"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Button {
                                            text: "回复"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("回复按钮被点击")
                                            }
                                        }

                                        Button {
                                            text: "♥ 8"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 70
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("点赞按钮被点击")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 回复项3
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#f0f4ff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👨"
                                        font.pixelSize: 20
                                    }
                                }

                                // 回复内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和操作类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "王五"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "回复了我的评论"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // 评论内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#f8f9fa"
                                        radius: 6

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "同意你的观点，这个地方确实值得一去，我上个月刚去过。"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-11-25 16:45"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Button {
                                            text: "回复"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("回复按钮被点击")
                                            }
                                        }

                                        Button {
                                            text: "♥ 15"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 70
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("点赞按钮被点击")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // === 新增：@我的内容区域 ===
        Rectangle {
            id: atMeContent
            Layout.preferredWidth: 1000
            Layout.fillHeight: true
            visible: false
            color: "#ffffff"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 顶部标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#f5f5f5"
                    border.color: "#e0e0e0"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "@我的"
                        font.bold: true
                        font.pixelSize: 18
                        color: "#333333"
                    }
                }

                // @我的列表
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: "#fafafa" }

                    ColumnLayout {
                        width: parent.width
                        spacing: 1

                        // @我的项1
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#e3f2fd"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👦"
                                        font.pixelSize: 20
                                    }
                                }

                                // @我的内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和操作类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "张三"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "在评论中@了我"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // @我的评论内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        color: "#f0f7ff"
                                        radius: 6
                                        border.color: "#d1e9ff"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "@旅行达人 这个景点怎么去最方便？有没有推荐的交通方式？"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-05 10:30"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Button {
                                            text: "回复"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("回复@我的消息")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // @我的项2
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#ffeef0"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👧"
                                        font.pixelSize: 20
                                    }
                                }

                                // @我的内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和操作类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "李四"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "在视频评论中@了我"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // @我的评论内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        color: "#f0f7ff"
                                        radius: 6
                                        border.color: "#d1e9ff"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "@旅行达人 你上次推荐的这个地方太美了！我也去打卡了，感谢分享！"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-03 15:20"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Button {
                                            text: "回复"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("回复@我的消息")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // @我的项3
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#f0f4ff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👨"
                                        font.pixelSize: 20
                                    }
                                }

                                // @我的内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和操作类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "王五"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "在帖子中@了我"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // @我的评论内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        color: "#f0f7ff"
                                        radius: 6
                                        border.color: "#d1e9ff"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "@旅行达人 请问这个季节去合适吗？天气怎么样？需要准备什么？"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-11-30 08:45"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Button {
                                            text: "回复"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("回复@我的消息")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // @我的项4
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#f3e5f5"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👩"
                                        font.pixelSize: 20
                                    }
                                }

                                // @我的内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和操作类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "赵六"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "在回答中@了我"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // @我的评论内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        color: "#f0f7ff"
                                        radius: 6
                                        border.color: "#d1e9ff"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "@旅行达人 我觉得你说的很对！这个地方确实值得推荐给大家"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-11-28 19:15"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Button {
                                            text: "回复"
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 12
                                            background: Rectangle {
                                                color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                                radius: 4
                                            }

                                            onClicked: {
                                                console.log("回复@我的消息")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // === 新增：收到的赞内容区域 ===
        Rectangle {
            id: likesContent
            Layout.preferredWidth: 1000
            Layout.fillHeight: true
            visible: false
            color: "#ffffff"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 顶部标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#f5f5f5"
                    border.color: "#e0e0e0"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "收到的赞"
                        font.bold: true
                        font.pixelSize: 18
                        color: "#333333"
                    }
                }

                // 点赞列表
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: "#fafafa" }

                    ColumnLayout {
                        width: parent.width
                        spacing: 1

                        // 点赞项1 - 点赞视频
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#e3f2fd"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👦"
                                        font.pixelSize: 20
                                    }
                                }

                                // 点赞内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和点赞类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "张三"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "赞了你的视频"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }

                                        // 点赞图标
                                        Text {
                                            text: "❤️"
                                            font.pixelSize: 16
                                            color: "#ff4757"
                                        }
                                    }

                                    // 被点赞的内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#fff5f5"
                                        radius: 6
                                        border.color: "#ffcccc"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "【旅行Vlog】探索神秘的古村落，发现不一样的风景"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-06 14:20"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                        // 点赞项2 - 点赞评论
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#ffeef0"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👧"
                                        font.pixelSize: 20
                                    }
                                }

                                // 点赞内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和点赞类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "李四"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "赞了你的评论"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }

                                        // 点赞图标
                                        Text {
                                            text: "❤️"
                                            font.pixelSize: 16
                                            color: "#ff4757"
                                        }
                                    }

                                    // 被点赞的内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#fff5f5"
                                        radius: 6
                                        border.color: "#ffcccc"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "这个地方真的很适合拍照，光线和角度都很好，推荐大家去打卡"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-05 09:30"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                        // 点赞项3 - 点赞视频
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#f0f4ff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👨"
                                        font.pixelSize: 20
                                    }
                                }

                                // 点赞内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和点赞类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "王五"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "赞了你的视频"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }

                                        // 点赞图标
                                        Text {
                                            text: "❤️"
                                            font.pixelSize: 16
                                            color: "#ff4757"
                                        }
                                    }

                                    // 被点赞的内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#fff5f5"
                                        radius: 6
                                        border.color: "#ffcccc"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "美食探店：这家餐厅的招牌菜真的太美味了！"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-04 16:45"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                        // 点赞项4 - 点赞评论
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#f3e5f5"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👩"
                                        font.pixelSize: 20
                                    }
                                }

                                // 点赞内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和点赞类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "赵六"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "赞了你的评论"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }

                                        // 点赞图标
                                        Text {
                                            text: "❤️"
                                            font.pixelSize: 16
                                            color: "#ff4757"
                                        }
                                    }

                                    // 被点赞的内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#fff5f5"
                                        radius: 6
                                        border.color: "#ffcccc"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "我觉得这个拍摄角度很独特，把建筑的对称美展现得淋漓尽致"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-03 11:15"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                        // 点赞项5 - 点赞动态
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: "#e8f5e8"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "👦"
                                        font.pixelSize: 20
                                    }
                                }

                                // 点赞内容区域
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    // 用户信息和点赞类型
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "钱七"
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: "#333333"
                                        }

                                        Text {
                                            text: "赞了你的动态"
                                            font.pixelSize: 13
                                            color: "#666666"
                                            Layout.fillWidth: true
                                        }

                                        // 点赞图标
                                        Text {
                                            text: "❤️"
                                            font.pixelSize: 16
                                            color: "#ff4757"
                                        }
                                    }

                                    // 被点赞的内容
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#fff5f5"
                                        radius: 6
                                        border.color: "#ffcccc"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "今天天气真好，适合出去走走～分享一些随手拍的美景"
                                            font.pixelSize: 13
                                            color: "#333333"
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 底部信息栏
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "2023-12-02 08:30"
                                            font.pixelSize: 12
                                            color: "#999999"
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // === 新增：系统通知内容区域 ===
        Rectangle {
            id: systemNotificationContent
            Layout.preferredWidth: 1000
            Layout.fillHeight: true
            visible: false
            color: "#ffffff"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 顶部标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#f5f5f5"
                    border.color: "#e0e0e0"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "系统通知"
                        font.bold: true
                        font.pixelSize: 18
                        color: "#333333"
                    }
                }

                // 通知列表
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: "#fafafa" }

                    ColumnLayout {
                        width: parent.width
                        spacing: 1

                        // 通知项1 - 系统更新
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 8

                                // 标题和日期行
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "📢 系统版本更新通知"
                                        font.bold: true
                                        font.pixelSize: 15
                                        color: "#333333"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "2023-12-07"
                                        font.pixelSize: 12
                                        color: "#999999"
                                    }
                                }

                                // 通知内容
                                Text {
                                    text: "亲爱的用户，我们已发布新版本v2.5.0，新增了多项功能优化和性能提升。建议您及时更新以获得更好的使用体验。更新内容包括：视频播放优化、消息界面改进、性能提升等。"
                                    font.pixelSize: 13
                                    color: "#666666"
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                }
                            }
                        }

                        // 通知项2 - 活动通知
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 8

                                // 标题和日期行
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "🎉 新年特别活动开启"
                                        font.bold: true
                                        font.pixelSize: 15
                                        color: "#333333"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "2023-12-05"
                                        font.pixelSize: 12
                                        color: "#999999"
                                    }
                                }

                                // 通知内容
                                Text {
                                    text: "迎接2024新年，我们特别推出了'分享你的年度旅行故事'活动。参与即有机会赢取精美礼品和会员特权！活动时间：2023.12.10 - 2024.1.10。快来分享你的精彩瞬间吧！"
                                    font.pixelSize: 13
                                    color: "#666666"
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                }
                            }
                        }

                        // 通知项3 - 安全提醒
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 8

                                // 标题和日期行
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "🔒 账号安全提醒"
                                        font.bold: true
                                        font.pixelSize: 15
                                        color: "#333333"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "2023-12-03"
                                        font.pixelSize: 12
                                        color: "#999999"
                                    }
                                }

                                // 通知内容
                                Text {
                                    text: "检测到您的账号在异地登录，如非本人操作，请立即修改密码。建议您开启双重验证功能，保护账号安全。如有疑问，请联系客服支持。"
                                    font.pixelSize: 13
                                    color: "#666666"
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                }
                            }
                        }

                        // 通知项4 - 功能上线
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 8

                                // 标题和日期行
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "✨ 新功能上线：消息分类"
                                        font.bold: true
                                        font.pixelSize: 15
                                        color: "#333333"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "2023-11-30"
                                        font.pixelSize: 12
                                        color: "#999999"
                                    }
                                }

                                // 通知内容
                                Text {
                                    text: "为了更好地管理您的消息，我们新增了消息分类功能。现在您可以更清晰地查看回复、@提及、点赞等不同类型的消息。希望这个改进能让您的使用体验更加愉悦！"
                                    font.pixelSize: 13
                                    color: "#666666"
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                }
                            }
                        }

                        // 通知项5 - 维护通知
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 8

                                // 标题和日期行
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "🛠️ 系统维护通知"
                                        font.bold: true
                                        font.pixelSize: 15
                                        color: "#333333"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "2023-11-28"
                                        font.pixelSize: 12
                                        color: "#999999"
                                    }
                                }

                                // 通知内容
                                Text {
                                    text: "为了提升系统稳定性，我们计划于2023年12月10日凌晨2:00-4:00进行系统维护。在此期间，部分服务可能会短暂不可用。给您带来的不便敬请谅解。感谢您的支持！"
                                    font.pixelSize: 13
                                    color: "#666666"
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                }
                            }
                        }

                        // 通知项6 - 社区规则
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#ffffff"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 8

                                // 标题和日期行
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "📝 社区规则更新提醒"
                                        font.bold: true
                                        font.pixelSize: 15
                                        color: "#333333"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "2023-11-25"
                                        font.pixelSize: 12
                                        color: "#999999"
                                    }
                                }

                                // 通知内容
                                Text {
                                    text: "为营造更好的社区环境，我们更新了社区行为规范。主要更新内容包括：明确禁止内容范围、优化举报处理流程、加强原创内容保护等。请仔细阅读新版社区规则，共同维护良好的交流氛围。"
                                    font.pixelSize: 13
                                    color: "#666666"
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                }
                            }
                        }
                    }
                }
            }
        }

        // === 新增：消息设置内容区域 ===
        Rectangle {
            id: messageSettingsContent
            Layout.preferredWidth: 1000
            Layout.fillHeight: true
            visible: false
            color: "#ffffff"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 顶部标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#f5f5f5"
                    border.color: "#e0e0e0"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "消息设置"
                        font.bold: true
                        font.pixelSize: 18
                        color: "#333333"
                    }
                }

                // 设置选项列表
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: "#fafafa" }

                    ColumnLayout {
                        width: parent.width
                        spacing: 1

                        // 设置项1 - 消息提示
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        text: "消息提示"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }

                                    Text {
                                        text: "开启或关闭所有消息提示"
                                        font.pixelSize: 12
                                        color: "#666666"
                                    }
                                }

                                Switch {
                                    checked: true
                                    onCheckedChanged: {
                                        console.log("消息提示: " + (checked ? "开启" : "关闭"))
                                    }
                                }
                            }
                        }

                        // 设置项2 - 私信智能拦截
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        text: "私信智能拦截"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }

                                    Text {
                                        text: "自动拦截垃圾私信和骚扰信息"
                                        font.pixelSize: 12
                                        color: "#666666"
                                    }
                                }

                                Switch {
                                    checked: true
                                    onCheckedChanged: {
                                        console.log("私信智能拦截: " + (checked ? "开启" : "关闭"))
                                    }
                                }
                            }
                        }

                        // 设置项3 - 添加消息屏蔽词
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        text: "添加消息屏蔽词"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }

                                    Text {
                                        text: "设置关键词屏蔽不想接收的消息"
                                        font.pixelSize: 12
                                        color: "#666666"
                                    }
                                }

                                Button {
                                    text: "管理"
                                    Layout.preferredHeight: 35
                                    Layout.preferredWidth: 80
                                    background: Rectangle {
                                        color: parent.down ? "#e0e0e0" : "#f0f0f0"
                                        radius: 4
                                    }

                                    onClicked: {
                                        console.log("打开屏蔽词管理")
                                    }
                                }
                            }
                        }

                        // 设置项4 - 回复我的消息提醒
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        text: "回复我的消息提醒"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }

                                    Text {
                                        text: "设置接收哪些人的回复消息提醒"
                                        font.pixelSize: 12
                                        color: "#666666"
                                    }
                                }

                                ComboBox {
                                    model: ["所有人", "关注的人", "不接受任何消息"]
                                    currentIndex: 0
                                    Layout.preferredWidth: 150
                                    onCurrentIndexChanged: {
                                        console.log("回复消息提醒设置: " + model[currentIndex])
                                    }
                                }
                            }
                        }

                        // 设置项5 - @我的消息提示
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        text: "@我的消息提示"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }

                                    Text {
                                        text: "设置接收哪些人的@消息提醒"
                                        font.pixelSize: 12
                                        color: "#666666"
                                    }
                                }

                                ComboBox {
                                    model: ["所有人", "关注的人", "不接受任何消息"]
                                    currentIndex: 0
                                    Layout.preferredWidth: 150
                                    onCurrentIndexChanged: {
                                        console.log("@我的消息提示设置: " + model[currentIndex])
                                    }
                                }
                            }
                        }

                        // 设置项6 - 收到的赞消息提示
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        text: "收到的赞消息提示"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }

                                    Text {
                                        text: "开启或关闭点赞消息提示"
                                        font.pixelSize: 12
                                        color: "#666666"
                                    }
                                }

                                Switch {
                                    checked: true
                                    onCheckedChanged: {
                                        console.log("点赞消息提示: " + (checked ? "开启" : "关闭"))
                                    }
                                }
                            }
                        }

                        // 设置项7 - 收到未关注人消息
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: "#ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        text: "收到未关注人消息"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }

                                    Text {
                                        text: "开启或关闭未关注人的消息接收"
                                        font.pixelSize: 12
                                        color: "#666666"
                                    }
                                }

                                Switch {
                                    checked: false
                                    onCheckedChanged: {
                                        console.log("未关注人消息: " + (checked ? "开启" : "关闭"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 错误重连弹窗
       Dialog {
           id: reconnectDialog
           title: "连接失败"
           modal: true
           standardButtons: Dialog.Retry | Dialog.Cancel
           closePolicy: Popup.NoAutoClose
           width: 400
           x: (parent.width - width) / 2
           y: (parent.height - height) / 2

           ColumnLayout {
               width: parent.width
               spacing: 10

               Label {
                   text: "⚠️ 无法连接到服务器"
                   font.bold: true
                   Layout.fillWidth: true
               }

               Label {
                   id: errorMessageLabel
                   text: "连接服务器时出现错误"
                   wrapMode: Text.Wrap
                   Layout.fillWidth: true
               }

               Label {
                   text: "是否尝试重新连接？"
                   color: "gray"
                   Layout.fillWidth: true
               }
           }

           onAccepted: {
                clientHandler.reconnect()
           }

           onRejected: {
               reconnectDialog.close()
           }
       }

}
