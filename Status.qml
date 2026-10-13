import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root
  property string state: "not-configured"
  property string errorClass: ""
  property string file: ""
  property string at: ""
  property string message: ""
  readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omakindle"
  property bool dirEnsured: false

  function notConfigured() {
    state = "not-configured"; errorClass = ""; file = ""; at = ""; message = "Kindle is not set up yet"
  }

  function parse(text) {
    var o
    try { o = JSON.parse(text) } catch (e) { return notConfigured() }
    if (o === null || typeof o !== "object" || Array.isArray(o)
        || ["idle", "sending", "sent", "error", "not-configured"].indexOf(o.state) < 0) return notConfigured()
    state = o.state; errorClass = o.error_class || ""
    file = o.file || ""; at = o.at || ""; message = o.message || ""
  }

  property FileView view: FileView {
    path: root.dir + "/status.json"
    watchChanges: true
    printErrors: false
    onFileChanged: { root.dirEnsured = false; reload() }
    onLoaded: root.parse(text())
    onLoadFailed: {
      root.notConfigured()
      if (root.dirEnsured) return
      root.dirEnsured = true
      root.mkdir.running = true
    }
  }

  // A missing directory leaves the FileView with nothing to watch; it re-arms only on reload.
  property Process mkdir: Process {
    command: ["mkdir", "-p", "-m", "700", root.dir]
    onExited: function(exitCode) { if (exitCode === 0) root.view.reload() }
  }
}
