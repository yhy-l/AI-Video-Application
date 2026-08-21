#include "download_manager.h"
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <QRegularExpression>
#include <QDateTime>
#include <QUuid>
#include <QDesktopServices>
#include <QDebug>

DownloadManager::DownloadManager(QObject *parent)
    : QObject(parent)
{
    // 默认下载目录：用户"下载"目录下的 bilibili 文件夹
    m_dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (m_dir.isEmpty())
        m_dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    m_dir = m_dir + "/bilibili";
    QDir().mkpath(m_dir);
}

QVariantList DownloadManager::downloads() const
{
    QVariantList list;
    for (const Task *t : m_tasks) {
        list.append(QVariantMap{
            {"id", t->id},
            {"videoId", t->videoId},
            {"title", t->title},
            {"status", t->status},
            {"filePath", t->filePath},
            {"progress", t->total > 0 ? int(t->received * 100 / t->total) : 0},
            {"received", t->received},
            {"total", t->total}
        });
    }
    return list;
}

QString DownloadManager::downloadDir() const
{
    return m_dir;
}

void DownloadManager::setDownloadDir(const QString &dir)
{
    QString d = dir;
    if (d.startsWith("file:///"))
        d = QUrl(d).toLocalFile();
    if (d.isEmpty() || !QDir().mkpath(d))
        return;
    if (m_dir == d)
        return;
    m_dir = d;
    emit downloadDirChanged();
}

QString DownloadManager::safeFileName(const QString &name) const
{
    QString s = name.trimmed();
    if (s.isEmpty())
        s = "video";
    s.replace(QRegularExpression(R"([\\/:*?"<>|])"), "_");
    if (s.length() > 80)
        s = s.left(80);
    return s;
}

void DownloadManager::startDownload(const QString &url, const QString &videoId,
                                    const QString &title)
{
    if (url.isEmpty())
        return;
    // 同一视频已有下载任务则跳过
    for (const Task *t : m_tasks) {
        if (t->videoId == videoId && t->status == "下载中")
            return;
    }

    QDir().mkpath(m_dir);
    const QString fileName = safeFileName(title) + ".mp4";
    const QString filePath = m_dir + "/" + fileName;

    Task *t = new Task;
    t->id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    t->videoId = videoId;
    t->title = title;
    t->url = url;
    t->status = "下载中";
    t->filePath = filePath;
    t->file = new QFile(filePath);
    if (!t->file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        t->status = "失败";
        m_tasks.append(t);
        emit downloadsChanged();
        return;
    }

    QNetworkRequest req{ QUrl(url) };
    t->reply = m_nam.get(req);
    m_tasks.append(t);
    emit downloadsChanged();

    connect(t->reply, &QNetworkReply::downloadProgress, this, [this, t](qint64 recv, qint64 total) {
        t->received = recv;
        t->total = total;
        // 进度变化 >=1% 才通知一次，避免高频刷新
        const int pct = total > 0 ? int(recv * 100 / total) : 0;
        if (pct != t->lastEmitPct) {
            t->lastEmitPct = pct;
            emitDownloadsChanged();
        }
    });
    connect(t->reply, &QNetworkReply::readyRead, this, [this, t]() {
        if (t->file)
            t->file->write(t->reply->readAll());
    });
    connect(t->reply, &QNetworkReply::finished, this, [this, t]() {
        t->reply->deleteLater();
        t->reply = nullptr;
        if (t->file) {
            t->file->flush();
            t->file->close();
            delete t->file;
            t->file = nullptr;
        }
        if (t->status == "下载中" && t->total > 0 && t->received >= t->total) {
            t->status = "已完成";
            emit downloadFinished(t->videoId, t->filePath);
        } else {
            t->status = "失败";
        }
        emit downloadsChanged();
    });
}

void DownloadManager::openDownloadDir()
{
    QDir().mkpath(m_dir);
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_dir));
}

void DownloadManager::emitDownloadsChanged()
{
    // 进度刷新不阻塞 UI；QML 列表直接绑定 downloads
    emit downloadsChanged();
}
