#pragma once

#include "occurrences.h"
#include "protocol.h"
#include "selection.h"

#include <Akonadi/Collection>
#include <Akonadi/FetchJobCalendar>

#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QTimer>

#include <vector>

namespace Akonadi {
class Monitor;
}

namespace corium::calendar {

// Loads every event from Akonadi (the store behind KOrganizer) and reloads
// whenever an event, a calendar or KOrganizer's calendar selection changes.
class AkonadiSource : public QObject
{
    Q_OBJECT

public:
    explicit AkonadiSource(QObject *parent = nullptr);

    // Starts the first load. `ready` or `failed` follows.
    void start();

    [[nodiscard]] bool isReady() const { return m_ready; }

    // Occurrences in [from, to] from the calendars ticked in KOrganizer.
    [[nodiscard]] std::vector<Occurrence> occurrences(QDate from, QDate to) const;

    // The calendars the given occurrences come from.
    [[nodiscard]] std::vector<CalendarInfo> calendarsFor(const std::vector<Occurrence> &occurrences) const;

Q_SIGNALS:
    void ready();
    void changed();
    void failed(const QString &message);

private:
    void reload();
    void fetchCollections();
    void fetchEvents();
    void loadSelection();
    void watchConfig();

    Akonadi::Monitor *m_monitor = nullptr;
    QTimer m_reloadTimer;
    QFileSystemWatcher m_configWatcher;

    bool m_ready = false;
    bool m_loading = false;
    bool m_reloadQueued = false;

    // The calendar being loaded, swapped in once it's complete.
    Akonadi::FetchJobCalendar::Ptr m_pending;
    Akonadi::FetchJobCalendar::Ptr m_calendar;
    QHash<Akonadi::Collection::Id, Akonadi::Collection> m_pendingCollections;
    QHash<Akonadi::Collection::Id, Akonadi::Collection> m_collections;
    CalendarSelection m_selection;
};

} // namespace corium::calendar
