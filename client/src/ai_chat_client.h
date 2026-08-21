#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include "api_client.h"

// AI 助手客户端：与 ai_service(8010) 通信，多轮会话 + ToolCalling
class AiChatClient : public QObject {
    Q_OBJECT
public:
    explicit AiChatClient(ApiClient *api, QObject *parent = nullptr);

    Q_INVOKABLE void sendMessage(const QString &sessionId, const QString &question);
    Q_INVOKABLE QString currentToken() const { return m_api->token(); }

signals:
    void replyReady(const QString &sessionId, const QString &answer,
                    const QStringList &toolsUsed);
    void errorOccurred(const QString &message);

private:
    ApiClient *m_api;
    QNetworkAccessManager m_nam;
    QString m_baseUrl = "http://127.0.0.1:8010";
};
