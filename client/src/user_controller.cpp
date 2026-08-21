#include "user_controller.h"
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QDebug>

UserController::UserController(ApiClient *api, QObject *parent)
    : QObject(parent)
    , m_api(api)
{
}

void UserController::setLoading(bool loading)
{
    if (m_loading != loading) {
        m_loading = loading;
        emit loadingChanged();
    }
}

void UserController::applyUserData(const QJsonObject &data)
{
    const QString oldAvatar = m_currentUser.value("avatarUrl").toString();
    m_currentUser = data.toVariantMap();
    m_currentUser["avatarUrl"] = m_api->absoluteUrl(m_currentUser.value("avatarUrl").toString());
    emit currentUserChanged();
    emit loginStatusChanged();
    if (m_currentUser.value("avatarUrl").toString() != oldAvatar) {
        m_avatarTimestamp = QDateTime::currentMSecsSinceEpoch();
        emit avatarUrlChanged();
    }
}

void UserController::registerUser(const QString &account, const QString &password,
                                  const QString &nickname, const QString &avatarUrl)
{
    setLoading(true);
    QJsonObject body{{"account", account}, {"password", password},
                     {"nickname", nickname}, {"avatarUrl", avatarUrl}};
    m_api->postJson("/api/register", body, [this](bool ok, const QJsonObject &obj) {
        setLoading(false);
        if (ok && obj.value("code").toInt() == 0) {
            emit registrationSuccess(obj.value("data").toObject().value("id").toString());
        } else {
            emit errorOccurred(obj.value("message").toString("注册失败"));
        }
    });
}

void UserController::login(const QString &account, const QString &password)
{
    setLoading(true);
    QJsonObject body{{"account", account}, {"password", password}};
    m_api->postJson("/api/login", body, [this](bool ok, const QJsonObject &obj) {
        setLoading(false);
        if (ok && obj.value("code").toInt() == 0) {
            QJsonObject data = obj.value("data").toObject();
            m_api->setToken(data.value("token").toString());
            data.remove("token");
            applyUserData(data);
            emit loginSuccess(m_currentUser.value("id").toString());
        } else {
            emit errorOccurred(obj.value("message").toString("登录失败"));
        }
    });
}

void UserController::logout()
{
    m_api->postJson("/api/logout", QJsonObject(), [this](bool, const QJsonObject &) {
        m_api->setToken(QString());
        m_currentUser.clear();
        m_likedIds.clear();
        m_followingIds.clear();
        emit currentUserChanged();
        emit loginStatusChanged();
        emit logoutSuccess();
    });
}

void UserController::updateProfile(const QString &nickname, const QString &signature,
                                   const QString &avatarUrl)
{
    setLoading(true);
    QJsonObject body{{"nickname", nickname}, {"signature", signature}, {"avatarUrl", avatarUrl}};
    m_api->postJson("/api/me/profile", body, [this](bool ok, const QJsonObject &obj) {
        setLoading(false);
        if (ok && obj.value("code").toInt() == 0) {
            applyUserData(obj.value("data").toObject());
            emit profileUpdated();
        } else {
            emit errorOccurred(obj.value("message").toString("更新资料失败"));
        }
    });
}

void UserController::addWatchHistory(const QString &videoId, const QString &videoTitle,
                                     const QString &coverUrl)
{
    Q_UNUSED(videoTitle)
    Q_UNUSED(coverUrl)
    m_api->postJson("/api/me/history/" + videoId, QJsonObject(),
                    [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0)
            emit errorOccurred(obj.value("message").toString("记录观看历史失败"));
    });
}

void UserController::loadWatchHistory()
{
    m_api->getJson("/api/me/history", [this](bool ok, const QJsonObject &obj) {
        if (ok && obj.value("code").toInt() == 0) {
            m_watchHistory = obj.value("data").toArray().toVariantList();
            for (auto &v : m_watchHistory) {
                QVariantMap m = v.toMap();
                m["videoUrl"] = m_api->absoluteUrl(m.value("videoUrl").toString());
                m["coverUrl"] = m_api->absoluteUrl(m.value("coverUrl").toString());
                v = m;
            }
            emit historyChanged();
        }
    });
}

void UserController::toggleLikeVideo(const QString &videoId)
{
    const bool liked = m_likedIds.contains(videoId);
    const QString path = "/api/videos/" + videoId + "/like";
    auto done = [this, videoId, liked](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("操作失败"));
            return;
        }
        if (liked) {
            m_likedIds.remove(videoId);
            emit videoUnliked(videoId);
        } else {
            m_likedIds.insert(videoId);
            emit videoLiked(videoId);
        }
    };
    if (liked)
        m_api->deleteJson(path, done);
    else
        m_api->postJson(path, QJsonObject(), done);
}

bool UserController::isVideoLiked(const QString &videoId) const
{
    return m_likedIds.contains(videoId);
}

void UserController::followUser(const QString &userId)
{
    m_api->postJson("/api/users/" + userId + "/follow", QJsonObject(),
                    [this, userId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("关注失败"));
            return;
        }
        m_followingIds.insert(userId);
        emit userFollowed(userId);
        loadFollowingUsers();
    });
}

void UserController::unfollowUser(const QString &userId)
{
    m_api->deleteJson("/api/users/" + userId + "/follow",
                      [this, userId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("取消关注失败"));
            return;
        }
        m_followingIds.remove(userId);
        emit userUnfollowed(userId);
        loadFollowingUsers();
    });
}

bool UserController::isFollowing(const QString &userId) const
{
    return m_followingIds.contains(userId);
}

void UserController::loadFollowingUsers()
{
    m_api->getJson("/api/me/following", [this](bool ok, const QJsonObject &obj) {
        if (ok && obj.value("code").toInt() == 0) {
            m_followingUsers = obj.value("data").toArray().toVariantList();
            m_followingIds.clear();
            for (const QVariant &u : std::as_const(m_followingUsers))
                m_followingIds.insert(u.toMap().value("id").toString());
            emit followingChanged();
        }
    });
}

void UserController::uploadAvatar(const QString &filePath)
{
    QString local = filePath;
    if (local.startsWith("file://"))
        local = QUrl(local).toLocalFile();
    // 兼容 Windows 路径前导斜杠
    if (local.startsWith('/') && local.size() > 2 && local.at(1).isLetter() && local.at(2) == ':')
        local = local.mid(1);
    QFileInfo fi(local);
    if (!fi.exists() || fi.size() > 20 * 1024 * 1024) {
        emit errorOccurred("头像文件无效或超过 20MB");
        return;
    }
    QFile f(local);
    if (!f.open(QIODevice::ReadOnly)) {
        emit errorOccurred("无法读取头像文件");
        return;
    }
    ApiUploadFile file;
    file.fieldName = "avatar";
    file.fileName = fi.fileName();
    file.contentType = "image/" + fi.suffix().toLower();
    file.data = f.readAll();

    m_api->postMultipart("/api/me/avatar", {}, {file},
                         [this](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("头像上传失败"));
            return;
        }
        applyUserData(obj.value("data").toObject());
        emit profileUpdated();
    });
}

void UserController::restoreSession()
{
    if (m_api->token().isEmpty())
        return;
    m_api->getJson("/api/me", [this](bool ok, const QJsonObject &obj) {
        if (ok && obj.value("code").toInt() == 0) {
            applyUserData(obj.value("data").toObject());
        } else {
            m_api->setToken(QString());
        }
    });
}

void UserController::addVideoCoin(const QString &videoId)
{
    m_api->postJson("/api/videos/" + videoId + "/coin", QJsonObject(),
                    [this, videoId](bool ok, const QJsonObject &obj) {
        if (!ok || obj.value("code").toInt() != 0) {
            emit errorOccurred(obj.value("message").toString("投币失败"));
            return;
        }
        const QJsonObject data = obj.value("data").toObject();
        const int count = data.value("userCoinCount").toInt();
        m_videoCoins.insert(videoId, count);
        emit videoCoined(videoId, count);
    });
}

int UserController::getUserVideoCoinCount(const QString &videoId) const
{
    return m_videoCoins.value(videoId, 0);
}

void UserController::addCreatedVideo(const QString &videoId)
{
    Q_UNUSED(videoId)
    qWarning() << "addCreatedVideo 暂未实现";
}
void UserController::loadFollowerUsers()
{
    m_api->getJson("/api/me/followers", [this](bool ok, const QJsonObject &obj) {
        if (ok && obj.value("code").toInt() == 0) {
            m_followerUsers = obj.value("data").toArray().toVariantList();
            emit followersChanged();
        }
    });
}
