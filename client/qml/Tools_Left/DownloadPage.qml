import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// 下载管理页：展示下载任务与进度（真实异步下载，不阻塞界面）
Rectangle {
    id: downloadPage
    color: "#f4f4f4"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // 标题栏
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "下载管理"
                font.pixelSize: 20
                font.bold: true
                color: "#18191C"
            }

            Text {
                text: downloadManager.downloads.length + " 个任务"
                font.pixelSize: 12
                color: "#9499A0"
                Layout.bottomMargin: 3
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 36
                text: "打开下载文件夹"

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                background: Rectangle {
                    color: parent.hovered ? "#F06A93" : "#FB7299"
                    radius: 18
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: downloadManager.openDownloadDir()
            }
        }

        // 下载目录
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "#FFFFFF"
            radius: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Image {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    source: "qrc:/icons/folder.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    text: "下载位置: " + (downloadManager.downloadDir || "未设置")
                    font.pixelSize: 13
                    color: "#333333"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        // 任务列表
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#FFFFFF"
            radius: 12
            clip: true

            ListView {
                id: downloadList
                anchors.fill: parent
                model: downloadManager.downloads
                spacing: 1
                clip: true

                delegate: Rectangle {
                    width: downloadList.width
                    height: 76
                    color: "#FFFFFF"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        Image {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: "qrc:/icons/download.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.title || "未命名视频"
                                font.pixelSize: 14
                                color: "#18191C"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ProgressBar {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    from: 0
                                    to: 100
                                    value: modelData.progress || 0

                                    background: Rectangle {
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        radius: 3
                                        color: "#E3E5E7"
                                    }

                                    contentItem: Rectangle {
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        radius: 3
                                        color: "#FB7299"
                                        width: parent.width * parent.visualPosition
                                    }
                                }

                                Text {
                                    text: modelData.status + " " + (modelData.progress || 0) + "%"
                                    font.pixelSize: 12
                                    color: modelData.status === "已完成" ? "#00A1D6" : "#666666"
                                }
                            }
                        }

                        Text {
                            text: formatSize(modelData.received)
                            font.pixelSize: 12
                            color: "#9499A0"

                            function formatSize(bytes) {
                                if (!bytes) return "0 B"
                                if (bytes < 1024 * 1024)
                                    return (bytes / 1024).toFixed(1) + " KB"
                                return (bytes / 1024 / 1024).toFixed(1) + " MB"
                            }
                        }
                    }
                }
            }

            // 空状态
            Column {
                anchors.centerIn: parent
                visible: downloadManager.downloads.length === 0
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📥"
                    font.pixelSize: 40
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "还没有下载任务"
                    font.pixelSize: 15
                    color: "#999999"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "在视频播放页点击下载按钮即可加入"
                    font.pixelSize: 12
                    color: "#BBBBBB"
                }
            }
        }
    }
}
