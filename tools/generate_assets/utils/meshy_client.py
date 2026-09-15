"""
scripts/utils/meshy_client.py

Thin wrapper around the Meshy REST API (https://docs.meshy.ai/en/api)
endpoints this pipeline needs: rigging, text-to-motion, and animation.
Extracted out of main_scripts/meshy_animate.py so main_scripts/
rig_base_models.py (rigging raw base meshes -- see scripts/README.md's
"Step 0") can reuse the exact same request/poll/error-handling logic
instead of duplicating it -- no `bpy` dependency, plain `python` +
`requests`.
"""
from __future__ import annotations

import io
import time
import zipfile
from pathlib import Path

import base64

import requests

API_BASE = "https://api.meshy.ai"

POLL_INTERVAL_S = 5.0
POLL_TIMEOUT_S = 20 * 60  # 20 minutes per task, generous for rigging/animation

# Process-wide Meshy credit-usage tally. MODULE-LEVEL (not per-MeshyClient
# instance) because generate_assets.py's single invocation spans multiple
# independent MeshyClient instances (one created per pipeline stage --
# see process_rig_stage's own client in generate_assets.py, and
# meshy_animate.run()'s own separate client) that all need to contribute
# to ONE end-of-run credit summary. Every real (non-dry-run) Meshy task
# that reaches a terminal state records its actual "consumed_credits"
# (from the task object itself, see each endpoint's docs -- rig: height-
# dependent, typically ~5; text-to-motion: 10 for prime mode / 3 for
# swift; animate: ~3) here as the single source of truth, rather than
# hard-coding per-endpoint credit constants that could drift from Meshy's
# real pricing.
_total_credits_used = 0


def reset_credit_total() -> None:
    """Resets the process-wide credit tally -- call once at the start of a
    top-level script run (e.g. generate_assets.py's main_with_args) so a
    later get_credit_total() reflects only THIS run's usage."""
    global _total_credits_used
    _total_credits_used = 0


def get_credit_total() -> int:
    """Total Meshy credits consumed by every real (non-dry-run) task this
    process has completed since the last reset_credit_total() call."""
    return _total_credits_used


def _record_credits(n: int) -> None:
    global _total_credits_used
    _total_credits_used += n


def download_glb(url: str, dest: Path) -> None:
    """
    Downloads a Meshy result URL to dest, auto-unzipping if the response is
    a .zip archive (Meshy's downloads sometimes arrive zipped rather than as
    a loose .glb) and picking the first .glb inside -- shared by
    meshy_animate.py and rig_base_models.py so both follow the exact same
    convention as mesh_discovery.py's own base_mesh/ auto-unzip logic.
    """
    dest.parent.mkdir(parents=True, exist_ok=True)
    resp = requests.get(url, timeout=120, stream=True)
    resp.raise_for_status()
    content = resp.content
    if content[:4] == b"PK\x03\x04":
        with zipfile.ZipFile(io.BytesIO(content)) as zf:
            glb_names = [n for n in zf.namelist() if n.lower().endswith(".glb")]
            if not glb_names:
                raise RuntimeError(f"downloaded zip from {url} contains no .glb file")
            with zf.open(glb_names[0]) as f:
                dest.write_bytes(f.read())
    else:
        dest.write_bytes(content)


class MeshyClient:
    """Thin wrapper around the Meshy REST API endpoints this pipeline needs."""

    def __init__(self, api_key: str):
        self._session = requests.Session()
        self._session.headers.update({"Authorization": f"Bearer {api_key}"})

    def _post(self, path: str, payload: dict) -> str:
        resp = self._session.post(f"{API_BASE}{path}", json=payload, timeout=60)
        resp.raise_for_status()
        return resp.json()["result"]

    def _get_task(self, path: str, task_id: str) -> dict:
        resp = self._session.get(f"{API_BASE}{path}/{task_id}", timeout=60)
        resp.raise_for_status()
        return resp.json()

    def _poll(self, path: str, task_id: str, label: str) -> dict:
        start = time.monotonic()
        last_progress = None
        while True:
            task = self._get_task(path, task_id)
            status = task.get("status")
            progress = task.get("progress")
            if progress != last_progress:
                print(f"    {label} [{task_id}]: {status} ({progress}%)")
                last_progress = progress
            if status == "SUCCEEDED":
                # consumed_credits is present on every non-FAILED task per
                # Meshy's own docs (rig/text-to-motion/animate task
                # objects all expose it) -- reading it straight off the
                # real response, rather than a hard-coded per-endpoint
                # constant, keeps this correct even if Meshy's pricing
                # later changes (e.g. rig's cost varies with height_meters).
                _record_credits(int(task.get("consumed_credits") or 0))
                return task
            if status in ("FAILED", "CANCELED"):
                # Per Meshy's docs, credits are automatically refunded on
                # failure/cancellation (consumed_credits reads back as 0
                # for these) -- nothing to record.
                err = (task.get("task_error") or {}).get("message") or status
                raise RuntimeError(f"{label} task {task_id} {status}: {err}")
            if time.monotonic() - start > POLL_TIMEOUT_S:
                raise TimeoutError(f"{label} task {task_id} did not finish within {POLL_TIMEOUT_S}s")
            time.sleep(POLL_INTERVAL_S)

    def rig(self, glb_path: Path, height_meters: float = 1.7) -> tuple[str, str]:
        data_uri = "data:model/gltf-binary;base64," + base64.b64encode(glb_path.read_bytes()).decode("ascii")
        task_id = self._post("/openapi/v1/rigging", {"model_url": data_uri, "height_meters": height_meters})
        task = self._poll("/openapi/v1/rigging", task_id, "rig")
        return task_id, task["result"]["rigged_character_glb_url"]

    def text_to_motion(self, prompt: str, duration: float, mode: str = "prime") -> tuple[str, str]:
        task_id = self._post("/openapi/v1/text-to-motion", {"prompt": prompt, "duration": duration, "mode": mode})
        task = self._poll("/openapi/v1/text-to-motion", task_id, "text-to-motion")
        return task_id, task["result"]["motion_url"]

    def animate(self, rig_task_id: str, *, motion_task_id: str | None = None, action_id: int | None = None) -> dict:
        """
        Applies an animation to a rigged character -- either a free-form
        Text-to-Motion clip (motion_task_id) or a preset from Meshy's
        Animation Library (action_id, see GET /openapi/v1/animations/library
        and list_animation_library() below). Exactly one of the two must be
        given, matching the API's own mutually-exclusive requirement.
        """
        if (motion_task_id is None) == (action_id is None):
            raise ValueError("animate() requires exactly one of motion_task_id or action_id")
        payload = {"rig_task_id": rig_task_id}
        if motion_task_id is not None:
            payload["motion_task_id"] = motion_task_id
        else:
            payload["action_id"] = action_id
        task_id = self._post("/openapi/v1/animations", payload)
        task = self._poll("/openapi/v1/animations", task_id, "animate")
        return task["result"]

    def list_animation_library(self, *, search: str | None = None, category: str | None = None,
                                sub_category: str | None = None, action_ids: list[int] | None = None) -> list[dict]:
        """
        GET /openapi/v1/animations/library -- the free (no-credit) catalog
        of preset animations retargetable onto any biped rig via
        animate(rig_task_id, action_id=...). Returns the full list (already
        unpaginated by Meshy); filters just narrow it. See
        https://docs.meshy.ai/en/api/animation-library for the full
        category/sub_category vocabulary and object schema (action_id, name,
        key, category, sub_category, preview_url).
        """
        params = {}
        if search:
            params["search"] = search
        if category:
            params["category"] = category
        if sub_category:
            params["sub_category"] = sub_category
        if action_ids:
            params["action_ids"] = ",".join(str(a) for a in action_ids)
        resp = self._session.get(f"{API_BASE}/openapi/v1/animations/library", params=params, timeout=60)
        resp.raise_for_status()
        return resp.json()
