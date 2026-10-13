#include "selection.h"

namespace corium::calendar {

namespace {

QString remoteKey(const QString &resource, const QString &remoteId)
{
    return resource + u'/' + remoteId;
}

} // namespace

CalendarSelection CalendarSelection::fromEntries(const std::optional<QStringList> &entries)
{
    CalendarSelection selection;
    if (!entries)
        return selection;

    selection.m_selectsAll = false;
    for (const QString &entry : *entries) {
        if (entry.size() < 2)
            continue;

        const QString value = entry.mid(1);
        if (entry.startsWith(u'c')) {
            bool ok = false;
            const qint64 id = value.toLongLong(&ok);
            if (ok)
                selection.m_ids.insert(id);
        } else if (entry.startsWith(u'r') && value.contains(u'/')) {
            selection.m_remoteKeys.insert(value);
        }
    }
    return selection;
}

bool CalendarSelection::isSelected(qint64 collectionId, const QString &resource, const QString &remoteId) const
{
    return m_selectsAll
        || m_ids.contains(collectionId)
        || m_remoteKeys.contains(remoteKey(resource, remoteId));
}

} // namespace corium::calendar
