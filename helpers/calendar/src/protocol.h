#pragma once

#include "occurrences.h"

#include <QByteArray>
#include <QByteArrayView>
#include <QColor>
#include <QDate>
#include <QJsonObject>
#include <QJsonValue>
#include <QString>

#include <expected>
#include <span>

// The helper talks to Quickshell with one JSON object per line.
//
// Requests (stdin):
//   {"id": <any>, "from": "2026-09-28", "to": "2026-11-08"}
//
// Messages (stdout):
//   {"type": "ready"}                   events are loaded, requests can be answered
//   {"type": "changed"}                 events changed, ask again for fresh data
//   {"type": "events", "id": <same id>, "events": [...], "calendars": [...]}
//   {"type": "error", "id": <same id or null>, "message": "..."}
namespace corium::calendar {

// Longest range a single request may ask for, in days.
inline constexpr qint64 maxRangeDays = 366;

struct Request {
    QJsonValue id;
    QDate from;
    QDate to;
};

struct CalendarInfo {
    qint64 id = -1;
    QString name;
    QColor color;
};

std::expected<Request, QString> parseRequest(QByteArrayView line);

QJsonObject occurrenceToJson(const Occurrence &occurrence);

QJsonObject eventsMessage(const QJsonValue &id,
                          std::span<const Occurrence> occurrences,
                          std::span<const CalendarInfo> calendars);
QJsonObject errorMessage(const QJsonValue &id, const QString &message);
QJsonObject notification(const QString &type);

// A message as one compact line, newline included.
QByteArray toLine(const QJsonObject &message);

} // namespace corium::calendar
