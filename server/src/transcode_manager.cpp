#include "transcode_manager.h"
#include "repository.h"
#include "database.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QSqlQuery>
#include <QDebug>
#include <QProcess>
#include <QRegularExpression>

static double parseFfmpegTime(const QString &text)
{
    static const QRegularExpression re("time=(\\d+):(\\d+):(\\d+(?:\\.\\d+)?)");
    QRegularExpressionMatch m = re.match(text);
    if (!m.hasMatch())
        return -1.0;
    return m.captured(1).toDouble() * 3600.0
         + m.captured(2).toDouble() * 60.0
         + m.captured(3).toDouble();
}

TranscodeManager::TranscodeManager(QObject *parent) : QObject(parent) {}

void TranscodeManager::configure(const QString &uploadsDir, const QString &ffmpegPath,
                                 const QString &ffprobePath, bool enabled, int maxConcurrent)
{
    m_uploadsDir = uploadsDir;
    m_ffmpeg = ffmpegPath;
    m_ffprobe = ffprobePath;
    m_enabled = enabled;
    m_maxConcurrent = qBound(1, maxConcurrent, 4);
    m_configured = enabled && QFile::exists(m_ffmpeg) && QFile::exists(m_ffprobe);
    qInfo() << "TranscodeManager:" << (m_configured ? "ready" : "disabled / tools missing")
            << "ffmpeg=" << m_ffmpeg << "ffprobe=" << m_ffprobe << "workers=" << m_maxConcurrent;
}

QString TranscodeManager::fileNameOf(const QString &mediaUrl) const
{
    QString name = mediaUrl;
    const int slash = name.lastIndexOf('/');
    if (slash >= 0)
        name = name.mid(slash + 1);
    return name;
}

QList<int> TranscodeManager::planQualities(int w, int h, const QList<int> &alreadyDone) const
{
    QList<int> result;
    if (w <= 0 || h <= 0)
        return result;
    // 480p/720p/1080p 指"较短的边/高"：横屏看 h，竖屏看 w（等效 qMax 短边）
    const int capacity = qMin(w, h);
    QList<int> candidates;
    if (capacity >= 1080) candidates << 1080;
    if (capacity >= 720)  candidates << 720;
    if (capacity >= 480)  candidates << 480;
    for (int q : candidates)
        if (!alreadyDone.contains(q))
            result << q;
    return result;
}

QString TranscodeManager::variantAbsPath(const QString &baseName, int quality) const
{
    const QFileInfo fi(baseName);
    return QDir(m_uploadsDir).filePath(fi.completeBaseName() + "__" + QString::number(quality) + "." + fi.suffix());
}

void TranscodeManager::enqueue(const QString &videoId)
{
    if (!m_configured) {
        repo::setVideoTranscodeStatus(videoId, "done", repo::doneQualitiesOfVideo(videoId));
        return;
    }
    // 已在探测/等待/执行中的视频不再重复入队
    for (const ProbeCtx &p : std::as_const(m_probing)) {
        if (p.videoId == videoId)
            return;
    }
    for (const Job &j : std::as_const(m_waiting)) {
        if (j.videoId == videoId)
            return;
    }
    for (const Job &j : std::as_const(m_active)) {
        if (j.videoId == videoId)
            return;
    }
    probeVideo(videoId);
}

void TranscodeManager::enqueuePendingFromDb()
{
    if (!m_configured)
        return;
    const auto pending = repo::pendingTranscodeTasks();
    for (const auto &p : pending) {
        qInfo() << "resume transcode:" << p.first << "quality" << p.second;
        probeVideo(p.first);
    }
}

void TranscodeManager::probeVideo(const QString &videoId)
{
    // 同一视频已处于探测中则跳过（enqueue 也做了一轮，这里兜底并发路径）
    for (const ProbeCtx &p : std::as_const(m_probing)) {
        if (p.videoId == videoId)
            return;
    }
    auto v = repo::findVideoById(videoId);
    if (!v || v->videoPath.isEmpty())
        return;
    ProbeCtx ctx;
    ctx.videoId = videoId;
    ctx.proc = new QProcess(this);
    ctx.proc->setProcessChannelMode(QProcess::MergedChannels);
    const QString src = QDir(m_uploadsDir).filePath(fileNameOf(v->videoPath));
    const QStringList args = {"-v", "error", "-print_format", "json",
                              "-show_format", "-show_streams", src};
    connect(ctx.proc, &QProcess::finished, this, [this, ctx](int code, QProcess::ExitStatus) {
        onProbeFinished(ctx, code);
    });
    ctx.proc->start(m_ffprobe, args);
    m_probing.append(ctx);
}

void TranscodeManager::onProbeFinished(ProbeCtx ctx, int code)
{
    const QString out = QString::fromUtf8(ctx.proc->readAll());
    for (int i = 0; i < m_probing.size(); ++i) {
        if (m_probing[i].proc == ctx.proc) {
            m_probing[i].proc->deleteLater();
            m_probing.removeAt(i);
            break;
        }
    }
    auto v = repo::findVideoById(ctx.videoId);
    if (!v || code != 0) {
        qWarning() << "ffprobe failed" << ctx.videoId << "code" << code << out.left(300);
        return;
    }

    int w = 0, h = 0;
    double dur = 0.0;
    const QJsonDocument doc = QJsonDocument::fromJson(out.toUtf8());
    if (doc.isObject()) {
        dur = doc.object().value("format").toObject().value("duration").toVariant().toString().toDouble();
        if (dur <= 0.0)
        dur = doc.object().value("format").toObject().value("duration").toVariant().toString().toDouble();
        if (dur <= 0.0)
            dur = doc.object().value("format").toObject().value("duration").toDouble(0.0);
        const QJsonArray streams = doc.object().value("streams").toArray();
        for (const QJsonValue &sv : streams) {
            const QJsonObject s = sv.toObject();
            if (s.value("codec_type").toString() == "video") {
                w = s.value("width").toVariant().toInt();
                h = s.value("height").toVariant().toInt();
                if (w == 0 || h == 0) {
                    w = s.value("coded_width").toVariant().toInt();
                    h = s.value("coded_height").toVariant().toInt();
                }
                break;
            }
        }
    }
    if (w <= 0 || h <= 0 || dur <= 0.0) {
        qWarning() << "bad media meta" << ctx.videoId << w << "x" << h << "dur" << dur;
        return;
    }

    const QString src = QDir(m_uploadsDir).filePath(fileNameOf(v->videoPath));
    repo::updateVideoMediaMeta(ctx.videoId, w, h, dur, QFileInfo(src).size());

    QStringList done = repo::doneQualitiesOfVideo(ctx.videoId);
    QList<int> doneQ;
    for (const QString &d : std::as_const(done)) {
        bool ok = false;
        const int q = d.toInt(&ok);
        if (ok) doneQ << q;
    }
    // 清理"超出源分辨率"的孤儿任务（旧版本可能误建 1080p 行）
    const QList<TranscodeTaskInfo> oldTasks = repo::transcodeTasksOf(ctx.videoId);
    for (const TranscodeTaskInfo &t : oldTasks) {
        // 480/720/1080 语义为"较短边/高度档位"：横屏按高、竖屏按宽也须低于源
        // 简化判据：该档放大后不超过源的短边尺寸才保留（防止把 720p 源升到 1080）
        const bool valid = (w >= h) ? (t.quality <= h) : (t.quality <= w);
        if (!valid) {
            repo::removeTranscodeTask(ctx.videoId, t.quality);
            qInfo() << "removed orphan transcode task" << ctx.videoId << "q" << t.quality;
        }
    }
    const QList<int> todo = planQualities(w, h, doneQ);

    Job job;
    job.videoId = ctx.videoId;
    job.sourcePath = src;
    job.baseName = fileNameOf(v->videoPath);
    job.durationSec = dur;
    job.sourceW = w;
    job.sourceH = h;
    job.doneQualities = doneQ;
    job.pendingQualities = todo;
    job.needCover = v->coverPath.isEmpty();

    // 封面 + 无档位：只抽封面
    if (todo.isEmpty() && !job.needCover) {
        repo::setVideoTranscodeStatus(ctx.videoId, "done", done);
        emit transcodeFinished(ctx.videoId);
        return;
    }
    if (v->transcodeStatus != "transcoding")
        repo::setVideoTranscodeStatus(ctx.videoId, "transcoding", done);
    for (int q : todo)
        repo::ensureTranscodeTask(ctx.videoId, q);

    job.phase = job.needCover ? Job::PhaseCover : Job::PhaseTranscode;
    m_waiting.append(job);
    startNextJobs();
}

void TranscodeManager::startNextJobs()
{
    while (!m_waiting.isEmpty() && m_active.size() < m_maxConcurrent) {
        Job job = m_waiting.takeFirst();
        startJob(job);
    }
}

void TranscodeManager::startJob(Job &job)
{
    if (job.phase == Job::PhaseCover) {
        job.phase = Job::PhaseTranscode;   // 封面结束后进入转码阶段，避免无限重复抽封面
        job.currentQuality = -1;           // -1 标记当前进程是"抽封面"
        const QString coverFile = job.videoId + "__cover__auto.jpg";
        const QString outPath = QDir(m_uploadsDir).filePath(coverFile);
        const double t = job.durationSec > 1.0 ? 1.0 : 0.1;
        const QStringList args = {"-y", "-ss", QString::number(t, 'f', 2), "-i", job.sourcePath,
                                  "-frames:v", "1", "-q:v", "3", outPath};

        job.proc = new QProcess(this);
        job.proc->setProcessChannelMode(QProcess::MergedChannels);
        m_active.append(job);
        QProcess *p = job.proc;
        connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, videoId = job.videoId](int code, QProcess::ExitStatus) {
                    onJobFinished(videoId, code);
                });
        qInfo() << "cover extract start" << job.videoId;
        p->start(m_ffmpeg, args);
        return;
    }

    if (job.pendingQualities.isEmpty()) {
        // 无档位可转（封面阶段已走完或失败）
        repo::setVideoTranscodeStatus(job.videoId, "done", repo::doneQualitiesOfVideo(job.videoId));
        emit transcodeFinished(job.videoId);
        startNextJobs();
        return;
    }

    const int q = job.pendingQualities.first();
    if (QFile::exists(variantAbsPath(job.baseName, q))) {
        job.pendingQualities.removeFirst();
        job.doneQualities.append(q);
        repo::updateTranscodeTask(job.videoId, q, "done", 100);
        startJob(job);
        return;
    }

    // q 是"短边目标"：横屏压高度、竖屏压宽度，再等比例算另一边并取偶
    // （libx264 要求宽高均为偶数）
    int tw = 0, th = 0;
    if (job.sourceW >= job.sourceH) {
        th = q;
        tw = qMax(2, int(q * qint64(job.sourceW) / job.sourceH));
    } else {
        tw = q;
        th = qMax(2, int(q * qint64(job.sourceH) / job.sourceW));
    }
    tw -= tw % 2;   // 853 -> 852
    th -= th % 2;   // 偶化高度（保留在 filter 后仍由 force_original_aspect_ratio 保证不放大）

    job.currentQuality = q;
    job.lastLine.clear();
    const QString outPath = variantAbsPath(job.baseName, q);
    const QStringList args = {
        "-y", "-i", job.sourcePath,
        "-vf", QString("scale=%1:%2:force_original_aspect_ratio=decrease:force_divisible_by=2").arg(tw).arg(th),
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
        "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart", outPath
    };

    job.proc = new QProcess(this);
    job.proc->setProcessChannelMode(QProcess::MergedChannels);
    m_active.append(job);
    QProcess *p = job.proc;

    connect(p, &QProcess::readyRead, this, [this, videoId = job.videoId]() {
        for (auto &j : m_active) {
            if (j.videoId == videoId && j.proc) {
                const QByteArray chunk = j.proc->readAll();
                j.lastLine += QString::fromUtf8(chunk);
                const double t = parseFfmpegTime(j.lastLine);
                if (t >= 0.0 && j.durationSec > 0.0) {
                    const int pct = qBound(1, int((t / j.durationSec) * 100.0), 99);
                    if (repo::updateTranscodeTask(videoId, j.currentQuality, "running", pct))
                        emit taskUpdated(videoId);
                    if (j.lastLine.size() > 4096)
                        j.lastLine = j.lastLine.right(2048);
                }
            }
        }
    });
    connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, videoId = job.videoId](int code, QProcess::ExitStatus) {
                onJobFinished(videoId, code);
            });

    qInfo() << "transcode start" << job.videoId << "q" << q << "->" << outPath;
    repo::updateTranscodeTask(job.videoId, q, "running", 1);
    p->start(m_ffmpeg, args);
}

void TranscodeManager::onJobFinished(const QString &videoId, int exitCode)
{
    int idx = -1;
    for (int i = 0; i < m_active.size(); ++i) {
        if (m_active[i].videoId == videoId) {
            idx = i;
            break;
        }
    }
    if (idx < 0) {
        startNextJobs();
        return;
    }
    Job job = m_active.takeAt(idx);
    QProcess *p = job.proc;
    job.proc = nullptr;
    if (p)
        p->deleteLater();

    // 抽封面完成：更新 cover_path 后继续转码（或无档位则收尾）
    if (job.currentQuality == -1) {
        if (exitCode == 0) {
            QSqlQuery up(db::connection());
            up.prepare("UPDATE videos SET cover_path = ? WHERE id = ?");
            up.addBindValue("/media/" + videoId + "__cover__auto.jpg");
            up.addBindValue(videoId);
            up.exec();
        } else {
            qWarning() << "cover extract failed" << videoId;
        }
        m_waiting.prepend(job);
        startNextJobs();
        return;
    }

    // 只抽封面（无转码档位）也会从 startJob 空队列分支收尾，不会走到这里
    const int q = job.currentQuality;
    const bool fileOk = QFile::exists(variantAbsPath(job.baseName, q));
    if (exitCode != 0 || !fileOk) {
        // 收集 ffmpeg stderr 帮助排查失败原因
        QString errTail;
        if (p && p->bytesAvailable() > 0)
            errTail = QString::fromUtf8(p->readAllStandardError()).right(800);
        qWarning() << "ffmpeg failed detail" << videoId << "q" << q
                   << "code" << exitCode << "err:" << errTail.left(600);
        if (p)
            qWarning() << "ffmpeg exitStatus:" << int(p->exitStatus())
                       << "error:" << p->errorString();
    }
    if (exitCode == 0 && fileOk) {
        repo::updateTranscodeTask(videoId, q, "done", 100);
        job.doneQualities.append(q);
        job.pendingQualities.removeFirst();
        qInfo() << "transcode ok" << videoId << "q" << q;
    } else {
        repo::updateTranscodeTask(videoId, q, "failed", 0);
        qWarning() << "transcode failed" << videoId << "q" << q << "code" << exitCode;
        repo::setVideoTranscodeStatus(videoId, "done", repo::doneQualitiesOfVideo(videoId));
        emit transcodeFinished(videoId);
        startNextJobs();
        return;
    }

    if (!job.pendingQualities.isEmpty()) {
        m_waiting.prepend(job);
    } else {
        repo::setVideoTranscodeStatus(videoId, "done", repo::doneQualitiesOfVideo(videoId));
        emit transcodeFinished(videoId);
    }
    startNextJobs();
}
