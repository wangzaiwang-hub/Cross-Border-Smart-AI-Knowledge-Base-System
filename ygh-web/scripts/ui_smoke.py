import base64
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "test-results" / "ui-smoke"
RESULTS.mkdir(parents=True, exist_ok=True)


def mock_login(page, user_id: str, roles: list[str]) -> None:
    def encode(value: dict[str, object]) -> str:
        raw = json.dumps(value, separators=(",", ":")).encode()
        return base64.urlsafe_b64encode(raw).decode().rstrip("=")

    token = f'{encode({"alg": "none", "typ": "JWT"})}.{encode({"sub": user_id, "roles": roles, "permissions": []})}.visual-smoke'
    payload = {
        "code": "SUCCESS",
        "message": "OK",
        "data": {
            "userId": user_id,
            "tokens": {
                "accessToken": token,
                "refreshToken": "visual-smoke-refresh-token",
                "tokenType": "Bearer",
                "expiresIn": 900,
                "refreshExpiresIn": 86400,
            },
        },
        "traceId": "visual-smoke",
        "timestamp": "2026-07-13T00:00:00Z",
    }
    page.route(
        "**/api/v1/auth/login",
        lambda route: route.fulfill(status=200, content_type="application/json", body=json.dumps(payload)),
    )


def inspect(page, base_url: str, paths: list[str], prefix: str) -> None:
    errors: list[str] = []
    page.on(
        "console",
        lambda message: errors.append(message.text)
        if message.type == "error" and not message.text.startswith("Failed to load resource:")
        else None,
    )
    page.on("pageerror", lambda error: errors.append(str(error)))
    for index, path in enumerate(paths):
        page.goto(f"{base_url}{path}", wait_until="networkidle")
        assert page.locator("body").inner_text().strip(), f"empty page: {path}"
        assert "页面未找到" not in page.locator("body").inner_text(), f"unexpected 404: {path}"
        if index in (0, len(paths) - 1):
            page.screenshot(path=RESULTS / f"{prefix}-{index}.png", full_page=True)
    assert not errors, f"browser errors in {prefix}: {errors}"


parser = argparse.ArgumentParser()
parser.add_argument("--target", choices=("all", "mall", "admin"), default="all")
args = parser.parse_args()

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    if args.target in ("all", "mall"):
        mall = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        mock_login(mall, "visual-user", ["USER"])
        inspect(mall, "http://127.0.0.1:5173", ["/", "/products", "/products/10001", "/knowledge", "/knowledge/k-101", "/ai-service"], "mall-public")
        mall.goto("http://127.0.0.1:5173/login", wait_until="networkidle")
        mall.get_by_role("button", name="登录平台").click()
        mall.wait_for_url("**/workspace/profile")
        inspect(mall, "http://127.0.0.1:5173", ["/workspace/cart", "/workspace/orders", "/workspace/wallet", "/workspace/training", "/workspace/training/courses/c1", "/workspace/training/progress"], "mall-workspace")
        mall.close()

    if args.target in ("all", "admin"):
        admin = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        mock_login(admin, "visual-admin", ["ADMIN"])
        admin.goto("http://127.0.0.1:5174/login", wait_until="networkidle")
        admin.get_by_role("button", name="进入运营后台").click()
        admin.wait_for_url("**/dashboard")
        inspect(admin, "http://127.0.0.1:5174", ["/dashboard", "/products", "/orders", "/knowledge", "/ai", "/training", "/roles", "/audit"], "admin")
        admin.close()
    browser.close()

print(f"UI_SMOKE_OK target={args.target}")
