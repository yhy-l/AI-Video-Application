#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QSet>
#include <QHash>
#include "api_client.h"

// 用户控制器：异步 HTTP
class UserController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap currentUser READ currentUser NOTIFY currentUserChanged)
    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY loginStatusChanged)
    Q_PROPERTY(QString avatarUrl READ avatarUrl NOTIFY avatarUrlChanged)
    Q_PROPERTY(qint64 avatarTimestamp READ avatarTimestamp NOTIFY avatarUrlChanged)
    Q_PROPERTY(QVariantList followingUsers READ followingUsers NOTIFY followingChanged)
    Q_PROPERTY(QVariantList followerUsers READ followerUsers NOTIFY followersChanged)
    Q_PROPERTY(QVariantList watchHistory READ watchHistory NOTIFY historyChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
public:
    explicit UserController(ApiClient *api, QObject *parent = nullptr);

    QVariantMap currentUser() const { return m_currentUser; }
    bool isLoggedIn() const { return !m_currentUser.isEmpty(); }
    QString avatarUrl() const { return m_currentUser.value("avatarUrl").toString(); }
    qint64 avatarTimestamp() const { return m_avatarTimestamp; }
    QVariantList followingUsers() const { return m_followingUsers; }
    QVariantList followerUsers() const { return m_followerUsers; }
    QVariantList watchHistory() const { return m_watchHistory; }
    bool loading() const { return m_loading; }

    Q_INVOKABLE void registerUser(const QString &account, const QString &password,
                                  const QString &nickname, const QString &avatarUrl = "");
    Q_INVOKABLE void login(const QString &account, const QString &password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void updateProfile(const QString &nickname, const QString &signature,
                                   const QString &avatarUrl);
    Q_INVOKABLE void uploadAvatar(const QString &filePath);
    Q_INVOKABLE void restoreSession();
    Q_INVOKABLE void addWatchHistory(const QString &videoId, const QString &videoTitle = "",
                                     const QString &coverUrl = "");
    Q_INVOKABLE void loadWatchHistory();
    Q_INVOKABLE void toggleLikeVideo(const QString &videoId);
    Q_INVOKABLE bool isVideoLiked(const QString &videoId) const;
    Q_INVOKABLE void followUser(const QString &userId);
    Q_INVOKABLE void unfollowUser(const QString &userId);
    Q_INVOKABLE bool isFollowing(const QString &userId) const;
    Q_INVOKABLE void loadFollowingUsers();
    Q_INVOKABLE void loadFollowerUsers();
    Q_INVOKABLE void addVideoCoin(const QString &videoId);
    Q_INVOKABLE int getUserVideoCoinCount(const QString &videoId) const;
    Q_INVOKABLE void addCreatedVideo(const QString &videoId);

signals:
    void currentUserChanged();
    void loginStatusChanged();
    void followingChanged();
    void followersChanged();
    void historyChanged();
    void loadingChanged();
    void errorOccurred(const QString &message);
    void registrationSuccess(const QString &userId);
    void loginSuccess(const QString &userId);
    void logoutSuccess();
    void profileUpdated();
    void videoLiked(const QString &videoId);
    void videoUnliked(const QString &videoId);
    void userFollowed(const QString &userId);
    void userUnfollowed(const QString &userId);
    void avatarUrlChanged();
    void videoCoined(const QString &videoId, int coinCount);

private:
    void setLoading(bool loading);
    void applyUserData(const QJsonObject &data);

    ApiClient *m_api;
    QVariantMap m_currentUser;
    QVariantList m_followingUsers;
    QVariantList m_followerUsers;
    QVariantList m_watchHistory;
    QSet<QString> m_likedIds;
    QSet<QString> m_followingIds;
    qint64 m_avatarTimestamp = 0;
    QHash<QString, int> m_videoCoins;
    bool m_loading = false;
};
