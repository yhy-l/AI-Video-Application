#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include "src/api_client.h"
#include "src/video_controller.h"
#include "src/user_controller.h"
#include "src/chat_client.h"
#include "src/settings_manager.h"
#include "src/download_manager.h"
#include "src/ai_chat_client.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("bilibili");
    QQuickStyle::setStyle("Basic"); // 让自定义按钮/样式生效，避免原生样式警告

    // 统一 HTTP 客户端，服务端地址可在此修改
    ApiClient api;
    api.setBaseUrl("http://127.0.0.1:8090"); // 经 nginx 反向代理访问服务端
    api.setToken(ApiClient::loadSavedToken()); // 恢复上次登录态

    SettingsManager settings;
    VideoController videoController(&api);
    UserController userController(&api);
    ChatClient chatClient(&api);
    DownloadManager downloadManager;
    AiChatClient aiChatClient(&api);
    userController.restoreSession(); // token 有效则自动恢复用户信息
    // 下载目录跟随设置；未设置时使用 DownloadManager 默认目录
    if (!settings.downloadDir().isEmpty())
        downloadManager.setDownloadDir(settings.downloadDir());
    QObject::connect(&settings, &SettingsManager::downloadDirChanged, &downloadManager,
                     [&downloadManager](const QString &dir) {
        if (!dir.isEmpty())
            downloadManager.setDownloadDir(dir);
    });

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("videoController", &videoController);
    engine.rootContext()->setContextProperty("userController", &userController);
    engine.rootContext()->setContextProperty("clientHandler", &chatClient);
    engine.rootContext()->setContextProperty("appSettings", &settings);
    engine.rootContext()->setContextProperty("downloadManager", &downloadManager);
    engine.rootContext()->setContextProperty("aiClient", &aiChatClient);

    const QUrl url(QStringLiteral("qrc:/Bilibili/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
                     [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);
    return app.exec();
}
