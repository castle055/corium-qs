#pragma once

#include <KCalendarCore/Calendar>
#include <KCalendarCore/Incidence>

#include <QDate>
#include <QDateTime>
#include <QList>
#include <QTimeZone>

#include <vector>

namespace corium::calendar {

// One occurrence of an event, in the local time zone.
struct Occurrence {
    KCalendarCore::Incidence::Ptr incidence;

    QString uid;
    QString summary;
    QString location;
    bool allDay = false;

    // For all-day events only the dates matter and `end` is the last day, inclusive.
    // For timed events `end` is exclusive.
    QDateTime start;
    QDateTime end;

    // The days in the requested range that this occurrence is (partly) on.
    QList<QDate> days;

    // The Akonadi collection the event is stored in, or -1 if unknown.
    qint64 calendarId = -1;
};

// Days of [from, to] covered by an occurrence. A timed event that ends exactly
// at midnight does not cover the following day.
QList<QDate> daysCovered(const QDateTime &start, const QDateTime &end, bool allDay, QDate from, QDate to);

// All occurrences of the calendar's events that are on at least one day of
// [from, to] (both inclusive), with recurrences expanded and their exceptions
// applied. Sorted by first day, then all-day before timed, then start time.
std::vector<Occurrence> occurrencesInRange(const KCalendarCore::Calendar &calendar,
                                           QDate from,
                                           QDate to,
                                           const QTimeZone &zone);

} // namespace corium::calendar
