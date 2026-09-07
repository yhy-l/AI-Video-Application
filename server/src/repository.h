#pragma once
#include "models.h"
#include <QJsonObject>
#include <QList>
#include <QPair>
#include <optional>

namespace repo {

// ---- 用户 ----
std::optional<UserRecord> findUserByAccount(const QString &account);
std::optional<UserRecord> findUserById(const QString &id);
bool insertUser(const UserRecord &user);
bool updateUserProfile(const QString &userId, const QString &nickname,
                       const QString &signature, const QString &avatarUrl);
bool updateUserPassword(const QString &userId, const QString &passwordHash,
                        const QString &salt);

// ---- 视频 ----
bool insertVideo(VideoRecord &video); // video.tags 逗号分隔
std::optional<VideoRecord> findVideoById(const QString &id);
QList<VideoRecord> listVideos(int page, int pageSize);
QList<VideoRecord> videosByUser(const QString &userId);   // 我的投稿
QList<VideoRecord> listHotVideos(int page, int pageSize);
QList<VideoRecord> listVideosByViews(int limit);
QList<VideoRecord> videosByIds(const QStringList &ids);
QList<VideoRecord> searchVideos(const QString &keyword);
bool videoExists(const QString &id);
bool incrementVideoCounter(const QString &id, const QString &column);
bool deleteVideoRecord(const QString &videoId);   // 删除数据库记录及全部关联表（调用方负责删磁盘文件）

// ---- 转码元数据/任务状态 ----
bool updateVideoMediaMeta(const QString &videoId, int width, int height, double durationSec, qint64 fileSize);
bool ensureTranscodeTask(const QString &videoId, int quality);
bool updateTranscodeTask(const QString &videoId, int quality, const QString &status, int progress);
QList<TranscodeTaskInfo> transcodeTasksOf(const QString &videoId);
QList<QPair<QString,int>> pendingTranscodeTasks();   // 服务启动恢复
QStringList doneQualitiesOfVideo(const QString &videoId);
bool setVideoTranscodeStatus(const QString &videoId, const QString &status, const QStringList &doneQualities);
QList<QString> videosNeedingTranscode();   // 启动恢复：未转码完成的视频
bool removeTranscodeTask(const QString &videoId, int quality);   // 清理超源分辨率的孤儿任务

// ---- 评论 ----
bool insertComment(CommentRecord &comment);
QList<CommentRecord> commentsForVideo(const QString &videoId);
bool incrementCommentCounter(const QString &commentId, const QString &column);
bool adjustCommentCounter(const QString &commentId, const QString &column, int delta);

// ---- 互动 ----
bool isVideoLikedByUser(const QString &userId, const QString &videoId);
bool setVideoLiked(const QString &userId, const QString &videoId, bool liked);
bool isVideoFavoritedByUser(const QString &userId, const QString &videoId);
bool setVideoFavorited(const QString &userId, const QString &videoId, bool favorited);
QList<VideoRecord> favoriteVideosOf(const QString &userId);

// ---- 历史 ----
bool addWatchHistory(const QString &userId, const QString &videoId);
QList<VideoRecord> watchHistoryOf(const QString &userId);

bool adjustVideoCounter(const QString &id, const QString &column, int delta);

// ---- 关注 ----
bool followUser(const QString &followerId, const QString &followingId);
bool unfollowUser(const QString &followerId, const QString &followingId);
bool isFollowing(const QString &followerId, const QString &followingId);
QList<UserRecord> followingUsersOf(const QString &userId);
QList<UserRecord> followerUsersOf(const QString &userId);

// ---- 令牌 ----
bool saveToken(const QString &token, const QString &userId);
QString userIdForToken(const QString &token);
bool removeToken(const QString &token);

// ---- 评论点赞/踩 ----
bool commentExists(const QString &commentId);
bool isCommentLikedByUser(const QString &userId, const QString &commentId);
bool setCommentLiked(const QString &userId, const QString &commentId, bool liked);
bool addCommentUnlike(const QString &commentId);

// ---- 投币 ----
int addUserCoin(const QString &userId, const QString &videoId);
int userCoinCount(const QString &userId, const QString &videoId);

// ---- 聊天 ----
bool insertChatMessage(const QString &id, const QString &fromUser, const QString &toUser,
                       const QString &content);
QList<QJsonObject> chatMessagesBetween(const QString &userA, const QString &userB);
QList<UserRecord> listAllUsers();

// ---- 弹幕 ----
bool insertDanmaku(DanmakuRecord &danmaku);
QList<DanmakuRecord> danmakuForVideo(const QString &videoId);

}
