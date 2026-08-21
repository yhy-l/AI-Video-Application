#include "auth.h"
#include "repository.h"
#include <QCryptographicHash>
#include <QRandomGenerator>

namespace auth {

static QByteArray randomBytes(int count)
{
    QByteArray bytes(count, Qt::Uninitialized);
    QRandomGenerator *gen = QRandomGenerator::system();
    for (int i = 0; i < count; ++i)
        bytes[i] = char(gen->bounded(256));
    return bytes;
}

QString generateSalt()
{
    return randomBytes(16).toHex();
}

QString hashPassword(const QString &password, const QString &salt)
{
    QByteArray input = salt.toUtf8() + password.toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(input, QCryptographicHash::Sha256).toHex());
}

QString generateToken()
{
    return QString::fromLatin1(randomBytes(32).toHex());
}

}

QString TokenStore::issue(const QString &userId)
{
    QString token = auth::generateToken();
    if (!repo::saveToken(token, userId))
        return QString();
    return token;
}

QString TokenStore::userIdForToken(const QString &token) const
{
    if (token.isEmpty())
        return QString();
    return repo::userIdForToken(token);
}

void TokenStore::revoke(const QString &token)
{
    if (!token.isEmpty())
        repo::removeToken(token);
}