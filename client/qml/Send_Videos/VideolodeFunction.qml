//视频上传功能函数（新架构：通过服务端 multipart 接口上传）

import QtQuick
import QtQuick.Controls

Item {
    id: uploader

    signal uploadProgress(var bytesSent, var bytesTotal)
    signal uploadFinished(string videoUrl, string coverUrl)
    signal uploadError(string error)
    signal uploadCancelled()

    // 配置属性
    property string apiBaseUrl: "http://localhost:3000/api"
    property string currentFilePath: ""
    property string currentTitle: ""
    property string currentDescription: ""
    property string currentCoverPath: ""
    property bool isUploading: false
    property var currentRequest: null

    // 转发服务端控制器信号
    Connections {
        target: videoController
        function onUploadProgress(bytesSent, bytesTotal) {
            uploadProgress(bytesSent, bytesTotal)
        }
        function onUploadFinished(videoUrl, coverUrl) {
            isUploading = false
            currentRequest = null
            uploadFinished(videoUrl, coverUrl)
        }
        function onUploadError(error) {
            isUploading = false
            currentRequest = null
            uploadError(error)
        }
        function onUploadCancelled() {
            isUploading = false
            currentRequest = null
            uploadCancelled()
        }
    }

    // 上传视频方法
    function uploadVideo(filePath, title, description, coverPath = "", tags = "") {
        console.log("🚀 开始上传视频 - 参数:");
        console.log("  filePath:", filePath);
        console.log("  title:", title);
        console.log("  description:", description);
        console.log("  coverPath:", coverPath);

        if (isUploading) {
            uploadError("已有文件正在上传");
            return;
        }

        currentFilePath = filePath;
        currentTitle = title || "未命名视频";
        currentDescription = description || "暂无描述";
        currentCoverPath = coverPath || "";
        isUploading = true;

        uploadViaPath(filePath, currentTitle, currentDescription, currentCoverPath, tags);
    }

    // 通过文件路径上传（C++ 读取文件后 multipart 上传到 /api/videos）
    function uploadViaPath(filePath, title, description, coverPath = "", tags = "") {
        console.log("📤 使用服务端上传接口");
        videoController.uploadVideo(filePath, coverPath, title, description, tags);
    }

    // 取消上传
    function cancelUpload() {
        console.log("取消上传");
        videoController.cancelUpload();
    }

    // 工具函数：从文件路径中提取文件名
    function getFileName(filePath) {
        var path = filePath.toString();
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        var lastSlash = path.lastIndexOf("/");
        return lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
    }

    // 获取文件扩展名
    function getFileExtension(filePath) {
        var fileName = getFileName(filePath);
        var lastDot = fileName.lastIndexOf(".");
        return lastDot >= 0 ? fileName.substring(lastDot + 1).toLowerCase() : "";
    }

    // 验证文件类型
    function isValidVideoFile(filePath) {
        var ext = getFileExtension(filePath);
        var videoExtensions = ["mp4", "avi", "mov", "mkv", "flv", "wmv", "webm"];
        return videoExtensions.includes(ext);
    }

    function isValidImageFile(filePath) {
        var ext = getFileExtension(filePath);
        var imageExtensions = ["jpg", "jpeg", "png", "bmp", "gif"];
        return imageExtensions.includes(ext);
    }
}
