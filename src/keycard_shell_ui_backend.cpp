#include "keycard_shell_ui_backend.h"

#include <QJsonArray>
#include <QJsonDocument>

// The generated umbrella carrying `struct LogosModules`.
#include "logos_sdk.h"

namespace {

QJsonObject parseObject(const QString &reply)
{
    return QJsonDocument::fromJson(reply.toUtf8()).object();
}

QString compact(const QJsonValue &v)
{
    if (v.isArray())
        return QString::fromUtf8(QJsonDocument(v.toArray()).toJson(QJsonDocument::Compact));
    if (v.isObject())
        return QString::fromUtf8(QJsonDocument(v.toObject()).toJson(QJsonDocument::Compact));
    return {};
}

} // namespace

bool KeycardShellUiBackend::ok(const QJsonObject &reply, const QString &context)
{
    if (reply.value(QStringLiteral("ok")).toBool())
        return true;
    QString e = reply.value(QStringLiteral("error")).toString();
    if (e.isEmpty())
        e = QStringLiteral("the Keycard Shell module didn't answer");
    setLastError(QStringLiteral("%1: %2").arg(context, e));
    return false;
}

void KeycardShellUiBackend::onContextReady()
{
    // A Shell plugged in or out, or the accounts changed: read them again, off the IPC stack.
    modules().keycard_shell_module.onSigner_accounts_changed([this](auto) {
        QTimer::singleShot(0, this, [this] { refresh(); });
    });
    modules().keycard_shell_module.onSigner_changed([this](auto) {
        QTimer::singleShot(0, this, [this] { refresh(); });
    });
    m_poll.setInterval(500);
    QObject::connect(&m_poll, &QTimer::timeout, this, [this] { poll(); });
    refresh();
}

void KeycardShellUiBackend::refresh()
{
    const QJsonObject devices = parseObject(modules().keycard_shell_module.devices());
    const QJsonArray connected = devices.value(QStringLiteral("devices")).toArray();
    setDevicesJson(ok(devices, QStringLiteral("Shells")) ? compact(connected) : QStringLiteral("[]"));
    const QJsonObject accounts = parseObject(modules().keycard_shell_module.signer_accounts());
    setAccountsJson(ok(accounts, QStringLiteral("accounts"))
                        ? compact(accounts.value(QStringLiteral("accounts")))
                        : QStringLiteral("[]"));
    setStatusText(connected.isEmpty() ? QStringLiteral("No Keycard Shell connected")
                                      : QStringLiteral("Connected"));
}

bool KeycardShellUiBackend::offer(QString familiesJson, QString chain, int account, QString label)
{
    setLastError(QString());
    QJsonObject p;
    p.insert(QStringLiteral("families"), QJsonDocument::fromJson(familiesJson.toUtf8()).array());
    p.insert(QStringLiteral("chain"), chain);
    p.insert(QStringLiteral("account"), account);
    if (!label.trimmed().isEmpty())
        p.insert(QStringLiteral("label"), label.trimmed());
    const QJsonObject reply = parseObject(modules().keycard_shell_module.add_accounts(
        QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact))));
    if (!ok(reply, QStringLiteral("offer")))
        return false;
    m_job = reply.value(QStringLiteral("job")).toString();
    setExportJson(QStringLiteral("{\"state\":\"confirm_on_device\"}"));
    m_poll.start();
    return true;
}

void KeycardShellUiBackend::poll()
{
    if (m_job.isEmpty()) {
        m_poll.stop();
        return;
    }
    QJsonObject reply = parseObject(modules().keycard_shell_module.add_status(m_job));
    if (!ok(reply, QStringLiteral("offer"))) {
        m_poll.stop();
        return;
    }
    const QString state = reply.value(QStringLiteral("state")).toString();
    reply.remove(QStringLiteral("ok"));
    reply.remove(QStringLiteral("job"));
    setExportJson(compact(reply));
    if (state == QLatin1String("done") || state == QLatin1String("failed")) {
        m_poll.stop();
        m_job.clear();
        refresh();
    }
}

bool KeycardShellUiBackend::removeAccount(QString id)
{
    setLastError(QString());
    const bool removed = ok(parseObject(modules().keycard_shell_module.remove_account(id)),
                            QStringLiteral("remove"));
    refresh();
    return removed;
}
