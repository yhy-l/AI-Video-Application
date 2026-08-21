#include "redis_client.h"
#include <QDebug>

bool RedisClient::connectToServer(const QString &host, quint16 port, int dbIndex, int timeoutMs)
{
    m_socket.connectToHost(host, port);
    if (!m_socket.waitForConnected(timeoutMs)) {
        m_lastError = "Redis 连接失败: " + m_socket.errorString();
        m_connected = false;
        return false;
    }

    // 先置为已连接，command() 才会真正发送命令
    m_connected = true;

    // SELECT 独立数据库；失败重试一次（应对慢启动/转发延迟）
    QVariant r = command({QByteArray("SELECT"), QByteArray::number(dbIndex)});
    if (r.typeId() != QMetaType::Bool || !r.toBool()) {
        m_socket.disconnectFromHost();
        m_connected = false;
        m_socket.connectToHost(host, port);
        if (!m_socket.waitForConnected(timeoutMs)) {
            m_lastError = "Redis 重连失败: " + m_socket.errorString();
            return false;
        }
        m_connected = true;
        r = command({QByteArray("SELECT"), QByteArray::number(dbIndex)});
    }
    if (r.typeId() != QMetaType::Bool || !r.toBool()) {
        m_lastError = "Redis SELECT " + QByteArray::number(dbIndex) + " 失败";
        m_socket.disconnectFromHost();
        m_connected = false;
        return false;
    }

    return true;
}

void RedisClient::disconnect()
{
    m_socket.disconnectFromHost();
    m_connected = false;
}

QVariant RedisClient::command(const QList<QByteArray> &args)
{
    if (!m_connected)
        return QVariant();

    QByteArray req;
    req += "*" + QByteArray::number(args.size()) + "\r\n";
    for (const QByteArray &a : args) {
        req += "$" + QByteArray::number(a.size()) + "\r\n" + a + "\r\n";
    }
    m_socket.write(req);
    m_socket.flush();

    QByteArray buffer;
    for (int i = 0; i < 2; ++i) {
        if (!m_socket.waitForReadyRead(kTimeoutMs)) {
            m_lastError = "Redis 读取超时";
            return QVariant();
        }
        buffer += m_socket.readAll();
        QByteArray probe = buffer;
        QVariant v = readReply(probe);
        if (!v.isNull())
            return v;
        if (probe.size() == 0)
            break;
        buffer = probe;
    }
    m_lastError = "Redis 回复不完整";
    return QVariant();
}

QVariant RedisClient::readReply(QByteArray &buffer)
{
    if (buffer.isEmpty())
        return QVariant();

    const char type = buffer.at(0);
    int lineEnd = buffer.indexOf("\r\n");
    if (lineEnd < 0)
        return QVariant();

    QByteArray line = buffer.mid(1, lineEnd - 1);
    buffer = buffer.mid(lineEnd + 2);

    if (type == '+') return true;
    if (type == '-') { m_lastError = QString::fromUtf8(line); return QVariant(); }
    if (type == ':') return line.toLongLong();
    if (type == '$') {
        qlonglong len = line.toLongLong();
        if (len < 0) return QVariant();
        if (buffer.size() < len + 2)
            return QVariant();
        QByteArray data = buffer.left(len);
        buffer = buffer.mid(len + 2);
        return QString::fromUtf8(data);
    }
    if (type == '*') {
        qlonglong count = line.toLongLong();
        if (count < 0) return QVariant();
        QVariantList list;
        for (qlonglong i = 0; i < count; ++i) {
            if (buffer.isEmpty())
                return QVariant();
            QVariant item = readReply(buffer);
            list.append(item);
        }
        return list;
    }
    return QVariant();
}

bool RedisClient::ping()
{
    QVariant r = command({QByteArray("PING")});
    return r.isValid() && r.toBool();
}

bool RedisClient::zincrby(const QByteArray &key, double increment, const QByteArray &member)
{
    QVariant r = command({QByteArray("ZINCRBY"), key, QByteArray::number(increment, 'f', 2), member});
    return r.isValid();
}

QList<QPair<QByteArray, double>> RedisClient::zrevrangeWithScores(const QByteArray &key, qlonglong start, qlonglong stop)
{
    QList<QPair<QByteArray, double>> result;
    QVariant r = command({QByteArray("ZREVRANGE"), key, QByteArray::number(start), QByteArray::number(stop), QByteArray("WITHSCORES")});
    QVariantList list = r.toList();
    for (int i = 0; i + 1 < list.size(); i += 2) {
        result.append({list[i].toString().toUtf8(), list[i + 1].toDouble()});
    }
    return result;
}

bool RedisClient::del(const QByteArray &key)
{
    QVariant r = command({QByteArray("DEL"), key});
    return r.isValid();
}

bool RedisClient::expire(const QByteArray &key, qlonglong seconds)
{
    QVariant r = command({QByteArray("EXPIRE"), key, QByteArray::number(seconds)});
    return r.isValid();
}
bool RedisClient::exists(const QByteArray &key)
{
    QVariant r = command({QByteArray("EXISTS"), key});
    return r.isValid() && r.toLongLong() > 0;
}

bool RedisClient::setex(const QByteArray &key, qlonglong seconds, const QByteArray &value)
{
    QVariant r = command({QByteArray("SETEX"), key, QByteArray::number(seconds), value});
    return r.isValid() && r.toBool();
}