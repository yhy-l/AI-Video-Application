import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 置顶桌面宠物：小悬浮窗（无边框、始终置顶、可拖动），点击展开聊天面板，
// AI 回复以气泡显示在宠物窗口上
Window {
    id: petWindow
    width: 320
    height: collapsed ? 96 : 540
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    visible: true
    color: "transparent"

    property bool collapsed: true
    property string sessionId: ""
    property bool waiting: false

    Behavior on height {
        NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
    }

    // 主面板
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#F5F6F8"
        border.color: "#E3E5E7"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // 头部：宠物图标 + 标题 + 收起/关闭
            Rectangle {
                id: petHeader
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#FB7299"
                radius: 14

                MouseArea {
                    anchors.fill: parent

                    // 顶层窗口不能用 drag.target，需手动按偏移移动窗口
                    property point pressPos: Qt.point(0, 0)
                    property bool dragging: false

                    onPressed: function(mouse) {
                        pressPos = Qt.point(mouse.x, mouse.y)
                        dragging = false
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed || dragging)
                            return
                        var dx = mouse.x - pressPos.x
                        var dy = mouse.y - pressPos.y
                        if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                            dragging = true
                            // 优先系统原生拖动，否则手动移动
                            if (typeof petWindow.startSystemMove === "function"
                                    && petWindow.startSystemMove()) {
                                return
                            }
                        }
                        if (dragging) {
                            petWindow.x += dx
                            petWindow.y += dy
                            pressPos = Qt.point(mouse.x, mouse.y)
                        }
                    }

                    onClicked: function() {
                        // 拖动不算点击：只有原地点击才展开/收起
                        if (!dragging)
                            petWindow.collapsed = !petWindow.collapsed
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    // 宠物头像
                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 23
                        color: "#FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: "🐱"
                            font.pixelSize: 26
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "AI 智能助手"
                            color: "white"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: petWindow.waiting ? "思考中..." : (petWindow.collapsed ? "点击开始聊天" : "多轮对话 · 业务数据加持")
                            color: "#FFFFFF99"
                            font.pixelSize: 11
                        }
                    }

                    Button {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        text: petWindow.collapsed ? "✕" : "—"
                        flat: true
                        padding: 0

                        background: Rectangle {
                            color: parent.hovered ? "#CCFFFFFF" : "transparent"
                            radius: 13
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            if (petWindow.collapsed) {
                                petWindow.close()
                            } else {
                                petWindow.collapsed = true
                            }
                        }
                    }
                }
            }

            // 消息列表
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !petWindow.collapsed
                color: "#FFFFFF"
                radius: 12
                clip: true

                ListView {
                    id: msgList
                    anchors.fill: parent
                    anchors.margins: 8
                    model: msgModel
                    spacing: 8
                    clip: true

                    onCountChanged: {
                        positionViewAtEnd()
                    }

                    delegate: ColumnLayout {
                        width: msgList.width
                        spacing: 3

                        Rectangle {
                            Layout.alignment: model.sender === "user" ? Qt.AlignRight : Qt.AlignLeft
                            Layout.maximumWidth: msgList.width * 0.8
                            Layout.preferredWidth: textItem.implicitWidth + 24
                            Layout.preferredHeight: textItem.implicitHeight + 18
                            radius: 10
                            color: model.sender === "user" ? "#FB7299" : "#F1F2F3"

                            Text {
                                id: textItem
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, msgList.width * 0.8 - 24)
                                text: model.text
                                color: model.sender === "user" ? "white" : "#333333"
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                            }
                        }

                        Text {
                            Layout.alignment: model.sender === "user" ? Qt.AlignRight : Qt.AlignLeft
                            visible: model.tools !== ""
                            text: "🔧 调用了工具: " + model.tools
                            color: "#AAAAAA"
                            font.pixelSize: 10
                        }
                    }
                }

                // 空状态
                Text {
                    anchors.centerIn: parent
                    visible: msgModel.count === 0 && !petWindow.waiting
                    text: "喵～ 问我点什么吧\n比如：推荐点视频看 / 我最近看过什么"
                    color: "#BBBBBB"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.6
                }

                // 思考中指示
                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 12
                    visible: petWindow.waiting
                    spacing: 6

                    BusyIndicator {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        running: true
                    }

                    Text {
                        text: "AI 正在思考..."
                        color: "#999999"
                        font.pixelSize: 12
                    }
                }
            }

            // 输入行
            RowLayout {
                Layout.fillWidth: true
                visible: !petWindow.collapsed
                spacing: 8

                TextField {
                    id: input
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    placeholderText: "和 AI 助手说点什么..."
                    placeholderTextColor: "#AAAAAA"
                    color: "#333333"
                    font.pixelSize: 13
                    selectByMouse: true

                    background: Rectangle {
                        color: "#FFFFFF"
                        radius: 19
                        border.color: input.focus ? "#FB7299" : "#E3E5E7"
                        border.width: 1
                    }

                    Keys.onReturnPressed: sendMessage()
                    Keys.onEnterPressed: sendMessage()
                }

                Button {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 38
                    text: "发送"

                    background: Rectangle {
                        color: parent.hovered ? "#F06A93" : "#FB7299"
                        radius: 19
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: sendMessage()
                }
            }

            // 清空会话
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                visible: !petWindow.collapsed && msgModel.count > 0
                text: "清空对话"
                flat: true

                contentItem: Text {
                    text: parent.text
                    color: "#999999"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    msgModel.clear()
                    petWindow.sessionId = ""
                }
            }
        }
    }

    ListModel {
        id: msgModel
    }

    function sendMessage() {
        var q = input.text.trim()
        if (!q || petWindow.waiting) return
        msgModel.append({sender: "user", text: q, tools: ""})
        input.text = ""
        petWindow.waiting = true
        aiClient.sendMessage(petWindow.sessionId, q)
    }

    Connections {
        target: aiClient

        function onReplyReady(sid, answer, toolsUsed) {
            petWindow.waiting = false
            if (sid)
                petWindow.sessionId = sid
            msgModel.append({
                sender: "ai",
                text: answer || "（无回复）",
                tools: toolsUsed ? toolsUsed.join("、") : ""
            })
            msgList.positionViewAtEnd()
        }

        function onErrorOccurred(message) {
            petWindow.waiting = false
            msgModel.append({sender: "ai", text: "⚠ " + message, tools: ""})
        }
    }
}
