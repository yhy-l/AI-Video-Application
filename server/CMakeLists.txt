cmake_minimum_required(VERSION 3.20)
project(bilibili_server VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Network Sql HttpServer)

qt_add_executable(bilibili_server
    main.cpp
    src/config.h src/config.cpp
    src/database.h src/database.cpp
    src/auth.h src/auth.cpp
    src/models.h src/models.cpp
    src/repository.h src/repository.cpp
    src/redis_client.h src/redis_client.cpp
    src/server.h src/server.cpp
    src/transcode_manager.h src/transcode_manager.cpp
)

target_link_libraries(bilibili_server PRIVATE
    Qt6::Core Qt6::Network Qt6::Sql Qt6::HttpServer
)

# 可选：构建后自动把 MySQL 运行库拷贝到 exe 旁边
# 注意：cmake -E copy_if_different 的"目标目录"形式在此版本有 bug，必须写完整目标文件名
if(DEFINED MYSQL_BIN_DIR AND EXISTS "${MYSQL_BIN_DIR}")
    add_custom_command(TARGET bilibili_server POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${MYSQL_BIN_DIR}/libmysql.dll" $<TARGET_FILE_DIR:bilibili_server>/libmysql.dll
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${MYSQL_BIN_DIR}/libssl-3-x64.dll" $<TARGET_FILE_DIR:bilibili_server>/libssl-3-x64.dll
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${MYSQL_BIN_DIR}/libcrypto-3-x64.dll" $<TARGET_FILE_DIR:bilibili_server>/libcrypto-3-x64.dll
        COMMENT "Copied MySQL runtime DLLs next to the executable"
    )
endif()