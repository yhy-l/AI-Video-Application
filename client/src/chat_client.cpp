#include "chat_client.h"
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

ChatClient::ChatClient(ApiClient *api, QObject *parent)
    : QObject(parent)
    , m_api(api)
{
    m_pollTimer.setInterval(3000);
    connect(&m_pollTimer, &QTimer::timeout, this, [this]() {
        if (!m_connected)
            return;
        refreshUsers();
        if (!m_activeId.isEmpty())
            refreshHistory();
    });
}

void ChatClient::setName(const QString &name)
{
    if (m_name == name)
        return;
    m_name = name;
    emit nameChanged(m_name);
    refreshUsers();
}

bool ChatClient::connectToServer(const QString &host, quint16 port)
{
    m_serverIp = host.isEmpty() ? "127.0.0.1" : host;
    m_serverPort = port;
    emit serverInfoChanged();

    if (m_api->token().isEmpty()) {
        emit connectionError("请先登录，再进入消息中心");
        return false;
    }

    m_connecting = true;
    emit connectingChanged(true);
    m_connected = true;
    m_connecting = false;
    emit connectingChanged(false);
    emit connected();
    emit connectionChanged();

    refreshUsers();
    m_pollTimer.start();
    return true;
}

void ChatClient::disconnectFromServer()
{
    m_pollTimer.stop();
    m_connected = false;
    emit disconnected();
    emit connectionChanged();
}

void ChatClient::refreshUsers()
{
    m_api->getJson("/api/users", [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0)
            return;
        const QJsonArray arr = obj.value("data").toArray();
        QStringList names;
        m_nameToId.clear();
        for (const QJsonValue &v : arr) {
            const QJsonObject u = v.toObject();
            const QString nick = u.value("nickname").toString();
            if (nick.isEmpty() || nick == m_selfName)
                continue;
            m_nameToId.insert(nick, u.value("id").toString());
            names << nick;
        }
        if (names != m_clientList) {
            m_clientList = names;
            emit clientListChanged();
        }
    });
}

void ChatClient::refreshHistory()
{
    if (m_activeId.isEmpty())
        return;
    m_api->getJson("/api/chat/messages?with=" + m_activeId,
                   [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0)
            return;
        const QJsonArray arr = obj.value("data").toArray();
        QString text;
        for (const QJsonValue &v : arr) {
            const QJsonObject m = v.toObject();
            const QString fromName = m.value("fromName").toString();
            text += (fromName == m_selfName ? "我" : fromName)
                    + ": " + m.value("content").toString() + "\n";
        }
        if (arr.size() > m_lastHistoryLen && m_lastHistoryLen >= 0 && !arr.isEmpty()) {
            emit newMessage(arr.last().toObject().value("content").toString());
        }
        m_lastHistoryLen = arr.size();
        if (m_chatHistory != text) {
            m_chatHistory = text;
            emit chatHistoryChanged();
        }
    });
}

void ChatClient::sendToClient(const QString &name, const QString &message)
{
    const QString id = m_nameToId.value(name, name);
    QJsonObject body{{"to", id}, {"content", message}};
    m_api->postJson("/api/chat/messages", body, [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit connectionError(obj.value("message").toString("发送失败"));
            return;
        }
        refreshHistory();
    });
}

void ChatClient::setActiveChat(const QString &clientName)
{
    m_activeName = clientName;
    m_activeId = m_nameToId.value(clientName);
    m_lastHistoryLen = -1;
    m_chatHistory.clear();
    emit chatHistoryChanged();
    refreshHistory();
}

QString ChatClient::getClientIdByName(const QString &name)
{
    return m_nameToId.value(name);
}

void ChatClient::reconnect()
{
    connectToServer(m_serverIp, m_serverPort);
}

void ChatClient::requestChatHistory(const QString &contactName)
{
    setActiveChat(contactName);
}

void ChatClient::loadChatHistory(const QString &contactName)
{
    setActiveChat(contactName);
}