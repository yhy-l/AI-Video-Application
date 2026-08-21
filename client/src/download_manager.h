#pragma once
#include <QObject>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QList>

// 异步下载管理器
class DownloadManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList downloads READ downloads NOTIFY downloadsChanged)
    Q_PROPERTY(QString downloadDir READ downloadDir WRITE setDownloadDir NOTIFY downloadDirChanged)
public:
    explicit DownloadManager(QObject *parent = nullptr);

    QVariantList downloads() const;
    QString downloadDir() const;
    void setDownloadDir(const QString &dir);

    Q_INVOKABLE void startDownload(const QString &url, const QString &videoId,
                                   const QString &title);
    Q_INVOKABLE void openDownloadDir();

signals:
    void downloadsChanged();
    void downloadDirChanged();
    void downloadFinished(const QString &videoId, const QString &filePath);

private:
    struct Task {
        QString id;          // 任务 id（随机）
        QString videoId;     // 视频 id
        QString title;       // 视频标题
        QString url;         // 下载地址
        QString status;      // 下载中 / 已完成 / 失败
        QString filePath;    // 目标文件路径
        qint64 received = 0;
        qint64 total = 0;
        int lastEmitPct = -1;
        QNetworkReply *reply = nullptr;
        QFile *file = nullptr;
    };

    QString safeFileName(const QString &name) const;
    void emitDownloadsChanged();

    QNetworkAccessManager m_nam;
    QList<Task*> m_tasks;
    QString m_dir;
};
