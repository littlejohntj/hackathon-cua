#!/usr/bin/env python3
import argparse
import base64
import json
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

from mlx_vlm import apply_chat_template, generate, load

GUIDE_SYSTEM = """
You are Northstar, a screen guidance assistant. The user is trying to complete a task on an iPhone. You see up to three recent screenshots, oldest to newest.

Output exactly one short next-step instruction in natural language. Do not output JSON. Do not mention that you are looking at a screenshot. Do not give multiple steps. Prefer visible labels and locations.

If the user should tap something, say what and where: “Tap the lower-right blue button labeled ‘Next’.”
If the user should type, say exactly what field to use: “Type the email address into the field labeled ‘Email’.”
If the needed UI is not visible, tell the user the one app or screen to open next.
If the task appears complete, start with “Done —”.
""".strip()

class State:
    def __init__(self, model_path: str):
        print(f"loading model: {model_path}", flush=True)
        self.model, self.processor = load(model_path)
        self.lock = threading.Lock()
        self.screenshots: list[bytes] = []
        self.instructions: list[str] = []
        print("model loaded", flush=True)

    def guide(self, task: str, image_bytes: bytes) -> str:
        with self.lock:
            self.screenshots.append(image_bytes)
            self.screenshots = self.screenshots[-3:]
            images = list(self.screenshots)
            prior_instructions = list(self.instructions)

            messages = [{"role": "system", "content": GUIDE_SYSTEM}]
            for instruction in prior_instructions:
                messages.append({"role": "assistant", "content": instruction})
            messages.append({
                "role": "user",
                "content": (
                    f"User task: {task}\n\n"
                    f"The attached screenshots are the last {len(images)} screen states, oldest to newest. "
                    "Use the newest screenshot as the current screen, and use earlier screenshots only as context.\n\n"
                    "What is the next single step the user should take on the current screen?"
                ),
            })

            temp_files = []
            try:
                for image in images:
                    f = tempfile.NamedTemporaryFile(suffix=".jpg", delete=True)
                    f.write(image)
                    f.flush()
                    temp_files.append(f)

                paths = [f.name for f in temp_files]
                formatted = apply_chat_template(
                    self.processor,
                    self.model.config,
                    messages,
                    num_images=len(paths),
                )
                print(
                    f"context screenshots={len(paths)} priorAssistant={len(prior_instructions)}",
                    flush=True,
                )
                result = generate(
                    self.model,
                    self.processor,
                    formatted,
                    image=paths,
                    max_tokens=48,
                    temperature=0.1,
                    top_p=0.8,
                    verbose=False,
                )
            finally:
                for f in temp_files:
                    f.close()

            text = result.text.strip().replace("\n", " ")
            text = text or "I don't see the next step yet — try opening the relevant app or settings screen."
            self.instructions.append(text)
            self.instructions = self.instructions[-12:]
            return text

class Handler(BaseHTTPRequestHandler):
    state: State

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {fmt % args}", flush=True)

    def send_json(self, code: int, obj: dict):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"ok": True})
        else:
            self.send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/guide":
            self.send_json(404, {"error": "not found"})
            return
        try:
            n = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(n))
            task = str(payload.get("task", "")).strip()
            image_b64 = str(payload.get("imageBase64", ""))
            if not task:
                raise ValueError("empty task")
            image = base64.b64decode(image_b64, validate=True)
            t0 = time.time()
            print(f"guide begin taskChars={len(task)} imageBytes={len(image)}", flush=True)
            text = self.state.guide(task, image)
            print(f"guide done seconds={time.time()-t0:.1f} text={text[:180]}", flush=True)
            self.send_json(200, {"instruction": text})
        except Exception as e:
            print(f"guide error: {e!r}", flush=True)
            self.send_json(500, {"error": str(e)})

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--model", default="models/Northstar-CUA-Fast-4bit")
    p.add_argument("--host", default="0.0.0.0")
    p.add_argument("--port", type=int, default=17772)
    args = p.parse_args()
    Handler.state = State(args.model)
    server = HTTPServer((args.host, args.port), Handler)
    print(f"serving http://{args.host}:{args.port}", flush=True)
    server.serve_forever()
