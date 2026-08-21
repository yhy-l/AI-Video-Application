#include "server.h"
#include "repository.h"
#include "database.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QUrlQuery>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QUuid>
#include <QCoreApplication>
#include <QDebug>
#include <QTcpServer>

namespace {
QJsonObject jsonBody(const QHttpServerRequest &req)
{
    return QJsonDocument::fromJson(req.body()).object();
}
}

BilibiliServer::BilibiliServer(QObject *parent)
    : QObject(parent)
{
}

bool BilibiliServer::start(quint16 port, const AppConfig &cfg)
{
    m_cfg = cfg;
    if (m_cfg.uploadsDir.isEmpty())
        m_cfg.uploadsDir = QCoreApplication::applicationDirPath() + "/uploads";
    QDir().mkpath(m_cfg.uploadsDir);

    // ---- 账号 ----
    m_server.route("/api/register", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleRegister(r); });
    m_server.route("/api/login", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleLogin(r); });
    m_server.route("/api/logout", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleLogout(r); });
    m_server.route("/api/me", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleMe(r); });

    // ---- 视频（search 必须先于 <arg> 注册）----
    m_server.route("/api/videos/meta", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleCreateVideoMeta(r); });
    m_server.route("/api/me/profile", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleUpdateProfile(r); });
    m_server.route("/api/me/following", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleFollowing(r); });
    m_server.route("/api/me/followers", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleFollowers(r); });
    m_server.route("/api/users/<arg>/follow", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleFollowUser(id, r); });
    m_server.route("/api/users/<arg>/follow", QHttpServerRequest::Method::Delete,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleUnfollowUser(id, r); });

    // 评论点赞/踩
    m_server.route("/api/comments/<arg>/like", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleCommentLike(id, r); });
    m_server.route("/api/comments/<arg>/like", QHttpServerRequest::Method::Delete,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleCommentLike(id, r); });
    m_server.route("/api/comments/<arg>/unlike", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleCommentUnlike(id, r); });

    // 投币
    m_server.route("/api/videos/<arg>/coin", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleCoin(id, r); });
    m_server.route("/api/me/coins/<arg>", QHttpServerRequest::Method::Get,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleMyCoins(id, r); });

    // 头像上传
    m_server.route("/api/me/avatar", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleUploadAvatar(r); });

    // 分块上传（支持 2GB 大文件）
    m_server.route("/api/uploads/init", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleUploadInit(r); });
    m_server.route("/api/uploads/<arg>/chunk", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleUploadChunk(id, r); });
    m_server.route("/api/uploads/<arg>/finalize", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleUploadFinalize(id, r); });
    m_server.route("/api/uploads/<arg>/status", QHttpServerRequest::Method::Get,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleUploadStatus(id, r); });

    // 用户列表与聊天
    m_server.route("/api/users", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleListUsers(r); });
    m_server.route("/api/chat/messages", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleSendChat(r); });
    m_server.route("/api/chat/messages", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleChatHistory(r); });
    m_server.route("/api/videos/search", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleSearch(r); });
    m_server.route("/api/videos", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleListVideos(r); });
    m_server.route("/api/videos", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleUploadVideo(r); });
    m_server.route("/api/videos/<arg>", QHttpServerRequest::Method::Get,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleGetVideo(id, r); });
    m_server.route("/api/videos/<arg>/view", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleView(id, r); });
    m_server.route("/api/videos/<arg>/like", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleLike(id, r); });
    m_server.route("/api/videos/<arg>/like", QHttpServerRequest::Method::Delete,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleUnlike(id, r); });
    m_server.route("/api/videos/<arg>/favorite", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleFavorite(id, r); });
    m_server.route("/api/videos/<arg>/favorite", QHttpServerRequest::Method::Delete,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleUnfavorite(id, r); });
    m_server.route("/api/videos/<arg>/comments", QHttpServerRequest::Method::Get,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleListComments(id, r); });
    m_server.route("/api/videos/<arg>/comments", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleAddComment(id, r); });
    m_server.route("/api/videos/<arg>/danmaku", QHttpServerRequest::Method::Get,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleGetDanmaku(id, r); });
    m_server.route("/api/videos/<arg>/danmaku", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handlePostDanmaku(id, r); });

    // ---- 用户数据 ----
    m_server.route("/api/me/history", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleHistory(r); });
    m_server.route("/api/me/history/<arg>", QHttpServerRequest::Method::Post,
                   [this](const QString &id, const QHttpServerRequest &r) { return handleAddHistory(id, r); });
    m_server.route("/api/me/favorites", QHttpServerRequest::Method::Get,
                   [this](const QHttpServerRequest &r) { return handleFavorites(r); });

    // ---- 媒体文件 ----
    m_server.route("/media/<arg>", QHttpServerRequest::Method::Get,
                   [this](const QString &f, const QHttpServerRequest &r) { return handleMedia(f, r); });

    // ---- 开发辅助 ----
    m_server.route("/api/dev/seed", QHttpServerRequest::Method::Post,
                   [this](const QHttpServerRequest &r) { return handleSeed(r); });

    // 连接 Redis（独立库，仅用于热门排行；失败则回退 MySQL 排序）
    m_redisReady = m_redis.connectToServer(m_cfg.redisHost, m_cfg.redisPort, m_cfg.redisDb);
    if (m_redisReady) {
        m_redis.ping();
        qInfo() << "Redis ready:" << m_cfg.redisHost << m_cfg.redisPort << "db" << m_cfg.redisDb;
    } else {
        qWarning() << "Redis 不可用，热门排行回退 MySQL:" << m_redis.lastError();
    }

    QTcpServer *tcpServer = new QTcpServer(this);
    if (!tcpServer->listen(QHostAddress::Any, port)) {
        qWarning() << "TCP listen failed on port" << port;
        return false;
    }
    if (!m_server.bind(tcpServer)) {
        qWarning() << "Failed to bind QHttpServer to QTcpServer";
        return false;
    }
    return true;
}

// ---------- 辅助 ----------

void BilibiliServer::bumpHotScore(const QString &videoId, double delta)
{
    if (!m_redisReady)
        return;
    m_redis.zincrby(m_hotKey.toUtf8(), delta, videoId.toUtf8());
    m_redis.expire(m_hotKey.toUtf8(), 7 * 24 * 3600);
}
QString BilibiliServer::bearerUserId(const QHttpServerRequest &req) const
{
    const QString auth = QString::fromUtf8(req.value("Authorization"));
    if (!auth.startsWith("Bearer "))
        return QString();
    return m_tokens.userIdForToken(auth.mid(7).trimmed());
}

QHttpServerResponse BilibiliServer::okJson(const QJsonValue &data, const QString &message) const
{
    QJsonObject obj{
        {"code", 0},
        {"message", message},
        {"data", data}
    };
    return QHttpServerResponse(QByteArrayLiteral("application/json; charset=utf-8"),
                                QJsonDocument(obj).toJson());
}

QHttpServerResponse BilibiliServer::errJson(const QString &message,
                                            QHttpServerResponse::StatusCode status) const
{
    QJsonObject obj{
        {"code", 1},
        {"message", message}
    };
    return QHttpServerResponse(QByteArrayLiteral("application/json; charset=utf-8"),
                                QJsonDocument(obj).toJson(), status);
}

QString BilibiliServer::uploadsPath(const QString &fileName) const
{
    return m_cfg.uploadsDir + "/" + fileName;
}

QByteArray BilibiliServer::contentTypeFor(const QString &path) const
{
    const QString ext = QFileInfo(path).suffix().toLower();
    if (ext == "mp4") return "video/mp4";
    if (ext == "webm") return "video/webm";
    if (ext == "mov") return "video/quicktime";
    if (ext == "jpg" || ext == "jpeg") return "image/jpeg";
    if (ext == "png") return "image/png";
    if (ext == "webp") return "image/webp";
    if (ext == "gif") return "image/gif";
    return "application/octet-stream";
}

QList<MultipartPart> BilibiliServer::parseMultipart(const QByteArray &body,
                                                    const QByteArray &boundary) const
{
    QList<MultipartPart> parts;
    if (boundary.isEmpty())
        return parts;

    const QByteArray delim = "--" + boundary;
    int pos = body.indexOf(delim);
    while (pos >= 0) {
        int lineEnd = body.indexOf("\r\n", pos);
        if (lineEnd < 0)
            break;
        int partStart = lineEnd + 2;
        int nextDelim = body.indexOf(delim, partStart);
        if (nextDelim < 0)
            break;

        QByteArray part = body.mid(partStart, nextDelim - partStart);
        while (part.endsWith("\r\n"))
            part.chop(2);

        int headerEnd = part.indexOf("\r\n\r\n");
        if (headerEnd < 0)
            headerEnd = part.indexOf("\n\n");
        if (headerEnd < 0) {
            pos = nextDelim;
            continue;
        }

        QByteArray headers = part.left(headerEnd);
        QByteArray data = part.mid(headerEnd + 4);
        if (data.endsWith("\r\n"))
            data.chop(2);

        MultipartPart p;
        for (const QByteArray &rawLine : headers.split('\n')) {
            QByteArray line = rawLine.trimmed();
            if (line.startsWith("Content-Disposition:")) {
                int n = line.indexOf("name=\"");
                if (n >= 0) {
                    int s = n + 6;
                    int e = line.indexOf('"', s);
                    if (e > s)
                        p.name = QString::fromUtf8(line.mid(s, e - s));
                }
                int f = line.indexOf("filename=\"");
                if (f >= 0) {
                    int s = f + 10;
                    int e = line.indexOf('"', s);
                    if (e > s)
                        p.fileName = QString::fromUtf8(line.mid(s, e - s));
                }
            } else if (line.startsWith("Content-Type:")) {
                p.contentType = QString::fromUtf8(line.mid(13).trimmed());
            }
        }
        p.data = data;
        parts.append(p);

        pos = nextDelim;
    }
    return parts;
}

// ---------- 账号 ----------

QHttpServerResponse BilibiliServer::handleRegister(const QHttpServerRequest &req)
{
    const QJsonObject body = jsonBody(req);
    const QString account = body.value("account").toString().trimmed();
    const QString password = body.value("password").toString();
    const QString nickname = body.value("nickname").toString().trimmed();

    if (account.size() < 4)
        return errJson("账号至少 4 个字符");
    if (password.size() < 6)
        return errJson("密码至少 6 个字符");
    if (nickname.isEmpty())
        return errJson("昵称不能为空");
    if (repo::findUserByAccount(account))
        return errJson("账号已存在");

    UserRecord u;
    u.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    u.account = account;
    u.nickname = nickname;
    u.salt = auth::generateSalt();
    u.passwordHash = auth::hashPassword(password, u.salt);

    if (!repo::insertUser(u))
        return errJson("注册失败，请稍后重试", QHttpServerResponse::StatusCode::InternalServerError);

    qInfo() << "registered:" << account;
    return okJson(u.toJson(), "注册成功");
}

QHttpServerResponse BilibiliServer::handleLogin(const QHttpServerRequest &req)
{
    const QJsonObject body = jsonBody(req);
    const QString account = body.value("account").toString().trimmed();
    const QString password = body.value("password").toString();

    auto user = repo::findUserByAccount(account);
    if (!user || user->passwordHash != auth::hashPassword(password, user->salt))
        return errJson("账号或密码错误", QHttpServerResponse::StatusCode::Unauthorized);

    const QString token = m_tokens.issue(user->id);
    qInfo() << "logged in:" << account;

    QJsonObject data = user->toJson();
    data.insert("token", token);
    return okJson(data, "登录成功");
}

QHttpServerResponse BilibiliServer::handleLogout(const QHttpServerRequest &req)
{
    const QString auth = QString::fromUtf8(req.value("Authorization"));
    if (auth.startsWith("Bearer "))
        m_tokens.revoke(auth.mid(7).trimmed());
    return okJson(QJsonValue(), "已退出登录");
}

QHttpServerResponse BilibiliServer::handleMe(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    auto user = repo::findUserById(userId);
    if (!user)
        return errJson("用户不存在", QHttpServerResponse::StatusCode::Unauthorized);
    return okJson(user->toJson());
}

// ---------- 视频 ----------

QHttpServerResponse BilibiliServer::handleListVideos(const QHttpServerRequest &req)
{
    const QUrlQuery query = req.query();
    int page = query.queryItemValue("page").toInt();
    int size = query.queryItemValue("size").toInt();
    if (page < 1) page = 1;
    if (size < 1 || size > 50) size = 24;

    QJsonArray arr;
    const QString sort = query.queryItemValue("sort");
    if (sort == "hot") {
        // 热门：先按 Redis 热度分排序，没有热度分的视频按播放量兜底，
        // 保证每个视频都能出现在首页（不会"消失"）
        QHash<QString, double> scoreMap;
        if (m_redisReady) {
            const auto scored = m_redis.zrevrangeWithScores(m_hotKey.toUtf8(), 0, -1);
            for (const auto &p : scored)
                scoreMap.insert(QString::fromUtf8(p.first), p.second);
        }
        const auto all = repo::listVideosByViews(2000);
        QList<VideoRecord> ranked, unranked;
        for (const VideoRecord &v : all) {
            if (scoreMap.contains(v.id))
                ranked.append(v);
            else
                unranked.append(v);
        }
        std::sort(ranked.begin(), ranked.end(),
                  [&scoreMap](const VideoRecord &a, const VideoRecord &b) {
                      double sa = scoreMap.value(a.id);
                      double sb = scoreMap.value(b.id);
                      if (qFuzzyCompare(sa, sb))
                          return a.viewCount > b.viewCount;
                      return sa > sb;
                  });
        const QList<VideoRecord> merged = ranked + unranked;
        const int start = (page - 1) * size;
        for (int i = start; i < merged.size() && i < start + size; ++i)
            arr.append(merged[i].toJson());
    } else {
        for (const VideoRecord &v : repo::listVideos(page, size))
            arr.append(v.toJson());
    }
    return okJson(arr);
}

QHttpServerResponse BilibiliServer::handleGetVideo(const QString &id, const QHttpServerRequest &req)
{
    Q_UNUSED(req)
    auto v = repo::findVideoById(id);
    if (!v)
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);
    return okJson(v->toJson());
}

QHttpServerResponse BilibiliServer::handleSearch(const QHttpServerRequest &req)
{
    const QString keyword = req.query().queryItemValue("keyword").trimmed();
    QJsonArray arr;
    if (!keyword.isEmpty()) {
        for (const VideoRecord &v : repo::searchVideos(keyword))
            arr.append(v.toJson());
    }
    return okJson(arr);
}

QHttpServerResponse BilibiliServer::handleView(const QString &id, const QHttpServerRequest &req)
{
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);

    // 防刷：同一用户（未登录按 IP）对同一视频 30 分钟内只计一次
    const QString userId = bearerUserId(req);
    const QString who = userId.isEmpty()
        ? req.remoteAddress().toString()
        : userId;
    const QByteArray key = "bilibili:view:" + id.toUtf8() + ":" + who.toUtf8();

    if (!m_redisReady || !m_redis.exists(key)) {
        if (m_redisReady)
            m_redis.setex(key, 30 * 60, "1");
        repo::incrementVideoCounter(id, "view_count");
        bumpHotScore(id, 1.0);
    }

    auto v = repo::findVideoById(id);
    return okJson(v ? v->toJson() : QJsonObject());
}

QHttpServerResponse BilibiliServer::handleUploadVideo(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    auto user = repo::findUserById(userId);
    if (!user)
        return errJson("用户不存在", QHttpServerResponse::StatusCode::Unauthorized);

    const QString contentType = QString::fromUtf8(req.value("Content-Type"));
    const int b = contentType.indexOf("boundary=");
    if (b < 0)
        return errJson("请求格式不正确（缺少 boundary）");
    const QByteArray boundary = contentType.mid(b + 9).trimmed().toUtf8();
    const QList<MultipartPart> parts = parseMultipart(req.body(), boundary);

    QString title, description;
    QByteArray videoData, coverData;
    QString videoFileName, coverFileName;
    for (const MultipartPart &p : parts) {
        if (p.name == "title")
            title = QString::fromUtf8(p.data).trimmed();
        else if (p.name == "description")
            description = QString::fromUtf8(p.data).trimmed();
        else if (p.name == "video" && !p.data.isEmpty()) {
            videoData = p.data;
            videoFileName = p.fileName;
        } else if (p.name == "cover" && !p.data.isEmpty()) {
            coverData = p.data;
            coverFileName = p.fileName;
        }
    }

    if (title.isEmpty())
        return errJson("标题不能为空");
    if (videoData.isEmpty())
        return errJson("缺少视频文件");
    if (videoData.size() > 200 * 1024 * 1024)
        return errJson("视频文件过大（上限 200MB）");

    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);

    QString safeVideo = QFileInfo(videoFileName).fileName();
    if (safeVideo.isEmpty()) safeVideo = "video.mp4";
    safeVideo = id + "__video__" + safeVideo;
    const QString videoRel = "/media/" + safeVideo;
    QFile vf(uploadsPath(safeVideo));
    if (!vf.open(QIODevice::WriteOnly)) {
        qWarning() << "save video file failed:" << vf.errorString();
        return errJson("保存视频文件失败", QHttpServerResponse::StatusCode::InternalServerError);
    }
    vf.write(videoData);
    vf.close();

    QString coverRel;
    if (!coverData.isEmpty()) {
        QString safeCover = QFileInfo(coverFileName).fileName();
        if (safeCover.isEmpty()) safeCover = "cover.jpg";
        safeCover = id + "__cover__" + safeCover;
        coverRel = "/media/" + safeCover;
        QFile cf(uploadsPath(safeCover));
        if (!cf.open(QIODevice::WriteOnly)) {
            qWarning() << "save cover file failed:" << cf.errorString();
            return errJson("保存封面失败", QHttpServerResponse::StatusCode::InternalServerError);
        }
        cf.write(coverData);
        cf.close();
    }

    VideoRecord v;
    v.id = id;
    v.userId = user->id;
    v.authorName = user->nickname;
    v.title = title;
    v.description = description;
    v.videoPath = videoRel;
    v.coverPath = coverRel;

    if (!repo::insertVideo(v))
        return errJson("写入数据库失败", QHttpServerResponse::StatusCode::InternalServerError);

    qInfo() << "video uploaded:" << id << title;
    auto saved = repo::findVideoById(id);
    return okJson(saved ? saved->toJson() : QJsonObject(), "上传成功");
}

// ---------- 互动 ----------

QHttpServerResponse BilibiliServer::handleLike(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);
    if (!repo::isVideoLikedByUser(userId, id)) {
        repo::setVideoLiked(userId, id, true);
        repo::adjustVideoCounter(id, "like_count", +1);
        bumpHotScore(id, 3.0);
    }
    auto v = repo::findVideoById(id);
    return okJson(v ? v->toJson() : QJsonObject());
}

QHttpServerResponse BilibiliServer::handleUnlike(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);
    if (repo::isVideoLikedByUser(userId, id)) {
        repo::setVideoLiked(userId, id, false);
        repo::adjustVideoCounter(id, "like_count", -1);
    }
    auto v = repo::findVideoById(id);
    return okJson(v ? v->toJson() : QJsonObject());
}

QHttpServerResponse BilibiliServer::handleFavorite(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);
    if (!repo::isVideoFavoritedByUser(userId, id)) {
        repo::setVideoFavorited(userId, id, true);
        repo::adjustVideoCounter(id, "favorite_count", +1);
        bumpHotScore(id, 2.0);
    }
    auto v = repo::findVideoById(id);
    return okJson(v ? v->toJson() : QJsonObject());
}

QHttpServerResponse BilibiliServer::handleUnfavorite(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);
    if (repo::isVideoFavoritedByUser(userId, id)) {
        repo::setVideoFavorited(userId, id, false);
        repo::adjustVideoCounter(id, "favorite_count", -1);
    }
    auto v = repo::findVideoById(id);
    return okJson(v ? v->toJson() : QJsonObject());
}

// ---------- 评论 ----------

QHttpServerResponse BilibiliServer::handleListComments(const QString &id, const QHttpServerRequest &req)
{
    Q_UNUSED(req)
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);
    QJsonArray arr;
    for (const CommentRecord &c : repo::commentsForVideo(id))
        arr.append(c.toJson());
    return okJson(arr);
}

QHttpServerResponse BilibiliServer::handleAddComment(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    auto user = repo::findUserById(userId);
    if (!user)
        return errJson("用户不存在", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);

    const QJsonObject body = jsonBody(req);
    const QString content = body.value("content").toString().trimmed();
    if (content.isEmpty())
        return errJson("评论内容不能为空");

    CommentRecord c;
    c.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    c.videoId = id;
    c.userId = user->id;
    c.userName = user->nickname;
    c.parentId = body.value("parentId").toString();
    c.content = content;

    if (!repo::insertComment(c))
        return errJson("发表评论失败", QHttpServerResponse::StatusCode::InternalServerError);
    repo::incrementVideoCounter(id, "comment_count");
    return okJson(c.toJson(), "评论成功");
}

// ---------- 用户数据 ----------

QHttpServerResponse BilibiliServer::handleHistory(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    QJsonArray arr;
    for (const VideoRecord &v : repo::watchHistoryOf(userId))
        arr.append(v.toJson());
    return okJson(arr);
}

QHttpServerResponse BilibiliServer::handleAddHistory(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);
    repo::addWatchHistory(userId, id);
    return okJson(QJsonValue(), "已记录观看历史");
}

QHttpServerResponse BilibiliServer::handleFavorites(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    QJsonArray arr;
    for (const VideoRecord &v : repo::favoriteVideosOf(userId))
        arr.append(v.toJson());
    return okJson(arr);
}

// ---------- 媒体 ----------

QHttpServerResponse BilibiliServer::handleMedia(const QString &fileName, const QHttpServerRequest &req)
{
    Q_UNUSED(req)
    const QString name = QFileInfo(fileName).fileName(); // 去掉路径部分，防目录穿越
    if (name.isEmpty() || name == "." || name == "..")
        return errJson("文件不存在", QHttpServerResponse::StatusCode::NotFound);

    QFile f(uploadsPath(name));
    if (!f.open(QIODevice::ReadOnly))
        return errJson("文件不存在", QHttpServerResponse::StatusCode::NotFound);
    const QByteArray data = f.readAll();
    return QHttpServerResponse(contentTypeFor(name), data);
}


// ---------- 追加接口（客户端兼容用） ----------

QHttpServerResponse BilibiliServer::handleCreateVideoMeta(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    auto user = repo::findUserById(userId);
    if (!user)
        return errJson("用户不存在", QHttpServerResponse::StatusCode::Unauthorized);

    const QJsonObject body = jsonBody(req);
    const QString title = body.value("title").toString().trimmed();
    const QString videoUrl = body.value("videoUrl").toString().trimmed();
    if (title.isEmpty() || videoUrl.isEmpty())
        return errJson("标题和视频地址不能为空");

    VideoRecord v;
    v.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    v.userId = user->id;
    v.authorName = user->nickname;
    v.title = title;
    v.description = body.value("description").toString();
    v.videoPath = videoUrl;
    v.coverPath = body.value("coverUrl").toString();
    v.tags = body.value("tags").toString();

    if (!repo::insertVideo(v))
        return errJson("写入数据库失败", QHttpServerResponse::StatusCode::InternalServerError);
    auto saved = repo::findVideoById(v.id);
    return okJson(saved ? saved->toJson() : QJsonObject(), "创建成功");
}

QHttpServerResponse BilibiliServer::handleUpdateProfile(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);

    const QJsonObject body = jsonBody(req);
    const QString nickname = body.value("nickname").toString();
    const QString signature = body.value("signature").toString();
    const QString avatarUrl = body.value("avatarUrl").toString();

    if (!repo::updateUserProfile(userId, nickname, signature, avatarUrl))
        return errJson("更新失败", QHttpServerResponse::StatusCode::InternalServerError);

    auto user = repo::findUserById(userId);
    return okJson(user ? user->toJson() : QJsonObject(), "更新成功");
}


QHttpServerResponse BilibiliServer::handleFollowers(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    QJsonArray arr;
    for (const UserRecord &u : repo::followerUsersOf(userId))
        arr.append(u.toJson());
    return okJson(arr);
}
QHttpServerResponse BilibiliServer::handleFollowing(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    QJsonArray arr;
    for (const UserRecord &u : repo::followingUsersOf(userId))
        arr.append(u.toJson());
    return okJson(arr);
}

QHttpServerResponse BilibiliServer::handleFollowUser(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (userId == id)
        return errJson("不能关注自己");
    if (!repo::findUserById(id))
        return errJson("用户不存在", QHttpServerResponse::StatusCode::NotFound);
    repo::followUser(userId, id);
    return okJson(QJsonValue(true), "关注成功");
}

QHttpServerResponse BilibiliServer::handleUnfollowUser(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    repo::unfollowUser(userId, id);
    return okJson(QJsonValue(true), "已取消关注");
}


// ---------- 追加接口：评论/投币/头像/聊天 ----------

QHttpServerResponse BilibiliServer::handleCommentLike(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::commentExists(id))
        return errJson("评论不存在", QHttpServerResponse::StatusCode::NotFound);

    const bool liked = repo::isCommentLikedByUser(userId, id);
    const bool wantLike = (req.method() == QHttpServerRequest::Method::Post);
    if (wantLike && !liked) {
        repo::setCommentLiked(userId, id, true);
        repo::incrementCommentCounter(id, "like_count");
    } else if (!wantLike && liked) {
        repo::setCommentLiked(userId, id, false);
        repo::adjustCommentCounter(id, "like_count", -1);
    }
    return okJson(QJsonValue(wantLike), wantLike ? "已点赞" : "已取消点赞");
}

QHttpServerResponse BilibiliServer::handleCommentUnlike(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::commentExists(id))
        return errJson("评论不存在", QHttpServerResponse::StatusCode::NotFound);
    repo::addCommentUnlike(id);
    return okJson(QJsonValue(true), "已踩");
}

QHttpServerResponse BilibiliServer::handleCoin(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);

    const int userCoins = repo::addUserCoin(userId, id);
    repo::incrementVideoCounter(id, "coin_count");
    bumpHotScore(id, 5.0);
    auto v = repo::findVideoById(id);
    QJsonObject data;
    if (v) {
        data = v->toJson();
        data.insert("userCoinCount", userCoins);
    }
    return okJson(data, "投币成功");
}

QHttpServerResponse BilibiliServer::handleMyCoins(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    return okJson(repo::userCoinCount(userId, id));
}

QHttpServerResponse BilibiliServer::handleUploadAvatar(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    auto user = repo::findUserById(userId);
    if (!user)
        return errJson("用户不存在", QHttpServerResponse::StatusCode::Unauthorized);

    const QString contentType = QString::fromUtf8(req.value("Content-Type"));
    const int b = contentType.indexOf("boundary=");
    if (b < 0)
        return errJson("请求格式不正确（缺少 boundary）");
    const QByteArray boundary = contentType.mid(b + 9).trimmed().toUtf8();

    QByteArray avatarData;
    QString avatarFileName;
    for (const MultipartPart &p : parseMultipart(req.body(), boundary)) {
        if (p.name == "avatar" && !p.data.isEmpty()) {
            avatarData = p.data;
            avatarFileName = p.fileName;
        }
    }
    if (avatarData.isEmpty() || avatarData.size() > 20 * 1024 * 1024)
        return errJson("头像文件无效或超过 20MB");

    QString safe = QFileInfo(avatarFileName).fileName();
    if (safe.isEmpty()) safe = "avatar.png";
    safe = userId + "__avatar__" + safe;
    QFile f(uploadsPath(safe));
    if (!f.open(QIODevice::WriteOnly))
        return errJson("保存头像失败", QHttpServerResponse::StatusCode::InternalServerError);
    f.write(avatarData);
    f.close();

    const QString avatarUrl = "/media/" + safe;
    repo::updateUserProfile(userId, user->nickname, user->signature, avatarUrl);
    auto updated = repo::findUserById(userId);
    return okJson(updated ? updated->toJson() : QJsonObject(), "头像上传成功");
}

QHttpServerResponse BilibiliServer::handleListUsers(const QHttpServerRequest &req)
{
    Q_UNUSED(req)
    QJsonArray arr;
    for (const UserRecord &u : repo::listAllUsers())
        arr.append(u.toJson());
    return okJson(arr);
}

QHttpServerResponse BilibiliServer::handleSendChat(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    auto me = repo::findUserById(userId);
    if (!me)
        return errJson("用户不存在", QHttpServerResponse::StatusCode::Unauthorized);

    const QJsonObject body = jsonBody(req);
    const QString to = body.value("to").toString();
    const QString content = body.value("content").toString().trimmed();
    if (to.isEmpty() || to == userId)
        return errJson("接收人无效");
    if (content.isEmpty())
        return errJson("消息内容不能为空");
    // 支持 userId 或账号名
    QString targetId = to;
    if (!repo::findUserById(to)) {
        auto byAccount = repo::findUserByAccount(to);
        if (!byAccount)
            return errJson("接收人不存在", QHttpServerResponse::StatusCode::NotFound);
        targetId = byAccount->id;
    }

    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (!repo::insertChatMessage(id, userId, targetId, content))
        return errJson("发送失败", QHttpServerResponse::StatusCode::InternalServerError);

    QJsonObject msg{
        {"id", id},
        {"from", userId},
        {"to", to},
        {"fromName", me->nickname},
        {"content", content}
    };
    return okJson(msg, "发送成功");
}

QHttpServerResponse BilibiliServer::handleChatHistory(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    const QString with = req.query().queryItemValue("with");
    if (with.isEmpty())
        return errJson("缺少 with 参数");
    QJsonArray arr;
    for (const QJsonObject &m : repo::chatMessagesBetween(userId, with))
        arr.append(m);
    return okJson(arr);
}


// ---------- 分块上传（大文件 2GB） ----------

QHttpServerResponse BilibiliServer::handleUploadInit(const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);

    const QJsonObject body = jsonBody(req);
    const QString fileName = body.value("fileName").toString().trimmed();
    const qint64 fileSize = body.value("fileSize").toVariant().toLongLong();

    if (fileName.isEmpty())
        return errJson("文件名不能为空");
    if (fileSize <= 0)
        return errJson("文件大小无效");
    if (fileSize > 2LL * 1024 * 1024 * 1024)
        return errJson("文件超过 2GB 上限");

    const QString uploadId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    PendingUpload p;
    p.userId = userId;
    p.tags = body.value("tags").toString();
    p.totalSize = fileSize;
    p.safeName = uploadId + "__video__" + QFileInfo(fileName).fileName();
    const QString tmpDir = m_cfg.uploadsDir + "/tmp";
    QDir().mkpath(tmpDir);
    p.partPath = tmpDir + "/" + uploadId + ".part";

    QFile part(p.partPath);
    if (!part.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return errJson("创建上传文件失败", QHttpServerResponse::StatusCode::InternalServerError);
    }
    part.close();

    m_pendingUploads.insert(uploadId, p);
    qInfo() << "upload init:" << uploadId << fileName << fileSize;

    QJsonObject data{{"uploadId", uploadId}};
    return okJson(data, "开始上传");
}

QHttpServerResponse BilibiliServer::handleUploadChunk(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);

    if (!m_pendingUploads.contains(id))
        return errJson("上传会话不存在", QHttpServerResponse::StatusCode::NotFound);
    PendingUpload &p = m_pendingUploads[id];
    if (p.userId != userId)
        return errJson("无权操作该上传", QHttpServerResponse::StatusCode::Forbidden);

    const QByteArray body = req.body();
    if (body.isEmpty())
        return errJson("空分片");

    QFile part(p.partPath);
    if (!part.open(QIODevice::Append)) {
        return errJson("写入失败", QHttpServerResponse::StatusCode::InternalServerError);
    }
    part.write(body);
    part.close();

    p.received += body.size();
    if (p.received > p.totalSize) {
        m_pendingUploads.remove(id);
        QFile::remove(p.partPath);
        return errJson("数据超过声明大小", QHttpServerResponse::StatusCode::BadRequest);
    }

    QJsonObject data{{"received", p.received}, {"total", p.totalSize}};
    return okJson(data, "分片已接收");
}

QHttpServerResponse BilibiliServer::handleUploadFinalize(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);

    if (!m_pendingUploads.contains(id))
        return errJson("上传会话不存在", QHttpServerResponse::StatusCode::NotFound);
    PendingUpload p = m_pendingUploads[id];
    if (p.userId != userId)
        return errJson("无权操作该上传", QHttpServerResponse::StatusCode::Forbidden);

    if (p.received != p.totalSize)
        return errJson("文件不完整，请重新上传");

    // 解析 multipart：title/description + 可选 cover
    const QString contentType = QString::fromUtf8(req.value("Content-Type"));
    const int b = contentType.indexOf("boundary=");
    if (b < 0)
        return errJson("请求格式不正确（缺少 boundary）");
    const QByteArray boundary = contentType.mid(b + 9).trimmed().toUtf8();

    QString title, description;
    QByteArray coverData;
    QString coverFileName;
    for (const MultipartPart &part : parseMultipart(req.body(), boundary)) {
        if (part.name == "title")
            title = QString::fromUtf8(part.data).trimmed();
        else if (part.name == "description")
            description = QString::fromUtf8(part.data).trimmed();
        else if (part.name == "cover" && !part.data.isEmpty()) {
            coverData = part.data;
            coverFileName = part.fileName;
        }
    }
    if (title.isEmpty())
        return errJson("标题不能为空");

    // 视频文件就位
    const QString videoRel = "/media/" + p.safeName;
    const QString videoAbs = m_cfg.uploadsDir + "/" + p.safeName;
    if (!QFile::rename(p.partPath, videoAbs))
        return errJson("保存视频失败", QHttpServerResponse::StatusCode::InternalServerError);

    // 可选封面
    QString coverRel;
    if (!coverData.isEmpty()) {
        QString safeCover = QFileInfo(coverFileName).fileName();
        if (safeCover.isEmpty()) safeCover = "cover.jpg";
        safeCover = id + "__cover__" + safeCover;
        QFile cf(m_cfg.uploadsDir + "/" + safeCover);
        if (cf.open(QIODevice::WriteOnly)) {
            cf.write(coverData);
            cf.close();
            coverRel = "/media/" + safeCover;
        }
    }

    auto user = repo::findUserById(userId);
    VideoRecord v;
    v.id = id;
    v.userId = userId;
    v.authorName = user ? user->nickname : QString();
    v.title = title;
    v.description = description;
    v.videoPath = videoRel;
    v.coverPath = coverRel;
    v.tags = p.tags;
    if (!repo::insertVideo(v)) {
        m_pendingUploads.remove(id);
        return errJson("写入数据库失败", QHttpServerResponse::StatusCode::InternalServerError);
    }

    m_pendingUploads.remove(id);
    qInfo() << "upload finalized:" << id << title;

    auto saved = repo::findVideoById(id);
    return okJson(saved ? saved->toJson() : QJsonObject(), "上传成功");
}


// ---------- 弹幕 + 上传状态 ----------

QHttpServerResponse BilibiliServer::handleUploadStatus(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    if (!m_pendingUploads.contains(id))
        return errJson("上传会话不存在", QHttpServerResponse::StatusCode::NotFound);
    const PendingUpload &p = m_pendingUploads[id];
    if (p.userId != userId)
        return errJson("无权操作该上传", QHttpServerResponse::StatusCode::Forbidden);
    QJsonObject data{{"received", p.received}, {"total", p.totalSize}};
    return okJson(data);
}

QHttpServerResponse BilibiliServer::handleGetDanmaku(const QString &id, const QHttpServerRequest &req)
{
    Q_UNUSED(req)
    QJsonArray arr;
    for (const DanmakuRecord &d : repo::danmakuForVideo(id))
        arr.append(d.toJson());
    return okJson(arr);
}

QHttpServerResponse BilibiliServer::handlePostDanmaku(const QString &id, const QHttpServerRequest &req)
{
    const QString userId = bearerUserId(req);
    if (userId.isEmpty())
        return errJson("请先登录", QHttpServerResponse::StatusCode::Unauthorized);
    auto user = repo::findUserById(userId);
    if (!user)
        return errJson("用户不存在", QHttpServerResponse::StatusCode::Unauthorized);
    if (!repo::videoExists(id))
        return errJson("视频不存在", QHttpServerResponse::StatusCode::NotFound);

    const QJsonObject body = jsonBody(req);
    const QString content = body.value("content").toString().trimmed();
    if (content.isEmpty() || content.size() > 100)
        return errJson("弹幕内容无效（1-100 字）");

    DanmakuRecord d;
    d.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    d.videoId = id;
    d.userId = userId;
    d.userName = user->nickname;
    d.content = content;
    d.color = body.value("color").toString("#FFFFFF");
    d.timeSec = body.value("time").toDouble();

    if (!repo::insertDanmaku(d))
        return errJson("发送弹幕失败", QHttpServerResponse::StatusCode::InternalServerError);
    return okJson(d.toJson(), "发送成功");
}

// ---------- 开发辅助 ----------

QHttpServerResponse BilibiliServer::handleSeed(const QHttpServerRequest &req)
{
    Q_UNUSED(req)
    const QString demoId = "demo-user-001";
    if (!repo::findUserById(demoId)) {
        UserRecord u;
        u.id = demoId;
        u.account = "demo";
        u.nickname = "演示账号";
        u.salt = auth::generateSalt();
        u.passwordHash = auth::hashPassword("demo123456", u.salt);
        repo::insertUser(u);
    }

    struct Sample { QString id, title, desc, video, cover; };
    const QList<Sample> samples = {
        {"demo-video-001", "测试视频：海洋", "演示数据", "http://vjs.zencdn.net/v/oceans.mp4", "https://picsum.photos/320/180"},
        {"demo-video-002", "测试视频：树屋", "演示数据", "http://vjs.zencdn.net/v/oceans.mp4", "https://picsum.photos/320/181"},
        {"demo-video-003", "测试视频：黄昏", "演示数据", "http://vjs.zencdn.net/v/oceans.mp4", "https://picsum.photos/320/182"}
    };

    QJsonArray arr;
    for (const Sample &s : samples) {
        if (repo::videoExists(s.id))
            continue;
        VideoRecord v;
        v.id = s.id;
        v.userId = demoId;
        v.authorName = "演示账号";
        v.title = s.title;
        v.description = s.desc;
        v.videoPath = s.video;
        v.coverPath = s.cover;
        repo::insertVideo(v);
        auto got = repo::findVideoById(s.id);
        if (got)
            arr.append(got->toJson());
    }
    return okJson(arr, "演示数据已填充（账号 demo / demo123456）");
}
