// Bridges the Chromium web apps in chromium/webapps.json and the desktop,
// through one long-lived native messaging port to open-external-host:
//
// - Links an app with `external_links` opens in a new tab/window are sent to
//   the host, which opens them with bin/url-router, and the Chromium tab is
//   closed. Links to the app's own `hosts` and to `keep_hosts` stay; links to
//   another app go out too, so url-router can route them to that app.
// - `webapp route` asks (through the host) to load a link in an app's open
//   window instead of a new one.
//
// Nothing is hard-coded here: the host sends webapps.json on connect and after
// every change.
//
// Messages to the host:   {type: "open", url}
//                         {type: "result", id, ok}
// Messages from the host: {type: "config", apps, keep_hosts}
//                         {type: "navigate", id, app, url}

const HOST = "org.arkady.open_external";

let config = { apps: {}, keep_hosts: [] };

const matches = (host, list) =>
  (list || []).some((h) => host === h || host.endsWith("." + h));

function hostOf(url) {
  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

// The app whose own site `url` is on
function appFor(url) {
  const host = hostOf(url);
  return Object.entries(config.apps).find(([, app]) => matches(host, app.hosts)) ?? null;
}

// --- Native port -------------------------------------------------------------

// An open port also keeps this service worker alive.
let port = null;

function connect() {
  if (port) return port;
  port = chrome.runtime.connectNative(HOST);
  port.onMessage.addListener(onHostMessage);
  port.onDisconnect.addListener(() => {
    console.warn("open_external host disconnected:", chrome.runtime.lastError?.message);
    port = null;
    setTimeout(connect, 5000);
  });
  return port;
}

chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
// Safety net in case the worker was stopped while disconnected
chrome.alarms.create("keep-connected", { periodInMinutes: 1 });
chrome.alarms.onAlarm.addListener(connect);
connect();

function onHostMessage(msg) {
  if (msg?.type === "config") {
    config = { apps: msg.apps ?? {}, keep_hosts: msg.keep_hosts ?? [] };
  } else if (msg?.type === "navigate") {
    navigate(msg).then((ok) => connect().postMessage({ type: "result", id: msg.id, ok }));
  }
}

// --- Links from outside: reuse the app's open window ---------------------------

async function appTab(app) {
  const tabs = await chrome.tabs.query({ url: app.hosts.map((h) => `https://${h}/*`) });
  // Prefer a tab in an app window (bin/webapp) over one in a normal window
  for (const tab of tabs) {
    const win = await chrome.windows.get(tab.windowId).catch(() => null);
    if (win && win.type !== "normal") return tab;
  }
  return tabs[0] ?? null;
}

async function navigate({ app: id, url }) {
  try {
    const app = config.apps[id];
    if (!app?.hosts?.length || !/^https:/.test(url)) return false;
    const tab = await appTab(app);
    if (!tab) return false;
    await chrome.tabs.update(tab.id, { url, active: true });
    await chrome.windows.update(tab.windowId, { focused: true });
    return true;
  } catch (e) {
    console.warn("navigate failed:", e);
    return false;
  }
}

// --- Links opened by an app: hand them to the desktop --------------------------

// Tabs created by an app that have not navigated anywhere real yet: tabId -> app
const pending = new Map();

function handOff(tabId, url, source) {
  pending.delete(tabId);
  if (!/^https?:/.test(url)) return;
  const host = hostOf(url);
  // The app's own pop-outs and sign-in stay here
  if (matches(host, source.hosts) || matches(host, config.keep_hosts)) return;
  try {
    connect().postMessage({ type: "open", url });
    chrome.tabs.remove(tabId).catch(() => {});
  } catch (e) {
    // Leave the tab open so the link isn't lost
    console.warn("open_external failed:", e);
  }
}

chrome.webNavigation.onCreatedNavigationTarget.addListener(async (d) => {
  const source = await chrome.tabs.get(d.sourceTabId).catch(() => null);
  const app = source && appFor(source.url || "");
  if (!app || !app[1].external_links) return;

  if (/^https?:/.test(d.url)) handOff(d.tabId, d.url, app[1]);
  else pending.set(d.tabId, app[1]); // about:blank first, real URL follows
});

chrome.webNavigation.onBeforeNavigate.addListener((d) => {
  if (d.frameId === 0 && pending.has(d.tabId)) handOff(d.tabId, d.url, pending.get(d.tabId));
});

chrome.tabs.onRemoved.addListener((tabId) => pending.delete(tabId));
