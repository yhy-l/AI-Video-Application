#include "ai_chat_client.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>

AiChatClient::AiChatClient(ApiClient *api, QObject *parent)
    : QObject(parent)
    , m_api(api)
{
}

void AiChatClient::sendMessage(const QString &sessionId, const QString &question)
{
    QJsonObject body{
        {"question", question},
        {"session_id", sessionId},
        {"token", m_api->token()},
    };
    QNetworkRequest req(QUrl(m_baseUrl + "/chat"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    QNetworkReply *reply = m_nam.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred("AI 服务连接失败: " + reply->errorString());
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (obj.isEmpty()) {
            emit errorOccurred("AI 服务返回异常");
            return;
        }
        QStringList tools;
        const QJsonArray arr = obj.value("tools_used").toArray();
        for (const QJsonValue &v : arr)
            tools << v.toString();
        emit replyReady(obj.value("session_id").toString(),
                        obj.value("answer").toString(),
                        tools);
    });
}
