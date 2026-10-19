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
    readonly property string stateLabel: busy && hostWidget ? hostWidget.busyLabel : hostWidget ? hostWidget.label : "Conectando…"
    readonly property string aiLabel: ({applied: "Aplicada", disabled: "No activada en este equipo",
        pending: "Pendiente de aplicar", failed: "No se pudo aplicar", unknown: "Sin comprobar"})[snapshot.ai] || "Sin comprobar"
    readonly property string errorText: {
        if (snapshot.repo_updated && (snapshot.ai === "failed" || snapshot.ai === "pending"))
            return "Repositorio actualizado; la configuración AI no pudo aplicarse. Descargar reintenta Rulesync."
        if (snapshot.error) return snapshot.error
        if (snapshot.in_progress) return "Hay una operación de Git en curso. Revísala antes de sincronizar."
        if (!busy && snapshot.upstream === false) return "Se requiere una rama con upstream."
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
                        model: ["Sincronización", "Ajustes"]
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
                        UiText { Layout.fillWidth: true; text: "Repositorio"; section: true }
                        UiAction {
                            text: "Comprobar"
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
                        text: root.busy && root.hostWidget ? root.hostWidget.busyLabel : root.snapshot.dirty ? "Cambios locales sin guardar" : "Directorio de trabajo limpio"
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        UiText { Layout.fillWidth: true; text: "Por subir: " + (root.snapshot.ahead === undefined ? "…" : root.snapshot.ahead); secondary: true }
                        UiText { text: "Por descargar: " + (root.snapshot.behind === undefined ? "…" : root.snapshot.behind); secondary: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(4)
                        UiAction {
                            Layout.fillWidth: true
                            text: "Subir"
                            primary: true
                            tooltipText: "Crear un commit con timestamp UTC y subir los cambios"
                            enabled: root.hostWidget && !root.busy
                            onClicked: root.hostWidget.run("upload")
                        }
                        UiAction {
                            Layout.fillWidth: true
                            text: "Descargar"
                            enabled: root.hostWidget && !root.busy
                            onClicked: root.hostWidget.run("download")
                        }
                    }
                    UI.PanelSeparator { Layout.fillWidth: true; foreground: Color.foreground }
                    UiText { text: "Configuración AI"; section: true }
                    UiText { Layout.fillWidth: true; text: root.aiLabel }
                    UiText { Layout.fillWidth: true; text: "Las subidas se realizan solo al pulsar Subir."; secondary: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tab === 1
                    spacing: Style.space(12)
                    UiText { text: "Comprobación periódica"; section: true }
                    UiText {
                        Layout.fillWidth: true
                        text: "Cada " + (root.hostWidget ? root.hostWidget.intervalSeconds : 300) + " segundos"
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
                        UiText { Layout.fillWidth: true; text: "Descarga automática"; section: true }
                        UiAction {
                            text: root.hostWidget && root.hostWidget.autoDownload ? "Activada" : "Desactivada"
                            primary: root.hostWidget && root.hostWidget.autoDownload
                            enabled: root.hostWidget && root.hostWidget.canConfigure
                            onClicked: root.hostWidget.configure("autoDownload", !root.hostWidget.autoDownload)
                        }
                    }
                    UiText {
                        Layout.fillWidth: true
                        text: "Solo con el checkout limpio, upstream y avance fast-forward. Las subidas siempre son manuales."
                        secondary: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.errorText !== ""
                    spacing: Style.space(8)
                    UI.PanelSeparator { Layout.fillWidth: true; foreground: Color.foreground }
                    UiText { text: "Requiere atención"; section: true }
                    UiText { Layout.fillWidth: true; text: root.errorText }
                    UiAction {
                        text: "Resolver con AI"
                        visible: root.hasError
                        enabled: root.hostWidget && !root.busy
                        onClicked: root.hostWidget.run("resolve")
                    }
                }
            }
        }
    }
}
