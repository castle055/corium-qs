#include "selection.h"

#include <QTest>

using namespace corium::calendar;
using namespace Qt::StringLiterals;

class TestSelection : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void defaultSelectsEverything()
    {
        QVERIFY(CalendarSelection().isSelected(1, u"akonadi_ical_resource_0"_s, u"x"_s));
    }

    void missingConfigSelectsEverything()
    {
        QVERIFY(CalendarSelection::fromEntries(std::nullopt).isSelected(1, u"akonadi_ical_resource_0"_s, u"x"_s));
    }

    void emptyListSelectsNothing()
    {
        QVERIFY(!CalendarSelection::fromEntries(QStringList{}).isSelected(1, u"akonadi_ical_resource_0"_s, u"x"_s));
    }

    void selectsById()
    {
        const auto selection = CalendarSelection::fromEntries(QStringList{u"c42"_s});

        QVERIFY(selection.isSelected(42, u"any"_s, u"any"_s));
        QVERIFY(!selection.isSelected(4, u"any"_s, u"any"_s));
        QVERIFY(!selection.isSelected(420, u"any"_s, u"any"_s));
    }

    void selectsByResourceAndRemoteId()
    {
        const auto selection = CalendarSelection::fromEntries(QStringList{
            u"rakonadi_google_resource_3/someone@example.com"_s,
            u"rakonadi_google_resource_3/v424"_s,
        });

        QVERIFY(selection.isSelected(10, u"akonadi_google_resource_3"_s, u"someone@example.com"_s));
        QVERIFY(selection.isSelected(11, u"akonadi_google_resource_3"_s, u"v424"_s));
        QVERIFY(!selection.isSelected(12, u"akonadi_google_resource_3"_s, u"other@example.com"_s));
        QVERIFY(!selection.isSelected(13, u"akonadi_google_resource_4"_s, u"v424"_s));
    }

    void remoteIdMayContainSlashes()
    {
        const auto selection = CalendarSelection::fromEntries(QStringList{u"rakonadi_ical_resource_0/home/me/cal.ics"_s});

        QVERIFY(selection.isSelected(1, u"akonadi_ical_resource_0"_s, u"home/me/cal.ics"_s));
    }

    void emptyRemoteId()
    {
        const auto selection = CalendarSelection::fromEntries(QStringList{u"rakonadi_ical_resource_0/"_s});

        QVERIFY(selection.isSelected(1, u"akonadi_ical_resource_0"_s, QString()));
        QVERIFY(!selection.isSelected(1, u"akonadi_ical_resource_0"_s, u"x"_s));
    }

    void ignoresMalformedEntries()
    {
        const auto selection = CalendarSelection::fromEntries(QStringList{
            u""_s, u"c"_s, u"cabc"_s, u"x-1"_s, u"rnoslash"_s, u"c7"_s,
        });

        QVERIFY(selection.isSelected(7, u"r"_s, u"x"_s));
        QVERIFY(!selection.isSelected(-1, u"noslash"_s, QString()));
        QVERIFY(!selection.isSelected(1, u"r"_s, u"x"_s));
    }
};

QTEST_GUILESS_MAIN(TestSelection)
#include "test_selection.moc"
