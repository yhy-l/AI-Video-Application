#include "config.h"
#include <QSettings>
#include <QFile>
#include <QCoreApplication>
#include <QDir>

bool AppConfig::loadFromFile(const QString &iniPath)
{
    if (!QFile::exists(iniPath))
        return false;

    QSettings s(iniPath, QSettings::IniFormat);
    dbHost = s.value("db/host", dbHost).toString();
    dbPort = s.value("db/port", dbPort).toInt();
    dbName = s.value("db/name", dbName).toString();
    dbUser = s.value("db/user", dbUser).toString();
    dbPassword = s.value("db/password", dbPassword).toString();
    httpPort = s.value("server/port", httpPort).toUInt();
    redisHost = s.value("redis/host", redisHost).toString();
    redisPort = s.value("redis/port", redisPort).toUInt();
    redisDb = s.value("redis/db", redisDb).toInt();
    uploadsDir = s.value("server/uploads_dir", uploadsDir).toString();
    return true;
}