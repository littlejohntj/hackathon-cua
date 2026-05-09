import crypto from "node:crypto";
import http from "node:http";
import os from "node:os";

const port = Number(process.env.PORT ?? 8080);
const broadcasters = new Set();
const viewers = new Set();

const html = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Hackathon Safari Relay</title>
  <style>
    body { margin: 0; background: #111; color: #f8f8f8; font: 14px -apple-system, BlinkMacSystemFont, sans-serif; }
    header { height: 52px; display: flex; align-items: center; gap: 12px; padding: 0 16px; background: #1d1d1f; }
    img { display: block; width: 100vw; height: calc(100vh - 52px); object-fit: contain; background: #050505; }
    .dot { width: 8px; height: 8px; border-radius: 999px; background: #44d46b; }
  </style>
</head>
<body>
  <header><span class="dot"></span><strong>Hackathon Safari Relay</strong><span id="status">waiting for frames</span></header>
  <img id="frame" alt="screen stream">
  <script>
    const frame = document.getElementById("frame");
    const status = document.getElementById("status");
    let previous;
    const socket = new WebSocket((location.protocol === "https:" ? "wss://" : "ws://") + location.host + "/viewer");
    socket.binaryType = "blob";
    socket.onmessage = event => {
      if (previous) URL.revokeObjectURL(previous);
      previous = URL.createObjectURL(event.data);
      frame.src = previous;
      status.textContent = "receiving frames";
    };
    socket.onclose = () => status.textContent = "disconnected";
  </script>
</body>
</html>`;

const server = http.createServer((request, response) => {
  response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  response.end(html);
});

server.on("upgrade", (request, socket) => {
  const key = request.headers["sec-websocket-key"];
  if (!key) {
    socket.destroy();
    return;
  }

  const accept = crypto
    .createHash("sha1")
    .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest("base64");

  socket.write([
    "HTTP/1.1 101 Switching Protocols",
    "Upgrade: websocket",
    "Connection: Upgrade",
    `Sec-WebSocket-Accept: ${accept}`,
    "",
    "",
  ].join("\r\n"));

  const set = request.url === "/viewer" ? viewers : broadcasters;
  set.add(socket);
  socket.buffer = Buffer.alloc(0);
  socket.on("data", chunk => readFrames(socket, chunk));
  socket.on("close", () => set.delete(socket));
  socket.on("error", () => set.delete(socket));
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Viewer: http://localhost:${port}`);
  for (const address of localAddresses()) {
    console.log(`Device relay: ws://${address}:${port}/broadcast`);
  }
});

function readFrames(socket, chunk) {
  socket.buffer = Buffer.concat([socket.buffer, chunk]);

  while (socket.buffer.length >= 2) {
    const first = socket.buffer[0];
    const second = socket.buffer[1];
    const opcode = first & 0x0f;
    const masked = (second & 0x80) !== 0;
    let length = second & 0x7f;
    let offset = 2;

    if (length === 126) {
      if (socket.buffer.length < 4) return;
      length = socket.buffer.readUInt16BE(2);
      offset = 4;
    } else if (length === 127) {
      if (socket.buffer.length < 10) return;
      length = Number(socket.buffer.readBigUInt64BE(2));
      offset = 10;
    }

    const maskLength = masked ? 4 : 0;
    if (socket.buffer.length < offset + maskLength + length) return;

    const mask = masked ? socket.buffer.subarray(offset, offset + 4) : null;
    offset += maskLength;
    const payload = Buffer.from(socket.buffer.subarray(offset, offset + length));
    socket.buffer = socket.buffer.subarray(offset + length);

    if (mask) {
      for (let index = 0; index < payload.length; index += 1) {
        payload[index] ^= mask[index % 4];
      }
    }

    if (opcode === 0x8) {
      socket.end();
      return;
    }
    if (opcode === 0x2) {
      for (const viewer of viewers) {
        sendBinary(viewer, payload);
      }
    }
  }
}

function sendBinary(socket, payload) {
  if (socket.destroyed) return;
  const header = payload.length < 126
    ? Buffer.from([0x82, payload.length])
    : payload.length < 65536
      ? Buffer.from([0x82, 126, payload.length >> 8, payload.length & 0xff])
      : Buffer.concat([Buffer.from([0x82, 127]), uint64(payload.length)]);
  socket.write(Buffer.concat([header, payload]));
}

function uint64(value) {
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(BigInt(value));
  return buffer;
}

function localAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter(address => address?.family === "IPv4" && !address.internal)
    .map(address => address.address);
}
