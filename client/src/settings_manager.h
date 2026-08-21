#pragma once
#include <QObject>

// 客户端设置（QSettings 持久化），供设置页与夜间模式使用
class SettingsManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(bool autoPlayVideos READ autoPlayVideos WRITE setAutoPlayVideos NOTIFY autoPlayVideosChanged)
    Q_PROPERTY(bool autoStart READ autoStart WRITE setAutoStart NOTIFY autoStartChanged)
    Q_PROPERTY(bool rememberPassword READ rememberPassword WRITE setRememberPassword NOTIFY rememberPasswordChanged)
    Q_PROPERTY(QString downloadDir READ downloadDir WRITE setDownloadDir NOTIFY downloadDirChanged)
public:
    explicit SettingsManager(QObject *parent = nullptr);

    bool darkMode() const { return m_darkMode; }
    void setDarkMode(bool v);
    bool autoPlayVideos() const { return m_autoPlayVideos; }
    void setAutoPlayVideos(bool v);
    bool autoStart() const { return m_autoStart; }
    void setAutoStart(bool v);
    bool rememberPassword() const { return m_rememberPassword; }
    void setRememberPassword(bool v);
    QString downloadDir() const { return m_downloadDir; }
    void setDownloadDir(const QString &dir);

signals:
    void darkModeChanged();
    void autoPlayVideosChanged();
    void autoStartChanged();
    void rememberPasswordChanged();
    void downloadDirChanged(const QString &dir);

private:
    bool m_darkMode = false;
    bool m_autoPlayVideos = false;
    bool m_autoStart = false;
    bool m_rememberPassword = false;
    QString m_downloadDir;
};
