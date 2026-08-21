#pragma once
#include <QObject>
#include <QStringList>
#include <QMap>
#include <QTimer>
#include "api_client.h"

// 聊天客户端：通过服务端 HTTP 接口实现（轮询拉取消息）
// 聊天客户端（HTTP 轮询）
class ChatClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList clientList READ clientList NOTIFY clientListChanged)
    Q_PROPERTY(QString chatHistory READ chatHistory NOTIFY chatHistoryChanged)
    Q_PROPERTY(QString serverIp READ serverIp NOTIFY serverInfoChanged)
    Q_PROPERTY(quint16 serverPort READ serverPort NOTIFY serverInfoChanged)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionChanged)
    Q_PROPERTY(bool connecting READ isConnecting NOTIFY connectingChanged)
public:
    explicit ChatClient(ApiClient *api, QObject *parent = nullptr);

    QStringList clientList() const { return m_clientList; }
    QString chatHistory() const { return m_chatHistory; }
    QString serverIp() const { return m_serverIp; }
    quint16 serverPort() const { return m_serverPort; }
    QString name() const { return m_name; }
    bool isConnected() const { return m_connected; }
    bool isConnecting() const { return m_connecting; }

    Q_INVOKABLE void setName(const QString &name);
    Q_INVOKABLE bool connectToServer(const QString &host, quint16 port = 3000);
    Q_INVOKABLE void disconnectFromServer();
    Q_INVOKABLE void sendToClient(const QString &name, const QString &message);
    Q_INVOKABLE void setActiveChat(const QString &clientName);
    Q_INVOKABLE QString getClientIdByName(const QString &name);
    Q_INVOKABLE void reconnect();
    Q_INVOKABLE void requestChatHistory(const QString &contactName);
    Q_INVOKABLE void loadChatHistory(const QString &contactName);

signals:
    void newMessage(const QString &message);
    void connected();
    void disconnected();
    void clientListChanged();
    void chatHistoryChanged();
    void serverInfoChanged();
    void nameChanged(const QString &name);
    void connectionChanged();
    void connectingChanged(bool connecting);
    void connectionError(const QString &errorMessage);
    void historyReceived(const QString &contactName, const QString &history);

private:
    void refreshUsers();
    void refreshHistory();

    ApiClient *m_api;
    QTimer m_pollTimer;
    QStringList m_clientList;
    QMap<QString, QString> m_nameToId; // 昵称 -> userId
    QString m_name = "Anonymous";
    QString m_selfName;
    QString m_activeId;
    QString m_activeName;
    QString m_chatHistory;
    int m_lastHistoryLen = -1;
    bool m_connected = false;
    bool m_connecting = false;
    QString m_serverIp = "127.0.0.1";
    quint16 m_serverPort = 3000;
};
