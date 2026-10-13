import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  implicitWidth: glyph.implicitWidth
  implicitHeight: barSize

  Text {
    id: glyph
    anchors.centerIn: parent
    text: "󰂺"
    color: bar ? bar.foreground : Color.foreground
    font.family: bar ? bar.fontFamily : Style.font.family
  }
}
