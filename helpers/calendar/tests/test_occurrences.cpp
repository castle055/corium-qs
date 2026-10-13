#include "occurrences.h"

#include <KCalendarCore/Event>
#include <KCalendarCore/MemoryCalendar>
#include <KCalendarCore/Todo>

#include <QTest>

using namespace corium::calendar;
using namespace Qt::StringLiterals;

namespace {

const QTimeZone madrid("Europe/Madrid");

QDateTime at(int year, int month, int day, int hour, int minute = 0, const QTimeZone &zone = madrid)
{
    return QDateTime(QDate(year, month, day), QTime(hour, minute), zone);
}

KCalendarCore::Event::Ptr timedEvent(const QString &summary, const QDateTime &start, const QDateTime &end)
{
    KCalendarCore::Event::Ptr event(new KCalendarCore::Event);
    event->setSummary(summary);
    event->setDtStart(start);
    event->setDtEnd(end);
    return event;
}

// `last` is inclusive, as KCalendarCore stores all-day events.
KCalendarCore::Event::Ptr allDayEvent(const QString &summary, QDate first, QDate last)
{
    KCalendarCore::Event::Ptr event(new KCalendarCore::Event);
    event->setSummary(summary);
    event->setDtStart(QDateTime(first, QTime(0, 0), madrid));
    event->setDtEnd(QDateTime(last, QTime(0, 0), madrid));
    event->setAllDay(true);
    return event;
}

QStringList summaries(const std::vector<Occurrence> &occurrences)
{
    QStringList result;
    for (const Occurrence &o : occurrences)
        result.append(o.summary);
    return result;
}

QList<QDate> dates(QDate first, QDate last)
{
    QList<QDate> result;
    for (QDate d = first; d <= last; d = d.addDays(1))
        result.append(d);
    return result;
}

} // namespace

class TestOccurrences : public QObject
{
    Q_OBJECT

private:
    KCalendarCore::MemoryCalendar::Ptr calendar;

private Q_SLOTS:
    void init()
    {
        calendar.reset(new KCalendarCore::MemoryCalendar(madrid));
    }

    void daysCovered_data()
    {
        QTest::addColumn<QDateTime>("start");
        QTest::addColumn<QDateTime>("end");
        QTest::addColumn<bool>("allDay");
        QTest::addColumn<QList<QDate>>("expected");

        const QDate from(2026, 10, 1);

        QTest::newRow("timed, one day") << at(2026, 10, 12, 9) << at(2026, 10, 12, 10) << false
                                        << QList{QDate(2026, 10, 12)};
        QTest::newRow("timed, over midnight") << at(2026, 10, 12, 22) << at(2026, 10, 13, 2) << false
                                              << dates(QDate(2026, 10, 12), QDate(2026, 10, 13));
        QTest::newRow("timed, ends at midnight") << at(2026, 10, 12, 22) << at(2026, 10, 13, 0) << false
                                                 << QList{QDate(2026, 10, 12)};
        QTest::newRow("timed, no duration") << at(2026, 10, 12, 9) << at(2026, 10, 12, 9) << false
                                            << QList{QDate(2026, 10, 12)};
        QTest::newRow("all-day, inclusive end") << at(2026, 10, 12, 0) << at(2026, 10, 14, 0) << true
                                                << dates(QDate(2026, 10, 12), QDate(2026, 10, 14));
        QTest::newRow("clamped to range start") << at(2026, 9, 29, 0) << at(2026, 10, 2, 0) << true
                                                << dates(from, QDate(2026, 10, 2));
        QTest::newRow("clamped to range end") << at(2026, 10, 30, 0) << at(2026, 11, 3, 0) << true
                                              << dates(QDate(2026, 10, 30), QDate(2026, 10, 31));
        QTest::newRow("before range") << at(2026, 9, 20, 9) << at(2026, 9, 20, 10) << false << QList<QDate>{};
    }

    void daysCovered()
    {
        QFETCH(QDateTime, start);
        QFETCH(QDateTime, end);
        QFETCH(bool, allDay);
        QFETCH(QList<QDate>, expected);

        QCOMPARE(corium::calendar::daysCovered(start, end, allDay, QDate(2026, 10, 1), QDate(2026, 10, 31)), expected);
    }

    void singleTimedEvent()
    {
        auto event = timedEvent(u"Dentist"_s, at(2026, 10, 12, 9, 30), at(2026, 10, 12, 10, 15));
        event->setLocation(u"Calle Mayor 1"_s);
        calendar->addEvent(event);

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QCOMPARE(result.size(), 1u);
        const Occurrence &o = result.front();
        QCOMPARE(o.summary, u"Dentist"_s);
        QCOMPARE(o.location, u"Calle Mayor 1"_s);
        QCOMPARE(o.uid, event->uid());
        QVERIFY(!o.allDay);
        QCOMPARE(o.start, at(2026, 10, 12, 9, 30));
        QCOMPARE(o.end, at(2026, 10, 12, 10, 15));
        QCOMPARE(o.days, QList{QDate(2026, 10, 12)});
        QCOMPARE(o.calendarId, -1);
    }

    void rangeIsInclusive()
    {
        calendar->addEvent(timedEvent(u"before"_s, at(2026, 9, 30, 23), at(2026, 9, 30, 23, 30)));
        calendar->addEvent(timedEvent(u"first day"_s, at(2026, 10, 1, 0), at(2026, 10, 1, 1)));
        calendar->addEvent(timedEvent(u"last day"_s, at(2026, 10, 31, 23), at(2026, 10, 31, 23, 59)));
        calendar->addEvent(timedEvent(u"after"_s, at(2026, 11, 1, 0), at(2026, 11, 1, 1)));

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QCOMPARE(summaries(result), (QStringList{u"first day"_s, u"last day"_s}));
    }

    void convertsToLocalTime()
    {
        // 12:00 UTC is 14:00 in Madrid during summer time.
        calendar->addEvent(timedEvent(u"call"_s, at(2026, 10, 12, 12, 0, QTimeZone::UTC), at(2026, 10, 12, 13, 0, QTimeZone::UTC)));

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QCOMPARE(result.size(), 1u);
        QCOMPARE(result.front().start.time(), QTime(14, 0));
        QCOMPARE(result.front().start.timeZone(), madrid);
    }

    void eventCrossingMidnightInLocalTime()
    {
        // 23:30 UTC on the 12th is already the 13th in Madrid.
        calendar->addEvent(timedEvent(u"late"_s, at(2026, 10, 12, 23, 30, QTimeZone::UTC), at(2026, 10, 13, 0, 30, QTimeZone::UTC)));

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QCOMPARE(result.size(), 1u);
        QCOMPARE(result.front().days, QList{QDate(2026, 10, 13)});
    }

    void allDayEvents()
    {
        calendar->addEvent(allDayEvent(u"holiday"_s, QDate(2026, 10, 12), QDate(2026, 10, 12)));
        calendar->addEvent(allDayEvent(u"trip"_s, QDate(2026, 10, 20), QDate(2026, 10, 23)));

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QCOMPARE(result.size(), 2u);
        QVERIFY(result[0].allDay);
        QCOMPARE(result[0].start.date(), QDate(2026, 10, 12));
        QCOMPARE(result[0].end.date(), QDate(2026, 10, 12));
        QCOMPARE(result[0].days, QList{QDate(2026, 10, 12)});
        QCOMPARE(result[1].start.date(), QDate(2026, 10, 20));
        QCOMPARE(result[1].end.date(), QDate(2026, 10, 23));
        QCOMPARE(result[1].days, dates(QDate(2026, 10, 20), QDate(2026, 10, 23)));
    }

    void allDayEventStartingBeforeRange()
    {
        calendar->addEvent(allDayEvent(u"conference"_s, QDate(2026, 9, 28), QDate(2026, 10, 2)));

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QCOMPARE(result.size(), 1u);
        QCOMPARE(result.front().days, dates(QDate(2026, 10, 1), QDate(2026, 10, 2)));
    }

    void weeklyRecurrence()
    {
        // Mondays at 10:00, starting before the range.
        auto event = timedEvent(u"standup"_s, at(2026, 9, 7, 10), at(2026, 9, 7, 10, 30));
        event->recurrence()->setWeekly(1);
        calendar->addEvent(event);

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QList<QDate> days;
        for (const Occurrence &o : result) {
            QCOMPARE(o.start.time(), QTime(10, 0));
            QCOMPARE(o.end.time(), QTime(10, 30));
            days.append(o.days);
        }
        QCOMPARE(days, (QList{QDate(2026, 10, 5), QDate(2026, 10, 12), QDate(2026, 10, 19), QDate(2026, 10, 26)}));
    }

    void recurrenceKeepsLocalTimeAcrossDst()
    {
        // Summer time ends on 25 October; the event stays at 10:00 local time.
        auto event = timedEvent(u"standup"_s, at(2026, 10, 19, 10), at(2026, 10, 19, 11));
        event->recurrence()->setWeekly(1);
        calendar->addEvent(event);

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 19), QDate(2026, 11, 2), madrid);

        QCOMPARE(result.size(), 3u);
        for (const Occurrence &o : result)
            QCOMPARE(o.start.time(), QTime(10, 0));
    }

    void recurrenceWithExcludedDate()
    {
        auto event = timedEvent(u"standup"_s, at(2026, 10, 5, 10), at(2026, 10, 5, 10, 30));
        event->recurrence()->setWeekly(1);
        event->recurrence()->addExDateTime(at(2026, 10, 12, 10));
        calendar->addEvent(event);

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QList<QDate> days;
        for (const Occurrence &o : result)
            days.append(o.days);
        QCOMPARE(days, (QList{QDate(2026, 10, 5), QDate(2026, 10, 19), QDate(2026, 10, 26)}));
    }

    void recurrenceWithModifiedOccurrence()
    {
        auto event = timedEvent(u"standup"_s, at(2026, 10, 5, 10), at(2026, 10, 5, 10, 30));
        event->recurrence()->setWeekly(1);
        calendar->addEvent(event);

        // The 12 October occurrence moved to the afternoon and renamed.
        KCalendarCore::Event::Ptr moved(event->clone());
        moved->clearRecurrence();
        moved->setRecurrenceId(at(2026, 10, 12, 10));
        moved->setDtStart(at(2026, 10, 12, 16));
        moved->setDtEnd(at(2026, 10, 12, 17));
        moved->setSummary(u"standup (moved)"_s);
        calendar->addEvent(moved);

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 12), QDate(2026, 10, 12), madrid);

        QCOMPARE(result.size(), 1u);
        QCOMPARE(result.front().summary, u"standup (moved)"_s);
        QCOMPARE(result.front().start, at(2026, 10, 12, 16));
        QCOMPARE(result.front().uid, event->uid());
    }

    void longRecurringOccurrenceStartingBeforeRange()
    {
        // A two-week all-day event every month, already running when the range starts.
        auto event = allDayEvent(u"exam period"_s, QDate(2026, 8, 25), QDate(2026, 9, 7));
        event->recurrence()->setMonthly(1);
        calendar->addEvent(event);

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 3), madrid);

        QCOMPARE(result.size(), 1u);
        QCOMPARE(result.front().start.date(), QDate(2026, 9, 25));
        QCOMPARE(result.front().days, dates(QDate(2026, 10, 1), QDate(2026, 10, 3)));
    }

    void sortedAllDayFirstThenByTime()
    {
        calendar->addEvent(timedEvent(u"lunch"_s, at(2026, 10, 12, 14), at(2026, 10, 12, 15)));
        calendar->addEvent(timedEvent(u"tomorrow"_s, at(2026, 10, 13, 8), at(2026, 10, 13, 9)));
        calendar->addEvent(timedEvent(u"breakfast"_s, at(2026, 10, 12, 8), at(2026, 10, 12, 9)));
        calendar->addEvent(allDayEvent(u"holiday"_s, QDate(2026, 10, 12), QDate(2026, 10, 12)));

        const auto result = occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid);

        QCOMPARE(summaries(result), (QStringList{u"holiday"_s, u"breakfast"_s, u"lunch"_s, u"tomorrow"_s}));
    }

    void ignoresTodos()
    {
        KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
        todo->setSummary(u"buy milk"_s);
        todo->setDtStart(at(2026, 10, 12, 9));
        todo->setDtDue(at(2026, 10, 12, 10));
        calendar->addTodo(todo);

        QVERIFY(occurrencesInRange(*calendar, QDate(2026, 10, 1), QDate(2026, 10, 31), madrid).empty());
    }

    void invalidRangeIsEmpty()
    {
        calendar->addEvent(timedEvent(u"x"_s, at(2026, 10, 12, 9), at(2026, 10, 12, 10)));

        QVERIFY(occurrencesInRange(*calendar, QDate(2026, 10, 31), QDate(2026, 10, 1), madrid).empty());
        QVERIFY(occurrencesInRange(*calendar, QDate(), QDate(2026, 10, 1), madrid).empty());
    }
};

QTEST_GUILESS_MAIN(TestOccurrences)
#include "test_occurrences.moc"
