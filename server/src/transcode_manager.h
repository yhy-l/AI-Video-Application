#pragma once
#include <QObject>
#include <QString>
#include <QProcess>
#include <QList>

// 视频上传后的后台处理：
//  1) ffprobe 读取宽/高/时长 -> 落库
//  2) 若没传封面，用 ffmpeg 抽帧（1s）做封面
//  3) 生成不高于原分辨率的 480p/720p/1080p 档位（原文件保留为“原画”）
// 每档进度写 transcode_tasks 表，客户端轮询视频详情即可看到；
// 全部完成或失败后，videos.transcode_status 置 done。
// 服务重启后扫描未完成任务自动续转；全程事件驱动，不阻塞 HTTP 线程。
class TranscodeManager : public QObject
{
    Q_OBJECT
public:
    explicit TranscodeManager(QObject *parent = nullptr);

    void configure(const QString &uploadsDir,
                   const QString &ffmpegPath,
                   const QString &ffprobePath,
                   bool enabled = true,
                   int maxConcurrent = 2);
    bool isConfigured() const { return m_configured; }

    void enqueue(const QString &videoId);            // 上传完成/恢复时入队（自动探测）
    void enqueuePendingFromDb();                     // 服务启动恢复

signals:
    void transcodeFinished(const QString &videoId);  // 全部档位结束（成功或失败）
    void taskUpdated(const QString &videoId);        // 某档进度/状态变化

private:
    struct ProbeCtx {
        QString videoId;
        QProcess *proc = nullptr;
    };

    struct Job {
        enum Phase { PhaseCover, PhaseTranscode };
        QString videoId;
        QString sourcePath;
        QString baseName;            // 源文件名（含扩展名）
        double durationSec = 0.0;
        int sourceW = 0;
        int sourceH = 0;
        QList<int> pendingQualities; // 480/720/1080
        QList<int> doneQualities;
        QProcess *proc = nullptr;
        int currentQuality = 0;
        bool needCover = false;
        Phase phase = PhaseTranscode;
        QString lastLine;            // 进度解析缓存
    };

    QString fileNameOf(const QString &mediaUrl) const;
    QList<int> planQualities(int w, int h, const QList<int> &alreadyDone) const;
    QString variantAbsPath(const QString &baseName, int quality) const;

    void probeVideo(const QString &videoId);
    void onProbeFinished(ProbeCtx ctx, int code);
    void startNextJobs();
    void startJob(Job &job);
    void onJobFinished(const QString &videoId, int exitCode);
    void completeWithoutWork(const QString &videoId);

    QString m_uploadsDir;
    QString m_ffmpeg;
    QString m_ffprobe;
    bool m_enabled = true;
    bool m_configured = false;
    int m_maxConcurrent = 2;
    QList<ProbeCtx> m_probing;
    QList<Job> m_waiting;
    QList<Job> m_active;
};