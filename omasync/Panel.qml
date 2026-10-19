pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as UI

UI.Panel {
    id: root
    moduleName: "io.github.pablousx.omasync"
    manageIpc: false
    property Item anchorItem: null
    property Item hostWidget: null
    readonly property var themeFont: Style.font
    property int tab: 0
    readonly property var snapshot: hostWidget ? hostWidget.snapshot : ({})
    readonly property bool busy: hostWidget ? hostWidget.busy : true
    readonly property bool hasError: snapshot.status === "error"
    readonly property string stateLabel: busy && hostWidget ? hostWidget.busyLabel : hostWidget ? hostWidget.label : "Connecting…"
    readonly property string aiLabel: ({applied: "Applied", disabled: "Not enabled on this machine",
        pending: "Pending application", failed: "Could not apply", unknown: "Not checked"})[snapshot.ai] || "Not checked"
    readonly property string errorText: {
        if (snapshot.repo_updated && (snapshot.ai === "failed" || snapshot.ai === "pending"))
            return "Repository updated; AI configuration could not be applied. Download retries Rulesync."
        if (snapshot.error) return snapshot.error
        if (snapshot.in_progress) return "A Git operation is in progress. Review it before syncing."
        if (!busy && snapshot.upstream === false) return "A branch with an upstream is required."
        return ""
    }
    function switchPanel(direction) {
        return bar && typeof bar.switchPanelFrom === "function"
            ? bar.switchPanelFrom(hostWidget || root, direction) : false
    }
    UI.KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keys
        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)
        UI.PanelKeyCatcher {
            id: keys
            anchors.fill: parent
            blocked: true
            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_1 || event.key === Qt.Key_2)) {
                    root.tab = event.key - Qt.Key_1
                    event.accepted = true
                }
            }
            ColumnLayout {
                id: content
                width: parent.width
                spacing: Style.space(12)
                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)
                    UiText {
                        id: heroIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰑓"
                        font.pixelSize: root.themeFont.display
                    }
                    Column {
                        id: heroLabels
                        anchors.left: heroIcon.right
                        anchors.leftMargin: Style.space(14)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)
                        UiText { width: parent.width; text: "omasync"; font.pixelSize: root.themeFont.title; font.bold: true }
                        UiText {
                            width: parent.width
                            text: root.stateLabel.toUpperCase()
                            font.pixelSize: root.themeFont.caption
                            font.bold: true
                            font.letterSpacing: 1.2
                            secondary: true
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }
                }
                UI.PanelSeparator { Layout.fillWidth: true; foreground: Color.foreground }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    Repeater {
                        id: navigation
                        model: ["Sync", "Settings"]
                        UiAction {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            primary: root.tab === index
                            tooltipText: "Ctrl+" + (index + 1)
                            onClicked: root.tab = index
                            Keys.onLeftPressed: { root.tab = 1 - index; navigation.itemAt(root.tab).forceActiveFocus() }
                            Keys.onRightPressed: { root.tab = 1 - index; navigation.itemAt(root.tab).forceActiveFocus() }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tab === 0
                    spacing: Style.space(12)
                    RowLayout {
                        Layout.fillWidth: true
                        UiText { Layout.fillWidth: true; text: "Repository"; section: true }
                        UiAction {
                            text: "Check"
                            enabled: root.hostWidget && !root.busy
                            onClicked: root.hostWidget.check()
                        }
                    }
                    UiText {
                        Layout.fillWidth: true
                        text: root.hostWidget ? root.hostWidget.repo : ""
                        secondary: true
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                    UiText {
                        Layout.fillWidth: true
                        text: root.busy && root.hostWidget ? root.hostWidget.busyLabel : root.snapshot.dirty ? "Uncommitted changes" : "Working tree clean"
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        UiText { Layout.fillWidth: true; text: "To upload: " + (root.snapshot.ahead === undefined ? "…" : root.snapshot.ahead); secondary: true }
                        UiText { text: "To download: " + (root.snapshot.behind === undefined ? "…" : root.snapshot.behind); secondary: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(4)
                        UiAction {
                            Layout.fillWidth: true
                            text: "Upload"
                            primary: true
                            tooltipText: "Create a commit with a UTC timestamp and upload changes"
                            enabled: root.hostWidget && !root.busy
                            onClicked: root.hostWidget.run("upload")
                        }
                        UiAction {
                            Layout.fillWidth: true
                            text: "Download"
                            enabled: root.hostWidget && !root.busy
                            onClicked: root.hostWidget.run("download")
                        }
                    }
                    UI.PanelSeparator { Layout.fillWidth: true; foreground: Color.foreground }
                    UiText { text: "AI configuration"; section: true }
                    UiText { Layout.fillWidth: true; text: root.aiLabel }
                    UiText { Layout.fillWidth: true; text: "Uploads only run when you click Upload."; secondary: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tab === 1
                    spacing: Style.space(12)
                    UiText { text: "Periodic checks"; section: true }
                    UiText {
                        Layout.fillWidth: true
                        text: "Every " + (root.hostWidget ? root.hostWidget.intervalSeconds : 300) + " seconds"
                        secondary: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(4)
                        Repeater {
                            model: [60, 300, 900]
                            UiAction {
                                required property int modelData
                                Layout.fillWidth: true
                                text: (modelData / 60) + " min"
                                primary: root.hostWidget && root.hostWidget.intervalSeconds === modelData
                                enabled: root.hostWidget && root.hostWidget.canConfigure
                                onClicked: root.hostWidget.configure("intervalSeconds", modelData)
                            }
                        }
                    }
                    UI.PanelSeparator { Layout.fillWidth: true; foreground: Color.foreground }
                    RowLayout {
                        Layout.fillWidth: true
                        UiText { Layout.fillWidth: true; text: "Automatic download"; section: true }
                        UiAction {
                            text: root.hostWidget && root.hostWidget.autoDownload ? "Enabled" : "Disabled"
                            primary: root.hostWidget && root.hostWidget.autoDownload
                            enabled: root.hostWidget && root.hostWidget.canConfigure
                            onClicked: root.hostWidget.configure("autoDownload", !root.hostWidget.autoDownload)
                        }
                    }
                    UiText {
                        Layout.fillWidth: true
                        text: "Requires a clean checkout, an upstream and a fast-forward update. Uploads are always manual."
                        secondary: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.errorText !== ""
                    spacing: Style.space(8)
                    UI.PanelSeparator { Layout.fillWidth: true; foreground: Color.foreground }
                    UiText { text: "Needs attention"; section: true }
                    UiText { Layout.fillWidth: true; text: root.errorText }
                    UiAction {
                        text: "Resolve with AI"
                        visible: root.hasError
                        enabled: root.hostWidget && !root.busy
                        onClicked: root.hostWidget.run("resolve")
                    }
                }
            }
        }
    }
}
