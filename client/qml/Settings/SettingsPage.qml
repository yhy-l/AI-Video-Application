import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// 设置页：只保留已实现的功能。
// 夜间模式会真实切换主界面配色；其余设置项（快捷键/推送/下载/缓存/手柄等）
// 仅保留已实现的功能
Item {
    id: settingsRoot
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#F6F7F8"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        Text {
            text: "设置"
            font.pixelSize: 22
            font.bold: true
            color: "#18191C"
        }

        Text {
            text: "目前只开放已实现的功能项"
            font.pixelSize: 12
            color: "#9499A0"
            Layout.bottomMargin: 8
        }

        // 外观 - 夜间模式（真实生效）
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 130
            color: "#FFFFFF"
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "外观"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#18191C"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "夜间模式"
                        font.pixelSize: 14
                        color: "#333333"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ComboBox {
                        id: themeCombo
                        Layout.preferredWidth: 130
                        model: ["浅色", "深色"]
                        currentIndex: appSettings && appSettings.darkMode ? 1 : 0

                        onActivated: {
                            if (appSettings)
                                appSettings.darkMode = (index === 1)
                        }
                    }
                }
            }
        }

        // 下载设置
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            color: "#FFFFFF"
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "下载"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#18191C"
                }

                Text {
                    text: "下载目录: " + (downloadManager.downloadDir || "未设置")
                    font.pixelSize: 13
                    color: "#666666"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 34
                        text: "选择文件夹"

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

                        onClicked: folderDialog.open()
                    }

                    Button {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 34
                        text: "打开文件夹"

                        background: Rectangle {
                            color: parent.hovered ? "#F1F2F3" : "#FFFFFF"
                            radius: 17
                            border.color: "#E3E5E7"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "#333333"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: downloadManager.openDownloadDir()
                    }
                }
            }
        }

        FolderDialog {
            id: folderDialog
            title: "选择下载目录"

            onAccepted: {
                var urlStr = selectedFolder.toString()
                var path = urlStr
                if (urlStr.startsWith("file:///"))
                    path = urlStr.substring(8)
                else if (urlStr.startsWith("file://"))
                    path = urlStr.substring(7)
                if (appSettings)
                    appSettings.downloadDir = path
            }
        }

        // 关于
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            color: "#FFFFFF"
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8

                Text {
                    text: "关于"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#18191C"
                }

                Text {
                    text: "bilibili 客户端（课程项目）"
                    font.pixelSize: 13
                    color: "#333333"
                }

                Text {
                    text: "版本 0.1 · Qt 6.11 + C++ + QML"
                    font.pixelSize: 12
                    color: "#9499A0"
                }
            }
        }
    }
}
