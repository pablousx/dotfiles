import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
    id: root
    moduleName: "io.github.pablousx.omasync"
    // Install writes a local JSON string here, never a shell expression.
    property string repository: ""
    property string launcherError: ""
    property string activeAction: ""
    property var snapshot: ({status: "syncing"})
    readonly property string repo: String(setting("repository", repository))
    readonly property bool busy: worker.running || snapshot.status === "syncing"
    readonly property int intervalSeconds: Math.max(30, Math.min(86400, Number(root.setting("intervalSeconds", 300)) || 300))
    readonly property bool autoDownload: root.setting("autoDownload", false) === true
    readonly property bool canConfigure: !!(bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
    readonly property string label: ({updated: "Actualizado", local: "Cambios locales",
        remote: "Cambios remotos", syncing: "Sincronizando", error: "Error"})[snapshot.status] || "Error"
    readonly property bool opened: popup.item ? popup.item.opened : false
    readonly property bool popoutSwitchClosing: popup.item ? popup.item.popoutSwitchClosing : false
    function open() { if (popup.item) popup.item.open() }
    function close() { if (popup.item) popup.item.close() }
    function closeForPopoutSwitch() { if (popup.item) popup.item.closeForPopoutSwitch() }
    function toggle() { if (popup.item) popup.item.toggle() }
    function injectPanel() {
        if (!popup.item) return
        popup.item.bar = root.bar
        popup.item.anchorItem = button
        popup.item.hostWidget = root
    }
    function argv(action) {
        return ["python3", repo + "/omasync/sync.py", "--repo", repo, action]
    }
    function run(action) {
        if (worker.running || repo === "") return
        launcherError = ""
        activeAction = action
        worker.command = argv(action)
        worker.running = true
    }
    function configure(name, value) {
        if (!canConfigure) return
        var entry = {id: moduleName}
        for (var key in settings) if (key !== "id") entry[key] = settings[key]
        entry[name] = value
        // Persist through the official host API, preserving all other values.
        bar.shell.updateEntryInline(moduleName, entry)
        settings = entry
    }
    function check() {
        if (worker.running || repo === "") return
        var command = argv("tick")
        if (autoDownload) command.push("--auto-download")
        activeAction = "tick"
        worker.command = command
        worker.running = true
    }
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onBarChanged: injectPanel()
    Component.onCompleted: Qt.callLater(check)
    onRepoChanged: Qt.callLater(check)

    Timer {
        // Configurable interval, bounded to avoid tight loops or overflow.
        interval: root.intervalSeconds * 1000
        running: true
        repeat: true
        onTriggered: root.check()
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!reader.running && root.repo !== "") {
                reader.command = root.argv("status")
                reader.running = true
            }
        }
    }
    Process {
        id: worker
        // Discard output from explicit actions; the status reader owns JSON.
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(code) {
            if (code !== 0 && root.activeAction === "resolve")
                root.launcherError = "No se pudo abrir la AI predeterminada. Revisa Omarchy y reintenta."
        }
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var state = JSON.parse(text)
                    if (root.launcherError !== "") {
                        state.status = "error"
                        state.error = root.launcherError
                    }
                    root.snapshot = state
                }
                catch (error) { root.snapshot = {status: "error", error: "No se pudo leer el repositorio."} }
            }
        }
        stderr: StdioCollector {}
    }
    Loader {
        id: popup
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
    }
    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.busy ? "󰑓" : ({updated: "󰄬", local: "󰜷", remote: "󰜮", error: "󰅚"})[root.snapshot.status] || "󰅚"
        tooltipText: "omasync · " + (root.busy ? "Sincronizando" : root.label)
        onPressed: function(code) { if (code === Qt.LeftButton) root.toggle() }
    }
}
