#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QNetworkReply>
#include <QFile>
#include "api_client.h"

// 视频控制器：所有操作异步走 HTTP
class VideoController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList videos READ videos NOTIFY videosChanged)
    Q_PROPERTY(QVariantList comments READ comments NOTIFY commentsChanged)
    Q_PROPERTY(int commentCount READ commentCount NOTIFY commentCountChanged)
    Q_PROPERTY(QString commentVideoId READ commentVideoId NOTIFY commentCountChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QVariantList danmaku READ danmaku NOTIFY danmakuChanged)
public:
    explicit VideoController(ApiClient *api, QObject *parent = nullptr);

    QVariantList videos() const { return m_videos; }
    QVariantList comments() const { return m_comments; }
    int commentCount() const { return m_commentCount; }
    QString commentVideoId() const { return m_commentVideoId; }
    bool loading() const { return m_loading; }
    QVariantList danmaku() const { return m_danmaku; }

    Q_INVOKABLE void loadVideos();
    Q_INVOKABLE void loadMoreVideos(int count);
    Q_INVOKABLE void clearVideos();
    Q_INVOKABLE void loadVideoFromDatabase();
    Q_INVOKABLE QVariantMap getVideo(const QString &videoId) const;
    Q_INVOKABLE void createVideo(const QString &title, const QString &author,
                                 const QString &description, const QString &videoUrl,
                                 const QString &coverUrl, const QString &headUrl);
    Q_INVOKABLE void searchVideos(const QString &keyword);

    Q_INVOKABLE void loadComments(const QString &videoId);
    Q_INVOKABLE void addComment(const QString &videoId, const QString &userName,
                                const QString &content);
    Q_INVOKABLE void addReply(const QString &videoId, const QString &parentCommentId,
                              const QString &userName, const QString &content);
    Q_INVOKABLE void likeComment(const QString &videoId, const QString &commentId);
    Q_INVOKABLE void unlikeComment(const QString &videoId, const QString &commentId);
    Q_INVOKABLE int getCommentCount(const QString &videoId) const;
    Q_INVOKABLE void loadDanmaku(const QString &videoId);
    Q_INVOKABLE void addDanmaku(const QString &videoId, const QString &content,
                                double timeSec, const QString &color);
    Q_INVOKABLE void recordView(const QString &videoId);

    Q_INVOKABLE void uploadVideo(const QString &videoPath, const QString &coverPath,
                                 const QString &title, const QString &description,
                                 const QString &tags = QString());
    Q_INVOKABLE void cancelUpload();

private:
    void sendNextChunk(qint64 sent);
    void resumeUpload(qint64 expectedSent);
    void finalizeUpload();
    void cleanupUpload();

signals:
    void videosChanged();
    void commentsChanged();
    void commentCountChanged();
    void loadingChanged();
    void errorOccurred(const QString &message);
    void searchFinished(const QVariantList &results);
    void uploadProgress(qint64 bytesSent, qint64 bytesTotal);
    void uploadFinished(const QString &videoUrl, const QString &coverUrl);
    void uploadError(const QString &error);
    void uploadCancelled();
    void danmakuChanged();

private:
    void setLoading(bool loading);
    void resolveMediaUrls(QVariantList &list);

    ApiClient *m_api;
    QVariantList m_videos;
    QVariantList m_comments;
    QVariantList m_danmaku;
    int m_nextPage = 1;
    int m_commentCount = 0;
    QString m_commentVideoId;   // 当前 commentCount 对应的视频 id
    bool m_loading = false;
    QNetworkReply *m_uploadReply = nullptr;
    bool m_uploadCancelled = false;
    QFile m_uploadFile;
    QString m_uploadId;
    QString m_uploadCover;
    QString m_uploadTitle;
    QString m_uploadDescription;
    qint64 m_uploadTotal = 0;
    int m_uploadRetries = 0;
};
