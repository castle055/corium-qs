#include "occurrences.h"

#include <KCalendarCore/Event>
#include <KCalendarCore/OccurrenceIterator>

#include <algorithm>
#include <tuple>

namespace corium::calendar {

namespace {

// OccurrenceIterator only finds recurring occurrences that start inside the
// range it's given, so look back this far to catch long occurrences that start
// before the range and run into it.
constexpr int lookbackDays = 62;

} // namespace

QList<QDate> daysCovered(const QDateTime &start, const QDateTime &end, bool allDay, QDate from, QDate to)
{
    const QDate first = start.date();
    QDate last;
    if (allDay)
        last = std::max(first, end.date());
    else if (end > start)
        last = end.addMSecs(-1).date();
    else
        last = first;

    QList<QDate> days;
    for (QDate d = std::max(first, from); d <= std::min(last, to); d = d.addDays(1))
        days.append(d);
    return days;
}

std::vector<Occurrence> occurrencesInRange(const KCalendarCore::Calendar &calendar,
                                           QDate from,
                                           QDate to,
                                           const QTimeZone &zone)
{
    std::vector<Occurrence> result;
    if (!from.isValid() || !to.isValid() || from > to)
        return result;

    const QDateTime rangeStart = from.addDays(-lookbackDays).startOfDay(zone);
    const QDateTime rangeEnd = to.endOfDay(zone);

    for (KCalendarCore::OccurrenceIterator it(calendar, rangeStart, rangeEnd); it.hasNext();) {
        it.next();

        const auto incidence = it.incidence();
        if (!incidence || incidence->type() != KCalendarCore::IncidenceBase::TypeEvent)
            continue;

        Occurrence occurrence;
        occurrence.incidence = incidence;
        occurrence.uid = incidence->uid();
        occurrence.summary = incidence->summary();
        occurrence.location = incidence->location();
        occurrence.allDay = incidence->allDay();

        if (occurrence.allDay) {
            // All-day dates are floating: keep the calendar date as it is.
            occurrence.start = QDateTime(it.occurrenceStartDate().date(), QTime(0, 0), zone);
            occurrence.end = QDateTime(it.occurrenceEndDate().date(), QTime(0, 0), zone);
        } else {
            occurrence.start = it.occurrenceStartDate().toTimeZone(zone);
            occurrence.end = it.occurrenceEndDate().toTimeZone(zone);
        }

        occurrence.days = daysCovered(occurrence.start, occurrence.end, occurrence.allDay, from, to);
        if (occurrence.days.isEmpty())
            continue;

        result.push_back(std::move(occurrence));
    }

    std::ranges::sort(result, {}, [](const Occurrence &o) {
        return std::tuple(o.days.first(), !o.allDay, o.start, o.summary, o.uid);
    });
    return result;
}

} // namespace corium::calendar
