#include "settings_manager.h"
#include <QSettings>

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
{
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    m_darkMode = s.value("settings/darkMode", false).toBool();
    m_autoPlayVideos = s.value("settings/autoPlayVideos", false).toBool();
    m_autoStart = s.value("settings/autoStart", false).toBool();
    m_downloadDir = s.value("settings/downloadDir").toString();
    m_rememberPassword = s.value("settings/rememberPassword", false).toBool();
}

void SettingsManager::setDarkMode(bool v)
{
    if (m_darkMode == v)
        return;
    m_darkMode = v;
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    s.setValue("settings/darkMode", v);
    emit darkModeChanged();
}

void SettingsManager::setAutoPlayVideos(bool v)
{
    if (m_autoPlayVideos == v)
        return;
    m_autoPlayVideos = v;
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    s.setValue("settings/autoPlayVideos", v);
    emit autoPlayVideosChanged();
}

void SettingsManager::setAutoStart(bool v)
{
    if (m_autoStart == v)
        return;
    m_autoStart = v;
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    s.setValue("settings/autoStart", v);
    emit autoStartChanged();
}

void SettingsManager::setRememberPassword(bool v)
{
    if (m_rememberPassword == v)
        return;
    m_rememberPassword = v;
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    s.setValue("settings/rememberPassword", v);
    emit rememberPasswordChanged();
}

void SettingsManager::setDownloadDir(const QString &dir)
{
    if (m_downloadDir == dir)
        return;
    m_downloadDir = dir;
    QSettings s(QSettings::IniFormat, QSettings::UserScope, "bilibili", "client");
    if (dir.isEmpty())
        s.remove("settings/downloadDir");
    else
        s.setValue("settings/downloadDir", dir);
    emit downloadDirChanged(m_downloadDir);
}
