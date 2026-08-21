#pragma once
#include <QSqlDatabase>
#include <QString>
#include "config.h"

namespace db {

// 建立连接并创建所有表，失败时通过 errOut 返回错误信息
bool init(const AppConfig &cfg, QString *errOut = nullptr);
QSqlDatabase connection();
bool createTables(QString *errOut = nullptr);

}