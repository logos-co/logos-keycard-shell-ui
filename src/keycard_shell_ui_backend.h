#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QTimer>

#include "rep_keycard_shell_ui_source.h"
#include "logos_ui_plugin_context.h"

// The Keycard Shell's app backend: every call to keycard_shell_module is made here, over the
// generated typed client. An export waits for the person on the Shell, so it is polled.
class KeycardShellUiBackend : public KeycardShellUiSimpleSource,
                              public LogosUiPluginContext
{
public:
    void refresh() override;
    bool offer(QString familiesJson, QString chain, int account, QString label) override;
    bool removeAccount(QString id) override;

protected:
    void onContextReady() override;

private:
    /// Surface the module's refusal and report whether the call succeeded.
    bool ok(const QJsonObject &reply, const QString &context);
    void poll();

    QString m_job;
    QTimer m_poll;
};
