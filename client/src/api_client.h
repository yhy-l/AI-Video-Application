#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QUrl>
#include <QJsonObject>
#include <QHash>
#include <QList>
#include <functional>

// multipart 上传的一个文件
struct ApiUploadFile {
    QString fieldName;
    QString fileName;
    QString contentType;
    QByteArray data;
};

// 统一的异步 HTTP 客户端
class ApiClient : public QObject {
    Q_OBJECT
public:
    explicit ApiClient(QObject *parent = nullptr);

    void setBaseUrl(const QString &url) { m_baseUrl = url; }
    QString baseUrl() const { return m_baseUrl; }

    void setToken(const QString &token);
    QString token() const { return m_token; }
    // 把 /media/xxx 相对路径补全为完整地址（用于封面/视频/头像）
    QString absoluteUrl(const QString &path) const
    {
        if (!path.startsWith('/'))
            return path;
        // 媒体文件名可能含空格/中文，逐段百分号编码（保留 /）
        const QStringList parts = path.split('/');
        QStringList encoded;
        encoded.reserve(parts.size());
        for (const QString &part : parts) {
            if (part.isEmpty()) {
                encoded << QString();
            } else {
                encoded << QString::fromUtf8(QUrl::toPercentEncoding(part, "/"));
            }
        }
        return m_baseUrl + encoded.join('/');
    }
    // 从本地设置恢复上次保存的 token（登录态持久化）
    static QString loadSavedToken();
    static void clearSavedToken();

    using Callback = std::function<void(bool ok, const QJsonObject &obj)>;

    void getJson(const QString &path, const Callback &cb);
    void postJson(const QString &path, const QJsonObject &body, const Callback &cb);
    void deleteJson(const QString &path, const Callback &cb);
    QNetworkReply *postRaw(const QString &path, const QByteArray &data, const QString &contentType,
                           const Callback &cb);
    // 返回 reply 以便外部取消/监听进度；progressCb(bytesSent, bytesTotal)
    QNetworkReply *postMultipart(const QString &path,
                                 const QHash<QString, QString> &fields,
                                 const QList<ApiUploadFile> &files,
                                 const Callback &cb,
                                 const std::function<void(qint64, qint64)> &progressCb = {});

signals:
    void requestFinished(const QString &path, bool ok);

private:
    QNetworkRequest makeRequest(const QString &path) const;
    void handleReply(QNetworkReply *reply, const Callback &cb);

    QNetworkAccessManager m_nam;
    QString m_baseUrl = "http://127.0.0.1:3000";
    QString m_token;
};
