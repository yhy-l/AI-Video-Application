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

void VideoController::fetchVideoStatus(const QString &videoId)
{
    m_api->getJson("/api/videos/" + videoId,
                   [this, videoId](bool ok, const QJsonObject &obj) {
        QVariantMap empty;
        if (!ok || obj.value("code").toInt() != 0) {
            emit videoStatusReady(videoId, empty);
            return;
        }
        const QVariantMap video = resolveVideoMedia(obj.value("data").toObject().toVariantMap());
        // 同步到上传任务列表（侧栏"上传记录"展示转码进度）
        for (auto &t : m_uploadTasks) {
            QVariantMap m = t.toMap();
            if (m.value("id").toString() == videoId) {
                const QString st = video.value("transcodeStatus").toString();
                m.insert("transcodeStatus", st);
                m.insert("width", video.value("width").toInt());
                m.insert("height", video.value("height").toInt());
                m.insert("qualities", video.value("qualities"));
                m.insert("tasks", video.value("transcodeTasks"));
                if (st == "done")
                    m.insert("statusText", "转码完成");
                else if (st == "transcoding")
                    m.insert("statusText", "后台转码中…");
                else
                    m.insert("statusText", "等待转码…");
                t = m;
                emit uploadTasksChanged();
                break;
            }
        }
        emit videoStatusReady(videoId, video);
    });
}

void VideoController::loadMyVideos()
{
    m_api->getJson("/api/me/videos", [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("加载我的投稿失败"));
            return;
        }
        m_myVideos = obj.value("data").toArray().toVariantList();
        resolveMediaUrls(m_myVideos);
        emit myVideosChanged();
    });
}

void VideoController::deleteMyVideo(const QString &videoId)
{
    m_api->deleteJson("/api/videos/" + videoId, [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("删除失败"));
            return;
        }
        // 同时从我的投稿与首页列表移除
        for (auto it = m_myVideos.begin(); it != m_myVideos.end(); ++it) {
            if (it->toMap().value("id").toString() == videoId) {
                m_myVideos.erase(it);
                break;
            }
        }
        for (auto it = m_videos.begin(); it != m_videos.end(); ++it) {
            if (it->toMap().value("id").toString() == videoId) {
                m_videos.erase(it);
                break;
            }
        }
        emit myVideosChanged();
        emit videosChanged();
    });
}

void VideoController::clearUploadTasks()
{
    m_uploadTasks.clear();
    emit uploadTasksChanged();
}

// 上传失败（初始化/分片/读取等路径）时把当前任务标为失败
void VideoController::markCurrentUploadFailed(const QString &reason)
{
    for (auto &t : m_uploadTasks) {
        QVariantMap m = t.toMap();
        if (m.value("key").toString() == m_uploadFileName) {
            m.insert("stage", "failed");
            m.insert("statusText", "上传失败：" + reason);
            t = m;
            break;
        }
    }
    emit uploadTasksChanged();
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
    m_uploadFileName = vf.fileName();

    // 在任务列表顶部插入一条"上传中"记录（供上传页/侧栏上传记录展示）
    QVariantMap task;
    task.insert("key", m_uploadFileName);
    task.insert("id", QString());
    task.insert("title", m_uploadTitle);
    task.insert("fileName", m_uploadFileName);
    task.insert("stage", "uploading");          // uploading / uploaded / failed
    task.insert("transcodeStatus", QString());
    task.insert("statusText", "上传中…");
    task.insert("progress", 0);
    task.insert("width", 0);
    task.insert("height", 0);
    task.insert("qualities", QVariantList());   // 可用清晰度（后端）
    task.insert("tasks", QVariantList());       // 每档转码进度
    m_uploadTasks.prepend(task);
    emit uploadTasksChanged();

    m_uploadFile.setFileName(localVideo);
    if (!m_uploadFile.open(QIODevice::ReadOnly)) {
        emit uploadError("无法读取视频文件");
        return;
    }

    QJsonObject init{{"fileName", vf.fileName()}, {"fileSize", totalSize}, {"tags", tags}};
    m_api->postJson("/api/uploads/init", init, [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            markCurrentUploadFailed(obj.value("message").toString("初始化上传失败"));
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
        markCurrentUploadFailed("读取文件失败");
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
                markCurrentUploadFailed(obj.value("message").toString("分片上传失败"));
                cleanupUpload();
                emit uploadError(obj.value("message").toString("分片上传失败"));
                return;
            }
            emit uploadProgress(sent + chunkSize, m_uploadTotal);
            {
                // 更新任务列表里的上传进度
                for (auto &t : m_uploadTasks) {
                    QVariantMap m = t.toMap();
                    if (m.value("key").toString() == m_uploadFileName) {
                        m.insert("progress", int(double(sent + chunkSize) * 100.0 / double(m_uploadTotal)));
                        m.insert("statusText", QString("上传中 %1%").arg(int(double(sent + chunkSize) * 100.0 / double(m_uploadTotal))));
                        t = m;
                        break;
                    }
                }
                emit uploadTasksChanged();
            }
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
                const QVariantMap resolved = resolveVideoMedia(data.toVariantMap());
                // 上传成功：任务进入"转码中/等待探测"阶段，并立即拉一次最新状态
                const QString vid = resolved.value("id").toString();
                for (auto &t : m_uploadTasks) {
                    QVariantMap m = t.toMap();
                    if (m.value("key").toString() == m_uploadFileName) {
                        m.insert("id", vid);
                        m.insert("stage", "uploaded");
                        m.insert("transcodeStatus", resolved.value("transcodeStatus").toString());
                        m.insert("statusText", "上传成功，等待后台转码…");
                        m.insert("progress", 100);
                        m.insert("width", resolved.value("width").toInt());
                        m.insert("height", resolved.value("height").toInt());
                        m.insert("coverUrl", resolved.value("coverUrl").toString());
                        m.insert("videoUrl", resolved.value("videoUrl").toString());
                        t = m;
                        break;
                    }
                }
                emit uploadTasksChanged();
                if (!vid.isEmpty())
                    fetchVideoStatus(vid);
                emit uploadFinished(resolved.value("videoUrl").toString(),
                                   resolved.value("coverUrl").toString(),
                                   vid,
                                   resolved);
            } else {
                markCurrentUploadFailed(obj.value("message").toString("上传完成处理失败"));
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
        for (auto &t : m_uploadTasks) {
            QVariantMap m = t.toMap();
            if (m.value("key").toString() == m_uploadFileName) {
                m.insert("stage", "cancelled");
                m.insert("statusText", "上传已取消");
                t = m;
                break;
            }
        }
        emit uploadTasksChanged();
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
        v = resolveVideoMedia(v.toMap());
    }
}

QVariantMap VideoController::resolveVideoMedia(const QVariantMap &m)
{
    QVariantMap out = m;
    out["videoUrl"] = m_api->absoluteUrl(out.value("videoUrl").toString());
    out["coverUrl"] = m_api->absoluteUrl(out.value("coverUrl").toString());
    // 清晰度列表里的每个 url 同样是 /media/xxx，转成完整地址
    QVariantList quals = out.value("qualities").toList();
    for (auto &q : quals) {
        QVariantMap qm = q.toMap();
        qm["url"] = m_api->absoluteUrl(qm.value("url").toString());
        q = qm;
    }
    out["qualities"] = quals;
    return out;
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
        QVariantMap updated = resolveVideoMedia(obj.value("data").toObject().toVariantMap());
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
