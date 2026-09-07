cmake_minimum_required(VERSION 3.20)
project(bilibili_client VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml QuickControls2 Network Multimedia Svg)

qt_add_executable(appBilibili
    main.cpp
    src/api_client.h src/api_client.cpp
    src/video_controller.h src/video_controller.cpp
    src/user_controller.h src/user_controller.cpp
    src/chat_client.h src/chat_client.cpp
    src/settings_manager.h src/settings_manager.cpp
    src/download_manager.h src/download_manager.cpp
    src/ai_chat_client.h src/ai_chat_client.cpp
)

qt_add_resources(appBilibili "app_icons"
    PREFIX "/icons"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/icons"
    FILES
        icons/heart.svg
        icons/heart_outline.svg
        icons/coin.svg
        icons/download.svg
        icons/folder.svg
)

qt_add_qml_module(appBilibili
    URI Bilibili
    VERSION 1.0
    QML_FILES
        Main.qml
        component/FrameLessWindow.qml
        component/DamuSystem.qml
        component/ModernLoadingIndicator.qml
        qml/Commit.qml
        qml/Video_Playback/Video.qml
        qml/Tools_Left/PersonInfo.qml
        qml/Tools_Left/Message_Page.qml
        qml/Tools_Left/DownloadPage.qml
        qml/Tools_Left/UploadRecordsPage.qml
        qml/AI_Pet/PetWindow.qml
        qml/Settings/SettingsPage.qml
        qml/Send_Videos/VideoLode.qml
        qml/Send_Videos/VideolodeFunction.qml
        qml/Login/LoginPage.qml
)

target_link_libraries(appBilibili PRIVATE
    Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::Network Qt6::Multimedia Qt6::Svg
)

set_target_properties(appBilibili PROPERTIES
    WIN32_EXECUTABLE FALSE
)
