#include "video_controller.h"
#include <QJsonArray>
#include <QJsonObject>
#include <QUrl>
#include <QFile>
#include <QFileInfo>
#include <QDebug>

VideoController::VideoController(ApiClient *api, QObject *parent)
    : QObject(parent)
    , m_api(api)
{
}

void VideoController::setLoading(bool loading)
{
    if (m_loading != loading) {
        m_loading = loading;
        emit loadingChanged();
    }
}

void VideoController::loadVideos()
{
    setLoading(true);
    m_api->getJson("/api/videos?page=1&size=15&sort=hot", [this](bool ok, const QJsonObject &obj) {
        setLoading(false);
        if (ok && obj.value("code").toInt() == 0) {
            m_videos = obj.value("data").toArray().toVariantList();
            resolveMediaUrls(m_videos);
            m_nextPage = 2;
            emit videosChanged();
        } else {
            emit errorOccurred(obj.value("message").toString("加载视频失败"));
        }
    });
}

void VideoController::loadMoreVideos(int count)
{
    setLoading(true);
    if (count <= 0)
        count = 15; // 每次加载更多默认 15 条
    m_api->getJson(QString("/api/videos?page=%1&size=%2&sort=hot").arg(m_nextPage).arg(count),
                   [this](bool ok, const QJsonObject &obj) {
        setLoading(false);
        if (ok && obj.value("code").toInt() == 0) {
            QVariantList more = obj.value("data").toArray().toVariantList();
            resolveMediaUrls(more);
            for (const QVariant &v : more) {
                const QString id = v.toMap().value("id").toString();
                bool exists = false;
                for (const QVariant &e : std::as_const(m_videos)) {
                    if (e.toMap().value("id").toString() == id) { exists = true; break; }
                }
                if (!exists)
                    m_videos.append(v);
            }
            m_nextPage++;
            emit videosChanged();
        } else {
            emit errorOccurred(obj.value("message").toString("加载更多失败"));
        }
    });
}

void VideoController::clearVideos()
{
    m_videos.clear();
    m_nextPage = 1;
    emit videosChanged();
}

void VideoController::loadVideoFromDatabase()
{
    loadVideos();
}

QVariantMap VideoController::getVideo(const QString &videoId) const
{
    for (const QVariant &v : m_videos) {
        const QVariantMap video = v.toMap();
        if (video.value("id").toString() == videoId)
            return video;
    }
    qWarning() << "未找到视频 ID:" << videoId;
    return QVariantMap();
}

void VideoController::createVideo(const QString &title, const QString &author,
                                  const QString &description, const QString &videoUrl,
                                  const QString &coverUrl, const QString &headUrl)
{
    Q_UNUSED(author)
    Q_UNUSED(headUrl)
    QJsonObject body{
        {"title", title},
        {"description", description},
        {"videoUrl", videoUrl},
        {"coverUrl", coverUrl}
    };
    m_api->postJson("/api/videos/meta", body, [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0)
            emit errorOccurred(obj.value("message").toString("创建视频失败"));
        loadVideos();
    });
}

void VideoController::searchVideos(const QString &keyword)
{
    const QString path = "/api/videos/search?keyword="
                         + QString::fromUtf8(QUrl::toPercentEncoding(keyword));
    m_api->getJson(path, [this](bool ok, const QJsonObject &obj) {
        QVariantList results;
        if (ok && obj.value("code").toInt() == 0) {
            results = obj.value("data").toArray().toVariantList();
            resolveMediaUrls(results);
        } else
            emit errorOccurred(obj.value("message").toString("搜索失败"));
        emit searchFinished(results);
    });
}

void VideoController::loadComments(const QString &videoId)
{
    setLoading(true);
    m_api->getJson("/api/videos/" + videoId + "/comments", [this, videoId](bool ok, const QJsonObject &obj) {
        setLoading(false);
        if (ok && obj.value("code").toInt() == 0) {
            m_comments = obj.value("data").toArray().toVariantList();
            m_commentCount = m_comments.size();
            m_commentVideoId = videoId;
            emit commentsChanged();
            emit commentCountChanged();
        } else {
            emit errorOccurred(obj.value("message").toString("加载评论失败"));
        }
    });
}

void VideoController::addComment(const QString &videoId, const QString &userName,
                                 const QString &content)
{
    Q_UNUSED(userName)
    QJsonObject body{{"content", content}};
    m_api->postJson("/api/videos/" + videoId + "/comments", body,
                    [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0)
            emit errorOccurred(obj.value("message").toString("发表评论失败"));
        loadComments(videoId);
    });
}

void VideoController::addReply(const QString &videoId, const QString &parentCommentId,
                               const QString &userName, const QString &content)
{
    Q_UNUSED(userName)
    QJsonObject body{{"content", content}, {"parentId", parentCommentId}};
    m_api->postJson("/api/videos/" + videoId + "/comments", body,
                    [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0)
            emit errorOccurred(obj.value("message").toString("发表回复失败"));
        loadComments(videoId);
    });
}

void VideoController::likeComment(const QString &videoId, const QString &commentId)
{
    m_api->postJson("/api/comments/" + commentId + "/like", QJsonObject(),
                    [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("点赞失败"));
            return;
        }
        loadComments(videoId);
    });
}

void VideoController::unlikeComment(const QString &videoId, const QString &commentId)
{
    m_api->postJson("/api/comments/" + commentId + "/unlike", QJsonObject(),
                    [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("操作失败"));
            return;
        }
        loadComments(videoId);
    });
}

int VideoController::getCommentCount(const QString &videoId) const
{
    const QVariantMap video = getVideo(videoId);
    return video.value("commentCount").toInt();
}
void VideoController::uploadVideo(const QString &videoPath, const QString &coverPath,
                                  const QString &title, const QString &description,
                                  const QString &tags)
{
    if (m_api->token().isEmpty()) {
        emit uploadError("请先登录后再上传");
        return;
    }
    if (m_uploadReply) {
        emit uploadError("已有上传正在进行");
        return;
    }

    QString localVideo = videoPath;
    if (localVideo.startsWith("file://"))
        localVideo = QUrl(localVideo).toLocalFile();
    QString localCover = coverPath;
    if (localCover.startsWith("file://"))
        localCover = QUrl(localCover).toLocalFile();

    // 容错：Windows 路径可能出现多余的前导斜杠（如 /D:/xxx）
    auto fixWinPath = [](QString &p) {
        if (p.startsWith('/') && p.size() > 2 && p.at(1).isLetter() && p.at(2) == ':')
            p = p.mid(1);
    };
    fixWinPath(localVideo);
    fixWinPath(localCover);

    QFileInfo vf(localVideo);
    if (!vf.exists() || !vf.isFile()) {
        emit uploadError("视频文件不存在: " + localVideo);
        return;
    }
    const qint64 totalSize = vf.size();
    if (totalSize <= 0) {
        emit uploadError("视频文件为空");
        return;
    }
    if (totalSize > 2LL * 1024 * 1024 * 1024) {
        emit uploadError("视频文件超过 2GB 上限");
        return;
    }

    m_uploadCover = localCover;
    m_uploadTitle = title.isEmpty() ? "未命名视频" : title;
    m_uploadDescription = description;
    m_uploadTotal = totalSize;
    m_uploadCancelled = false;
    m_uploadRetries = 0;

    m_uploadFile.setFileName(localVideo);
    if (!m_uploadFile.open(QIODevice::ReadOnly)) {
        emit uploadError("无法读取视频文件");
        return;
    }

    QJsonObject init{{"fileName", vf.fileName()}, {"fileSize", totalSize}, {"tags", tags}};
    m_api->postJson("/api/uploads/init", init, [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            cleanupUpload();
            emit uploadError(obj.value("message").toString("初始化上传失败"));
            return;
        }
        m_uploadId = obj.value("data").toObject().value("uploadId").toString();
        sendNextChunk(0);
    });
}

void VideoController::sendNextChunk(qint64 sent)
{
    if (m_uploadCancelled) {
        cleanupUpload();
        emit uploadCancelled();
        return;
    }
    if (sent >= m_uploadTotal) {
        finalizeUpload();
        return;
    }

    m_uploadFile.seek(sent);
    const qint64 CHUNK = 16LL * 1024 * 1024;
    const QByteArray data = m_uploadFile.read(CHUNK);
    const qint64 chunkSize = data.size();
    if (chunkSize <= 0) {
        cleanupUpload();
        emit uploadError("读取文件失败");
        return;
    }

    m_uploadReply = m_api->postRaw("/api/uploads/" + m_uploadId + "/chunk", data,
                                   "application/octet-stream",
        [this, sent, chunkSize](bool ok, const QJsonObject &obj) {
            m_uploadReply = nullptr;
            if (m_uploadCancelled) {
                cleanupUpload();
                emit uploadCancelled();
                return;
            }
            if (!ok || obj.value("code").toInt() != 0) {
                if (m_uploadRetries < 3) {
                    resumeUpload(sent);
                    return;
                }
                cleanupUpload();
                emit uploadError(obj.value("message").toString("分片上传失败"));
                return;
            }
            emit uploadProgress(sent + chunkSize, m_uploadTotal);
            sendNextChunk(sent + chunkSize);
        });
}

void VideoController::finalizeUpload()
{
    QHash<QString, QString> fields;
    fields.insert("title", m_uploadTitle);
    fields.insert("description", m_uploadDescription);

    QList<ApiUploadFile> files;
    if (!m_uploadCover.isEmpty() && QFileInfo::exists(m_uploadCover)) {
        QFile cf(m_uploadCover);
        if (cf.open(QIODevice::ReadOnly)) {
            ApiUploadFile c;
            c.fieldName = "cover";
            c.fileName = QFileInfo(m_uploadCover).fileName();
            c.contentType = "image/" + QFileInfo(m_uploadCover).suffix().toLower();
            c.data = cf.readAll();
            files.append(c);
        }
    }

    m_api->postMultipart("/api/uploads/" + m_uploadId + "/finalize", fields, files,
        [this](bool ok, const QJsonObject &obj) {
            m_uploadFile.close();
            m_uploadId.clear();
            if (ok && obj.value("code").toInt() == 0) {
                const QJsonObject data = obj.value("data").toObject();
                emit uploadFinished(m_api->absoluteUrl(data.value("videoUrl").toString()),
                                   m_api->absoluteUrl(data.value("coverUrl").toString()));
            } else {
                emit uploadError(obj.value("message").toString("上传完成处理失败"));
            }
        });
}

void VideoController::cancelUpload()
{
    if (m_uploadReply) {
        m_uploadCancelled = true;
        m_uploadReply->abort();
    } else if (m_uploadFile.isOpen() || !m_uploadId.isEmpty()) {
        m_uploadCancelled = true;
        cleanupUpload();
        emit uploadCancelled();
    }
}

void VideoController::cleanupUpload()
{
    m_uploadCancelled = false;
    m_uploadRetries = 0;
    m_uploadReply = nullptr;
    m_uploadId.clear();
    m_uploadCover.clear();
    m_uploadTitle.clear();
    m_uploadDescription.clear();
    m_uploadTotal = 0;
    if (m_uploadFile.isOpen())
        m_uploadFile.close();
}

void VideoController::resolveMediaUrls(QVariantList &list)
{
    for (auto &v : list) {
        QVariantMap m = v.toMap();
        m["videoUrl"] = m_api->absoluteUrl(m.value("videoUrl").toString());
        m["coverUrl"] = m_api->absoluteUrl(m.value("coverUrl").toString());
        v = m;
    }
}
void VideoController::resumeUpload(qint64 expectedSent)
{
    m_api->getJson("/api/uploads/" + m_uploadId + "/status",
                   [this, expectedSent](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            cleanupUpload();
            emit uploadError("上传中断，无法恢复");
            return;
        }
        const qint64 received = obj.value("data").toObject().value("received").toVariant().toLongLong();
        m_uploadRetries++;
        if (received >= m_uploadTotal) {
            finalizeUpload();
        } else {
            sendNextChunk(received);
        }
    });
}

void VideoController::loadDanmaku(const QString &videoId)
{
    m_api->getJson("/api/videos/" + videoId + "/danmaku",
                   [this](bool ok, const QJsonObject &obj) {
        if (ok && obj.value("code").toInt() == 0) {
            m_danmaku = obj.value("data").toArray().toVariantList();
            emit danmakuChanged();
        }
    });
}

void VideoController::addDanmaku(const QString &videoId, const QString &content,
                                 double timeSec, const QString &color)
{
    QJsonObject body{{"content", content}, {"time", timeSec}, {"color", color}};
    m_api->postJson("/api/videos/" + videoId + "/danmaku", body,
                    [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("发送弹幕失败"));
            return;
        }
        loadDanmaku(videoId);
    });
}

void VideoController::recordView(const QString &videoId)
{
    // 上报播放量（服务端 30 分钟防刷）
    m_api->postJson("/api/videos/" + videoId + "/view", QJsonObject(),
                    [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            qWarning() << "recordView failed:" << obj.value("message").toString();
            return;
        }
        // 服务端返回最新视频数据，同步到已加载列表，让播放数即时 +1
        QVariantMap updated = obj.value("data").toObject().toVariantMap();
        updated["videoUrl"] = m_api->absoluteUrl(updated.value("videoUrl").toString());
        updated["coverUrl"] = m_api->absoluteUrl(updated.value("coverUrl").toString());
        for (auto &v : m_videos) {
            QVariantMap m = v.toMap();
            if (m.value("id").toString() == videoId) {
                v = updated;
                break;
            }
        }
        emit videosChanged();
    });
}
