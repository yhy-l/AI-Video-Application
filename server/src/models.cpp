#include "models.h"

QJsonObject UserRecord::toJson() const
{
    return {
        {"id", id},
        {"account", account},
        {"nickname", nickname},
        {"avatarUrl", avatarUrl},
        {"signature", signature},
        {"createdAt", createdAt.toString(Qt::ISODate)}
    };
}

QJsonObject VideoRecord::toJson() const
{
    QString formatted;
    if (viewCount >= 10000)
        formatted = QString("%1万").arg(viewCount / 10000.0, 0, 'f', 1);
    else
        formatted = QString::number(viewCount);

    return {
        {"id", id},
        {"userId", userId},
        {"author", authorName},
        {"title", title},
        {"description", description},
        {"tags", tags},
        {"uploadDate", createdAt.toString("yyyy-MM-dd")},
        {"videoUrl", videoPath},
        {"coverUrl", coverPath},
        {"viewCount", viewCount},
        {"formattedViewCount", formatted},
        {"likeCount", likeCount},
        {"coinCount", coinCount},
        {"favoriteCount", favoriteCount},
        {"commentCount", commentCount},
        {"createdAt", createdAt.toString(Qt::ISODate)}
    };
}

QJsonObject CommentRecord::toJson() const
{
    return {
        {"id", id},
        {"videoId", videoId},
        {"userId", userId},
        {"userName", userName},
        {"parentId", parentId},
        {"content", content},
        {"likeCount", likeCount},
        {"unlikeCount", unlikeCount},
        {"createdAt", createdAt.toString(Qt::ISODate)}
    };
}
QJsonObject DanmakuRecord::toJson() const
{
    return {
        {"id", id},
        {"videoId", videoId},
        {"userId", userId},
        {"userName", userName},
        {"content", content},
        {"color", color},
        {"time", timeSec},
        {"createdAt", createdAt.toString(Qt::ISODate)}
    };
}