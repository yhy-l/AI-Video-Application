//评论部分，基本不需要变动

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    Layout.fillHeight: true
    Layout.fillWidth: true
    property bool animationsEnabled: true

    property int currentCommentCount: 0
    property var mainWindow   // 主窗口引用，用于未登录时打开登录框

    signal commentCountChanged(int newCount)

    // 评论数据模型
    ListModel {
        id: commentModel
    }

        // 对外接口
        property var videoManager
        property var videoData

        function loadComments() {
                console.log("从C++加载评论数据");

                if (videoManager && videoData && videoData.id) {
                    videoManager.loadComments(videoData.id);
                } else {
                    console.error("无法加载评论: videoManager 或 videoData 不可用");
                }
            }

        function addComment(userName, content) {
                if (videoManager && videoData && videoData.id) {
                    videoManager.addComment(videoData.id, userName, content);
                    // 评论列表在服务端响应后统一刷新
                } else {
                    console.error("无法加载评论: videoManager 或 videoData 不可用");
                }
            }

        function addReply(commentId, userName, content) {
                if (videoManager && videoData && videoData.id) {
                    videoManager.addReply(videoData.id, commentId, userName, content);
                    // 回复成功后由服务端响应刷新
                } else {
                    console.error("无法加载评论: videoManager 或 videoData 不可用");
                }
            }

        function updateCommentModel() {
            if (!videoManager) {
                console.error("updateCommentModel: videoManager 不存在");
                return;
            }

            var comments = [];
            try {
                comments = videoManager.comments || [];
            } catch (error) {
                console.error("获取 comments 时出错:", error);
            }

            commentModel.clear();

            // 服务端返回的是扁平列表（回复带 parentId），
            // 这里组装成 父评论 -> 回复 的树形结构再展示
            var byId = {};
            var topLevelIds = [];
            for (var i = 0; i < comments.length; i++) {
                try {
                    var comment = comments[i];
                    if (!comment) {
                        console.warn("评论", i, "为空");
                        continue;
                    }

                    var item = {
                        id: comment.id || "unknown_id",
                        userName: comment.userName || "匿名用户",
                        time: comment.time || "",
                        formattedTime: comment.formattedTime || "",
                        content: comment.content || "",
                        likeCount: comment.likeCount || 0,
                        unlikeCount: comment.unlikeCount || 0,
                        isReply: comment.isReply || false,
                        parentId: comment.parentId || "",
                        replies: []
                    };
                    byId[item.id] = item;
                    if (!comment.parentId)
                        topLevelIds.push(item.id);
                } catch (error) {
                    console.error("添加评论到模型时出错:", error);
                }
            }

            // 把回复挂到对应父评论下；父评论不在列表里的异常数据按顶层展示
            for (var r = 0; r < comments.length; r++) {
                var rc = comments[r];
                if (!rc || !rc.parentId) continue;
                if (byId[rc.parentId]) {
                    byId[rc.parentId].replies.push(byId[rc.id]);
                } else if (topLevelIds.indexOf(rc.id) < 0) {
                    topLevelIds.push(rc.id);
                }
            }

            for (var t = 0; t < topLevelIds.length; t++)
                commentModel.append(byId[topLevelIds[t]]);

            if (videoData && videoData.id) {
                try {
                    var totalCount = videoManager.getCommentCount(videoData.id);
                    console.log("评论总数:", totalCount);
                    commentCountChanged(totalCount);
                } catch (error) {
                    console.error("获取评论总数时出错:", error);
                }
            }

        }

        Connections {
            target: videoManager

            function onCommentsChanged() {
                console.log("评论列表已更新");
                updateCommentModel();
            }

            function onErrorOccurred(message) {
                console.error("发生错误:", message);
            }
        }

        Component.onCompleted: {
                console.log("视频播放器初始化完成");
                Qt.callLater(function() {
                    loadComments();
                });
            }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // 评论输入框
        TextField {
            id: commentInput
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(widthNum.height * 0.7, contentHeight + 20)
            placeholderText: "评论千万条，等你发一条"
            placeholderTextColor: "#777777"
            color: "white"
            font.pixelSize: 14
            wrapMode: Text.Wrap // 自动换行
            selectByMouse: true // 允许鼠标选择文本
            HoverHandler {
                     cursorShape: Qt.IBeamCursor
                 }
            background: Rectangle {
                    id: commentInputBg
                    color: "#1E1E1E"
                    radius: 5
                    border.width: 1
                    border.color: "transparent" // 初始透明边框

                    // 添加边框颜色动画
                    Behavior on border.color {
                        ColorAnimation { duration: 200 }
                    }
                }

                // 添加高度动画
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }

                // 聚焦变化处理
                onFocusChanged: {
                    if (focus) {
                        // 获得焦点时：显示粉色边框，增加高度
                        commentInputBg.border.color = "#FF6699"; // 粉色边框
                        Layout.preferredHeight = widthNum.height * 0.9; // 增加高度
                    } else {
                        // 失去焦点时：隐藏边框，恢复高度
                        commentInputBg.border.color = "transparent";
                        Layout.preferredHeight = widthNum.height * 0.7;
                    }
                }

                onTextChanged: {
                       if (activeFocus) {
                           Layout.preferredHeight = Math.max(widthNum.height * 0.9, contentHeight + 30);
                       } else {
                           Layout.preferredHeight = Math.max(widthNum.height * 0.7, contentHeight + 20);
                       }
                   }
        }

        // 表情和发送按钮行
        RowLayout {
            Button {
                Layout.preferredWidth: widthNum.width * 0.1
                Layout.preferredHeight: widthNum.height * 0.65
                Layout.leftMargin: 20
                text: "😊"
                font.pixelSize: 20
                HoverHandler {
                         cursorShape: Qt.PointingHandCursor
                     }
                background: Rectangle {
                    color: "transparent"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: sendButton
                Layout.preferredWidth: widthNum.width * 0.2
                Layout.preferredHeight: widthNum.height * 0.65
                Layout.rightMargin: 20
                text: "发送"
                font.pixelSize: 14
                font.bold: true
                HoverHandler {
                         cursorShape: Qt.PointingHandCursor
                     }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 5
                    color: parent.down ? "#FF5252" : "#FF6699"
                }

                onClicked: {
                    if (commentInput.text.trim() !== "") {
                        if (!userController.isLoggedIn) {
                            userController.errorOccurred("请先登录后再操作")
                            if (mainWindow && mainWindow.openLoginDialog)
                                mainWindow.openLoginDialog()
                            return
                        }

                        // 添加新评论
                        addComment("当前用户", commentInput.text.trim());

                        console.log(videoData.id)
                        commentInput.text = "";
                    }
                }
            }
        }

        // 评论列表
        ScrollView {
            Layout.topMargin: 15
            Layout.leftMargin: 20
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn

            // 添加打开动画
                opacity: 0
                y: 20
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                }
                Behavior on y {
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                }

                Component.onCompleted: {
                    if (animationsEnabled) {
                        opacity = 1;
                        y = 0;
                    }
                }

            ListView {
                id: commentList
                width: parent.width
                model: commentModel
                spacing: 10

                delegate: Rectangle {
                    id: commentDelegate
                    width: commentList.width
                    height: commentContent.height + 50
                    color: "transparent"


                           // 进入动画
                               opacity: 0
                               scale: 0.90
                               transformOrigin: Item.Top

                               Behavior on opacity {
                                   NumberAnimation { duration: 500; easing.type: Easing.OutQuad }
                               }
                               Behavior on scale {
                                   NumberAnimation { duration: 500; easing.type: Easing.OutBack }
                               }

                               Component.onCompleted: {
                                   if (animationsEnabled) {
                                       opacity = 1;
                                       scale = 1;
                                   }
                               }

                    // 评论项内容
                    Column {
                        id: commentContent
                        width: parent.width
                        spacing: 5

                        // 用户信息
                        Row {
                            width: parent.width
                            spacing: 10

                            // 用户头像
                            Rectangle {
                                id: userAvatar
                                width: videoPlayerPage.height/18
                                height: width
                                radius: width/2
                                color: "#3A3A3A"

                                Text {
                                    text: "头像"
                                    color: "white"
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                // 用户名
                                Text {
                                    text: model.userName
                                    color: "#AAAAAA"
                                    font.bold: true
                                    font.pixelSize: 14
                                }

                                // 发布时间
                                Text {
                                    text: model.time
                                    color: "#777777"
                                    font.pixelSize: 12
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        // 评论内容
                        Text {
                            width: parent.width - widthNum.width * 0.15
                            wrapMode: Text.Wrap
                            text: model.content
                            color: "white"
                            font.pixelSize: 14
                            leftPadding: userAvatar.width * 1.2
                            topPadding: 10
                            bottomPadding: 15
                        }

                        // 评论操作
                        Row {
                            width: parent.width
                            spacing: 30
                            leftPadding: userAvatar.width * 1.2

                            // 点赞按钮
                            Button {
                                id: likeButton
                                flat: true
                                padding: 0

                                property bool isLiked: false

                                HoverHandler {
                                         cursorShape: Qt.PointingHandCursor
                                     }

                                contentItem: Row {
                                    spacing: 5

                                    Image {
                                        source: likeButton.isLiked
                                               ? "qrc:/icons/heart.svg"
                                               : "qrc:/icons/heart_outline.svg"
                                        sourceSize.width: 18
                                        sourceSize.height: 18
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        text: model.likeCount
                                        color: "#AAAAAA"
                                        font.pixelSize: 12
                                    }
                                }

                                background: Rectangle {
                                    color: "transparent"
                                }

                                onClicked: {
                                    // if(likeButton.isLiked) {
                                    //     // commentModel.setProperty(index, "likeCount", model.likeCount - 1);
                                    //     videoManager.unlikeComment(videoData.id,model.id)
                                    //     likeButton.isLiked = false;
                                    // } else {
                                    //     // commentModel.setProperty(index, "likeCount", model.likeCount + 1);
                                    //     videoManager.likeComment(videoData.id,model.id)
                                    //     likeButton.isLiked = true;
                                    //     // 如果之前点踩了，取消点踩
                                    //     if(unlikeButton.isLiked) {
                                    //         // commentModel.setProperty(index, "unlikeCount", model.unlikeCount - 1);
                                    //         videoManager.unlikeComment(videoData.id,model.id)
                                    //         unlikeButton.isLiked = false;
                                    //     }
                                    // }
                                    videoManager.likeComment(videoData.id,model.id)
                                }
                            }

                            // 点踩按钮
                            Button {
                                id: unlikeButton
                                flat: true
                                padding: 0

                                property bool isLiked: false

                                HoverHandler {
                                         cursorShape: Qt.PointingHandCursor
                                     }

                                contentItem: Row {
                                    spacing: 5

                                    Text {
                                        text: unlikeButton.isLiked ? "👎" : "👇"
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        text: model.unlikeCount
                                        color: "#AAAAAA"
                                        font.pixelSize: 12
                                    }
                                }

                                background: Rectangle {
                                    color: "transparent"
                                }

                                onClicked: {
                                    // if(unlikeButton.isLiked) {
                                    //     commentModel.setProperty(index, "unlikeCount", model.unlikeCount - 1);
                                    //     unlikeButton.isLiked = false;
                                    // } else {
                                    //     commentModel.setProperty(index, "unlikeCount", model.unlikeCount + 1);
                                    //     unlikeButton.isLiked = true;
                                    //     // 如果之前点赞了，取消点赞
                                    //     if(likeButton.isLiked) {
                                    //         commentModel.setProperty(index, "likeCount", model.likeCount - 1);
                                    //         likeButton.isLiked = false;
                                    //     }
                                    // }
                                    videoManager.unlikeComment(videoData.id,model.id)
                                }
                            }

                            // 回复按钮
                            Button {
                                id: replyButton
                                flat: true
                                padding: 0

                                HoverHandler {
                                         cursorShape: Qt.PointingHandCursor
                                     }

                                contentItem: Row {
                                    spacing: 5

                                    Text {
                                        text: "↩️"
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        text: "回复"
                                        color: "#AAAAAA"
                                        font.pixelSize: 12
                                    }
                                }

                                background: Rectangle {
                                    color: "transparent"
                                }

                                onClicked: {
                                    replyInput.donhua = !replyInput.donhua
                                    replyInput.focus = replyInput.visible
                                    console.log(replyInput.commentIndex )
                                    // replyInput.visible = true
                                }
                            }
                        }

                        // 回复输入框
                        Column {
                            id: replyInput
                            width: parent.width
                            spacing: 5
                            topPadding: 10
                            property int commentIndex: index
                            property bool donhua: false

                            // 添加高度动画
                            height: donhua ? childrenRect.height : 0
                            opacity: donhua? 1 : 0

                                Behavior on height {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                }

                            TextField {
                                id: replyPerson
                                width: parent.width
                                placeholderText: "回复该人"
                                placeholderTextColor: "#777777"
                                color: "white"
                                font.pixelSize: 14
                                wrapMode: Text.Wrap // 自动换行
                                selectByMouse: true // 允许鼠标选择文本
                                background: Rectangle {
                                        id: replyInputBg
                                        color: "#1E1E1E"
                                        radius: 5
                                        border.width: 1
                                        border.color: "transparent" // 初始透明边框

                                        // 添加边框颜色动画
                                        Behavior on border.color {
                                            ColorAnimation { duration: 200 }
                                        }
                                    }

                                    // 添加高度动画
                                    Behavior on implicitHeight {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                    }

                                    // 聚焦变化处理
                                    onFocusChanged: {
                                        if (focus) {
                                            // 获得焦点时：显示粉色边框，增加高度
                                            replyInputBg.border.color = "#FF6699"; // 粉色边框
                                            implicitHeight = widthNum.height * 0.8; // 增加高度
                                        } else {
                                            // 失去焦点时：隐藏边框，恢复高度
                                            replyInputBg.border.color = "transparent";
                                            implicitHeight = widthNum.height * 0.6;
                                        }
                                    }

                                    onTextChanged: {
                                            if (activeFocus) {
                                                implicitHeight = Math.max(widthNum.height * 0.8, contentHeight + 25);
                                            } else {
                                                implicitHeight = Math.max(widthNum.height * 0.6, contentHeight + 15);
                                            }
                                        }

                            }

                            // 回复操作区域
                            RowLayout {
                                width: parent.width
                                spacing: 10

                                Button {
                                    Layout.preferredWidth: widthNum.width * 0.1
                                    Layout.preferredHeight: widthNum.height * 0.65
                                    HoverHandler {
                                             cursorShape: Qt.PointingHandCursor
                                         }
                                    text: "😊"
                                    font.pixelSize: 20
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Button {
                                    Layout.preferredWidth: widthNum.width * 0.2
                                    Layout.preferredHeight: widthNum.height * 0.65
                                    Layout.rightMargin: 20
                                    text: "发送"
                                    font.pixelSize: 14
                                    font.bold: true

                                    HoverHandler {
                                             cursorShape: Qt.PointingHandCursor
                                         }

                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        radius: 5
                                        color: parent.down ? "#FF5252" : "#FF6699"
                                    }

                                    onClicked: {
                                        if (!userController.isLoggedIn) {
                                            userController.errorOccurred("请先登录后再操作")
                                            if (mainWindow && mainWindow.openLoginDialog)
                                                mainWindow.openLoginDialog()
                                            return
                                        }

                                        if (replyPerson.text.trim() !== "") {
                                            // 获取当前评论的回复模型ID
                                            var commentId = commentModel.get(replyInput.commentIndex).id;

                                            // 添加新回复
                                            addReply(commentId, "当前用户", replyPerson.text.trim());

                                            replyPerson.text = ""
                                            replyInput.donhua = false
                                        }
                                    }
                                }
                            }
                        }

                        // 回复区域
                        Column {
                            id: replyArea
                            width: parent.width - 50
                            leftPadding: userAvatar.width * 1.2
                            topPadding: 10
                            spacing: 8

                            // 获取当前评论的回复模型
                            property var replyModel: model.replies || null

                            // 根据回复数量决定是否显示
                            visible: replyModel && replyModel.count > 0

                            property bool showAllReplies: false
                            property int commentIndex: index

                            // 整个回复区域背景
                            Rectangle {
                                id: replyContainer
                                width: parent.width - widthNum.width * 0.12
                                height: replyContent.height
                                color: "#1E1E1E"
                                radius: 5
                                border.color: "#333333"
                                border.width: 1

                                Column {
                                    id: replyContent
                                    width: parent.width - 20
                                    anchors.centerIn: parent
                                    spacing: 8
                                    padding: 10

                                    // 回复项
                                    Repeater {
                                        model: {
                                            if (!replyArea.replyModel) return 0;

                                            // 获取回复数量
                                            var replyCount = replyArea.replyModel.count;

                                            // 如果显示全部回复或回复数量小于等于3，返回所有回复
                                            if (replyArea.showAllReplies || replyCount <= 3) {
                                                return replyArea.replyModel;
                                            }
                                            // 否则只返回前3条回复
                                            var firstThree = [];
                                            for (var i = 0; i < 3; i++) {
                                                firstThree.push(replyArea.replyModel.get(i));
                                            }
                                            return firstThree;
                                        }

                                        delegate: Rectangle {
                                            width: parent.width
                                            height: replyItem.height + 10
                                            color: "transparent"
                                            property var replyData: model.modelData ? model.modelData : model

                                            Column {
                                                id: replyItem
                                                width: parent.width
                                                spacing: 5


                                                // 回复内容
                                                Text {
                                                    width: parent.width
                                                    wrapMode: Text.Wrap
                                                    textFormat: Text.RichText
                                                    text: "<b><font color='#AAAAAA'>" +
                                                          replyData.userName + ":</font></b> " +
                                                          "<font color='white'>" + replyData.content + "</font>"
                                                    font.pixelSize: 12
                                                }

                                                Button {
                                                    id: rrButton
                                                    flat: true
                                                    padding: 0

                                                    HoverHandler {
                                                             cursorShape: Qt.PointingHandCursor
                                                         }

                                                    contentItem: Row {
                                                        spacing: 5

                                                        Text {
                                                            text: "↩️"
                                                            font.pixelSize: 16
                                                        }

                                                        Text {
                                                            text: "回复"
                                                            color: "#AAAAAA"
                                                            font.pixelSize: 12
                                                        }
                                                    }

                                                    background: Rectangle {
                                                        color: "transparent"
                                                    }

                                                    onClicked: {
                                                        rreplyInput.donhua = !rreplyInput.donhua
                                                        rreplyInput.focus = rreplyInput.visible
                                                        rreplyInput.commentIndex = index
                                                        rreplyInput.targetUserName = replyData.userName // 设置目标用户名
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 查看更多回复按钮
                                    Button {
                                        id: showMoreButton
                                        visible: replyArea.replyModel && replyArea.replyModel.count > 3 && !replyArea.showAllReplies
                                        flat: true
                                        padding: 5
                                        width: parent.width
                                        height: widthNum.height * 0.5
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        HoverHandler {
                                                 cursorShape: Qt.PointingHandCursor
                                             }

                                        contentItem: Text {
                                            // text: "查看更多" + (replyArea.replyModel.count - 3) + "条回复"
                                            text:
                                            {
                                                if (!replyArea.replyModel) {
                                                            return "查看更多回复";
                                                }
                                                var count = replyArea.replyModel.count || 0;
                                                return "查看更多" + (count - 3) + "条回复";
                                            }

                                            color: "#AAAAAA"
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            color: "transparent"
                                            border.color: "#333333"
                                            border.width: 1
                                            radius: 5
                                        }

                                        onClicked: {
                                            replyArea.showAllReplies = true
                                        }
                                    }

                                    // 收起按钮
                                    Button {
                                        id: collapseButton
                                        visible: replyArea.showAllReplies
                                        flat: true
                                        padding: 5
                                        width: parent.width
                                        height: widthNum.height * 0.5
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        HoverHandler {
                                                 cursorShape: Qt.PointingHandCursor
                                             }

                                        contentItem: Text {
                                            text: "收起"
                                            color: "#AAAAAA"
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            color: "transparent"
                                            border.color: "#333333"
                                            border.width: 1
                                            radius: 5
                                        }

                                        onClicked: {
                                            replyArea.showAllReplies = false
                                        }
                                    }
                                }
                            }
                        }

                        //回复的回复输入
                        Column {
                            id: rreplyInput
                            width: parent.width
                            spacing: 5
                            topPadding: 10
                            property int commentIndex: -1
                            property bool donhua: false
                            property string targetUserName

                            // 添加高度动画
                            height: donhua ? childrenRect.height : 0
                            opacity: donhua? 1 : 0

                                Behavior on height {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                }

                            TextField {
                                id: rreplyPerson
                                width: parent.width
                                placeholderText: "回复该人"
                                placeholderTextColor: "#777777"
                                color: "white"
                                font.pixelSize: 14
                                wrapMode: Text.Wrap // 自动换行
                                selectByMouse: true // 允许鼠标选择文本
                                background: Rectangle {
                                        id: rreplyInputBg
                                        color: "#1E1E1E"
                                        radius: 5
                                        border.width: 1
                                        border.color: "transparent" // 初始透明边框

                                        // 添加边框颜色动画
                                        Behavior on border.color {
                                            ColorAnimation { duration: 200 }
                                        }
                                    }

                                    // 添加高度动画
                                    Behavior on implicitHeight {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                    }

                                    // 聚焦变化处理
                                    onFocusChanged: {
                                        if (focus) {
                                            // 获得焦点时：显示粉色边框，增加高度
                                            rreplyInputBg.border.color = "#FF6699"; // 粉色边框
                                            implicitHeight = widthNum.height * 0.8; // 增加高度
                                        } else {
                                            // 失去焦点时：隐藏边框，恢复高度
                                            rreplyInputBg.border.color = "transparent";
                                            implicitHeight = widthNum.height * 0.6;
                                        }
                                    }

                                    onTextChanged: {
                                            if (activeFocus) {
                                                implicitHeight = Math.max(widthNum.height * 0.8, contentHeight + 25);
                                            } else {
                                                implicitHeight = Math.max(widthNum.height * 0.6, contentHeight + 15);
                                            }
                                        }

                            }

                            // 回复操作区域
                            RowLayout {
                                width: parent.width
                                spacing: 10

                                Button {
                                    Layout.preferredWidth: widthNum.width * 0.1
                                    Layout.preferredHeight: widthNum.height * 0.65
                                    HoverHandler {
                                             cursorShape: Qt.PointingHandCursor
                                         }
                                    text: "😊"
                                    font.pixelSize: 20
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Button {
                                    Layout.preferredWidth: widthNum.width * 0.2
                                    Layout.preferredHeight: widthNum.height * 0.65
                                    Layout.rightMargin: 20
                                    text: "发送"
                                    font.pixelSize: 14
                                    font.bold: true

                                    HoverHandler {
                                             cursorShape: Qt.PointingHandCursor
                                         }

                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        radius: 5
                                        color: parent.down ? "#FF5252" : "#FF6699"
                                    }

                                    onClicked: {
                                        if (!userController.isLoggedIn) {
                                            userController.errorOccurred("请先登录后再操作")
                                            if (mainWindow && mainWindow.openLoginDialog)
                                                mainWindow.openLoginDialog()
                                            return
                                        }

                                        if (rreplyPerson.text.trim() !== "") {
                                            // 获取当前评论的回复模型ID
                                            var commentId = commentModel.get(replyInput.commentIndex).id;

                                            var content = "回复 @" + rreplyInput.targetUserName + ": " + rreplyPerson.text.trim();

                                            // 添加新回复
                                            addReply(commentId, "当前用户", content);

                                            rreplyPerson.text = ""
                                            rreplyInput.donhua = false
                                            // console.log("这是儿：" + replyInput.commentIndex)
                                            // console.log("这是儿：" + commentId)

                                        }
                                        else
                                            rreplyInput.donhua = false
                                    }
                                }
                            }
                        }  //回复的回复

                    }   //评论项

                    // 分隔线
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: "#333333"
                    }
                }   //delegate
            }
        }  //评论部分

    }
}
