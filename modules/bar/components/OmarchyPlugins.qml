pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Third-party Omarchy shell plugins that live in the Omarchy bar. Collapsed to
// a single button; clicking it reveals one icon per plugin, and each icon
// summons the plugin's own popout/panel through the running Omarchy shell, so
// the plugins keep working exactly as they do there.
//
// The list follows Omarchy: every enabled, user-installed (not first-party)
// bar-widget plugin shows up, including ones added or enabled later.
//
// Icon per plugin, first match wins:
//   1. "icons" map in ~/.config/caelestia/omarchy-plugins.json ({ "icons": { "<plugin id>": "<material icon>" } })
//   2. "caelestia": { "icon": "<material icon>" } in the plugin's manifest.json
//   3. the plugin's bar widget category
//   4. "extension"
StyledRect {
    id: root

    readonly property var categoryIcons: ({
            "Audio": "graphic_eq",
            "Desktop": "desktop_windows",
            "Development": "code",
            "Games": "sports_esports",
            "Media": "play_circle",
            "Network": "lan",
            "Productivity": "task_alt",
            "System": "settings",
            "Utilities": "build",
            "Weather": "partly_cloudy_day",
            "Wellbeing": "self_improvement"
        })

    property var iconOverrides: ({})
    property list<var> plugins: []
    property bool expanded

    function refresh(): void {
        listProc.running = true;
    }

    function iconFor(plugin: var): string {
        return iconOverrides[plugin.id] || plugin.icon || categoryIcons[plugin.category] || "extension";
    }

    visible: plugins.length > 0
    clip: true
    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: {
        if (!visible)
            return 0;
        const list = expanded ? column.implicitHeight + Tokens.spacing.small : 0;
        return list + toggle.implicitHeight + Tokens.padding.medium * 2;
    }

    Component.onCompleted: refresh()

    Column {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.medium
        spacing: Tokens.spacing.small

        opacity: root.expanded ? 1 : 0
        scale: root.expanded ? 1 : 0.6
        transformOrigin: Item.Bottom

        Repeater {
            model: root.plugins

            Item {
                id: entry

                required property var modelData

                implicitWidth: icon.implicitHeight + Tokens.padding.small
                implicitHeight: icon.implicitHeight

                StateLayer {
                    anchors.fill: undefined
                    anchors.centerIn: parent
                    implicitWidth: implicitHeight
                    implicitHeight: icon.implicitHeight + Tokens.padding.small
                    radius: Tokens.rounding.full
                    disabled: !root.expanded
                    onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "toggle", entry.modelData.id, "{}"])
                }

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: root.iconFor(entry.modelData)
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.small
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Item {
        id: toggle

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.medium

        implicitWidth: toggleIcon.implicitHeight + Tokens.padding.small
        implicitHeight: toggleIcon.implicitHeight

        StateLayer {
            anchors.fill: undefined
            anchors.centerIn: parent
            implicitWidth: implicitHeight
            implicitHeight: toggleIcon.implicitHeight + Tokens.padding.small
            radius: Tokens.rounding.full
            onClicked: {
                root.expanded = !root.expanded;
                if (root.expanded)
                    root.refresh();
            }
        }

        MaterialIcon {
            id: toggleIcon

            anchors.centerIn: parent
            text: "extension"
            fill: root.expanded ? 1 : 0
            rotation: root.expanded ? 90 : 0
            color: root.expanded ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small

            Behavior on rotation {
                Anim {}
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    // Picks up plugins installed, enabled or disabled while the bar is collapsed.
    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.refresh()
    }

    FileView {
        path: `${Paths.config}/omarchy-plugins.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.iconOverrides = JSON.parse(text()).icons ?? {};
            } catch (e) {
                root.iconOverrides = {};
            }
        }
        onLoadFailed: root.iconOverrides = {}
    }

    Process {
        id: listProc

        // omarchy-plugin-list knows what is enabled; the catalog has each
        // plugin's manifest (bar widget name, category, optional icon).
        command: ["sh", "-c", `jq -nc --argjson list "$(omarchy-plugin-list --json)" --argjson catalog "$(omarchy-plugin-catalog)" '
            [$list[]
             | select(.enabled and (.firstParty | not) and ((.kinds // []) | index("bar-widget")))
             | . as $p
             | (first($catalog[] | select(.id == $p.id)) // {}) as $m
             | {id: $p.id, category: ($m.barWidget.category // ""), icon: ($m.caelestia.icon // "")}]'`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.plugins = JSON.parse(text);
                } catch (e) {
                    // Omarchy tools unavailable; keep the last list and retry on the timer.
                }
            }
        }
    }
}
