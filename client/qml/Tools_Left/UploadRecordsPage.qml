// 侧栏"上传记录"：展示本次运行里每个上传任务的转码状态。
// 每个任务列出 原画/480P/720P/1080P 条目与各自百分比；无删除按钮（临时数据，关闭应用清空）。
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: recordsPage
    width: 900
    height: 720

    signal closeRequested()

    // 根据高度推断应显示的档位（与转码器一致：1080p 源显示 1080/720/480）
    function neededQualities(h, w) {
        var vh = Number(h || 0)
        var vw = Number(w || 0)
        var base = vh > 0 ? vh : Math.max(vw, vh)
        if (base >= 1080) return [1080, 720, 480]
        if (base >= 720) return [720, 480]
        if (base >= 480) return [480]
        return []
    }

    function qualityStatus(q, task) {
        // 返回 {label, text, ok, percent}
        var doneMap = {}
        var arr = task.qualities || []
        for (var i = 0; i < arr.length; i++) {
            var qq = Number(arr[i].quality || 0)
            if (qq > 0) doneMap[qq] = true
        }
        var prog = {}
        var tarr = task.tasks || []
        for (var j = 0; j < tarr.length; j++) {
            var tv = tarr[j]
            prog[Number(tv.quality)] = {st: Number(tv.status || 0), p: Number(tv.progress || 0)}
        }
        if (doneMap[q]) return {label: q + "P", text: "已完成", ok: true}
        var t = prog[q]
        if (t && t.st === 3) return {label: q + "P", text: "失败", ok: false}
        if (t && t.st === 1) return {label: q + "P", text: t.p + "%", ok: false}
        return {label: q + "P", text: "等待", ok: false}
    }

    Rectangle {
        anchors.fill: parent
        color: "#F6F7F8"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // 页头
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 42
                height: 42
                radius: 10
                color: "#FB7299"
                Text {
                    anchors.centerIn: parent
                    text: "📤"
                    font.pixelSize: 20
                }
            }

            Column {
                spacing: 2
                Text {
                    text: "上传记录"
                    font.pixelSize: 19
                    font.bold: true
                    color: "#18191C"
                }
                Text {
                    text: "上传与各清晰度转码进度（本次运行，关闭应用后清空）"
                    font.pixelSize: 12
                    color: "#9499A0"
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "关闭"
                Layout.preferredHeight: 34
                flat: true
                background: Rectangle {
                    color: parent.hovered ? "#FFF0F3" : "#FFFFFF"
                    radius: 8
                    border.color: "#E3E5E7"
                    border.width: 1
                }
                contentItem: Text {
                    text: "关闭"
                    font.pixelSize: 13
                    color: "#61666D"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: recordsPage.closeRequested()
            }
        }

        // 空状态
        Text {
            visible: videoController.uploadTasks.length === 0
            text: "暂无上传记录\n在“上传视频”里发布后会显示在这里"
            font.pixelSize: 15
            color: "#C9CCD0"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: 80
        }

        // 任务卡片
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 12

                Repeater {
                    model: videoController.uploadTasks

                    Rectangle {
                        // 当前任务（避免嵌套 Repeater 的 modelData 重名混淆）
                        property var task: modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 112
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E3E5E7"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 8
                                    color: task.stage === "failed" ? "#FDEBEB"
                                         : (task.stage === "uploaded" ? "#E8F8EF" : "#FFF0F3")
                                    Text {
                                        anchors.centerIn: parent
                                        text: task.stage === "failed" ? "❌"
                                            : (task.stage === "uploaded" ? "✅" : "⏳")
                                        font.pixelSize: 16
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Text {
                                        text: task.title || task.fileName || "未命名"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#18191C"
                                        elide: Text.ElideRight
                                        width: 320
                                    }
                                    Text {
                                        text: task.statusText || "等待上传"
                                        font.pixelSize: 11
                                        color: task.stage === "failed" ? "#D33A3A" : "#61666D"
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: task.stage === "uploading"
                                          ? ("上传中 " + (task.progress || 0) + "%")
                                          : (task.stage === "failed" ? "失败" : "已上传")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: task.stage === "failed" ? "#D33A3A"
                                         : (task.stage === "uploaded" ? "#1B8A5A" : "#FB7299")
                                }
                            }

                            // 分辨率条目：原画 + 480/720/1080
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: {
                                        var items = [{label: "原画", text: "完成", ok: true}]
                                        var need = recordsPage.neededQualities(
                                                    task.height, task.width)
                                        for (var i = 0; i < need.length; i++) {
                                            var st = recordsPage.qualityStatus(need[i], task)
                                            items.push(st)
                                        }
                                        return items
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 180
                                        Layout.preferredHeight: 42
                                        radius: 8
                                        color: modelData.ok ? "#F0FAF5" : "#F6F7F8"
                                        border.color: modelData.ok ? "#BFE6CF" : "#E3E5E7"
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            Text {
                                                text: modelData.label
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: modelData.ok ? "#1B8A5A" : "#61666D"
                                            }
                                            Text {
                                                text: modelData.text
                                                font.pixelSize: 11
                                                color: modelData.ok ? "#1B8A5A"
                                                     : (modelData.text === "失败" ? "#D33A3A" : "#9499A0")
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
    }
}
