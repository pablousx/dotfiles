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
    property bool refreshPending: false
    property var snapshot: ({status: "unknown"})
    readonly property string repo: String(setting("repository", repository))
    readonly property bool busy: worker.running || snapshot.status === "syncing"
    readonly property bool checking: busy && (snapshot.status === "syncing"
        ? snapshot.busy_operation === "check"
        : worker.running && (activeAction === "tick" || activeAction === "check"))
    readonly property string busyLabel: {
        var action = snapshot.status === "syncing" && snapshot.busy_operation
            ? snapshot.busy_operation : worker.running ? activeAction : ""
        return ({tick: "Comprobando remotos…", check: "Comprobando remotos…",
            up: "Subiendo…", upload: "Subiendo…", down: "Descargando…",
            download: "Descargando…", "auto-down": "Descargando…",
            resolve: "Abriendo AI…"})[action] || "Sincronizando…"
    }
    readonly property int intervalSeconds: Math.max(30, Math.min(86400, Number(root.setting("intervalSeconds", 300)) || 300))
    readonly property bool autoDownload: root.setting("autoDownload", false) === true
    readonly property bool canConfigure: !!(bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
    readonly property string label: ({updated: "Actualizado", local: "Cambios locales",
        remote: "Cambios remotos", syncing: "Sincronizando", error: "Error", unknown: "Sin comprobar"})[snapshot.status] || "Error"
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
    function acceptSnapshot(state) {
        // A writer holding the lock cannot provide fresh Git counts. Keep the
        // previous values until the next full snapshot instead of showing zero.
        var merged = {}
        for (var key in snapshot) merged[key] = snapshot[key]
        for (var name in state) merged[name] = state[name]
        if (state.status !== "syncing") delete merged.busy_operation
        if (launcherError !== "") {
            merged.status = "error"
            merged.error = launcherError
        }
        snapshot = merged
    }
    function readStatus() {
        if (repo === "") return
        if (reader.running) {
            refreshPending = true
            return
        }
        refreshPending = false
        reader.command = argv("status")
        reader.running = true
    }
    function finishStatus(code, text) {
        try {
            if (code !== 0) throw new Error("status failed")
            var state = JSON.parse(text)
            if (!state || ["updated", "local", "remote", "syncing", "error"].indexOf(state.status) < 0)
                throw new Error("invalid status")
            acceptSnapshot(state)
        }
        catch (error) {
            acceptSnapshot({status: "error", error: "No se pudo leer el repositorio. Reintenta la comprobación."})
        }
        if (refreshPending) Qt.callLater(readStatus)
    }
    function localDiagnostics() {
        return {busy: busy, checking: checking, workerRunning: worker.running,
            readerRunning: reader.running, status: snapshot.status, activeAction: activeAction}
    }
    IpcHandler {
        target: "io.github.pablousx.omasync"
        function diagnostics(): string {
            var items = root.bar && typeof root.bar.moduleWidgets === "function"
                ? root.bar.moduleWidgets(root.moduleName) : [root]
            return JSON.stringify(items.map(function(item) { return item.localDiagnostics() }))
        }
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
        onTriggered: root.readStatus()
    }
    Process {
        id: worker
        // Discard output from explicit actions; the status reader owns JSON.
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(code) {
            if (code !== 0 && root.activeAction === "resolve")
                root.launcherError = "No se pudo abrir la AI predeterminada. Revisa Omarchy y reintenta."
            root.activeAction = ""
            Qt.callLater(root.readStatus)
        }
    }
    Process {
        id: reader
        stdout: StdioCollector { id: readerOutput }
        stderr: StdioCollector {}
        onExited: function(code) {
            root.finishStatus(code, readerOutput.text)
        }
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
        tooltipText: "omasync · " + (root.busy ? root.busyLabel : root.label)
        onPressed: function(code) { if (code === Qt.LeftButton) root.toggle() }
    }
}
