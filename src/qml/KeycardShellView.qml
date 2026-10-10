import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// The Keycard Shell's app: which Shells are connected, which of their accounts Logos apps may
// use, and offering more. A .rep SLOT answers a pending reply, so calls go through logos.watch.
Item {
    id: root
    objectName: "keycardShellRoot"
    anchors.fill: parent

    Rectangle { anchors.fill: parent; color: Theme.palette.background }

    readonly property var backend: logos.module("keycard_shell_ui")

    // Writable, fed by the signal: a binding with a function call would latch false at creation.
    property bool ready: false
    Connections {
        target: logos
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName === "keycard_shell_ui") root.ready = isReady && root.backend !== null
        }
    }

    function j(t, fb) { try { return JSON.parse(t && t.length ? t : fb) } catch (e) { return JSON.parse(fb) } }
    readonly property var devices: ready ? j(backend.devicesJson, "[]") : []
    readonly property var accounts: ready ? j(backend.accountsJson, "[]") : []
    readonly property var exporting: ready ? j(backend.exportJson, "{}") : ({})
    readonly property bool waiting: exporting.state === "confirm_on_device"

    function familyWords(f) {
        return f === "evm" ? "EVM" : f === "bitcoin" ? "native segwit" : "taproot"
    }

    function exportLine() {
        if (root.waiting) return "Confirm on the Shell: it asks before each key leaves it."
        if (root.exporting.state === "done") {
            var n = (root.exporting.accounts || []).length
            return "Offered " + n + (n === 1 ? " account." : " accounts.")
        }
        if (root.exporting.state === "failed") return "Not offered: " + (root.exporting.error || "")
        return ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.medium
        spacing: Theme.spacing.small

        LogosText { text: "Keycard Shell"; font.pixelSize: 22 }

        LogosText {
            objectName: "shellNote"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Its keys stay on the card inside the Shell. Logos apps see only the accounts "
                  + "offered here, and every request is shown and confirmed on the Shell itself."
        }

        // ── the Shells connected ─────────────────────────────────────────────────
        LogosText { text: "Connected"; font.bold: true }
        LogosText {
            objectName: "noShell"
            visible: root.ready && root.devices.length === 0
            color: Theme.palette.textSecondary
            text: "No Keycard Shell connected. Plug it in and unlock it."
        }
        Repeater {
            model: root.devices
            delegate: LogosText {
                objectName: "shellLine_" + index
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: "Keycard Shell" + (modelData.firmware ? ", firmware " + modelData.firmware : "")
                      + (modelData.busy ? ", busy" : "") + " (" + modelData.serial + ")"
            }
        }

        // ── offering accounts ────────────────────────────────────────────────────
        LogosText { text: "Offer accounts"; font.bold: true }
        RowLayout {
            spacing: Theme.spacing.small
            LogosCheckbox { id: evmBox; objectName: "offerEvm"; text: "EVM"; checked: true }
            LogosCheckbox { id: segwitBox; objectName: "offerSegwit"; text: "Bitcoin, native segwit" }
            LogosCheckbox { id: taprootBox; objectName: "offerTaproot"; text: "Bitcoin, taproot" }
        }
        RowLayout {
            spacing: Theme.spacing.small
            ButtonGroup { id: chainGroup }
            LogosRadioButton { id: mainChain; objectName: "chainMain"; ButtonGroup.group: chainGroup; text: "Bitcoin" }
            LogosRadioButton { objectName: "chainTest"; ButtonGroup.group: chainGroup; text: "Test networks"; checked: true }
        }
        RowLayout {
            spacing: Theme.spacing.small
            LogosText { text: "Account" }
            LogosTextField {
                id: accountField
                objectName: "offerAccount"
                Layout.preferredWidth: 80
                text: "0"
                validator: IntValidator { bottom: 0; top: 2147483647 }
            }
            LogosTextField {
                id: labelField
                objectName: "offerLabel"
                Layout.fillWidth: true
                placeholderText: "Name (optional)"
            }
        }
        LogosText {
            objectName: "offerNote"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "The Shell asks before each key leaves it: once for an EVM account, twice for a "
                  + "Bitcoin one, whose xpub carries its parent's fingerprint. Only public keys are kept."
        }
        LogosButton {
            objectName: "offerButton"
            text: "Offer"
            enabled: root.ready && root.devices.length > 0 && !root.waiting
                     && (evmBox.checked || segwitBox.checked || taprootBox.checked)
            onClicked: {
                var families = []
                if (evmBox.checked) families.push("evm")
                if (segwitBox.checked) families.push("bitcoin")
                if (taprootBox.checked) families.push("bitcoin_taproot")
                logos.watch(root.backend.offer(JSON.stringify(families), mainChain.checked ? "main" : "test",
                                               parseInt(accountField.text || "0"), labelField.text),
                            function (started) {})
            }
        }
        LogosText {
            objectName: "exportLine"
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: root.exporting.state === "failed" ? Theme.palette.error : Theme.palette.text
            text: root.exportLine()
        }

        // ── the accounts offered ─────────────────────────────────────────────────
        LogosText { text: "Offered to apps"; font.bold: true }
        LogosText {
            objectName: "noAccounts"
            visible: root.ready && root.accounts.length === 0
            color: Theme.palette.textSecondary
            text: "No account offered yet."
        }
        Repeater {
            id: accountRepeater
            objectName: "accountRepeater"
            model: root.accounts
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.small
                LogosText {
                    objectName: "accountLine_" + index
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: (modelData.label || root.familyWords(modelData.family)) + " — "
                          + (modelData.address || modelData.path || modelData.id)
                          + (modelData.available ? "" : ", not connected")
                }
                LogosButton {
                    objectName: "removeAccount_" + index
                    text: "Remove"
                    onClicked: logos.watch(root.backend.removeAccount(modelData.id), function (gone) {})
                }
            }
        }

        LogosText {
            objectName: "lastError"
            Layout.fillWidth: true
            visible: root.ready && root.backend.lastError !== ""
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: Theme.palette.error
            text: root.ready ? root.backend.lastError : ""
        }

        Item { Layout.fillHeight: true }
    }
}
