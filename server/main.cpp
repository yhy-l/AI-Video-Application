#include <QCoreApplication>
#include <QDir>
#include <QDebug>
#include "src/config.h"
#include "src/database.h"
#include "src/server.h"

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    AppConfig cfg;
    const QString iniPath = QCoreApplication::applicationDirPath() + "/config.ini";
    if (cfg.loadFromFile(iniPath))
        qInfo() << "Loaded config:" << iniPath;
    else
        qInfo() << "No config.ini, using defaults";

    QString err;
    if (!db::init(cfg, &err)) {
        qCritical() << "Database init failed:" << err;
        qCritical() << "请确认 MySQL 服务已启动（net start MySQL80）且 config.ini 配置正确";
        return 1;
    }

    BilibiliServer server;
    if (!server.start(cfg.httpPort, cfg)) {
        qCritical() << "HTTP server failed to listen on port" << cfg.httpPort;
        return 1;
    }

    qInfo() << "========================================";
    qInfo() << " bilibili server is running:";
    qInfo() << "   http://127.0.0.1:" << cfg.httpPort;
    qInfo() << "   uploads dir:" << cfg.uploadsDir;
    qInfo() << " 演示数据: POST /api/dev/seed (demo/demo123456)";
    qInfo() << "========================================";

    return app.exec();
}