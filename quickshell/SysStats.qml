pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU and memory figures, sampled every 2 seconds.
Singleton {
    id: root

    // Percent, overall and per core
    property int cpu: 0
    property list<int> cores: []
    property string load: ""

    // kB
    property real memTotal: 1
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property int memory: Math.round(100 * memUsed / memTotal)

    // Previous { idle, total } jiffies per /proc/stat cpu line
    property var previous: ({})

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // cpuN user nice system idle iowait irq softirq steal ...
            const usage = text().split("\n").filter(line => line.startsWith("cpu")).map(line => {
                const fields = line.trim().split(/\s+/);
                const times = fields.slice(1, 9).map(Number);
                const idle = times[3] + times[4];
                const total = times.reduce((a, b) => a + b, 0);
                const last = root.previous[fields[0]] ?? { idle: 0, total: 0 };
                root.previous[fields[0]] = { idle, total };
                return total > last.total ? Math.round(100 * (1 - (idle - last.idle) / (total - last.total))) : 0;
            });
            root.cpu = usage[0] ?? 0;
            root.cores = usage.slice(1);
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp("^" + key + ":\\s+(\\d+)", "m"))?.[1] ?? 0);
            root.memTotal = kb("MemTotal") || 1;
            root.memUsed = root.memTotal - kb("MemAvailable");
            root.swapTotal = kb("SwapTotal");
            root.swapUsed = root.swapTotal - kb("SwapFree");
        }
    }

    FileView {
        id: loadavg
        path: "/proc/loadavg"
        onLoaded: root.load = text().split(" ").slice(0, 3).join("  ")
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            loadavg.reload();
        }
    }
}
