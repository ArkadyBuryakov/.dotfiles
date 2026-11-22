pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, from config.yaml next to this file. Edits apply as the file
// is saved; a key left out keeps its default below.
//
// The YAML goes through PyYAML (python-yaml) into JSON: Quickshell reads no
// YAML itself. A file that does not parse keeps the settings as they were.
Singleton {
    id: root

    // Settings, once the file has been read (or found broken or missing):
    // before that they are the defaults
    property bool loaded: false

    readonly property string sidebarMode: settings.sidebar?.mode === "single" ? "single" : "monitor"

    property var settings: ({})

    // YAML on stdin -> JSON on stdout, or just the error on stderr
    readonly property string toJson: `import json, sys, yaml
try:
    settings = yaml.safe_load(sys.stdin) or {}
except yaml.YAMLError as error:
    sys.exit(str(error))
print(json.dumps(settings, default=str))`

    FileView {
        id: file
        path: Quickshell.shellPath("config.yaml")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: parse.exec(["python3", "-c", root.toJson])
        onLoadFailed: root.loaded = true
    }

    Process {
        id: parse
        stdinEnabled: true
        onStarted: {
            write(file.text());
            stdinEnabled = false;
        }
        onExited: stdinEnabled = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
                        root.settings = parsed;
                    else
                        console.warn("config.yaml: not a mapping, ignored");
                } catch (e) {
                    // PyYAML said why on stderr
                }
                root.loaded = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text)
                    console.warn(`config.yaml: ${text.trim()}`);
            }
        }
    }
}
