#pragma once
#include <QObject>
#include <QHttpServer>
#include <QJsonObject>
#include <QJsonValue>
#include "config.h"
#include "auth.h"
#include "redis_client.h"
#include "models.h"
#include "transcode_manager.h"

// multipart/form-data 中的一个字段
struct MultipartPart {
    QString name;
    QString fileName;
    QString contentType;
    QByteArray data;
};

class BilibiliServer : public QObject {
    Q_OBJECT
public:
    explicit BilibiliServer(QObject *parent = nullptr);
    bool start(quint16 port, const AppConfig &cfg);

private:
    QHttpServerResponse handleRegister(const QHttpServerRequest &req);
    QHttpServerResponse handleLogin(const QHttpServerRequest &req);
    QHttpServerResponse handleLogout(const QHttpServerRequest &req);
    QHttpServerResponse handleMe(const QHttpServerRequest &req);
    QHttpServerResponse handleListVideos(const QHttpServerRequest &req);
    QHttpServerResponse handleGetVideo(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleSearch(const QHttpServerRequest &req);
    QHttpServerResponse handleUploadVideo(const QHttpServerRequest &req);
    QHttpServerResponse handleView(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleLike(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleUnlike(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleFavorite(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleUnfavorite(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleListComments(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleAddComment(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleHistory(const QHttpServerRequest &req);
    QHttpServerResponse handleAddHistory(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleFavorites(const QHttpServerRequest &req);
    QHttpServerResponse handleMyVideos(const QHttpServerRequest &req);
    QHttpServerResponse handleDeleteVideo(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleMedia(const QString &fileName, const QHttpServerRequest &req);
    QHttpServerResponse handleSeed(const QHttpServerRequest &req);
    QHttpServerResponse handleCreateVideoMeta(const QHttpServerRequest &req);
    QHttpServerResponse handleUpdateProfile(const QHttpServerRequest &req);
    QHttpServerResponse handleFollowing(const QHttpServerRequest &req);
    QHttpServerResponse handleFollowers(const QHttpServerRequest &req);
    QHttpServerResponse handleFollowUser(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleUnfollowUser(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleCommentLike(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleCommentUnlike(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleCoin(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleMyCoins(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleUploadAvatar(const QHttpServerRequest &req);
    QHttpServerResponse handleListUsers(const QHttpServerRequest &req);
    QHttpServerResponse handleSendChat(const QHttpServerRequest &req);
    QHttpServerResponse handleChatHistory(const QHttpServerRequest &req);
    QHttpServerResponse handleUploadInit(const QHttpServerRequest &req);
    QHttpServerResponse handleUploadChunk(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleUploadFinalize(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleUploadStatus(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handleGetDanmaku(const QString &id, const QHttpServerRequest &req);
    QHttpServerResponse handlePostDanmaku(const QString &id, const QHttpServerRequest &req);

    void bumpHotScore(const QString &videoId, double delta);
    QString bearerUserId(const QHttpServerRequest &req) const;
    QHttpServerResponse okJson(const QJsonValue &data, const QString &message = "ok") const;
    QHttpServerResponse errJson(const QString &message,
                                QHttpServerResponse::StatusCode status = QHttpServerResponse::StatusCode::BadRequest) const;
    QList<MultipartPart> parseMultipart(const QByteArray &body, const QByteArray &boundary) const;
    QByteArray contentTypeFor(const QString &path) const;
    QString uploadsPath(const QString &fileName) const;

    struct PendingUpload {
        QString userId;
        QString tags;
        QString safeName;
        QString coverName;
        qint64 totalSize = 0;
        qint64 received = 0;
        QString partPath;
    };
    QHash<QString, PendingUpload> m_pendingUploads;

    RedisClient m_redis;
    bool m_redisReady = false;
    QString m_hotKey = "bilibili:hot:videos";

    QHttpServer m_server;
    AppConfig m_cfg;
    TranscodeManager m_transcoder;
    TokenStore m_tokens;
};