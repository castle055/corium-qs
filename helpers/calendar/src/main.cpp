// corium-calendar: reads KOrganizer's events from Akonadi for the bar's clock.
//
//   corium-calendar serve                  answer requests on stdin, see protocol.h
//   corium-calendar list FROM TO           print the events in [FROM, TO] once
//
// Dates are YYYY-MM-DD.

#include "akonadisource.h"
#include "protocol.h"

#include <QCoreApplication>
#include <QSocketNotifier>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <unistd.h>

using namespace corium::calendar;
using namespace Qt::StringLiterals;

namespace {

void send(const QJsonObject &message)
{
    const QByteArray line = toLine(message);
    std::fwrite(line.constData(), 1, line.size(), stdout);
    std::fflush(stdout);
}

void answer(const AkonadiSource &source, const Request &request)
{
    const auto occurrences = source.occurrences(request.from, request.to);
    send(eventsMessage(request.id, occurrences, source.calendarsFor(occurrences)));
}

int usage()
{
    std::fputs("usage: corium-calendar serve\n"
               "       corium-calendar list FROM TO   (dates as YYYY-MM-DD)\n",
               stderr);
    return 2;
}

int list(QCoreApplication &app, AkonadiSource &source, const QString &from, const QString &to)
{
    const auto request = parseRequest(toLine({{u"from"_s, from}, {u"to"_s, to}}));
    if (!request) {
        std::fprintf(stderr, "corium-calendar: %s\n", qPrintable(request.error()));
        return 2;
    }

    QObject::connect(&source, &AkonadiSource::ready, &app, [&] {
        answer(source, *request);
        app.quit();
    });
    QObject::connect(&source, &AkonadiSource::failed, &app, [&](const QString &message) {
        std::fprintf(stderr, "corium-calendar: %s\n", qPrintable(message));
        app.exit(1);
    });

    source.start();
    return app.exec();
}

int serve(QCoreApplication &app, AkonadiSource &source)
{
    // Requests that arrive before the first load are answered once it's done.
    QList<Request> waiting;
    QByteArray buffer;

    QObject::connect(&source, &AkonadiSource::ready, &app, [&] {
        send(notification(u"ready"_s));
        for (const Request &request : std::exchange(waiting, {}))
            answer(source, request);
    });
    QObject::connect(&source, &AkonadiSource::changed, &app, [] {
        send(notification(u"changed"_s));
    });
    QObject::connect(&source, &AkonadiSource::failed, &app, [&](const QString &message) {
        send(errorMessage(QJsonValue::Null, message));
        // Nothing loaded yet (e.g. Akonadi isn't up): exit so Quickshell retries
        // later. Once loaded, keep serving the last good data instead.
        if (!source.isReady())
            app.exit(1);
    });

    QSocketNotifier stdinNotifier(STDIN_FILENO, QSocketNotifier::Read);
    QObject::connect(&stdinNotifier, &QSocketNotifier::activated, &app, [&] {
        char chunk[4096];
        const ssize_t count = ::read(STDIN_FILENO, chunk, sizeof chunk);
        if (count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
            return; // Quickshell may hand us a non-blocking pipe.
        if (count <= 0) {
            // Quickshell went away.
            if (count < 0)
                std::fprintf(stderr, "corium-calendar: reading stdin: %s\n", std::strerror(errno));
            app.quit();
            return;
        }
        buffer.append(chunk, count);

        qsizetype newline;
        while ((newline = buffer.indexOf('\n')) >= 0) {
            const QByteArray line = buffer.left(newline).trimmed();
            buffer.remove(0, newline + 1);
            if (line.isEmpty())
                continue;

            const auto request = parseRequest(line);
            if (!request)
                send(errorMessage(QJsonValue::Null, request.error()));
            else if (source.isReady())
                answer(source, *request);
            else
                waiting.append(*request);
        }
    });

    source.start();
    return app.exec();
}

} // namespace

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    app.setApplicationName(u"corium-calendar"_s);
    // Akonadi's jobs hold quit locks, so by default the app would quit as soon
    // as the last one finished. It should quit only when we say so.
    QCoreApplication::setQuitLockEnabled(false);

    const QStringList args = app.arguments().mid(1);
    AkonadiSource source;

    if (args.size() == 1 && args[0] == u"serve")
        return serve(app, source);
    if (args.size() == 3 && args[0] == u"list")
        return list(app, source, args[1], args[2]);
    return usage();
}
