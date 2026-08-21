#include "api_client.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QRandomGenerator>
#include <QUuid>
#include <QHttpMultiPart>
#include <QUrlQuery>
#include <QDebug>
#include <QSettings>

ApiClient::ApiClient(QObject *parent)
    : QObject(parent)
{
}

QNetworkRequest ApiClient::makeRequest(const QString &path) const
{
    QNetworkRequest req(QUrl(m_baseUrl + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (!m_token.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    return req;
}

void ApiClient::handleReply(QNetworkReply *reply, const Callback &cb)
{
    QJsonObject obj;
    const QByteArray data = reply->readAll();
    const QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isObject())
        obj = doc.object();
    else if (doc.isArray())
        obj.insert("data", doc.array());

    if (reply->error() != QNetworkReply::NoError) {
        obj.insert("code", 1);
        if (obj.value("message").toString().isEmpty())
            obj.insert("message", reply->errorString());
    }
    emit requestFinished(reply->url().path(), reply->error() == QNetworkReply::NoError);
    if (cb)
        cb(reply->error() == QNetworkReply::NoError, obj);
    reply->deleteLater();
}

void ApiClient::getJson(const QString &path, const Callback &cb)
{
    QNetworkReply *reply = m_nam.get(makeRequest(path));
    connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() { handleReply(reply, cb); });
}

void ApiClient::postJson(const QString &path, const QJsonObject &body, const Callback &cb)
{
    QNetworkReply *reply = m_nam.post(makeRequest(path), QJsonDocument(body).toJson());
    connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() { handleReply(reply, cb); });
}

void ApiClient::deleteJson(const QString &path, const Callback &cb)
{
    QNetworkReply *reply = m_nam.deleteResource(makeRequest(path));
    connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() { handleReply(reply, cb); });
}

QNetworkReply *ApiClient::postMultipart(const QString &path,
                                 const QHash<QString, QString> &fields,
                                 const QList<ApiUploadFile> &files,
                                 const Callback &cb,
                                 const std::function<void(qint64, qint64)> &progressCb)
{
    // 手写标准 multipart/form-data 报文（避免 QHttpMultiPart 格式差异）
    const QByteArray boundary = "----bilibiliClient" + QByteArray::number(QRandomGenerator::global()->generate(), 16);
    QByteArray body;

    for (auto it = fields.constBegin(); it != fields.constEnd(); ++it) {
        body += "--" + boundary + "\r\n";
        body += "Content-Disposition: form-data; name=\"" + it.key().toUtf8() + "\"\r\n\r\n";
        body += it.value().toUtf8() + "\r\n";
    }

    for (const ApiUploadFile &f : files) {
        body += "--" + boundary + "\r\n";
        body += "Content-Disposition: form-data; name=\"" + f.fieldName.toUtf8()
                + "\"; filename=\"" + f.fileName.toUtf8() + "\"\r\n";
        body += "Content-Type: " + f.contentType.toUtf8() + "\r\n\r\n";
        body += f.data + "\r\n";
    }
    body += "--" + boundary + "--\r\n";

    QNetworkRequest req(QUrl(m_baseUrl + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "multipart/form-data; boundary=" + boundary);
    if (!m_token.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());

    QNetworkReply *reply = m_nam.post(req, body);
    if (progressCb) {
        connect(reply, &QNetworkReply::uploadProgress, this,
                [progressCb](qint64 sent, qint64 total) { progressCb(sent, total); });
    }
    connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() { handleReply(reply, cb); });
    return reply;
}
void ApiClient::setToken(const QString &token)
{
    m_token = token;
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    if (token.isEmpty())
        s.remove("auth/token");
    else
        s.setValue("auth/token", token);
}

QString ApiClient::loadSavedToken()
{
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    return s.value("auth/token").toString();
}

void ApiClient::clearSavedToken()
{
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    s.remove("auth/token");
}
QNetworkReply *ApiClient::postRaw(const QString &path, const QByteArray &data, const QString &contentType,
                                  const Callback &cb)
{
    QNetworkRequest req(QUrl(m_baseUrl + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    if (!m_token.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    QNetworkReply *reply = m_nam.post(req, data);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() { handleReply(reply, cb); });
    return reply;
}