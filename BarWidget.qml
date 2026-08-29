import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root

    property var presets: []
    property string activePreset: ""
    property string pendingPreset: ""
    property string errorMessage: ""
    property int selectedIndex: 0
    property bool opened: false
    property bool busy: loadProc.running
    property bool cycleAfterRefresh: false
    property bool popoutSwitchClosing: false
    readonly property string presetDirectory: Quickshell.env("HOME") + "/.local/share/easyeffects/output"
    readonly property string loadHelper: Quickshell.env("HOME") + "/.config/omarchy/plugins/nerdyworm.easyeffects-presets/scripts/load-preset"
    readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
    readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

    function friendlyName(name) {
        var label = String(name || "").replace(/[-_]+/g, " ");
        return label.length > 0 ? label.charAt(0).toUpperCase() + label.slice(1) : "None";
    }

    function parsePresetListing(raw) {
        var found = [];
        var lines = String(raw || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var file = lines[i].trim();
            if (!file.endsWith(".json"))
                continue;

            found.push(file.slice(0, -5));
        }
        found.sort(function(a, b) {
            return friendlyName(a).localeCompare(friendlyName(b));
        });
        presets = found;
        syncSelection();
    }

    function syncSelection() {
        var index = presets.indexOf(activePreset);
        if (index >= 0)
            selectedIndex = index;
        else if (presets.length > 0)
            selectedIndex = Math.min(selectedIndex, presets.length - 1);
        else
            selectedIndex = 0;
    }

    function refreshPresets() {
        if (!listProc.running)
            listProc.running = true;

    }

    function refreshActive() {
        if (!activeProc.running)
            activeProc.running = true;

    }

    function loadPreset(name) {
        if (busy || presets.indexOf(name) < 0)
            return ;

        pendingPreset = name;
        errorMessage = "";
        loadProc.command = [root.loadHelper, name];
        loadProc.running = true;
    }

    function cyclePreset() {
        if (busy || presets.length === 0)
            return ;

        cycleAfterRefresh = true;
        refreshActive();
    }

    function cycleFromActive() {
        if (busy || presets.length === 0)
            return ;

        var current = presets.indexOf(activePreset);
        var next = current < 0 ? 0 : (current + 1) % presets.length;
        selectedIndex = next;
        loadPreset(presets[next]);
    }

    function moveSelection(delta) {
        if (presets.length === 0)
            return ;

        selectedIndex = (selectedIndex + delta + presets.length) % presets.length;
    }

    function open() {
        opened = true;
        refreshPresets();
        refreshActive();
    }

    function close() {
        opened = false;
    }

    function toggle() {
        opened ? close() : open();
    }

    function closeForPopoutSwitch() {
        popoutSwitchClosing = true;
        close();
        Qt.callLater(function() {
            popoutSwitchClosing = false;
        });
    }

    function switchPanel(direction) {
        if (bar && typeof bar.switchPanelFrom === "function")
            return bar.switchPanelFrom(root, direction);

        return false;
    }

    moduleName: "nerdyworm.easyeffects-presets"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    Component.onCompleted: {
        refreshPresets();
        refreshActive();
    }

    IpcHandler {
        function status() : string {
            return JSON.stringify({
                "active": root.activePreset,
                "pending": root.pendingPreset,
                "presets": root.presets,
                "busy": root.busy,
                "label": button.text
            });
        }

        function cycle() : string {
            root.cyclePreset();
            return "queued";
        }

        function selectPreset(name: string) : string {
            root.loadPreset(name);
            return "queued";
        }

        target: "nerdyworm.easyeffects-presets"
    }

    Process {
        id: activeProc

        command: ["easyeffects", "--last-loaded-preset", "output"]
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.cycleAfterRefresh) {
                root.cycleAfterRefresh = false;
                root.errorMessage = "Could not read the active EasyEffects preset";
            }
        }

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var name = String(text || "").trim();
                if (name !== "" && name !== "None") {
                    root.activePreset = name;
                    root.syncSelection();
                }
                if (root.cycleAfterRefresh) {
                    root.cycleAfterRefresh = false;
                    Qt.callLater(function() {
                        root.cycleFromActive();
                    });
                }
            }
        }

    }

    Process {
        id: listProc

        command: ["find", root.presetDirectory, "-maxdepth", "1", "-type", "f", "-name", "*.json", "-printf", "%f\\n"]
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.presets.length === 0)
                root.errorMessage = "Could not read EasyEffects presets";

        }

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parsePresetListing(text)
        }

    }

    Process {
        id: loadProc

        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.activePreset = root.pendingPreset;
                root.syncSelection();
                refreshAfterLoad.restart();
            } else {
                root.errorMessage = "EasyEffects could not load " + root.friendlyName(root.pendingPreset);
            }
            root.pendingPreset = "";
        }
    }

    Timer {
        id: refreshAfterLoad

        interval: 500
        onTriggered: root.refreshActive()
    }

    WidgetButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: "EQ · " + root.friendlyName(root.busy ? root.pendingPreset : root.activePreset)
        tooltipText: "EasyEffects presets · Right-click to cycle"
        active: root.busy
        onPressed: function(mouseButton) {
            if (mouseButton === Qt.RightButton)
                root.cyclePreset();
            else
                root.toggle();
        }
    }

    KeyboardPanel {
        id: panel

        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(300))
        contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(480))

        PanelKeyCatcher {
            id: keyCatcher

            anchors.fill: parent
            onMoveRequested: function(dx, dy) {
                if (dy !== 0)
                    root.moveSelection(dy);

            }
            onActivateRequested: {
                if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length)
                    root.loadPreset(root.presets[root.selectedIndex]);

            }
            onCloseRequested: root.close()
            onTabRequested: function(direction) {
                root.switchPanel(direction);
            }
            onTextKey: function(value) {
                if (value === "r" || value === "R")
                    root.refreshPresets();

            }

            ScrollView {
                id: scrollArea

                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                Column {
                    id: panelColumn

                    width: scrollArea.availableWidth
                    spacing: Style.space(10)

                    PanelHero {
                        title: "EasyEffects"
                        meta: root.busy ? "Applying " + root.friendlyName(root.pendingPreset) : root.friendlyName(root.activePreset) + " preset"
                        detail: root.busy ? "WAIT" : "OUTPUT"
                        foreground: root.foreground
                        fontFamily: root.fontFamily

                        iconComponent: Component {
                            Text {
                                text: "EQ"
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.title
                                font.bold: true
                            }

                        }

                    }

                    PanelSeparator {
                        foreground: root.foreground
                    }

                    PanelSectionHeader {
                        text: "OUTPUT PRESETS"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                    }

                    Repeater {
                        model: root.presets

                        Button {
                            required property string modelData
                            required property int index

                            width: panelColumn.width
                            text: root.friendlyName(modelData)
                            iconText: modelData === root.activePreset ? "✓" : ""
                            selected: modelData === root.activePreset
                            hasCursor: index === root.selectedIndex
                            enabled: !root.busy
                            leftAlign: true
                            bordered: true
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            onHovered: function(isHovered) {
                                if (isHovered)
                                    root.selectedIndex = index;

                            }
                            onClicked: root.loadPreset(modelData)
                        }

                    }

                    Text {
                        visible: root.presets.length === 0 && root.errorMessage === ""
                        width: parent.width
                        text: "No output presets found"
                        color: Qt.darker(root.foreground, 1.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                    }

                    Text {
                        visible: root.errorMessage !== ""
                        width: parent.width
                        text: root.errorMessage
                        color: root.bar ? root.bar.urgent : Color.urgent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: "Right-click the bar widget to cycle · R to refresh"
                        color: Qt.darker(root.foreground, 1.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }

                }

            }

        }

    }

}
