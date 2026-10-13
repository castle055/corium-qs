#include "protocol.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>

namespace corium::calendar {

namespace {

std::expected<QDate, QString> dateField(const QJsonObject &object, const QString &key)
{
    const QJsonValue value = object.value(key);
    if (!value.isString())
        return std::unexpected(QStringLiteral("\"%1\" must be a date string").arg(key));

    const QDate date = QDate::fromString(value.toString(), Qt::ISODate);
    if (!date.isValid())
        return std::unexpected(QStringLiteral("\"%1\" is not a valid YYYY-MM-DD date").arg(key));
    return date;
}

QString timestamp(const QDateTime &dateTime, bool allDay)
{
    // No offset: the receiver reads it as local time, which it already is.
    return allDay ? dateTime.date().toString(Qt::ISODate)
                  : dateTime.toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss"));
}

} // namespace

std::expected<Request, QString> parseRequest(QByteArrayView line)
{
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(line.toByteArray(), &error);
    if (error.error != QJsonParseError::NoError)
        return std::unexpected(QStringLiteral("invalid JSON: %1").arg(error.errorString()));
    if (!document.isObject())
        return std::unexpected(QStringLiteral("request must be a JSON object"));

    const QJsonObject object = document.object();

    auto from = dateField(object, QStringLiteral("from"));
    if (!from)
        return std::unexpected(from.error());
    auto to = dateField(object, QStringLiteral("to"));
    if (!to)
        return std::unexpected(to.error());

    if (*from > *to)
        return std::unexpected(QStringLiteral("\"from\" is after \"to\""));
    if (from->daysTo(*to) + 1 > maxRangeDays)
        return std::unexpected(QStringLiteral("range is longer than %1 days").arg(maxRangeDays));

    return Request{object.value(QStringLiteral("id")), *from, *to};
}

QJsonObject occurrenceToJson(const Occurrence &occurrence)
{
    QJsonArray days;
    for (const QDate &day : occurrence.days)
        days.append(day.toString(Qt::ISODate));

    return {
        {QStringLiteral("uid"), occurrence.uid},
        {QStringLiteral("summary"), occurrence.summary},
        {QStringLiteral("location"), occurrence.location},
        {QStringLiteral("allDay"), occurrence.allDay},
        {QStringLiteral("start"), timestamp(occurrence.start, occurrence.allDay)},
        {QStringLiteral("end"), timestamp(occurrence.end, occurrence.allDay)},
        {QStringLiteral("days"), days},
        {QStringLiteral("calendar"), occurrence.calendarId},
    };
}

QJsonObject eventsMessage(const QJsonValue &id,
                          std::span<const Occurrence> occurrences,
                          std::span<const CalendarInfo> calendars)
{
    QJsonArray events;
    for (const Occurrence &occurrence : occurrences)
        events.append(occurrenceToJson(occurrence));

    QJsonArray calendarList;
    for (const CalendarInfo &calendar : calendars) {
        calendarList.append(QJsonObject{
            {QStringLiteral("id"), calendar.id},
            {QStringLiteral("name"), calendar.name},
            {QStringLiteral("color"), calendar.color.isValid() ? calendar.color.name() : QString()},
        });
    }

    return {
        {QStringLiteral("type"), QStringLiteral("events")},
        {QStringLiteral("id"), id},
        {QStringLiteral("events"), events},
        {QStringLiteral("calendars"), calendarList},
    };
}

QJsonObject errorMessage(const QJsonValue &id, const QString &message)
{
    return {
        {QStringLiteral("type"), QStringLiteral("error")},
        {QStringLiteral("id"), id},
        {QStringLiteral("message"), message},
    };
}

QJsonObject notification(const QString &type)
{
    return {{QStringLiteral("type"), type}};
}

QByteArray toLine(const QJsonObject &message)
{
    return QJsonDocument(message).toJson(QJsonDocument::Compact) + '\n';
}

} // namespace corium::calendar
