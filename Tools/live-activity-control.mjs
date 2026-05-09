import http from "node:http";

const appID = process.env.ONESIGNAL_APP_ID ?? "517f535f-c5aa-4733-b569-d6007f7b1092";
const serverAPIKey = process.env.ONESIGNAL_API_KEY ?? "";
const port = Number(process.env.LIVE_ACTIVITY_CONTROL_PORT ?? 8090);

const icons = [
  ["display", "Display"],
  ["safari", "Safari"],
  ["video.fill", "Video"],
  ["bolt.fill", "Boost"],
  ["person.2.fill", "People"],
];

const page = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Live Activity Control</title>
  <style>
    :root { color-scheme: light dark; --accent: #d92d20; --line: #d0d5dd; }
    body { margin: 0; font: 15px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: Canvas; color: CanvasText; }
    main { max-width: 820px; margin: 0 auto; padding: 28px 18px 48px; }
    h1 { margin: 0 0 18px; font-size: 28px; letter-spacing: 0; }
    section { border: 1px solid var(--line); border-radius: 8px; padding: 18px; margin-bottom: 18px; }
    label { display: grid; gap: 7px; font-weight: 600; margin-bottom: 14px; }
    label.inline { display: flex; align-items: center; gap: 10px; }
    label.inline input { width: 18px; height: 18px; }
    input, select, textarea { font: inherit; padding: 10px 12px; border: 1px solid var(--line); border-radius: 8px; background: Field; color: FieldText; }
    textarea { min-height: 52px; resize: vertical; }
    .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
    .icons { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 10px; margin: 8px 0 16px; }
    .icon { border: 1px solid var(--line); border-radius: 8px; padding: 12px 8px; background: ButtonFace; color: ButtonText; cursor: pointer; font-weight: 700; }
    .icon[aria-pressed="true"] { border-color: var(--accent); box-shadow: 0 0 0 2px color-mix(in srgb, var(--accent), transparent 75%); }
    .actions { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
    button { border: 1px solid var(--line); border-radius: 8px; padding: 10px 14px; font: inherit; font-weight: 700; cursor: pointer; }
    .primary { background: var(--accent); border-color: var(--accent); color: white; }
    .danger { color: #b42318; }
    pre { white-space: pre-wrap; word-break: break-word; margin: 12px 0 0; padding: 12px; border-radius: 8px; background: color-mix(in srgb, CanvasText, transparent 92%); }
    .hint { color: color-mix(in srgb, CanvasText, transparent 35%); font-size: 13px; }
    @media (max-width: 640px) { .grid, .icons { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <main>
    <h1>Live Activity Control</h1>
    <section>
      <div class="grid">
        <label>Activity ID
          <input id="activityID" value="safari-stream-demo" autocomplete="off">
        </label>
        <label>OneSignal API key
          <input id="apiKey" type="password" placeholder="${serverAPIKey ? "Loaded from server env" : "Paste key or set ONESIGNAL_API_KEY"}">
        </label>
      </div>
      <p class="hint">Start the Live Activity in the iOS app first using the same Activity ID, then push updates from here.</p>
    </section>

    <section>
      <label>Icon</label>
      <div class="icons" id="icons">
        ${icons.map(([name, label], index) => `<button class="icon" type="button" data-icon="${name}" aria-pressed="${index === 0}">${label}<br><small>${name}</small></button>`).join("")}
      </div>

      <label>Headline
        <input id="headline" value="Screen share is live" maxlength="80">
      </label>
      <label>Bottom line 1
        <input id="detailLine1" value="Todd is presenting the Safari workflow" maxlength="96">
      </label>
      <label>Bottom line 2
        <input id="detailLine2" value="Tap to return to Hackathon Safari" maxlength="96">
      </label>

      <div class="grid">
        <label>Status
          <select id="status">
            <option>Live</option>
            <option>Paused</option>
            <option>Processing</option>
            <option>Ending</option>
          </select>
        </label>
        <label>Quality
          <select id="quality">
            <option>720p</option>
            <option>1080p</option>
            <option>1440p</option>
            <option>Audio only</option>
          </select>
        </label>
        <label>Viewers
          <input id="viewerCount" type="number" min="0" value="3">
        </label>
        <label>Elapsed seconds
          <input id="elapsedSeconds" type="number" min="0" value="0">
        </label>
      </div>
      <label class="inline">
        <input id="alertUpdate" type="checkbox" checked>
        Alert and expand on update
      </label>

      <div class="actions">
        <button class="primary" id="push" type="button">Push Live Activity Update</button>
        <button id="plusViewer" type="button">+ Viewer</button>
        <button id="plusTime" type="button">+ 30 seconds</button>
        <button class="danger" id="end" type="button">End Activity</button>
      </div>
      <pre id="output">Ready.</pre>
    </section>
  </main>

  <script>
    let iconName = "display";
    const output = document.getElementById("output");
    document.querySelectorAll(".icon").forEach(button => {
      button.addEventListener("click", () => {
        iconName = button.dataset.icon;
        document.querySelectorAll(".icon").forEach(item => item.setAttribute("aria-pressed", String(item === button)));
      });
    });
    document.getElementById("plusViewer").addEventListener("click", () => {
      const input = document.getElementById("viewerCount");
      input.value = Number(input.value || 0) + 1;
    });
    document.getElementById("plusTime").addEventListener("click", () => {
      const input = document.getElementById("elapsedSeconds");
      input.value = Number(input.value || 0) + 30;
    });
    document.getElementById("push").addEventListener("click", () => send("update"));
    document.getElementById("end").addEventListener("click", () => send("end"));

    async function send(event) {
      output.textContent = "Sending...";
      const body = {
        activityID: value("activityID"),
        apiKey: value("apiKey"),
        event,
        alert: event === "update" && document.getElementById("alertUpdate").checked,
        state: {
          status: event === "end" ? "Ended" : value("status"),
          viewerCount: Number(value("viewerCount")),
          elapsedSeconds: Number(value("elapsedSeconds")),
          quality: value("quality"),
          isLive: event !== "end",
          iconName,
          headline: value("headline"),
          detailLine1: value("detailLine1"),
          detailLine2: value("detailLine2")
        }
      };
      const response = await fetch("/api/live-activity", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body)
      });
      const text = await response.text();
      output.textContent = text;
    }

    function value(id) {
      return document.getElementById(id).value.trim();
    }
  </script>
</body>
</html>`;

const server = http.createServer(async (request, response) => {
  try {
    if (request.method === "GET" && request.url === "/") {
      send(response, 200, "text/html; charset=utf-8", page);
      return;
    }

    if (request.method === "POST" && request.url === "/api/live-activity") {
      const input = JSON.parse(await readBody(request));
      const result = await sendLiveActivity(input);
      send(response, result.ok ? 200 : result.status, "application/json", JSON.stringify(result.body, null, 2));
      return;
    }

    send(response, 404, "text/plain", "Not found");
  } catch (error) {
    send(response, 500, "application/json", JSON.stringify({ error: error.message }, null, 2));
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Live Activity control: http://localhost:${port}`);
  console.log(serverAPIKey ? "Using ONESIGNAL_API_KEY from environment." : "No ONESIGNAL_API_KEY set; paste it into the web form.");
});

async function sendLiveActivity(input) {
  const activityID = requireText(input.activityID, "activityID");
  const apiKey = (input.apiKey || serverAPIKey).trim();
  requireText(apiKey, "apiKey");
  const event = input.event === "end" ? "end" : "update";
  const state = normalizeState(input.state ?? {}, event);
  const shouldAlert = event === "update" && input.alert !== false;
  const payload = {
    event,
    event_updates: state,
    name: event === "end" ? "Hackathon Safari ended" : "Hackathon Safari update",
    contents: { en: shouldAlert ? state.detailLine1 : state.headline },
    headings: shouldAlert ? { en: state.headline } : undefined,
    priority: shouldAlert ? 10 : 5,
    ios_sound: shouldAlert ? "default" : "nil",
    ios_relevance_score: event === "end" ? 0 : shouldAlert ? 1 : 0.9,
    stale_date: event === "end" ? undefined : Math.floor(Date.now() / 1000) + 15 * 60,
    dismissal_date: event === "end" ? Math.floor(Date.now() / 1000) - 60 : undefined
  };

  const url = `https://api.onesignal.com/apps/${appID}/live_activities/${encodeURIComponent(activityID)}/notifications`;
  const oneSignalResponse = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": apiKey.toLowerCase().startsWith("key ") ? apiKey : `Key ${apiKey}`,
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  const bodyText = await oneSignalResponse.text();
  let body;
  try {
    body = JSON.parse(bodyText);
  } catch {
    body = { raw: bodyText };
  }

  return {
    ok: oneSignalResponse.ok,
    status: oneSignalResponse.status,
    body: {
      ok: oneSignalResponse.ok,
      status: oneSignalResponse.status,
      activityID,
      event,
      alertingUpdate: shouldAlert,
      sentState: state,
      oneSignal: body
    }
  };
}

function normalizeState(state, event) {
  return {
    status: stringValue(state.status, event === "end" ? "Ended" : "Live"),
    viewerCount: numberValue(state.viewerCount, 0),
    elapsedSeconds: numberValue(state.elapsedSeconds, 0),
    quality: stringValue(state.quality, "720p"),
    isLive: event !== "end" && Boolean(state.isLive),
    iconName: allowedIcon(state.iconName),
    headline: stringValue(state.headline, event === "end" ? "Screen share ended" : "Screen share is live"),
    detailLine1: stringValue(state.detailLine1, "Live Activity updated from the web control"),
    detailLine2: stringValue(state.detailLine2, "Hackathon Safari")
  };
}

function allowedIcon(iconName) {
  return icons.some(([name]) => name === iconName) ? iconName : "display";
}

function stringValue(value, fallback) {
  const text = String(value ?? "").trim();
  return text || fallback;
}

function numberValue(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(0, Math.floor(number)) : fallback;
}

function requireText(value, name) {
  const text = String(value ?? "").trim();
  if (!text) throw new Error(`${name} is required`);
  return text;
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    request.on("data", chunk => chunks.push(chunk));
    request.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    request.on("error", reject);
  });
}

function send(response, status, contentType, body) {
  response.writeHead(status, { "content-type": contentType });
  response.end(body);
}
