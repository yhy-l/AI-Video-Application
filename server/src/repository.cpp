#include "repository.h"
#include "database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QDebug>

namespace repo {

static VideoRecord videoFromQuery(QSqlQuery &q)
{
    VideoRecord v;
    v.id = q.value("id").toString();
    v.userId = q.value("user_id").toString();
    v.authorName = q.value("author_name").toString();
    v.title = q.value("title").toString();
    v.description = q.value("description").toString();
    v.videoPath = q.value("video_path").toString();
    v.coverPath = q.value("cover_path").toString();
    v.tags = q.value("tags").toString();
    v.viewCount = q.value("view_count").toInt();
    v.likeCount = q.value("like_count").toInt();
    v.coinCount = q.value("coin_count").toInt();
    v.favoriteCount = q.value("favorite_count").toInt();
    v.commentCount = q.value("comment_count").toInt();
    v.createdAt = q.value("created_at").toDateTime();
    return v;
}

static const char *kVideoSelect =
    "SELECT v.id, v.user_id, u.nickname AS author_name, v.title, v.description, "
    "v.video_path, v.cover_path, v.tags, v.view_count, v.like_count, v.coin_count, "
    "v.favorite_count, v.comment_count, v.created_at "
    "FROM videos v JOIN users u ON u.id = v.user_id ";

// ---- 用户 ----

std::optional<UserRecord> findUserByAccount(const QString &account)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT * FROM users WHERE account = ?");
    q.addBindValue(account);
    if (!q.exec() || !q.next())
        return std::nullopt;
    UserRecord u;
    u.id = q.value("id").toString();
    u.account = q.value("account").toString();
    u.passwordHash = q.value("password_hash").toString();
    u.salt = q.value("salt").toString();
    u.nickname = q.value("nickname").toString();
    u.avatarUrl = q.value("avatar_url").toString();
    u.signature = q.value("signature").toString();
    u.createdAt = q.value("created_at").toDateTime();
    return u;
}

std::optional<UserRecord> findUserById(const QString &id)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT * FROM users WHERE id = ?");
    q.addBindValue(id);
    if (!q.exec() || !q.next())
        return std::nullopt;
    UserRecord u;
    u.id = q.value("id").toString();
    u.account = q.value("account").toString();
    u.passwordHash = q.value("password_hash").toString();
    u.salt = q.value("salt").toString();
    u.nickname = q.value("nickname").toString();
    u.avatarUrl = q.value("avatar_url").toString();
    u.signature = q.value("signature").toString();
    u.createdAt = q.value("created_at").toDateTime();
    return u;
}

bool insertUser(const UserRecord &user)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO users (id, account, password_hash, salt, nickname, avatar_url, signature) "
              "VALUES (?, ?, ?, ?, ?, ?, ?)");
    q.addBindValue(user.id);
    q.addBindValue(user.account);
    q.addBindValue(user.passwordHash);
    q.addBindValue(user.salt);
    q.addBindValue(user.nickname);
    q.addBindValue(user.avatarUrl);
    q.addBindValue(user.signature);
    if (!q.exec()) {
        qWarning() << "insertUser failed:" << q.lastError().text();
        return false;
    }
    return true;
}

bool updateUserProfile(const QString &userId, const QString &nickname,
                       const QString &signature, const QString &avatarUrl)
{
    QSqlQuery q(db::connection());
    q.prepare("UPDATE users SET nickname = ?, signature = ?, avatar_url = ? WHERE id = ?");
    q.addBindValue(nickname);
    q.addBindValue(signature);
    q.addBindValue(avatarUrl);
    q.addBindValue(userId);
    return q.exec();
}

bool updateUserPassword(const QString &userId, const QString &passwordHash,
                        const QString &salt)
{
    QSqlQuery q(db::connection());
    q.prepare("UPDATE users SET password_hash = ?, salt = ? WHERE id = ?");
    q.addBindValue(passwordHash);
    q.addBindValue(salt);
    q.addBindValue(userId);
    return q.exec();
}

// ---- 视频 ----

bool insertVideo(VideoRecord &video)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO videos (id, user_id, title, description, video_path, cover_path, tags) "
              "VALUES (?, ?, ?, ?, ?, ?, ?)");
    q.addBindValue(video.id);
    q.addBindValue(video.userId);
    q.addBindValue(video.title);
    q.addBindValue(video.description);
    q.addBindValue(video.videoPath);
    q.addBindValue(video.coverPath);
    q.addBindValue(video.tags);
    if (!q.exec()) {
        qWarning() << "insertVideo failed:" << q.lastError().text();
        return false;
    }
    return true;
}

std::optional<VideoRecord> findVideoById(const QString &id)
{
    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) + "WHERE v.id = ?");
    q.addBindValue(id);
    if (!q.exec() || !q.next())
        return std::nullopt;
    return videoFromQuery(q);
}

QList<VideoRecord> listVideos(int page, int pageSize)
{
    QList<VideoRecord> result;
    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) + "ORDER BY v.created_at DESC LIMIT ? OFFSET ?");
    q.addBindValue(pageSize);
    q.addBindValue((page - 1) * pageSize);
    if (!q.exec()) {
        qWarning() << "listVideos failed:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(videoFromQuery(q));
    return result;
}

QList<VideoRecord> searchVideos(const QString &keyword)
{
    QList<VideoRecord> result;
    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) +
              "WHERE v.title LIKE ? OR u.nickname LIKE ? OR v.description LIKE ? "
              "ORDER BY v.created_at DESC");
    const QString pattern = "%" + keyword + "%";
    q.addBindValue(pattern);
    q.addBindValue(pattern);
    q.addBindValue(pattern);
    if (!q.exec()) {
        qWarning() << "searchVideos failed:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(videoFromQuery(q));
    return result;
}

bool videoExists(const QString &id)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT COUNT(*) FROM videos WHERE id = ?");
    q.addBindValue(id);
    return q.exec() && q.next() && q.value(0).toInt() > 0;
}

bool incrementVideoCounter(const QString &id, const QString &column)
{
    QSqlQuery q(db::connection());
    q.prepare("UPDATE videos SET " + column + " = " + column + " + 1 WHERE id = ?");
    q.addBindValue(id);
    if (!q.exec()) {
        qWarning() << "incrementVideoCounter failed:" << q.lastError().text();
        return false;
    }
    return true;
}

// ---- 评论 ----

bool insertComment(CommentRecord &comment)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO comments (id, video_id, user_id, user_name, parent_id, content) "
              "VALUES (?, ?, ?, ?, ?, ?)");
    q.addBindValue(comment.id);
    q.addBindValue(comment.videoId);
    q.addBindValue(comment.userId);
    q.addBindValue(comment.userName);
    q.addBindValue(comment.parentId);
    q.addBindValue(comment.content);
    if (!q.exec()) {
        qWarning() << "insertComment failed:" << q.lastError().text();
        return false;
    }
    return true;
}

QList<CommentRecord> commentsForVideo(const QString &videoId)
{
    QList<CommentRecord> result;
    QSqlQuery q(db::connection());
    q.prepare("SELECT id, video_id, user_id, user_name, parent_id, content, "
              "like_count, unlike_count, created_at FROM comments "
              "WHERE video_id = ? ORDER BY created_at ASC");
    q.addBindValue(videoId);
    if (!q.exec()) {
        qWarning() << "commentsForVideo failed:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        CommentRecord c;
        c.id = q.value("id").toString();
        c.videoId = q.value("video_id").toString();
        c.userId = q.value("user_id").toString();
        c.userName = q.value("user_name").toString();
        c.parentId = q.value("parent_id").toString();
        c.content = q.value("content").toString();
        c.likeCount = q.value("like_count").toInt();
        c.unlikeCount = q.value("unlike_count").toInt();
        c.createdAt = q.value("created_at").toDateTime();
        result.append(c);
    }
    return result;
}

bool incrementCommentCounter(const QString &commentId, const QString &column)
{
    QSqlQuery q(db::connection());
    q.prepare("UPDATE comments SET " + column + " = " + column + " + 1 WHERE id = ?");
    q.addBindValue(commentId);
    return q.exec();
}

// ---- 互动 ----

bool isVideoLikedByUser(const QString &userId, const QString &videoId)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT COUNT(*) FROM video_likes WHERE user_id = ? AND video_id = ?");
    q.addBindValue(userId);
    q.addBindValue(videoId);
    return q.exec() && q.next() && q.value(0).toInt() > 0;
}

bool setVideoLiked(const QString &userId, const QString &videoId, bool liked)
{
    QSqlQuery q(db::connection());
    if (liked) {
        q.prepare("INSERT IGNORE INTO video_likes (user_id, video_id) VALUES (?, ?)");
    } else {
        q.prepare("DELETE FROM video_likes WHERE user_id = ? AND video_id = ?");
    }
    q.addBindValue(userId);
    q.addBindValue(videoId);
    return q.exec();
}

bool isVideoFavoritedByUser(const QString &userId, const QString &videoId)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT COUNT(*) FROM favorites WHERE user_id = ? AND video_id = ?");
    q.addBindValue(userId);
    q.addBindValue(videoId);
    return q.exec() && q.next() && q.value(0).toInt() > 0;
}

bool setVideoFavorited(const QString &userId, const QString &videoId, bool favorited)
{
    QSqlQuery q(db::connection());
    if (favorited) {
        q.prepare("INSERT IGNORE INTO favorites (user_id, video_id) VALUES (?, ?)");
    } else {
        q.prepare("DELETE FROM favorites WHERE user_id = ? AND video_id = ?");
    }
    q.addBindValue(userId);
    q.addBindValue(videoId);
    return q.exec();
}

QList<VideoRecord> favoriteVideosOf(const QString &userId)
{
    QList<VideoRecord> result;
    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) +
              "JOIN favorites f ON f.video_id = v.id AND f.user_id = ? "
              "ORDER BY f.created_at DESC");
    q.addBindValue(userId);
    if (!q.exec()) {
        qWarning() << "favoriteVideosOf failed:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(videoFromQuery(q));
    return result;
}

// ---- 历史 ----

bool addWatchHistory(const QString &userId, const QString &videoId)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO watch_history (user_id, video_id) VALUES (?, ?) "
              "ON DUPLICATE KEY UPDATE watched_at = CURRENT_TIMESTAMP");
    q.addBindValue(userId);
    q.addBindValue(videoId);
    return q.exec();
}

QList<VideoRecord> watchHistoryOf(const QString &userId)
{
    QList<VideoRecord> result;
    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) +
              "JOIN watch_history h ON h.video_id = v.id AND h.user_id = ? "
              "ORDER BY h.watched_at DESC");
    q.addBindValue(userId);
    if (!q.exec()) {
        qWarning() << "watchHistoryOf failed:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(videoFromQuery(q));
    return result;
}

}
namespace repo {

bool adjustVideoCounter(const QString &id, const QString &column, int delta)
{
    QSqlQuery q(db::connection());
    q.prepare("UPDATE videos SET " + column + " = GREATEST(" + column + " + ?, 0) WHERE id = ?");
    q.addBindValue(delta);
    q.addBindValue(id);
    if (!q.exec()) {
        qWarning() << "adjustVideoCounter failed:" << q.lastError().text();
        return false;
    }
    return true;
}


// ---- 关注 ----

bool followUser(const QString &followerId, const QString &followingId)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT IGNORE INTO follow_relations (follower_id, following_id) VALUES (?, ?)");
    q.addBindValue(followerId);
    q.addBindValue(followingId);
    return q.exec();
}

bool unfollowUser(const QString &followerId, const QString &followingId)
{
    QSqlQuery q(db::connection());
    q.prepare("DELETE FROM follow_relations WHERE follower_id = ? AND following_id = ?");
    q.addBindValue(followerId);
    q.addBindValue(followingId);
    return q.exec();
}

bool isFollowing(const QString &followerId, const QString &followingId)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT COUNT(*) FROM follow_relations WHERE follower_id = ? AND following_id = ?");
    q.addBindValue(followerId);
    q.addBindValue(followingId);
    return q.exec() && q.next() && q.value(0).toInt() > 0;
}

QList<UserRecord> followingUsersOf(const QString &userId)
{
    QList<UserRecord> result;
    QSqlQuery q(db::connection());
    q.prepare("SELECT u.* FROM users u JOIN follow_relations f ON f.following_id = u.id "
              "WHERE f.follower_id = ? ORDER BY f.created_at DESC");
    q.addBindValue(userId);
    if (!q.exec()) {
        qWarning() << "followingUsersOf failed:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        UserRecord u;
        u.id = q.value("id").toString();
        u.account = q.value("account").toString();
        u.passwordHash.clear();
        u.salt.clear();
        u.nickname = q.value("nickname").toString();
        u.avatarUrl = q.value("avatar_url").toString();
        u.signature = q.value("signature").toString();
        u.createdAt = q.value("created_at").toDateTime();
        result.append(u);
    }
    return result;
}

// ---- 令牌 ----

bool saveToken(const QString &token, const QString &userId)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO tokens (token, user_id) VALUES (?, ?)");
    q.addBindValue(token);
    q.addBindValue(userId);
    return q.exec();
}

QString userIdForToken(const QString &token)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT user_id FROM tokens WHERE token = ?");
    q.addBindValue(token);
    if (q.exec() && q.next())
        return q.value("user_id").toString();
    return QString();
}

bool removeToken(const QString &token)
{
    QSqlQuery q(db::connection());
    q.prepare("DELETE FROM tokens WHERE token = ?");
    q.addBindValue(token);
    return q.exec();
}

// ---- 评论点赞/踩 ----

bool commentExists(const QString &commentId)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT COUNT(*) FROM comments WHERE id = ?");
    q.addBindValue(commentId);
    return q.exec() && q.next() && q.value(0).toInt() > 0;
}

bool isCommentLikedByUser(const QString &userId, const QString &commentId)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT COUNT(*) FROM comment_likes WHERE user_id = ? AND comment_id = ?");
    q.addBindValue(userId);
    q.addBindValue(commentId);
    return q.exec() && q.next() && q.value(0).toInt() > 0;
}

bool setCommentLiked(const QString &userId, const QString &commentId, bool liked)
{
    QSqlQuery q(db::connection());
    if (liked)
        q.prepare("INSERT IGNORE INTO comment_likes (user_id, comment_id) VALUES (?, ?)");
    else
        q.prepare("DELETE FROM comment_likes WHERE user_id = ? AND comment_id = ?");
    q.addBindValue(userId);
    q.addBindValue(commentId);
    return q.exec();
}

bool addCommentUnlike(const QString &commentId)
{
    QSqlQuery q(db::connection());
    q.prepare("UPDATE comments SET unlike_count = unlike_count + 1 WHERE id = ?");
    q.addBindValue(commentId);
    return q.exec();
}

// ---- 投币 ----

int addUserCoin(const QString &userId, const QString &videoId)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO video_coins (user_id, video_id, coin_count) VALUES (?, ?, 1) "
              "ON DUPLICATE KEY UPDATE coin_count = coin_count + 1");
    q.addBindValue(userId);
    q.addBindValue(videoId);
    if (!q.exec())
        return -1;
    return userCoinCount(userId, videoId);
}

int userCoinCount(const QString &userId, const QString &videoId)
{
    QSqlQuery q(db::connection());
    q.prepare("SELECT coin_count FROM video_coins WHERE user_id = ? AND video_id = ?");
    q.addBindValue(userId);
    q.addBindValue(videoId);
    if (q.exec() && q.next())
        return q.value(0).toInt();
    return 0;
}

// ---- 聊天 ----

bool insertChatMessage(const QString &id, const QString &fromUser, const QString &toUser,
                       const QString &content)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO chat_messages (id, from_user, to_user, content) VALUES (?, ?, ?, ?)");
    q.addBindValue(id);
    q.addBindValue(fromUser);
    q.addBindValue(toUser);
    q.addBindValue(content);
    return q.exec();
}

QList<QJsonObject> chatMessagesBetween(const QString &userA, const QString &userB)
{
    QList<QJsonObject> result;
    QSqlQuery q(db::connection());
    q.prepare("SELECT m.id, m.from_user, m.to_user, m.content, m.created_at, "
              "fu.nickname AS from_name, tu.nickname AS to_name "
              "FROM chat_messages m "
              "JOIN users fu ON fu.id = m.from_user "
              "JOIN users tu ON tu.id = m.to_user "
              "WHERE (m.from_user = ? AND m.to_user = ?) OR (m.from_user = ? AND m.to_user = ?) "
              "ORDER BY m.created_at ASC");
    q.addBindValue(userA);
    q.addBindValue(userB);
    q.addBindValue(userB);
    q.addBindValue(userA);
    if (!q.exec()) {
        qWarning() << "chatMessagesBetween failed:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QJsonObject{
            {"id", q.value("id").toString()},
            {"from", q.value("from_user").toString()},
            {"to", q.value("to_user").toString()},
            {"fromName", q.value("from_name").toString()},
            {"toName", q.value("to_name").toString()},
            {"content", q.value("content").toString()},
            {"createdAt", q.value("created_at").toDateTime().toString(Qt::ISODate)}
        });
    }
    return result;
}

QList<UserRecord> listAllUsers()
{
    QList<UserRecord> result;
    QSqlQuery q(db::connection());
    if (!q.exec("SELECT id, account, nickname, avatar_url, signature, created_at FROM users ORDER BY created_at DESC")) {
        qWarning() << "listAllUsers failed:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        UserRecord u;
        u.id = q.value("id").toString();
        u.account = q.value("account").toString();
        u.passwordHash.clear();
        u.salt.clear();
        u.nickname = q.value("nickname").toString();
        u.avatarUrl = q.value("avatar_url").toString();
        u.signature = q.value("signature").toString();
        u.createdAt = q.value("created_at").toDateTime();
        result.append(u);
    }
    return result;
}

bool adjustCommentCounter(const QString &commentId, const QString &column, int delta)
{
    QSqlQuery q(db::connection());
    q.prepare("UPDATE comments SET " + column + " = GREATEST(" + column + " + ?, 0) WHERE id = ?");
    q.addBindValue(delta);
    q.addBindValue(commentId);
    return q.exec();
}

QList<UserRecord> followerUsersOf(const QString &userId)
{
    QList<UserRecord> result;
    QSqlQuery q(db::connection());
    q.prepare("SELECT u.* FROM users u JOIN follow_relations f ON f.follower_id = u.id "
              "WHERE f.following_id = ? ORDER BY f.created_at DESC");
    q.addBindValue(userId);
    if (!q.exec()) {
        qWarning() << "followerUsersOf failed:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        UserRecord u;
        u.id = q.value("id").toString();
        u.account = q.value("account").toString();
        u.passwordHash.clear();
        u.salt.clear();
        u.nickname = q.value("nickname").toString();
        u.avatarUrl = q.value("avatar_url").toString();
        u.signature = q.value("signature").toString();
        u.createdAt = q.value("created_at").toDateTime();
        result.append(u);
    }
    return result;
}

// ---- 弹幕 ----

bool insertDanmaku(DanmakuRecord &danmaku)
{
    QSqlQuery q(db::connection());
    q.prepare("INSERT INTO danmaku (id, video_id, user_id, user_name, content, time_sec, color) "
              "VALUES (?, ?, ?, ?, ?, ?, ?)");
    q.addBindValue(danmaku.id);
    q.addBindValue(danmaku.videoId);
    q.addBindValue(danmaku.userId);
    q.addBindValue(danmaku.userName);
    q.addBindValue(danmaku.content);
    q.addBindValue(danmaku.timeSec);
    q.addBindValue(danmaku.color);
    return q.exec();
}

QList<DanmakuRecord> danmakuForVideo(const QString &videoId)
{
    QList<DanmakuRecord> result;
    QSqlQuery q(db::connection());
    q.prepare("SELECT id, video_id, user_id, user_name, content, time_sec, color, created_at "
              "FROM danmaku WHERE video_id = ? ORDER BY time_sec ASC");
    q.addBindValue(videoId);
    if (!q.exec()) {
        qWarning() << "danmakuForVideo failed:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        DanmakuRecord d;
        d.id = q.value("id").toString();
        d.videoId = q.value("video_id").toString();
        d.userId = q.value("user_id").toString();
        d.userName = q.value("user_name").toString();
        d.content = q.value("content").toString();
        d.color = q.value("color").toString();
        d.timeSec = q.value("time_sec").toDouble();
        d.createdAt = q.value("created_at").toDateTime();
        result.append(d);
    }
    return result;
}

QList<VideoRecord> listHotVideos(int page, int pageSize)
{
    QList<VideoRecord> result;
    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) + "ORDER BY v.view_count DESC LIMIT ? OFFSET ?");
    q.addBindValue(pageSize);
    q.addBindValue((page - 1) * pageSize);
    if (!q.exec()) {
        qWarning() << "listHotVideos failed:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(videoFromQuery(q));
    return result;
}

QList<VideoRecord> videosByIds(const QStringList &ids)
{
    QList<VideoRecord> result;
    if (ids.isEmpty())
        return result;

    QStringList ph;
    QVariantList binds;
    for (const QString &id : ids) {
        ph << "?";
        binds << id;
    }

    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) + "WHERE v.id IN (" + ph.join(",") + ")");
    for (const QVariant &b : binds)
        q.addBindValue(b);
    if (!q.exec()) {
        qWarning() << "videosByIds failed:" << q.lastError().text();
        return result;
    }

    QHash<QString, VideoRecord> byId;
    while (q.next()) {
        VideoRecord v = videoFromQuery(q);
        byId.insert(v.id, v);
    }
    for (const QString &id : ids) {
        auto it = byId.constFind(id);
        if (it != byId.constEnd())
            result.append(it.value());
    }
    return result;
}

QList<VideoRecord> listVideosByViews(int limit)
{
    QList<VideoRecord> result;
    QSqlQuery q(db::connection());
    q.prepare(QString(kVideoSelect) + "ORDER BY v.view_count DESC, v.created_at DESC LIMIT ?");
    q.addBindValue(limit);
    if (!q.exec()) {
        qWarning() << "listVideosByViews failed:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(videoFromQuery(q));
    return result;
}
} // namespace repo
