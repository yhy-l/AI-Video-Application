#pragma once
#include <QString>

struct AppConfig {
    QString dbHost = "127.0.0.1";
    int dbPort = 3306;
    QString dbName = "bilibili";
    QString dbUser = "bilibili";
    QString dbPassword;   // 从 config.ini 读取，不内置默认密码
    quint16 httpPort = 3000;
    QString redisHost = "127.0.0.1";
    quint16 redisPort = 6379;
    int redisDb = 15; // 使用独立数据库，避免影响其它项目（勿用 0）
    QString uploadsDir; // 为空时使用 exe 所在目录下的 uploads

    bool loadFromFile(const QString &iniPath);
};
