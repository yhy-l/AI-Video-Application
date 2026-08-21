#pragma once
#include <QString>
#include <QString>

namespace auth {

// 生成随机盐（16 字节 hex）
QString generateSalt();
// 加盐哈希：sha256(salt + password)
QString hashPassword(const QString &password, const QString &salt);
// 生成随机 token（32 字节 hex）
QString generateToken();

}

// 内存版 token 存储（服务重启后需要重新登录）
class TokenStore {
public:
    QString issue(const QString &userId);
    QString userIdForToken(const QString &token) const;
    void revoke(const QString &token);


};