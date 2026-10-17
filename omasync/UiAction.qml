import QtQuick
import QtQuick.Controls as QQC
import qs.Commons

// Compact theme-aware buttons following omadocs' panel conventions.
QQC.Button {
    id: root
    readonly property var themeFont: Style.font
    property bool primary: false
    property string tooltipText: ""
    implicitWidth: Math.max(Style.space(64), label.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Style.space(32), label.implicitHeight + topPadding + bottomPadding)
    leftPadding: Style.space(10)
    rightPadding: Style.space(10)
    topPadding: Style.space(7)
    bottomPadding: Style.space(7)
    activeFocusOnTab: true
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    QQC.ToolTip.visible: hovered && tooltipText !== ""
    QQC.ToolTip.text: tooltipText
    QQC.ToolTip.delay: 700
    contentItem: Text {
        id: label
        text: root.text
        textFormat: Text.PlainText
        color: Color.foreground
        font.family: root.themeFont.family
        font.pixelSize: Style.space(12)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Style.space(4)
        color: Qt.alpha(Color.foreground, root.down ? 0.20 : root.hovered ? 0.10 : root.primary ? 0.13 : 0)
        border.color: root.activeFocus ? Color.accent : Qt.alpha(Color.foreground, root.primary ? 0.42 : 0.24)
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: tooltipText
    Accessible.onPressAction: if (enabled) clicked()
}
