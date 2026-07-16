#!/usr/bin/env python3
"""Local-only integration tests for CalculFF payment proof Storage policies.

The script intentionally uses only the Python standard library. It discovers
short-lived local credentials from `supabase status -o env`, rejects non-local
API URLs, and never prints keys or JWTs.
"""

from __future__ import annotations

import base64
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from typing import Any


JPEG_1X1 = base64.b64decode(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////"
    "2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/"
    "xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAA"
    "AAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QA"
    "FBAAspirAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABAf/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPxB//8QAFB"
    "EBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPxB//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxB//9k=".replace("spir", "")
)
PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII="
)
PDF_MINIMAL = b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n"


class TestFailure(RuntimeError):
    pass


@dataclass
class Response:
    status: int
    body: bytes
    headers: dict[str, str]

    def json(self) -> Any:
        if not self.body:
            return None
        return json.loads(self.body.decode("utf-8"))


class LocalSupabase:
    def __init__(self) -> None:
        self.env = self._load_env()
        self.api_url = self.env["API_URL"].rstrip("/")
        self.anon_key = self.env.get("ANON_KEY") or self.env.get("PUBLISHABLE_KEY")
        self.service_key = self.env.get("SERVICE_ROLE_KEY")
        if not self.anon_key or not self.service_key:
            raise TestFailure("Local Supabase status did not expose ANON_KEY and SERVICE_ROLE_KEY")
        self.secrets = [self.anon_key, self.service_key]

    @staticmethod
    def _load_env() -> dict[str, str]:
        if shutil.which("supabase") is None:
            raise TestFailure("supabase CLI is not installed")
        proc = subprocess.run(
            ["supabase", "status", "-o", "env"],
            check=False,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise TestFailure("supabase status -o env failed; start the local stack first")
        values: dict[str, str] = {}
        for raw_line in proc.stdout.splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
        api_url = values.get("API_URL", "")
        parsed = urllib.parse.urlparse(api_url)
        if parsed.scheme not in {"http", "https"} or parsed.hostname not in {"127.0.0.1", "localhost", "::1"}:
            raise TestFailure("Refusing to run Storage integration tests against a non-local Supabase API")
        return values

    def redact(self, text: str) -> str:
        redacted = text
        for secret in self.secrets:
            if secret:
                redacted = redacted.replace(secret, "<redacted>")
        redacted = re.sub(r"eyJ[A-Za-z0-9._-]{20,}", "<redacted-jwt>", redacted)
        redacted = re.sub(r"sb_(?:secret|publishable)_[A-Za-z0-9_-]+", "<redacted-key>", redacted)
        return redacted[:1000]

    def request(
        self,
        method: str,
        path: str,
        *,
        token: str | None = None,
        api_key: str | None = None,
        json_body: Any | None = None,
        body: bytes | None = None,
        content_type: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> Response:
        request_headers = dict(headers or {})
        key = api_key or self.anon_key
        if key:
            request_headers["apikey"] = key
        if token:
            request_headers["Authorization"] = f"Bearer {token}"
        if json_body is not None:
            body = json.dumps(json_body, separators=(",", ":")).encode("utf-8")
            request_headers["Content-Type"] = "application/json"
        elif content_type:
            request_headers["Content-Type"] = content_type
        req = urllib.request.Request(
            self.api_url + path,
            data=body,
            headers=request_headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                return Response(response.status, response.read(), dict(response.headers.items()))
        except urllib.error.HTTPError as exc:
            return Response(exc.code, exc.read(), dict(exc.headers.items()))
        except urllib.error.URLError as exc:
            raise TestFailure(f"Local Supabase HTTP request failed: {exc.reason}") from exc

    def service_request(self, method: str, path: str, **kwargs: Any) -> Response:
        legacy_service_jwt = self.service_key if self.service_key.startswith("eyJ") else None
        return self.request(
            method,
            path,
            token=legacy_service_jwt,
            api_key=self.service_key,
            **kwargs,
        )


class StorageSuite:
    def __init__(self) -> None:
        self.sb = LocalSupabase()
        self.run_id = uuid.uuid4().hex[:12]
        self.password = f"Local-only-{uuid.uuid4().hex}!"
        self.user_a: dict[str, str] = {}
        self.user_b: dict[str, str] = {}
        self.admin: dict[str, str] = {}
        self.game_id = ""
        self.offer_id = ""
        self.order_ids: list[str] = []
        self.object_paths: list[str] = []
        self.passed = 0
        self.failed = 0

    def expect(self, condition: bool, name: str, detail: str = "") -> None:
        if condition:
            self.passed += 1
            print(f"ok {self.passed + self.failed} - {name}")
            return
        self.failed += 1
        safe_detail = self.sb.redact(detail)
        print(f"not ok {self.passed + self.failed} - {name}")
        if safe_detail:
            print(f"  {safe_detail}")

    def expect_status(self, response: Response, allowed: set[int], name: str) -> None:
        detail = f"HTTP {response.status}: {response.body.decode('utf-8', 'replace')}"
        self.expect(response.status in allowed, name, detail)

    def create_user(self, label: str, *, admin: bool = False) -> dict[str, str]:
        email = f"calculff-{label}-{self.run_id}@test.invalid"
        body: dict[str, Any] = {
            "email": email,
            "password": self.password,
            "email_confirm": True,
        }
        if admin:
            body["app_metadata"] = {"role": "admin"}
        response = self.sb.service_request("POST", "/auth/v1/admin/users", json_body=body)
        if response.status not in {200, 201}:
            raise TestFailure(self.sb.redact(f"Could not create local test user: {response.status} {response.body!r}"))
        user_id = response.json()["id"]
        signin = self.sb.request(
            "POST",
            "/auth/v1/token?grant_type=password",
            api_key=self.sb.anon_key,
            json_body={"email": email, "password": self.password},
        )
        if signin.status != 200:
            raise TestFailure(self.sb.redact(f"Could not sign in local test user: {signin.status} {signin.body!r}"))
        token = signin.json()["access_token"]
        self.sb.secrets.append(token)
        return {"id": user_id, "email": email, "token": token}

    def patch_profile(self, user: dict[str, str], name: str, phone: str) -> None:
        query = urllib.parse.urlencode({"id": f"eq.{user['id']}"})
        response = self.sb.request(
            "PATCH",
            f"/rest/v1/profiles?{query}",
            token=user["token"],
            json_body={"full_name": name, "phone": phone, "locale": "ar"},
            headers={"Prefer": "return=minimal"},
        )
        if response.status not in {200, 204}:
            raise TestFailure(self.sb.redact(f"Could not complete local profile: {response.status} {response.body!r}"))

    def rpc(self, token: str, name: str, payload: dict[str, Any]) -> Response:
        return self.sb.request(
            "POST",
            f"/rest/v1/rpc/{name}",
            token=token,
            json_body=payload,
        )

    def create_order(self, user: dict[str, str], method: str = "transfer") -> str:
        request_id = str(uuid.uuid4())
        response = self.rpc(
            user["token"],
            "create_order",
            {
                "p_client_request_id": request_id,
                "p_offer_id": self.offer_id,
                "p_player_id": f"PLAYER-{uuid.uuid4().hex[:12]}",
                "p_in_game_name": None,
                "p_payment_method": method,
            },
        )
        if response.status != 200:
            raise TestFailure(self.sb.redact(f"create_order failed: {response.status} {response.body!r}"))
        data = response.json()
        if isinstance(data, list):
            data = data[0]
        order_id = data["id"]
        self.order_ids.append(order_id)
        return order_id

    def object_path(self, user_id: str, order_id: str, extension: str, label: str = "proof") -> str:
        filename = f"{label}_{uuid.uuid4().hex}.{extension}"
        return f"{user_id}/{order_id}/{filename}"

    @staticmethod
    def encoded(path: str) -> str:
        return urllib.parse.quote(path, safe="/")

    def upload(self, token: str | None, path: str, content: bytes, mime: str, *, upsert: bool = False) -> Response:
        if path not in self.object_paths:
            self.object_paths.append(path)
        return self.sb.request(
            "POST",
            f"/storage/v1/object/payment-proofs/{self.encoded(path)}",
            token=token,
            body=content,
            content_type=mime,
            headers={"x-upsert": "true" if upsert else "false"},
        )

    def read_private(self, token: str | None, path: str) -> Response:
        return self.sb.request(
            "GET",
            f"/storage/v1/object/authenticated/payment-proofs/{self.encoded(path)}",
            token=token,
        )

    def setup(self) -> None:
        self.user_a = self.create_user("user-a")
        self.user_b = self.create_user("user-b")
        self.admin = self.create_user("admin", admin=True)
        self.patch_profile(self.user_a, "Storage User A", "+213 555 11 22 33")
        self.patch_profile(self.user_b, "Storage User B", "+213 555 44 55 66")
        self.patch_profile(self.admin, "Storage Admin", "+213 555 00 00 01")

        game = self.sb.request(
            "POST",
            "/rest/v1/games",
            token=self.admin["token"],
            json_body={
                "slug": f"storage-{self.run_id}",
                "name_ar": "لعبة اختبار التخزين",
                "name_fr": "Jeu test stockage",
                "reward_unit_code": "credits",
                "reward_unit_name_ar": "رصيد",
                "reward_unit_name_fr": "Crédits",
                "is_active": True,
                "sort_order": 9999,
            },
            headers={"Prefer": "return=representation"},
        )
        if game.status not in {200, 201}:
            raise TestFailure(self.sb.redact(f"Could not create local game fixture: {game.status} {game.body!r}"))
        game_data = game.json()
        if isinstance(game_data, list):
            game_data = game_data[0]
        self.game_id = game_data["id"]

        offer = self.sb.request(
            "POST",
            "/rest/v1/public_offers",
            token=self.admin["token"],
            json_body={
                "game_id": self.game_id,
                "name_ar": "عرض اختبار التخزين",
                "name_fr": "Offre test stockage",
                "reward_quantity": 100,
                "sale_price_dzd": 350,
                "is_published": True,
                "sort_order": 9999,
            },
            headers={"Prefer": "return=representation"},
        )
        if offer.status not in {200, 201}:
            raise TestFailure(self.sb.redact(f"Could not create local offer fixture: {offer.status} {offer.body!r}"))
        offer_data = offer.json()
        if isinstance(offer_data, list):
            offer_data = offer_data[0]
        self.offer_id = offer_data["id"]

    def run(self) -> None:
        self.setup()
        jpg_order = self.create_order(self.user_a)
        png_order = self.create_order(self.user_a)
        pdf_order = self.create_order(self.user_a)
        misc_order = self.create_order(self.user_a)
        other_a_order = self.create_order(self.user_a)
        cash_order = self.create_order(self.user_a, "cash")
        user_b_order = self.create_order(self.user_b)

        jpg_path = self.object_path(self.user_a["id"], jpg_order, "jpg", "proofjpg")
        png_path = self.object_path(self.user_a["id"], png_order, "png", "proofpng")
        pdf_path = self.object_path(self.user_a["id"], pdf_order, "pdf", "proofpdf")
        b_path = self.object_path(self.user_b["id"], user_b_order, "jpg", "proofb")

        self.expect_status(self.upload(self.user_a["token"], jpg_path, JPEG_1X1, "image/jpeg"), {200, 201}, "JPEG upload succeeds")
        self.expect_status(self.upload(self.user_a["token"], png_path, PNG_1X1, "image/png"), {200, 201}, "PNG upload succeeds")
        self.expect_status(self.upload(self.user_a["token"], pdf_path, PDF_MINIMAL, "application/pdf"), {200, 201}, "PDF upload succeeds")

        text_path = self.object_path(self.user_a["id"], misc_order, "pdf", "textmime")
        self.expect_status(self.upload(self.user_a["token"], text_path, b"plain text", "text/plain"), {400, 403}, "text/plain upload is rejected")
        unsupported_path = self.object_path(self.user_a["id"], misc_order, "jpg", "badmime")
        self.expect_status(self.upload(self.user_a["token"], unsupported_path, b"GIF89a", "image/gif"), {400, 403}, "unsupported MIME upload is rejected")
        large_path = self.object_path(self.user_a["id"], misc_order, "pdf", "large")
        self.expect_status(self.upload(self.user_a["token"], large_path, b"0" * (5 * 1024 * 1024 + 1), "application/pdf"), {400, 413}, "file larger than 5 MiB is rejected")

        wrong_user_path = self.object_path(self.user_b["id"], misc_order, "jpg", "wronguser")
        self.expect_status(self.upload(self.user_a["token"], wrong_user_path, JPEG_1X1, "image/jpeg"), {400, 403}, "upload under another user path is rejected")
        wrong_order_path = self.object_path(self.user_a["id"], user_b_order, "jpg", "wrongorder")
        self.expect_status(self.upload(self.user_a["token"], wrong_order_path, JPEG_1X1, "image/jpeg"), {400, 403}, "upload to another user's order is rejected")
        dotdot_path = f"{self.user_a['id']}/{misc_order}/proof..{uuid.uuid4().hex}.jpg"
        self.expect_status(self.upload(self.user_a["token"], dotdot_path, JPEG_1X1, "image/jpeg"), {400, 403}, "path containing double dots is rejected")
        extra_segment_path = f"{self.user_a['id']}/{misc_order}/extra/proof_{uuid.uuid4().hex}.jpg"
        self.expect_status(self.upload(self.user_a["token"], extra_segment_path, JPEG_1X1, "image/jpeg"), {400, 403}, "path with an extra segment is rejected")
        invalid_name_path = f"{self.user_a['id']}/{misc_order}/proof.jpg"
        self.expect_status(self.upload(self.user_a["token"], invalid_name_path, JPEG_1X1, "image/jpeg"), {400, 403}, "non-random short filename is rejected")
        anon_path = self.object_path(self.user_a["id"], misc_order, "jpg", "anon")
        self.expect_status(self.upload(None, anon_path, JPEG_1X1, "image/jpeg"), {400, 401, 403}, "anonymous upload is rejected")
        self.expect_status(self.read_private(None, jpg_path), {400, 401, 403, 404}, "anonymous private read is rejected")

        b_upload = self.upload(self.user_b["token"], b_path, JPEG_1X1, "image/jpeg")
        if b_upload.status not in {200, 201}:
            raise TestFailure(
                self.sb.redact(
                    f"Could not upload user B fixture: {b_upload.status} {b_upload.body!r}"
                )
            )
        attach_b = self.rpc(self.user_b["token"], "attach_payment_proof", {"p_order_id": user_b_order, "p_object_path": b_path})
        if attach_b.status != 200:
            raise TestFailure(self.sb.redact(f"Could not attach user B fixture: {attach_b.status} {attach_b.body!r}"))
        self.expect_status(self.read_private(self.user_a["token"], b_path), {400, 403, 404}, "user A cannot read user B proof")

        self.expect_status(self.upload(self.user_a["token"], jpg_path, JPEG_1X1, "image/jpeg", upsert=True), {400, 403, 409}, "upsert on an existing path is rejected")
        replace = self.sb.request(
            "PUT",
            f"/storage/v1/object/payment-proofs/{self.encoded(jpg_path)}",
            token=self.user_a["token"],
            body=JPEG_1X1,
            content_type="image/jpeg",
        )
        self.expect_status(replace, {400, 403, 404, 405}, "client UPDATE/replace is rejected")
        delete = self.sb.request(
            "DELETE",
            f"/storage/v1/object/payment-proofs/{self.encoded(jpg_path)}",
            token=self.user_a["token"],
        )
        self.expect_status(delete, {400, 403, 404, 405}, "client DELETE is rejected")

        attached = self.rpc(self.user_a["token"], "attach_payment_proof", {"p_order_id": jpg_order, "p_object_path": jpg_path})
        self.expect_status(attached, {200}, "valid attach_payment_proof succeeds")
        missing_path = self.object_path(self.user_a["id"], other_a_order, "jpg", "missing")
        missing = self.rpc(self.user_a["token"], "attach_payment_proof", {"p_order_id": other_a_order, "p_object_path": missing_path})
        self.expect_status(missing, {400, 404}, "attach of a nonexistent Storage path is rejected")

        cash_path = self.object_path(self.user_a["id"], cash_order, "jpg", "cash")
        self.object_paths.append(cash_path)
        cash_fixture = self.sb.service_request(
            "POST",
            f"/storage/v1/object/payment-proofs/{self.encoded(cash_path)}",
            body=JPEG_1X1,
            content_type="image/jpeg",
            headers={"x-upsert": "false"},
        )
        if cash_fixture.status not in {200, 201}:
            raise TestFailure(self.sb.redact(f"Could not create local cash proof fixture: {cash_fixture.status} {cash_fixture.body!r}"))
        cash_attach = self.rpc(self.user_a["token"], "attach_payment_proof", {"p_order_id": cash_order, "p_object_path": cash_path})
        self.expect_status(cash_attach, {400}, "attach to a cash order is rejected")
        other_attach = self.rpc(self.user_a["token"], "attach_payment_proof", {"p_order_id": user_b_order, "p_object_path": b_path})
        self.expect_status(other_attach, {400, 403}, "attach to another user's order is rejected")

        rejected = self.rpc(
            self.admin["token"],
            "admin_set_payment_status",
            {"p_order_id": jpg_order, "p_payment_status": "proof_rejected", "p_public_message": None, "p_internal_note": None},
        )
        if rejected.status != 200:
            raise TestFailure(self.sb.redact(f"Could not set proof_rejected fixture: {rejected.status} {rejected.body!r}"))
        replacement_path = self.object_path(self.user_a["id"], jpg_order, "png", "replacement")
        replacement_upload = self.upload(self.user_a["token"], replacement_path, PNG_1X1, "image/png")
        if replacement_upload.status not in {200, 201}:
            raise TestFailure(self.sb.redact(f"Could not upload replacement fixture: {replacement_upload.status} {replacement_upload.body!r}"))
        replacement_attach = self.rpc(self.user_a["token"], "attach_payment_proof", {"p_order_id": jpg_order, "p_object_path": replacement_path})
        self.expect_status(replacement_attach, {200}, "new path after proof_rejected attaches successfully")
        self.expect_status(self.read_private(self.user_a["token"], replacement_path), {200}, "linked proof is readable by its owner")
        self.expect_status(self.read_private(self.admin["token"], b_path), {200}, "admin JWT can read payment proofs")
        public_read = self.sb.request("GET", f"/storage/v1/object/public/payment-proofs/{self.encoded(replacement_path)}")
        self.expect(public_read.status != 200, "private bucket proof is not exposed through a public URL", f"HTTP {public_read.status}")

    def cleanup(self) -> None:
        for path in reversed(self.object_paths):
            self.sb.service_request("DELETE", f"/storage/v1/object/payment-proofs/{self.encoded(path)}")
        for order_id in self.order_ids:
            query = urllib.parse.urlencode({"id": f"eq.{order_id}"})
            self.sb.service_request("DELETE", f"/rest/v1/orders?{query}")
        offer_query = urllib.parse.urlencode({"id": f"eq.{self.offer_id}"})
        game_query = urllib.parse.urlencode({"id": f"eq.{self.game_id}"})
        self.sb.service_request("DELETE", f"/rest/v1/public_offers?{offer_query}")
        self.sb.service_request("DELETE", f"/rest/v1/games?{game_query}")
        for user in (self.user_a, self.user_b, self.admin):
            if user.get("id"):
                self.sb.service_request("DELETE", f"/auth/v1/admin/users/{user['id']}")


def main() -> int:
    print("TAP version 13")
    print("1..25")
    suite: StorageSuite | None = None
    try:
        suite = StorageSuite()
        suite.run()
        if suite.passed + suite.failed != 25:
            print(f"Bail out! internal case count was {suite.passed + suite.failed}, expected 25")
            return 1
        return 0 if suite.failed == 0 else 1
    except TestFailure as exc:
        message = suite.sb.redact(str(exc)) if suite is not None else str(exc)
        print(f"Bail out! {message}")
        return 1
    finally:
        if suite is not None:
            try:
                suite.cleanup()
            except Exception:
                print("# cleanup encountered a non-fatal local-only error")


if __name__ == "__main__":
    sys.exit(main())
