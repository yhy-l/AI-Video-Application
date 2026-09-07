#pragma once
#include <QString>
#include <QDateTime>
#include <QJsonObject>

struct UserRecord {
    QString id;
    QString account;
    QString passwordHash;
    QString salt;
    QString nickname;
    QString avatarUrl;
    QString signature;
    QDateTime createdAt;

    QJsonObject toJson() const;
};

struct VideoRecord {
    QString id;
    QString userId;
    QString authorName;
    QString title;
    QString description;
    QString videoPath;   // /media/xxx.mp4 或完整 URL
    QString coverPath;   // /media/covers/xxx.jpg 或完整 URL
    QString tags;        // 逗号分隔的标签
    int viewCount = 0;
    int likeCount = 0;
    int coinCount = 0;
    int favoriteCount = 0;
    int commentCount = 0;
    // 转码/媒体元数据（上传后由 ffprobe + 后台转码更新）
    int width = 0;                 // 源视频宽
    int height = 0;                // 源视频高
    double durationSec = 0.0;      // 秒
    qint64 fileSizeBytes = 0;
    QString transcodeStatus;       // "" / "transcoding" / "done"
    QString doneQualities;         // 逗号分隔，如 "480,720"
    QDateTime createdAt;

    QJsonObject toJson() const;
};

// 单条转码档位进度（视频详情里供上传页展示）
struct TranscodeTaskInfo {
    int quality = 0;          // 480 / 720 / 1080，0 表示该源无需该档
    int status = 0;           // 0 待处理 1 转码中 2 完成 3 失败
    int progress = 0;         // 0-100
};

struct CommentRecord {
    QString id;
    QString videoId;
    QString userId;
    QString userName;
    QString parentId;
    QString content;
    int likeCount = 0;
    int unlikeCount = 0;
    QDateTime createdAt;

    QJsonObject toJson() const;
};
struct DanmakuRecord {
    QString id;
    QString videoId;
    QString userId;
    QString userName;
    QString content;
    QString color;
    double timeSec = 0;
    QDateTime createdAt;

    QJsonObject toJson() const;
};