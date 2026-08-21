//视频上传页面（竖排单列，B站风格）

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window

Item {
    id: videoLode
    width: 800
    height: 750

    // 公共属性
    property alias buttonText: uploadButton.text
    property alias progressVisible: progressBar.visible
    property alias progressValue: progressBar.value
    property alias progressText: progressText.text
    property alias statusText: statusText.text

    // 信号
    signal uploadStarted(string filePath, string title, string description, string coverPath, var tags)
    signal uploadCancelled()
    signal fileSelected(string filePath)
    signal coverSelected(string coverPath)
    signal uploadFinished(string videoUrl, string coverUrl)
    signal uploadError(string error)

    // 选择的文件路径
    property string selectedVideoPath: ""
    property string selectedCoverPath: ""
    property string videoTitle: ""
    property string videoDescription: ""
    property var selectedTags: []
    property var mainWindow   // 主窗口引用，用于未登录时打开登录框

    // 预定义标签
    property var predefinedTags: [
        "科技", "教育", "娱乐", "音乐", "游戏", "生活", "美食", "旅行",
        "体育", "健身", "时尚", "美妆", "宠物", "动漫", "电影", "读书",
        "编程", "设计", "摄影", "舞蹈", "汽车", "财经", "健康", "搞笑"
    ]

    // 上传器
    VideolodeFunction {
        id: uploader

        onUploadProgress: function(bytesSent, bytesTotal) {
            progressBar.value = bytesSent
            progressBar.to = bytesTotal
            var percent = bytesTotal > 0 ? Math.round((bytesSent / bytesTotal) * 100) : 0
            progressText.text = "上传进度: " + percent + "%"
        }

        onUploadFinished: function(videoUrl, coverUrl) {
            progressText.text = "上传完成!"
            statusText.text = "视频URL: " + videoUrl + "\n封面URL: " + coverUrl
            uploadButton.enabled = true
            progressBar.visible = false
            cancelButton.visible = false
            statusLog.text += "上传完成! 视频URL: " + videoUrl + "\n"
            videoLode.uploadFinished(videoUrl, coverUrl)
            resetForm()
        }

        onUploadError: function(error) {
            progressText.text = "上传错误"
            statusText.text = "错误: " + error
            uploadButton.enabled = true
            progressBar.visible = false
            cancelButton.visible = false
            statusLog.text += "上传错误: " + error + "\n"
            videoLode.uploadError(error)
        }

        onUploadCancelled: {
            progressText.text = "上传已取消"
            statusText.text = ""
            uploadButton.enabled = true
            progressBar.visible = false
            cancelButton.visible = false
            statusLog.text += "上传已取消\n"
        }
    }

    // 背景
    Rectangle {
        anchors.fill: parent
        color: "#f6f7f8"
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

        contentWidth: contentLayout.width
        contentHeight: contentLayout.height

        ColumnLayout {
            id: contentLayout
            width: scrollView.width - 20
            anchors.margins: 20
            spacing: 14

            // 页头
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                Rectangle {
                    width: 46
                    height: 46
                    radius: 12
                    color: "#FB7299"

                    Text {
                        anchors.centerIn: parent
                        text: "📹"
                        font.pixelSize: 22
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "上传视频"
                        font.pixelSize: 22
                        font.bold: true
                        color: "#18191C"
                    }

                    Text {
                        text: "上传你的创作，分享给全世界"
                        font.pixelSize: 12
                        color: "#9499A0"
                    }
                }
            }

            // 视频文件卡片
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                radius: 12
                color: "#FFFFFF"
                border.color: selectedVideoPath ? "#FB7299" : "#E3E5E7"
                border.width: selectedVideoPath ? 2 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text {
                        text: "视频文件"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#18191C"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: "#F6F7F8"
                        border.color: selectVideoHover.hovered ? "#FB7299" : "#E3E5E7"
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 12

                            Text {
                                text: selectedVideoPath ? "🎬" : "📁"
                                font.pixelSize: 28
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: selectedVideoPath ? getFileName(selectedVideoPath) : "点击选择视频文件"
                                    font.pixelSize: 13
                                    color: selectedVideoPath ? "#61666D" : "#18191C"
                                    font.bold: !selectedVideoPath
                                }

                                Text {
                                    text: "支持 mp4 / avi / mov / mkv 等，最大 2GB"
                                    font.pixelSize: 11
                                    color: "#C9CCD0"
                                }
                            }
                        }

                        HoverHandler {
                            id: selectVideoHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: videoFileDialog.open()
                        }
                    }
                }
            }

            // 封面卡片
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 210
                radius: 12
                color: "#FFFFFF"
                border.color: selectedCoverPath ? "#FB7299" : "#E3E5E7"
                border.width: selectedCoverPath ? 2 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "封面图"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#18191C"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "可选"
                            font.pixelSize: 11
                            color: "#9499A0"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 240
                            Layout.fillHeight: true
                            radius: 8
                            color: "#F6F7F8"
                            border.color: "#E3E5E7"
                            border.width: 1
                            clip: true

                            Image {
                                id: coverImage
                                anchors.fill: parent
                                source: selectedCoverPath ? "file:///" + selectedCoverPath : ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            Text {
                                anchors.centerIn: parent
                                text: selectedCoverPath ? "" : "🖼️"
                                font.pixelSize: 30
                                color: "#C9CCD0"
                            }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: coverFileDialog.open()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: selectedCoverPath ? "已选择封面: " + getFileName(selectedCoverPath) : "未选择封面（将使用默认封面）"
                                font.pixelSize: 12
                                color: selectedCoverPath ? "#61666D" : "#9499A0"
                                wrapMode: Text.Wrap
                            }

                            Button {
                                text: selectedCoverPath ? "更换封面" : "选择封面"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                flat: true
                                background: Rectangle {
                                    color: parent.hovered ? "#FFF0F3" : "#F6F7F8"
                                    radius: 8
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "#FB7299"
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: coverFileDialog.open()
                            }

                            Button {
                                text: "移除封面"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                flat: true
                                visible: selectedCoverPath
                                background: Rectangle {
                                    color: parent.hovered ? "#F1F2F3" : "transparent"
                                    radius: 8
                                }
                                contentItem: Text {
                                    text: "移除封面"
                                    color: "#61666D"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    selectedCoverPath = ""
                                    coverImage.source = ""
                                    coverSelected("")
                                    statusLog.text += "已移除封面\n"
                                }
                            }
                        }
                    }
                }
            }

            // 视频信息卡片
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                radius: 12
                color: "#FFFFFF"
                border.color: "#E3E5E7"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "视频信息"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#18191C"
                    }

                    Text {
                        text: "标题 *"
                        font.pixelSize: 12
                        color: "#61666D"
                    }

                    TextField {
                        id: titleInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "请输入视频标题"
                        placeholderTextColor: "#C9CCD0"
                        font.pixelSize: 14
                        color: "#18191C"
                        text: videoTitle
                        onTextChanged: videoTitle = text

                        background: Rectangle {
                            color: "#F6F7F8"
                            radius: 8
                            border.color: titleInput.focus ? "#FB7299" : "transparent"
                            border.width: 1
                        }
                    }

                    Text {
                        text: "简介"
                        font.pixelSize: 12
                        color: "#61666D"
                    }

                    TextArea {
                        id: descriptionInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "介绍一下你的视频内容..."
                        placeholderTextColor: "#C9CCD0"
                        font.pixelSize: 13
                        color: "#18191C"
                        wrapMode: TextArea.Wrap
                        text: videoDescription
                        onTextChanged: videoDescription = text

                        background: Rectangle {
                            color: "#F6F7F8"
                            radius: 8
                            border.color: descriptionInput.focus ? "#FB7299" : "transparent"
                            border.width: 1
                        }
                    }
                }
            }

            // 标签卡片
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                radius: 12
                color: "#FFFFFF"
                border.color: "#E3E5E7"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "标签"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#18191C"
                    }

                    GridLayout {
                        columns: 10
                        Layout.fillWidth: true
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: predefinedTags

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: 60
                                radius: 15
                                color: selectedTags.includes(modelData) ? "#FB7299" : "#F6F7F8"
                                border.color: selectedTags.includes(modelData) ? "#FB7299" : "#E3E5E7"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: selectedTags.includes(modelData) ? "white" : "#61666D"
                                    font.pixelSize: 12
                                }

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        if (selectedTags.includes(modelData)) {
                                            var index = selectedTags.indexOf(modelData);
                                            selectedTags.splice(index, 1);
                                        } else {
                                            selectedTags.push(modelData);
                                        }
                                        selectedTagsChanged();
                                        statusLog.text += "标签更新: " + selectedTags.join(", ") + "\n";
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: customTagInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            placeholderText: "自定义标签，用逗号分隔"
                            placeholderTextColor: "#C9CCD0"
                            font.pixelSize: 13
                            color: "#18191C"
                            onAccepted: addCustomTags()

                            background: Rectangle {
                                color: "#F6F7F8"
                                radius: 8
                                border.color: customTagInput.focus ? "#FB7299" : "transparent"
                                border.width: 1
                            }
                        }

                        Button {
                            text: "添加"
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 36
                            flat: true
                            background: Rectangle {
                                color: parent.hovered ? "#F06A93" : "#FB7299"
                                radius: 8
                            }
                            contentItem: Text {
                                text: "添加"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: addCustomTags()
                        }
                    }

                    GridLayout {
                        columns: 6
                        Layout.fillWidth: true
                        columnSpacing: 8
                        rowSpacing: 8
                        visible: selectedTags.length > 0

                        Repeater {
                            model: selectedTags

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: 100
                                radius: 15
                                color: "#FFF0F3"
                                border.color: "#FB7299"
                                border.width: 1

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 26
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: "#FB7299"
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "×"
                                    color: "#FB7299"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        var index = selectedTags.indexOf(modelData);
                                        if (index !== -1) {
                                            selectedTags.splice(index, 1);
                                            selectedTagsChanged();
                                            statusLog.text += "移除标签: " + modelData + "\n";
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 上传操作区
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 230
                radius: 12
                color: "#FFFFFF"
                border.color: "#E3E5E7"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    ProgressBar {
                        id: progressBar
                        Layout.fillWidth: true
                        visible: false
                        from: 0
                        to: 100
                        value: 0

                        background: Rectangle {
                            implicitHeight: 8
                            color: "#F1F2F3"
                            radius: 4
                        }

                        contentItem: Item {
                            implicitHeight: 8

                            Rectangle {
                                width: progressBar.visualPosition * parent.width
                                height: parent.height
                                radius: 4
                                color: "#FB7299"
                            }
                        }
                    }

                    Text {
                        id: progressText
                        text: "准备就绪"
                        font.pixelSize: 13
                        color: "#61666D"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Button {
                            id: uploadButton
                            text: "🚀 开始上传"
                            Layout.preferredWidth: 220
                            Layout.preferredHeight: 46
                            enabled: selectedVideoPath && titleInput.text.trim() !== ""

                            background: Rectangle {
                                color: uploadButton.enabled
                                       ? (uploadButton.hovered ? "#F06A93" : "#FB7299")
                                       : "#E3E5E7"
                                radius: 23
                            }

                            contentItem: Text {
                                text: uploadButton.text
                                color: uploadButton.enabled ? "white" : "#9499A0"
                                font.pixelSize: 15
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: startUpload()
                        }

                        Button {
                            id: cancelButton
                            text: "取消上传"
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 46
                            visible: false

                            background: Rectangle {
                                color: cancelButton.hovered ? "#F1F2F3" : "transparent"
                                radius: 23
                                border.color: "#E3E5E7"
                                border.width: 1
                            }

                            contentItem: Text {
                                text: cancelButton.text
                                color: "#61666D"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                uploader.cancelUpload()
                                uploadCancelled()
                            }
                        }
                    }

                    TextArea {
                        id: statusText
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        placeholderText: "上传状态将显示在这里..."
                        readOnly: true
                        font.pixelSize: 12
                        color: "#61666D"
                        wrapMode: TextArea.Wrap
                        visible: false
                    }

                    TextArea {
                        id: statusLog
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readOnly: true
                        placeholderText: "日志..."
                        font.pixelSize: 11
                        color: "#C9CCD0"
                        wrapMode: TextArea.Wrap
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
            }
        }
    }

    // 文件选择对话框
    FileDialog {
        id: videoFileDialog
        title: "选择视频文件"
        nameFilters: ["视频文件 (*.mp4 *.avi *.mov *.mkv *.flv *.wmv)"]
        currentFolder: ""

        onAccepted: {
            var fileUrl = selectedFile;
            if (!fileUrl && selectedFiles.length > 0) {
                fileUrl = selectedFiles[0];
            }
            if (fileUrl) {
                var filePath = toLocalPath(fileUrl.toString());
                selectedVideoPath = filePath
                fileSelected(filePath)
                statusLog.text += "选择了视频文件: " + getFileName(filePath) + "\n"
            }
        }
    }

    FileDialog {
        id: coverFileDialog
        title: "选择封面图片"
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.bmp *.gif)"]
        currentFolder: ""

        onAccepted: {
            var fileUrl = selectedFile;
            if (!fileUrl && selectedFiles.length > 0) {
                fileUrl = selectedFiles[0];
            }
            if (fileUrl) {
                var filePath = toLocalPath(fileUrl.toString());
                selectedCoverPath = filePath
                coverSelected(filePath)
                statusLog.text += "选择了封面文件: " + getFileName(filePath) + "\n"
            }
        }
    }

    // 添加自定义标签函数
    function addCustomTags() {
        var customTags = customTagInput.text.split(/[,，]/).map(tag => tag.trim()).filter(tag => tag !== "");

        customTags.forEach(tag => {
            if (!selectedTags.includes(tag)) {
                selectedTags.push(tag);
            }
        });

        customTagInput.text = "";
        selectedTagsChanged();
        statusLog.text += "添加自定义标签: " + customTags.join(", ") + "\n";
    }

    function startUpload() {
        if (!userController.isLoggedIn) {
            statusText.visible = true
            statusText.text = "请先登录后再上传"
            if (mainWindow && mainWindow.openLoginDialog)
                mainWindow.openLoginDialog()
            return
        }

        if (!selectedVideoPath) {
            statusText.visible = true
            statusText.text = "请先选择视频文件"
            return
        }

        if (!videoTitle.trim()) {
            statusText.visible = true
            statusText.text = "请输入视频标题"
            return
        }

        console.log("开始上传流程 - 文件:", selectedVideoPath);
        console.log("封面:", selectedCoverPath);
        console.log("标题:", videoTitle);
        console.log("描述:", videoDescription);
        console.log("标签:", selectedTags);

        uploadButton.enabled = false
        progressBar.visible = true
        progressBar.value = 0
        progressText.text = "准备上传..."
        statusText.visible = true
        statusText.text = "文件: " + getFileName(selectedVideoPath) + "\n标题: " + videoTitle + "\n标签: " + selectedTags.join(", ")
        cancelButton.visible = true

        uploadStarted(selectedVideoPath, videoTitle, videoDescription, selectedCoverPath, selectedTags)
        statusLog.text += "开始上传: " + getFileName(selectedVideoPath) + " 标签: " + selectedTags.join(", ") + "\n"

        uploader.uploadVideo(selectedVideoPath, videoTitle, videoDescription, selectedCoverPath, selectedTags.join(","))
    }

    // 工具函数
    function toLocalPath(urlStr) {
        var s = urlStr.toString();
        if (s.startsWith("file:///")) return s.substring(8);
        if (s.startsWith("file://")) return s.substring(7);
        return s;
    }

    function getFileName(filePath) {
        var path = filePath.toString().replace("file://", "");
        var lastSlash = path.lastIndexOf("/");
        return lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
    }

    function resetForm() {
        selectedVideoPath = ""
        selectedCoverPath = ""
        videoTitle = ""
        videoDescription = ""
        selectedTags = []
        titleInput.text = ""
        descriptionInput.text = ""
        customTagInput.text = ""
        coverImage.source = ""
        uploadButton.enabled = true
        progressBar.visible = false
        progressBar.value = 0
        progressText.text = "准备就绪"
        statusText.text = ""
        statusText.visible = false
        cancelButton.visible = false
    }

    function reset() {
        resetForm()
    }

    function setProgress(percent) {
        progressBar.value = percent
        progressText.text = "上传进度: " + percent + "%"
    }

    function setStatus(message) {
        statusText.visible = true
        statusText.text = message
    }
}
