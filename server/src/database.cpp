#include "database.h"
#include "config.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

namespace db {

static QSqlDatabase s_db;

QSqlDatabase connection()
{
    return s_db;
}

bool createTables(QString *errOut)
{
    const QStringList statements = {
        // 用户
        R"(CREATE TABLE IF NOT EXISTS users (
            id VARCHAR(64) PRIMARY KEY,
            account VARCHAR(64) NOT NULL UNIQUE,
            password_hash VARCHAR(128) NOT NULL,
            salt VARCHAR(32) NOT NULL,
            nickname VARCHAR(64) NOT NULL,
            avatar_url TEXT,
            signature TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 视频
        R"(CREATE TABLE IF NOT EXISTS videos (
            id VARCHAR(64) PRIMARY KEY,
            user_id VARCHAR(64) NOT NULL,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            video_path TEXT NOT NULL,
            cover_path TEXT,
            tags TEXT,
            view_count INT DEFAULT 0,
            like_count INT DEFAULT 0,
            coin_count INT DEFAULT 0,
            favorite_count INT DEFAULT 0,
            comment_count INT DEFAULT 0,
            width INT DEFAULT 0,
            height INT DEFAULT 0,
            duration_sec DOUBLE DEFAULT 0,
            file_size_bytes BIGINT DEFAULT 0,
            transcode_status VARCHAR(16) DEFAULT '',
            done_qualities VARCHAR(64) DEFAULT '',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            KEY idx_videos_user (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 评论
        R"(CREATE TABLE IF NOT EXISTS comments (
            id VARCHAR(64) PRIMARY KEY,
            video_id VARCHAR(64) NOT NULL,
            user_id VARCHAR(64) NOT NULL,
            user_name VARCHAR(64),
            parent_id VARCHAR(64),
            content TEXT NOT NULL,
            like_count INT DEFAULT 0,
            unlike_count INT DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            KEY idx_comments_video (video_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 收藏
        R"(CREATE TABLE IF NOT EXISTS favorites (
            user_id VARCHAR(64) NOT NULL,
            video_id VARCHAR(64) NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (user_id, video_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 点赞
        R"(CREATE TABLE IF NOT EXISTS video_likes (
            user_id VARCHAR(64) NOT NULL,
            video_id VARCHAR(64) NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (user_id, video_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 观看历史
        R"(CREATE TABLE IF NOT EXISTS watch_history (
            user_id VARCHAR(64) NOT NULL,
            video_id VARCHAR(64) NOT NULL,
            watched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (user_id, video_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 关注关系
        R"(CREATE TABLE IF NOT EXISTS follow_relations (
            follower_id VARCHAR(64) NOT NULL,
            following_id VARCHAR(64) NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (follower_id, following_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 登录令牌（持久化，服务重启不失效）
        R"(CREATE TABLE IF NOT EXISTS tokens (
            token VARCHAR(64) PRIMARY KEY,
            user_id VARCHAR(64) NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            KEY idx_tokens_user (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 评论点赞
        R"(CREATE TABLE IF NOT EXISTS comment_likes (
            user_id VARCHAR(64) NOT NULL,
            comment_id VARCHAR(64) NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (user_id, comment_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 投币记录
        R"(CREATE TABLE IF NOT EXISTS video_coins (
            user_id VARCHAR(64) NOT NULL,
            video_id VARCHAR(64) NOT NULL,
            coin_count INT DEFAULT 0,
            PRIMARY KEY (user_id, video_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 弹幕
        R"(CREATE TABLE IF NOT EXISTS danmaku (
            id VARCHAR(64) PRIMARY KEY,
            video_id VARCHAR(64) NOT NULL,
            user_id VARCHAR(64) NOT NULL,
            user_name VARCHAR(64),
            content TEXT NOT NULL,
            time_sec DOUBLE NOT NULL,
            color VARCHAR(16) DEFAULT '#FFFFFF',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            KEY idx_danmaku_video (video_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 站内聊天消息
        R"(CREATE TABLE IF NOT EXISTS chat_messages (
            id VARCHAR(64) PRIMARY KEY,
            from_user VARCHAR(64) NOT NULL,
            to_user VARCHAR(64) NOT NULL,
            content TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            KEY idx_chat_pair (from_user, to_user)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
        // 视频转码任务（每档位一条；上传完成后由后台 ffmpeg 队列处理）
        R"(CREATE TABLE IF NOT EXISTS transcode_tasks (
            id INT AUTO_INCREMENT PRIMARY KEY,
            video_id VARCHAR(64) NOT NULL,
            quality INT NOT NULL,
            status VARCHAR(16) DEFAULT 'pending',
            progress INT DEFAULT 0,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uq_video_quality (video_id, quality)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4)",
    };

    for (const QString &sql : statements) {
        QSqlQuery q(s_db);
        if (!q.exec(sql)) {
            if (errOut) *errOut = q.lastError().text();
            qCritical() << "createTables failed:" << q.lastError().text();
            return false;
        }
    }
    qInfo() << "Database tables ready";
    // 旧库补列（幂等，新库建表已含这些列，contains 会跳过）
    const QList<QPair<QString, QString>> videoColumns = {
        {"width", "INT DEFAULT 0"},
        {"height", "INT DEFAULT 0"},
        {"duration_sec", "DOUBLE DEFAULT 0"},
        {"file_size_bytes", "BIGINT DEFAULT 0"},
        {"transcode_status", "VARCHAR(16) DEFAULT ''"},
        {"done_qualities", "VARCHAR(64) DEFAULT ''"}
    };
    for (const auto &c : videoColumns) {
        QSqlQuery check(s_db);
        check.prepare("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'videos' AND COLUMN_NAME = ?");
        check.addBindValue(c.first);
        if (check.exec() && check.next() && check.value(0).toInt() == 0) {
            QSqlQuery alter(s_db);
            const QString sql = QString("ALTER TABLE videos ADD COLUMN %1 %2").arg(c.first, c.second);
            if (!alter.exec(sql)) {
                if (errOut) *errOut = alter.lastError().text();
                qCritical() << "migrate videos failed:" << alter.lastError().text();
                return false;
            }
            qInfo() << "migrated videos." << c.first;
        }
    }
    return true;
}

bool init(const AppConfig &cfg, QString *errOut)
{
    const QString connName = "bilibili_server";
    if (QSqlDatabase::contains(connName)) {
        s_db = QSqlDatabase::database(connName);
    } else {
        s_db = QSqlDatabase::addDatabase("QMYSQL", connName);
        s_db.setHostName(cfg.dbHost);
        s_db.setPort(cfg.dbPort);
        s_db.setDatabaseName(cfg.dbName);
        s_db.setUserName(cfg.dbUser);
        s_db.setPassword(cfg.dbPassword);
        s_db.setConnectOptions("MYSQL_OPT_CONNECT_TIMEOUT=5");
    }

    if (!s_db.open()) {
        if (errOut) *errOut = s_db.lastError().text();
        qCritical() << "DB open failed:" << s_db.lastError().text();
        return false;
    }
    qInfo() << "DB connected:" << cfg.dbHost << cfg.dbPort << cfg.dbName;
    return createTables(errOut);
}

}
