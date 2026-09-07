#include "models.h"
#include <QJsonArray>

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

// 由 /media/<原名>.mp4 推导某清晰度文件名：<原名>__<q>.mp4
static QString mediaVariantPath(const QString &basePath, const QString &suffix)
{
    const int ext = basePath.lastIndexOf('.');
    if (ext <= 0)
        return basePath + "__" + suffix;
    return basePath.left(ext) + "__" + suffix + basePath.mid(ext);
}

QJsonObject VideoRecord::toJson() const
{
    QString formatted;
    if (viewCount >= 10000)
        formatted = QString("%1万").arg(viewCount / 10000.0, 0, 'f', 1);
    else
        formatted = QString::number(viewCount);

    // 可用清晰度：源视频 + "计划生成的档位"。
    // 无论转码是否完成都把候选档位列出来（state=ready/transcoding/failed/pending），
    // 这样客户端在转码期间也能看到完整清晰度列表（未就绪项置灰）。
    QJsonArray qualities;
    QJsonObject orig;
    orig.insert("quality", 0);
    orig.insert("name", "原画");
    orig.insert("url", videoPath);
    orig.insert("state", "ready");
    qualities.append(orig);

    const QStringList done = doneQualities.split(',', Qt::SkipEmptyParts);
    const int shortSide = qMin(width, height);
    QList<int> planned;
    if (width > 0 && height > 0) {
        if (shortSide >= 1080) planned << 1080;
        if (shortSide >= 720)  planned << 720;
        if (shortSide >= 480)  planned << 480;
    }
    const QString status = transcodeStatus.isEmpty() ? "none" : transcodeStatus;
    for (int qn : planned) {
        QJsonObject item;
        item.insert("quality", qn);
        item.insert("name", qn >= 2160 ? QString::number(qn / 1000.0) + "K" : QString::number(qn) + "P");
        item.insert("url", mediaVariantPath(videoPath, QString::number(qn)));
        if (done.contains(QString::number(qn)))
            item.insert("state", "ready");
        else if (status == "transcoding")
            item.insert("state", "transcoding");
        else if (status == "done")
            item.insert("state", "failed");
        else
            item.insert("state", "pending");
        qualities.append(item);
    }

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
        {"createdAt", createdAt.toString(Qt::ISODate)},
        // 转码元数据
        {"width", width},
        {"height", height},
        {"durationSec", durationSec},
        {"fileSizeBytes", qint64(fileSizeBytes)},
        {"transcodeStatus", status},
        {"transcodeTasks", QJsonArray()},   // 占位：server 层查询后补充实际进度
        {"qualities", qualities}
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
