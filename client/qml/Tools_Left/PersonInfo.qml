import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

// 个人中心：头像与关注/粉丝
Rectangle {
    id: personInfoPage
    color: "#f4f4f4"

    signal logoutRequested()

    property bool showFollowingList: false
    property bool showFollowerList: false

    ListModel { id: followingListModel }
    ListModel { id: followerListModel }

    function fillFollowingModel() {
        followingListModel.clear()
        var list = userController.followingUsers || []
        for (var i = 0; i < list.length; i++) {
            var u = list[i]
            followingListModel.append({
                id: u.id || "",
                account: u.account || "",
                nickname: u.nickname || "未知用户",
                sign: u.signature || "这个用户很懒，什么都没有写"
            })
        }
    }

    function fillFollowerModel() {
        followerListModel.clear()
        var list = userController.followerUsers || []
        for (var i = 0; i < list.length; i++) {
            var u = list[i]
            followerListModel.append({
                id: u.id || "",
                account: u.account || "",
                nickname: u.nickname || "未知用户",
                sign: u.signature || "这个用户很懒，什么都没有写"
            })
        }
    }

    function refreshAll() {
        userController.loadFollowingUsers()
        userController.loadFollowerUsers()
    }

    function uploadUserAvatar(path) {
        userController.uploadAvatar(path)
    }

    Connections {
        target: userController

        function onFollowingChanged() {
            fillFollowingModel()
        }

        function onFollowersChanged() {
            fillFollowerModel()
        }
    }

    Component.onCompleted: {
        console.log("个人信息页面初始化完成")
        refreshAll()
    }

    FileDialog {
        id: avatarFileDialog
        title: "选择头像图片"
        nameFilters: ["图片文件 (*.png *.jpg *.jpeg)"]

        onAccepted: {
            var urlStr = selectedFile.toString()
            var filePath = urlStr
            if (urlStr.startsWith("file:///"))
                filePath = urlStr.substring(8)
            else if (urlStr.startsWith("file://"))
                filePath = urlStr.substring(7)
            console.log("选择的头像文件:", filePath)
            uploadUserAvatar(filePath)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        // 用户信息卡片
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            color: "#FFFFFF"
            radius: 12

            RowLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                Rectangle {
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 84
                    radius: 42
                    clip: true
                    color: "#F1F2F3"

                    Image {
                        anchors.fill: parent
                        source: userController.avatarUrl
                                ? userController.avatarUrl + "?t=" + userController.avatarTimestamp
                                : "https://i0.hdslb.com/bfs/face/member/noface.jpg"
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }

                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: avatarFileDialog.open()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: (userController.currentUser && userController.currentUser.nickname) || "未登录"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#18191C"
                    }

                    Text {
                        text: "账号: " + ((userController.currentUser && userController.currentUser.account) || "")
                        font.pixelSize: 13
                        color: "#9499A0"
                    }

                    Text {
                        text: (userController.currentUser && userController.currentUser.signature)
                              || "这个人很懒，什么都没有写"
                        font.pixelSize: 13
                        color: "#9499A0"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Button {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 34
                    text: "更换头像"

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    background: Rectangle {
                        color: parent.hovered ? "#F06A93" : "#FB7299"
                        radius: 17
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: avatarFileDialog.open()
                }
            }
        }

        // 关注 / 粉丝 入口
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Button {
                id: followingBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: "我的关注 (" + followingListModel.count + ")"

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                background: Rectangle {
                    color: parent.hovered ? "#FFF0F3" : "#FFFFFF"
                    radius: 10
                    border.color: showFollowingList ? "#FB7299" : "#E3E5E7"
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: showFollowingList ? "#FB7299" : "#18191C"
                    font.pixelSize: 14
                    font.bold: showFollowingList
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    showFollowingList = !showFollowingList
                    showFollowerList = false
                }
            }

            Button {
                id: followerBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: "我的粉丝 (" + followerListModel.count + ")"

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                background: Rectangle {
                    color: parent.hovered ? "#FFF0F3" : "#FFFFFF"
                    radius: 10
                    border.color: showFollowerList ? "#FB7299" : "#E3E5E7"
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: showFollowerList ? "#FB7299" : "#18191C"
                    font.pixelSize: 14
                    font.bold: showFollowerList
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    showFollowerList = !showFollowerList
                    showFollowingList = false
                }
            }
        }

        // 关注列表
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: showFollowingList
            color: "#FFFFFF"
            radius: 12
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Text {
                    text: "关注列表"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#18191C"
                    Layout.leftMargin: 20
                    Layout.topMargin: 16
                    Layout.bottomMargin: 10
                }

                ListView {
                    id: followingList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: followingListModel
                    spacing: 1

                    delegate: Rectangle {
                        width: followingList.width
                        height: 66
                        color: "#FFFFFF"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 21
                                color: "#FB7299"

                                Text {
                                    anchors.centerIn: parent
                                    text: model.nickname ? model.nickname.charAt(0) : "?"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: model.nickname || "未知用户"
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: "#333333"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.sign || "这个用户很懒，什么都没有写"
                                    font.pixelSize: 12
                                    color: "#999999"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Button {
                                Layout.preferredWidth: 92
                                Layout.preferredHeight: 32
                                text: "取消关注"

                                background: Rectangle {
                                    color: parent.hovered ? "#FFE3EA" : "#FFF0F3"
                                    radius: 16
                                    border.color: "#FB7299"
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "#FB7299"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    userController.unfollowUser(model.id)
                                    refreshAll()
                                }
                            }
                        }
                    }
                }
            }

            // 空状态
            Text {
                anchors.centerIn: parent
                visible: followingListModel.count === 0
                text: "还没有关注任何人"
                font.pixelSize: 15
                color: "#999999"
            }
        }

        // 粉丝列表
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: showFollowerList
            color: "#FFFFFF"
            radius: 12
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Text {
                    text: "粉丝列表"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#18191C"
                    Layout.leftMargin: 20
                    Layout.topMargin: 16
                    Layout.bottomMargin: 10
                }

                ListView {
                    id: followerList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: followerListModel
                    spacing: 1

                    delegate: Rectangle {
                        width: followerList.width
                        height: 66
                        color: "#FFFFFF"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 21
                                color: "#00A1D6"

                                Text {
                                    anchors.centerIn: parent
                                    text: model.nickname ? model.nickname.charAt(0) : "?"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: model.nickname || "未知用户"
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: "#333333"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.sign || "这个用户很懒，什么都没有写"
                                    font.pixelSize: 12
                                    color: "#999999"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Button {
                                id: followBackBtn
                                Layout.preferredWidth: 92
                                Layout.preferredHeight: 32

                                property bool isFollowing: userController.isFollowing(model.id)

                                text: isFollowing ? "已关注" : "回关"

                                background: Rectangle {
                                    color: isFollowing ? "#F1F2F3" : (parent.hovered ? "#F06A93" : "#FB7299")
                                    radius: 16
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: isFollowing ? "#666666" : "white"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    if (isFollowing) {
                                        userController.unfollowUser(model.id)
                                        isFollowing = false
                                    } else {
                                        userController.followUser(model.id)
                                        isFollowing = true
                                    }
                                    refreshAll()
                                }
                            }
                        }
                    }
                }
            }

            // 空状态
            Text {
                anchors.centerIn: parent
                visible: followerListModel.count === 0
                text: "还没有粉丝"
                font.pixelSize: 15
                color: "#999999"
            }
        }

        // 退出登录
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            text: "退出登录"

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            background: Rectangle {
                color: parent.hovered ? "#FFF0F3" : "#FFFFFF"
                radius: 10
                border.color: "#E3E5E7"
                border.width: 1
            }

            contentItem: Text {
                text: parent.text
                color: "#FB7299"
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                console.log("退出登录")
                userController.logout()
                logoutRequested()
            }
        }
    }
}
