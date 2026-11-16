// Links that Outlook opens in a new tab or window get handed to the system
// URL handler (bin/url-router -> Zen, or Teams for meeting links) and the
// Chromium tab is closed. Navigation inside Outlook itself is untouched.

const HOST = "org.arkady.open_external";

// Tabs whose links should leave Chromium.
const SOURCE_HOSTS = [
  "outlook.cloud.microsoft",
  "outlook.office.com",
  "outlook.office365.com",
  "outlook.live.com",
];

// Targets that must stay in Chromium: Outlook's own pop-out windows and the
// Microsoft sign-in popups that need this profile's session.
const KEEP_HOSTS = [
  ...SOURCE_HOSTS,
  "login.microsoftonline.com",
  "login.microsoft.com",
  "login.live.com",
  "account.live.com",
];

const matches = (host, list) =>
  list.some((h) => host === h || host.endsWith("." + h));

function hostOf(url) {
  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

// Tabs created by Outlook that have not navigated anywhere real yet.
const pending = new Set();

function handOff(tabId, url) {
  pending.delete(tabId);
  if (!/^https?:/.test(url) || matches(hostOf(url), KEEP_HOSTS)) return false;
  chrome.runtime.sendNativeMessage(HOST, { url }, () => {
    if (chrome.runtime.lastError) {
      console.warn("open_external failed:", chrome.runtime.lastError.message);
      return; // leave the tab open so the link isn't lost
    }
    chrome.tabs.remove(tabId).catch(() => {});
  });
  return true;
}

chrome.webNavigation.onCreatedNavigationTarget.addListener(async (d) => {
  const source = await chrome.tabs.get(d.sourceTabId).catch(() => null);
  if (!source || !matches(hostOf(source.url || ""), SOURCE_HOSTS)) return;

  if (/^https?:/.test(d.url)) handOff(d.tabId, d.url);
  else pending.add(d.tabId); // about:blank first, real URL follows
});

chrome.webNavigation.onBeforeNavigate.addListener((d) => {
  if (d.frameId === 0 && pending.has(d.tabId)) handOff(d.tabId, d.url);
});

chrome.tabs.onRemoved.addListener((tabId) => pending.delete(tabId));
