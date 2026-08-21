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
    QString videoPath;   // /media/videos/xxx.mp4 或完整 URL
    QString coverPath;   // /media/covers/xxx.jpg 或完整 URL
    QString tags;        // 逗号分隔的标签
    int viewCount = 0;
    int likeCount = 0;
    int coinCount = 0;
    int favoriteCount = 0;
    int commentCount = 0;
    QDateTime createdAt;

    QJsonObject toJson() const;
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