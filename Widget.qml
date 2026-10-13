import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.tiilyat.omakindle"
  ipcTarget: "io.github.tiilyat.omakindle"
  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property string cli: pluginDir + "/bin/omakindle"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool isError: status.state === "error"

  property bool completed: false
  property bool manifestSettled: false
  property bool markerSettled: false
  property string manifestVersion: ""
  property string markerVersion: ""
  property bool menuChecked: false

  function checkMenu() {
    if (menuChecked || !completed || !manifestSettled || !markerSettled) return
    menuChecked = true
    if (manifestVersion !== "" && markerVersion !== manifestVersion) Quickshell.execDetached([cli, "install-menu"])
  }

  Component.onCompleted: { completed = true; checkMenu() }

  function run(command) {
    root.close()
    if (root.bar) root.bar.run(command)
  }

  function stateText() {
    switch (status.state) {
      case "idle": return "Ready"
      case "sending": return "Sending…"
      case "sent": return "Sent"
      case "error": return "Failed · " + status.errorClass
      default: return "Not set up"
    }
  }
  function when() {
    if (!status.at) return ""
    var d = new Date(status.at); return isNaN(d) ? status.at : Qt.formatDateTime(d, "ddd HH:mm")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Status { id: status }

  FileView {
    path: root.pluginDir + "/manifest.json"
    printErrors: false
    onLoaded: {
      try { root.manifestVersion = String(JSON.parse(text()).version || "") } catch (e) {}
      root.manifestSettled = true; root.checkMenu()
    }
    onLoadFailed: { root.manifestSettled = true; root.checkMenu() }
  }

  FileView {
    path: status.dir + "/menu-version"
    printErrors: false
    onLoaded: { root.markerVersion = text().trim(); root.markerSettled = true; root.checkMenu() }
    onLoadFailed: { root.markerSettled = true; root.checkMenu() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂺"
    foreground: root.isError ? root.urgent : root.barForeground
    useActiveColor: false
    tooltipText: ""
    onPressed: function(b) { if (b === Qt.LeftButton) root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(420))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Kindle"
          meta: root.stateText()
          detail: status.state === "not-configured" ? "Set up your Kindle address and mail account" : ""
          foreground: root.isError ? root.urgent : root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text { text: "󰂺"; color: root.isError ? root.urgent : root.foreground; font.pixelSize: Style.font.display; font.family: root.fontFamily }
          }
        }

        Text {
          visible: status.message !== ""
          width: parent.width
          text: status.message
          color: root.isError ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Column {
          visible: status.file !== ""
          width: parent.width
          spacing: Style.spacing.labelGap
          PanelSectionHeader { text: "LAST SEND"; foreground: root.foreground; fontFamily: root.fontFamily }
          Pair { label: "File"; value: status.file }
          Pair { label: "When"; value: root.when() }
          Pair { visible: status.errorClass !== ""; label: "Error"; value: status.errorClass }
        }

        PanelSeparator { foreground: root.foreground }

        Row {
          spacing: Style.space(8)
          anchors.horizontalCenter: parent.horizontalCenter
          Button {
            readonly property bool setUp: status.state === "not-configured"
            text: setUp ? "Set up…" : "Send file…"
            onClicked: root.run(Util.shellQuote(root.cli) + (setUp ? " setup" : " send"))
          }
          Button { text: "Settings…"; onClicked: root.run(Util.shellQuote(root.cli) + " setup") }
          Button { visible: root.isError; text: "Log"; onClicked: root.run("omarchy-launch-editor " + Util.shellQuote(status.dir + "/last-send.log")) }
        }
      }
    }
  }

  component Pair: Row {
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: Style.space(8)
    Text { text: label; color: root.foreground; opacity: 0.6; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; width: Style.space(60) }
    Text { text: value; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; width: parent.width - Style.space(68) }
  }
}
