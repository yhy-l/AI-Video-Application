#pragma once
#include <QTcpSocket>
#include <QByteArray>
#include <QVariant>
#include <QList>
#include <QPair>

// 极简 Redis 客户端（RESP 协议，同步 + 超时），仅用于热门排行缓存
class RedisClient {
public:
    bool connectToServer(const QString &host, quint16 port, int dbIndex, int timeoutMs = 500);
    void disconnect();
    bool isConnected() const { return m_connected; }
    QString lastError() const { return m_lastError; }

    QVariant command(const QList<QByteArray> &args);

    bool ping();
    bool zincrby(const QByteArray &key, double increment, const QByteArray &member);
    QList<QPair<QByteArray, double>> zrevrangeWithScores(const QByteArray &key, qlonglong start, qlonglong stop);
    bool exists(const QByteArray &key);
    bool setex(const QByteArray &key, qlonglong seconds, const QByteArray &value);
    bool del(const QByteArray &key);
    bool expire(const QByteArray &key, qlonglong seconds);

private:
    QVariant readReply(QByteArray &buffer);

    QTcpSocket m_socket;
    bool m_connected = false;
    QString m_lastError;
    static const int kTimeoutMs = 2000;
};