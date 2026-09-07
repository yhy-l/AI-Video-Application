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
    property bool showMyVideos: true
    property bool showFollowerList: false
    property string pendingDeleteId: ""
    property string pendingDeleteTitle: ""

    Dialog {
        id: deleteConfirmDialog
        modal: true
        anchors.centerIn: parent
        title: "删除视频"
        standardButtons: Dialog.Yes | Dialog.No

        contentItem: Text {
            text: "确定删除《" + pendingDeleteTitle + "》吗？\n原视频、各清晰度与封面都会从服务器删除，且不可恢复。"
            font.pixelSize: 14
            color: "#333333"
            wrapMode: Text.Wrap
            width: 360
        }

        onAccepted: {
            if (pendingDeleteId)
                videoController.deleteMyVideo(pendingDeleteId)
            pendingDeleteId = ""
        }
        onRejected: pendingDeleteId = ""
    }

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
        videoController.loadMyVideos()
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

        // 我的投稿 / 关注 / 粉丝 入口
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                id: myVideosBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: "我的投稿 (" + (videoController.myVideos ? videoController.myVideos.length : 0) + ")"
                background: Rectangle {
                    color: parent.hovered ? "#FFF0F3" : "#FFFFFF"
                    radius: 10
                    border.color: showMyVideos ? "#FB7299" : "#E3E5E7"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: showMyVideos ? "#FB7299" : "#18191C"
                    font.pixelSize: 14
                    font.bold: showMyVideos
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    showMyVideos = true
                    showFollowingList = false
                    showFollowerList = false
                }
            }

            Button {
                id: followingBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: "我的关注 (" + followingListModel.count + ")"
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
                    showMyVideos = false
                    showFollowingList = true
                    showFollowerList = false
                }
            }

            Button {
                id: followerBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: "我的粉丝 (" + followerListModel.count + ")"
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
                    showMyVideos = false
                    showFollowingList = false
                    showFollowerList = true
                }
            }
        }

        // 我的投稿列表
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: showMyVideos
            color: "#FFFFFF"
            radius: 12
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "我上传的视频（删除后原文件与各清晰度一并移除）"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#61666D"
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: videoController.myVideos

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 104
                                radius: 10
                                color: "#FAFBFC"
                                border.color: "#EAECEE"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 132
                                        Layout.preferredHeight: 80
                                        radius: 6
                                        clip: true
                                        color: "#121212"

                                        Image {
                                            id: myVideoCover
                                            anchors.fill: parent
                                            source: modelData.coverUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "🎬"
                                            font.pixelSize: 24
                                            visible: myVideoCover.status !== Image.Ready
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Text {
                                            text: modelData.title || "无标题"
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: "#18191C"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: (modelData.formattedViewCount || "0") + " 播放 · 上传于 " + (modelData.uploadDate || "")
                                            font.pixelSize: 12
                                            color: "#9499A0"
                                        }

                                        Text {
                                            text: modelData.transcodeStatus === "done"
                                                  ? "转码完成 ✅"
                                                  : (modelData.transcodeStatus === "transcoding" ? "后台转码中…" : "等待转码…")
                                            font.pixelSize: 11
                                            color: modelData.transcodeStatus === "done" ? "#1B8A5A" : "#FB7299"
                                        }
                                    }

                                    Button {
                                        text: "删除"
                                        Layout.preferredHeight: 32
                                        flat: true
                                        background: Rectangle {
                                            color: parent.hovered ? "#FDEBEB" : "#F6F7F8"
                                            radius: 8
                                            border.color: "#E3E5E7"
                                            border.width: 1
                                        }
                                        contentItem: Text {
                                            text: "删除"
                                            font.pixelSize: 12
                                            color: parent.parent.hovered ? "#D33A3A" : "#61666D"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: {
                                            pendingDeleteId = modelData.id
                                            pendingDeleteTitle = modelData.title || "该视频"
                                            deleteConfirmDialog.open()
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: !videoController.myVideos || videoController.myVideos.length === 0
                            text: "还没有上传过视频\n点左侧“上传视频”发布第一个作品"
                            font.pixelSize: 14
                            color: "#C9CCD0"
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            Layout.topMargin: 60
                        }
                    }
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
