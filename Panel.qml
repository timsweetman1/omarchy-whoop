import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.timsweetman1.whoop"
  ipcTarget: "io.github.timsweetman1.whoop"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string backend: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")) + "bin/whoop-widget"
  readonly property string whoopIconSource: Qt.resolvedUrl(
    foreground.r + foreground.g + foreground.b > 1.5
      ? "whoop-puck-white.svg"
      : "whoop-puck-black.svg"
  )

  property var report: ({})
  property bool refreshing: false
  readonly property bool connected: !!report.fetched_at
  readonly property var recovery: report.recovery || ({})
  readonly property var sleep: report.sleep || ({})
  readonly property var cycle: report.cycle || ({})
  readonly property var weeklyTrend: report.weekly_trend || []
  readonly property real recoveryScore: numberOr(recovery.recovery_score, -1)
  readonly property real sleepScore: numberOr(sleep.sleep_performance_percentage, -1)
  readonly property real strainScore: numberOr(cycle.day_strain, -1)
  readonly property bool recoveryLow: recoveryScore >= 0 && recoveryScore < 34

  function numberOr(value, fallback) {
    var parsed = Number(value)
    return isFinite(parsed) ? parsed : fallback
  }

  function decimal(value, suffix) {
    var parsed = numberOr(value, -1)
    return parsed < 0 ? "—" : (Math.round(parsed * 10) / 10).toFixed(1) + suffix
  }

  function integer(value, suffix) {
    var parsed = numberOr(value, -1)
    return parsed < 0 ? "—" : Math.round(parsed) + suffix
  }

  function duration(value) {
    var hours = numberOr(value, -1)
    if (hours < 0) return "—"
    var totalMinutes = Math.round(hours * 60)
    return Math.floor(totalMinutes / 60) + "h " + (totalMinutes % 60) + "m"
  }

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
  }

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  function updatedText() {
    if (!connected) return "CONNECTION REQUIRED"
    var date = new Date(report.fetched_at)
    if (!isFinite(date.getTime())) return "PRIVATE LOCAL DATA"
    return "PRIVATE LOCAL DATA · UPDATED " + Qt.formatTime(date, "h:mm AP")
  }

  function dayLabel(dateText) {
    if (!dateText) return "—"
    var date = new Date(dateText + "T12:00:00")
    return isFinite(date.getTime()) ? Qt.formatDate(date, "ddd").toUpperCase() : "—"
  }

  function load() {
    if (!detailProc.running) detailProc.running = true
  }

  function refreshNow() {
    if (refreshProc.running) return
    refreshing = true
    refreshProc.running = true
  }

  function openWhoop() {
    Quickshell.execDetached([backend, "open"])
    root.close()
  }

  function setupPlugin() {
    Quickshell.execDetached([backend, "setup"])
    root.close()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    root.load()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: detailProc
    command: [root.backend, "detail"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try { root.report = JSON.parse(raw) } catch (error) {}
      }
    }
  }

  Process {
    id: refreshProc
    command: [root.backend, "sync"]
    onExited: {
      root.refreshing = false
      root.load()
    }
  }

  Timer {
    interval: 250
    running: true
    onTriggered: root.load()
  }

  Timer {
    interval: 60 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.refreshNow()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    active: root.recoveryLow
    tooltipText: ""

    iconComponent: Component {
      Image {
        source: root.whoopIconSource
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.connected ? root.openWhoop() : root.setupPlugin()
      else if (buttonCode === Qt.MiddleButton) root.refreshNow()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refreshNow()
        else if (text === "o" || text === "O") root.connected ? root.openWhoop() : root.setupPlugin()
      }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelScroll.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "WHOOP"
            meta: root.updatedText()
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Image {
                source: root.whoopIconSource
                sourceSize.width: Style.font.display * 2
                sourceSize.height: Style.font.display * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }
          }

          BorderSurface {
            visible: !root.connected
            width: parent.width
            implicitHeight: setupColumn.implicitHeight + Style.space(28)
            color: root.alpha(root.foreground, 0.04)
            borderSpec: Border.flat(root.alpha(root.foreground, 0.14), 1)
            radius: Style.cornerRadius

            Column {
              id: setupColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(14)
              spacing: Style.space(5)

              Text {
                width: parent.width
                text: "WHOOP is not connected"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                width: parent.width
                text: "Run guided setup to connect your own WHOOP developer app. Tokens and health data stay on this device."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
          }

          PanelSeparator {
            visible: root.connected
            foreground: root.foreground
          }

          Column {
            visible: root.connected && root.weeklyTrend.length > 0
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "7-DAY TREND"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Item {
              width: parent.width
              implicitHeight: trendRecoveryHeader.implicitHeight

              Text {
                anchors.left: parent.left
                width: Style.space(40)
                text: "DAY"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                id: trendRecoveryHeader
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -Style.space(54)
                text: "RECOVERY"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(20)
                text: "SLEEP"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Repeater {
              model: root.weeklyTrend

              TrendRow {
                required property var modelData
                width: parent.width
                day: modelData
              }
            }
          }

          PanelSeparator {
            visible: root.connected && root.weeklyTrend.length > 0
            foreground: root.foreground
          }

          Column {
            visible: root.connected
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              width: parent.width
              text: "RECOVERY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            MetricRow {
              width: parent.width
              label: "Recovery"
              value: root.integer(root.recoveryScore, "%")
              alarming: root.recoveryLow
            }

            Meter {
              width: parent.width
              value: root.recoveryScore < 0 ? -1 : root.recoveryScore / 100
              alarming: root.recoveryLow
            }

            MetricRow {
              width: parent.width
              label: "Heart rate variability"
              value: root.decimal(root.recovery.hrv_rmssd_milli, " ms")
            }
          }

          PanelSeparator {
            visible: root.connected
            foreground: root.foreground
          }

          Column {
            visible: root.connected
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              width: parent.width
              text: "SLEEP"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            MetricRow {
              width: parent.width
              label: "Sleep performance"
              value: root.integer(root.sleepScore, "%")
            }

            Meter {
              width: parent.width
              value: root.sleepScore < 0 ? -1 : root.sleepScore / 100
            }

            MetricRow {
              width: parent.width
              label: "Time asleep"
              value: root.duration(root.sleep.sleep_duration_hours)
            }
          }

          PanelSeparator {
            visible: root.connected
            foreground: root.foreground
          }

          Column {
            visible: root.connected
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              width: parent.width
              text: "TODAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            MetricRow {
              width: parent.width
              label: "Day strain"
              value: root.decimal(root.strainScore, "")
            }

            Meter {
              width: parent.width
              value: root.strainScore < 0 ? -1 : root.strainScore / 21
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(actionLabel.implicitHeight, actionButtons.implicitHeight)

            Text {
              id: actionLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.refreshing
                ? "Refreshing WHOOP…"
                : (root.connected ? "R refresh · O open WHOOP" : "Open guided setup")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              id: actionButtons
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              PanelActionButton {
                iconText: root.refreshing ? "󰑓" : "󰑐"
                tooltipText: "Refresh WHOOP"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.refreshing
                onClicked: root.refreshNow()
              }

              PanelActionButton {
                iconText: "󰖟"
                tooltipText: root.connected ? "Open WHOOP" : "Set up WHOOP"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.connected ? root.openWhoop() : root.setupPlugin()
              }
            }
          }
        }
      }
    }
  }

  component MetricRow: Item {
    id: metricRow
    property string label: ""
    property string value: "—"
    property bool alarming: false

    implicitHeight: Math.max(metricLabel.implicitHeight, metricValue.implicitHeight)

    Text {
      id: metricLabel
      anchors.left: parent.left
      anchors.right: metricValue.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: metricRow.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      id: metricValue
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: metricRow.value
      color: metricRow.alarming ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.alarming ? root.urgent : root.foreground

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }
  }

  component TrendRow: Item {
    id: trendRow
    property var day: null
    readonly property real recoveryValue: root.numberOr(day ? day.recovery_score : null, -1)
    readonly property real sleepValue: root.numberOr(day ? day.sleep_performance_percentage : null, -1)
    readonly property bool alarming: recoveryValue >= 0 && recoveryValue < 34

    implicitHeight: Math.max(trendDay.implicitHeight, recoveryTrack.height, sleepTrack.height) + Style.space(5)

    Text {
      id: trendDay
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(40)
      text: root.dayLabel(trendRow.day ? trendRow.day.date : "")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Rectangle {
      id: recoveryTrack
      anchors.left: trendDay.right
      anchors.right: recoveryText.left
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(7)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(trendRow.recoveryValue / 100, 0, 1)
        color: trendRow.alarming ? root.urgent : root.foreground
      }
    }

    Text {
      id: recoveryText
      anchors.right: parent.horizontalCenter
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(34)
      text: trendRow.recoveryValue < 0 ? "—" : Math.round(trendRow.recoveryValue)
      color: trendRow.alarming ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }

    Rectangle {
      id: sleepTrack
      anchors.left: parent.horizontalCenter
      anchors.right: sleepText.left
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(7)
      anchors.verticalCenter: parent.verticalCenter
      height: recoveryTrack.height
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(trendRow.sleepValue / 100, 0, 1)
        color: root.alpha(root.foreground, 0.62)
      }
    }

    Text {
      id: sleepText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(34)
      text: trendRow.sleepValue < 0 ? "—" : Math.round(trendRow.sleepValue)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }
  }
}
