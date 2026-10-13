#include "protocol.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QTest>

using namespace corium::calendar;
using namespace Qt::StringLiterals;

namespace {

const QTimeZone madrid("Europe/Madrid");

Occurrence timedOccurrence()
{
    Occurrence o;
    o.uid = u"uid-1"_s;
    o.summary = u"Dentist"_s;
    o.location = u"Calle Mayor 1"_s;
    o.start = QDateTime(QDate(2026, 10, 12), QTime(9, 30), madrid);
    o.end = QDateTime(QDate(2026, 10, 12), QTime(10, 15), madrid);
    o.days = {QDate(2026, 10, 12)};
    o.calendarId = 7;
    return o;
}

Occurrence allDayOccurrence()
{
    Occurrence o;
    o.uid = u"uid-2"_s;
    o.summary = u"Trip"_s;
    o.allDay = true;
    o.start = QDateTime(QDate(2026, 10, 20), QTime(0, 0), madrid);
    o.end = QDateTime(QDate(2026, 10, 21), QTime(0, 0), madrid);
    o.days = {QDate(2026, 10, 20), QDate(2026, 10, 21)};
    o.calendarId = 7;
    return o;
}

} // namespace

class TestProtocol : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parsesValidRequest()
    {
        const auto request = parseRequest(R"({"id": 3, "from": "2026-09-28", "to": "2026-11-08"})");

        QVERIFY2(request, qPrintable(request ? QString() : request.error()));
        QCOMPARE(request->id, QJsonValue(3));
        QCOMPARE(request->from, QDate(2026, 9, 28));
        QCOMPARE(request->to, QDate(2026, 11, 8));
    }

    void idIsOptionalAndOfAnyType()
    {
        QVERIFY(parseRequest(R"({"from": "2026-10-01", "to": "2026-10-01"})")->id.isUndefined());
        QCOMPARE(parseRequest(R"({"id": "abc", "from": "2026-10-01", "to": "2026-10-01"})")->id, QJsonValue(u"abc"_s));
    }

    void rejectsInvalidRequests_data()
    {
        QTest::addColumn<QByteArray>("line");
        QTest::addColumn<QString>("errorContains");

        QTest::newRow("not JSON") << QByteArray("hello") << u"invalid JSON"_s;
        QTest::newRow("not an object") << QByteArray("[1, 2]") << u"JSON object"_s;
        QTest::newRow("missing from") << QByteArray(R"({"to": "2026-10-01"})") << u"\"from\""_s;
        QTest::newRow("missing to") << QByteArray(R"({"from": "2026-10-01"})") << u"\"to\""_s;
        QTest::newRow("date not a string") << QByteArray(R"({"from": 20261001, "to": "2026-10-01"})") << u"\"from\""_s;
        QTest::newRow("impossible date") << QByteArray(R"({"from": "2026-02-30", "to": "2026-10-01"})") << u"valid"_s;
        QTest::newRow("wrong date format") << QByteArray(R"({"from": "01/10/2026", "to": "2026-10-01"})") << u"valid"_s;
        QTest::newRow("reversed range") << QByteArray(R"({"from": "2026-10-02", "to": "2026-10-01"})") << u"after"_s;
        QTest::newRow("range too long") << QByteArray(R"({"from": "2026-01-01", "to": "2027-01-02"})") << u"longer"_s;
    }

    void rejectsInvalidRequests()
    {
        QFETCH(QByteArray, line);
        QFETCH(QString, errorContains);

        const auto request = parseRequest(line);
        QVERIFY(!request);
        QVERIFY2(request.error().contains(errorContains), qPrintable(request.error()));
    }

    void acceptsLongestAllowedRange()
    {
        // 2028 is a leap year: 1 January to 31 December is exactly 366 days.
        QVERIFY(parseRequest(R"({"from": "2028-01-01", "to": "2028-12-31"})"));
    }

    void timedOccurrenceToJson()
    {
        const QJsonObject json = occurrenceToJson(timedOccurrence());

        QCOMPARE(json[u"uid"_s].toString(), u"uid-1"_s);
        QCOMPARE(json[u"summary"_s].toString(), u"Dentist"_s);
        QCOMPARE(json[u"location"_s].toString(), u"Calle Mayor 1"_s);
        QCOMPARE(json[u"allDay"_s].toBool(), false);
        QCOMPARE(json[u"start"_s].toString(), u"2026-10-12T09:30:00"_s);
        QCOMPARE(json[u"end"_s].toString(), u"2026-10-12T10:15:00"_s);
        QCOMPARE(json[u"days"_s].toArray(), QJsonArray{u"2026-10-12"_s});
        QCOMPARE(json[u"calendar"_s].toInteger(), 7);
    }

    void allDayOccurrenceToJson()
    {
        const QJsonObject json = occurrenceToJson(allDayOccurrence());

        QCOMPARE(json[u"allDay"_s].toBool(), true);
        QCOMPARE(json[u"start"_s].toString(), u"2026-10-20"_s);
        QCOMPARE(json[u"end"_s].toString(), u"2026-10-21"_s);
        QCOMPARE(json[u"days"_s].toArray(), (QJsonArray{u"2026-10-20"_s, u"2026-10-21"_s}));
    }

    void eventsMessageShape()
    {
        const std::vector occurrences{timedOccurrence(), allDayOccurrence()};
        const std::vector calendars{
            CalendarInfo{.id = 7, .name = u"Personal"_s, .color = QColor(0x80, 0xbf, 0xff)},
            CalendarInfo{.id = 8, .name = u"No colour"_s},
        };

        const QJsonObject message = eventsMessage(QJsonValue(5), occurrences, calendars);

        QCOMPARE(message[u"type"_s].toString(), u"events"_s);
        QCOMPARE(message[u"id"_s], QJsonValue(5));
        QCOMPARE(message[u"events"_s].toArray().size(), 2);
        QCOMPARE(message[u"events"_s].toArray()[1].toObject()[u"summary"_s].toString(), u"Trip"_s);

        const QJsonArray calendarList = message[u"calendars"_s].toArray();
        QCOMPARE(calendarList.size(), 2);
        QCOMPARE(calendarList[0].toObject(),
                 (QJsonObject{{u"id"_s, 7}, {u"name"_s, u"Personal"_s}, {u"color"_s, u"#80bfff"_s}}));
        QCOMPARE(calendarList[1].toObject()[u"color"_s].toString(), QString());
    }

    void messageWithoutIdHasNoIdField()
    {
        QVERIFY(!eventsMessage(QJsonValue::Undefined, {}, {}).contains(u"id"_s));
    }

    void errorAndNotificationMessages()
    {
        QCOMPARE(errorMessage(QJsonValue(1), u"boom"_s),
                 (QJsonObject{{u"type"_s, u"error"_s}, {u"id"_s, 1}, {u"message"_s, u"boom"_s}}));
        QCOMPARE(notification(u"ready"_s), (QJsonObject{{u"type"_s, u"ready"_s}}));
    }

    void linesAreSingleLineJson()
    {
        const QByteArray line = toLine(eventsMessage(QJsonValue(1), std::vector{timedOccurrence()}, {}));

        QVERIFY(line.endsWith('\n'));
        QCOMPARE(line.count('\n'), 1);
        QVERIFY(QJsonDocument::fromJson(line).isObject());
    }

    void requestRoundTrip()
    {
        // What the list command does: build a request line and parse it back.
        const auto request = parseRequest(toLine({{u"from"_s, u"2026-10-01"_s}, {u"to"_s, u"2026-10-31"_s}}));

        QVERIFY(request);
        QCOMPARE(request->from, QDate(2026, 10, 1));
        QCOMPARE(request->to, QDate(2026, 10, 31));
    }
};

QTEST_GUILESS_MAIN(TestProtocol)
#include "test_protocol.moc"
