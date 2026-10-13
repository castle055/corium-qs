#include "akonadisource.h"

#include <Akonadi/AttributeFactory>
#include <Akonadi/CollectionColorAttribute>
#include <Akonadi/CollectionFetchJob>
#include <Akonadi/CollectionFetchScope>
#include <Akonadi/Monitor>

#include <KCalendarCore/Event>

#include <KConfig>
#include <KConfigGroup>

#include <QStandardPaths>

#include <algorithm>

namespace corium::calendar {

namespace {

// Wait for a burst of changes (e.g. a sync) to settle before reloading.
constexpr int reloadDelayMs = 500;

QString korganizerConfigPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/korganizerrc");
}

} // namespace

AkonadiSource::AkonadiSource(QObject *parent)
    : QObject(parent)
{
    // Without this the colour attribute arrives as an opaque blob.
    Akonadi::AttributeFactory::registerAttribute<Akonadi::CollectionColorAttribute>();

    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(reloadDelayMs);
    connect(&m_reloadTimer, &QTimer::timeout, this, &AkonadiSource::reload);

    connect(&m_configWatcher, &QFileSystemWatcher::fileChanged, this, [this] {
        // KConfig saves by replacing the file, which drops it from the watcher.
        watchConfig();
        loadSelection();
        if (m_ready)
            Q_EMIT changed();
    });
}

void AkonadiSource::start()
{
    m_monitor = new Akonadi::Monitor(this);
    m_monitor->setMimeTypeMonitored(KCalendarCore::Event::eventMimeType());
    m_monitor->setCollectionMonitored(Akonadi::Collection::root());

    const auto scheduleReload = [this] { m_reloadTimer.start(); };
    connect(m_monitor, &Akonadi::Monitor::itemAdded, this, scheduleReload);
    connect(m_monitor, &Akonadi::Monitor::itemChanged, this, scheduleReload);
    connect(m_monitor, &Akonadi::Monitor::itemsRemoved, this, scheduleReload);
    connect(m_monitor, &Akonadi::Monitor::itemsMoved, this, scheduleReload);
    connect(m_monitor, &Akonadi::Monitor::collectionAdded, this, scheduleReload);
    connect(m_monitor, qOverload<const Akonadi::Collection &>(&Akonadi::Monitor::collectionChanged), this, scheduleReload);
    connect(m_monitor, &Akonadi::Monitor::collectionRemoved, this, scheduleReload);

    watchConfig();
    loadSelection();
    reload();
}

void AkonadiSource::watchConfig()
{
    const QString path = korganizerConfigPath();
    if (!m_configWatcher.files().contains(path))
        m_configWatcher.addPath(path);
}

void AkonadiSource::loadSelection()
{
    const KConfig config(korganizerConfigPath(), KConfig::SimpleConfig);
    const KConfigGroup group = config.group(QStringLiteral("GlobalCollectionSelection"));

    std::optional<QStringList> entries;
    if (group.hasKey("Selection"))
        entries = group.readEntry("Selection", QStringList());
    m_selection = CalendarSelection::fromEntries(entries);
}

void AkonadiSource::reload()
{
    if (m_loading) {
        m_reloadQueued = true;
        return;
    }
    m_loading = true;
    m_reloadQueued = false;
    fetchCollections();
}

void AkonadiSource::fetchCollections()
{
    auto *job = new Akonadi::CollectionFetchJob(Akonadi::Collection::root(), Akonadi::CollectionFetchJob::Recursive, this);
    job->fetchScope().setContentMimeTypes({KCalendarCore::Event::eventMimeType()});
    job->fetchScope().setListFilter(Akonadi::CollectionFetchScope::NoFilter);

    connect(job, &KJob::result, this, [this, job] {
        if (job->error()) {
            m_loading = false;
            Q_EMIT failed(job->errorString());
            return;
        }

        m_pendingCollections.clear();
        for (const Akonadi::Collection &collection : job->collections())
            m_pendingCollections.insert(collection.id(), collection);
        fetchEvents();
    });
}

void AkonadiSource::fetchEvents()
{
    m_pending.reset(new Akonadi::FetchJobCalendar());

    connect(m_pending.data(), &Akonadi::FetchJobCalendar::loadFinished, this, [this](bool success, const QString &error) {
        m_loading = false;

        if (!success) {
            m_pending.reset();
            Q_EMIT failed(error);
        } else {
            m_calendar = std::exchange(m_pending, {});
            m_collections = std::exchange(m_pendingCollections, {});

            if (!m_ready) {
                m_ready = true;
                Q_EMIT ready();
            } else {
                Q_EMIT changed();
            }
        }

        if (m_reloadQueued)
            reload();
    });
}

std::vector<Occurrence> AkonadiSource::occurrences(QDate from, QDate to) const
{
    if (!m_calendar)
        return {};

    auto result = occurrencesInRange(*m_calendar, from, to, QTimeZone::systemTimeZone());

    for (Occurrence &occurrence : result) {
        const Akonadi::Item item = m_calendar->item(occurrence.incidence);
        occurrence.calendarId = item.parentCollection().isValid() ? item.parentCollection().id() : item.storageCollectionId();
    }

    std::erase_if(result, [this](const Occurrence &occurrence) {
        const auto it = m_collections.constFind(occurrence.calendarId);
        if (it == m_collections.cend())
            return false; // Unknown calendar: show it rather than lose events.
        return !m_selection.isSelected(it->id(), it->resource(), it->remoteId());
    });

    return result;
}

std::vector<CalendarInfo> AkonadiSource::calendarsFor(const std::vector<Occurrence> &occurrences) const
{
    std::vector<CalendarInfo> result;
    for (const Occurrence &occurrence : occurrences) {
        if (std::ranges::contains(result, occurrence.calendarId, &CalendarInfo::id))
            continue;

        CalendarInfo info;
        info.id = occurrence.calendarId;
        if (const auto it = m_collections.constFind(occurrence.calendarId); it != m_collections.cend()) {
            info.name = it->displayName();
            if (const auto *color = it->attribute<Akonadi::CollectionColorAttribute>())
                info.color = color->color();
        }
        result.push_back(std::move(info));
    }
    return result;
}

} // namespace corium::calendar
