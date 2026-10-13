#pragma once

#include <QSet>
#include <QString>
#include <QStringList>

#include <optional>

namespace corium::calendar {

// Which calendars are ticked in KOrganizer's calendar list.
//
// KOrganizer keeps this in korganizerrc, [GlobalCollectionSelection] Selection=,
// as a list of collections in the format Akonadi's view state savers use:
// "c<collection id>" or "r<resource identifier>/<collection remote id>".
class CalendarSelection
{
public:
    // Selects every calendar.
    CalendarSelection() = default;

    // `entries` is the Selection= list, or nullopt if KOrganizer never saved one,
    // in which case every calendar is selected.
    static CalendarSelection fromEntries(const std::optional<QStringList> &entries);

    [[nodiscard]] bool isSelected(qint64 collectionId, const QString &resource, const QString &remoteId) const;

private:
    bool m_selectsAll = true;
    QSet<qint64> m_ids;
    QSet<QString> m_remoteKeys;
};

} // namespace corium::calendar
