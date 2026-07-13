"""Browser acceptance against a real Gateway and real service data; no route mocking."""

import os
from pathlib import Path
from playwright.sync_api import Page, sync_playwright


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "test-results" / "ui-real-e2e"
RESULTS.mkdir(parents=True, exist_ok=True)


def required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"missing required environment variable: {name}")
    return value


def monitor(page: Page, name: str) -> list[str]:
    failures: list[str] = []
    page.on("pageerror", lambda error: failures.append(f"pageerror: {error}"))
    page.on(
        "response",
        lambda response: failures.append(f"HTTP {response.status}: {response.url}")
        if "/api/" in response.url and response.status >= 400
        else None,
    )
    page.on(
        "console",
        lambda message: failures.append(f"console: {message.text}")
        if message.type == "error" and "favicon" not in message.text.lower()
        else None,
    )
    page.set_default_timeout(15_000)
    return failures


def assert_page(page: Page, url: str, label: str, screenshot: bool = False) -> None:
    page.goto(url, wait_until="networkidle")
    body = page.locator("body").inner_text().strip()
    assert body, f"empty page: {url}"
    assert "页面未找到" not in body, f"unexpected frontend 404: {url}"
    assert "Internal Server Error" not in body, f"server error rendered: {url}"
    if screenshot:
        page.screenshot(path=RESULTS / f"{label}.png", full_page=True)


def login(page: Page, base: str, username: str, password: str, admin: bool) -> None:
    page.goto(f"{base}/login", wait_until="networkidle")
    page.get_by_label("工作账号" if admin else "账号").fill(username)
    page.get_by_label("登录密码" if admin else "密码").fill(password)
    with page.expect_response(lambda response: response.url.endswith("/api/v1/auth/login")) as login_response:
        page.get_by_role("button", name="进入运营后台" if admin else "登录平台").click()
    assert login_response.value.status == 200, f"real login failed: HTTP {login_response.value.status}"
    page.wait_for_url(f"**/{'dashboard' if admin else 'workspace/profile'}")


mall_url = os.getenv("YGH_E2E_MALL_URL", "http://127.0.0.1:5173").rstrip("/")
admin_url = os.getenv("YGH_E2E_ADMIN_URL", "http://127.0.0.1:5174").rstrip("/")
employee_user = required("YGH_E2E_EMPLOYEE_USERNAME")
employee_password = required("YGH_E2E_EMPLOYEE_PASSWORD")
admin_user = required("YGH_E2E_ADMIN_USERNAME")
admin_password = required("YGH_E2E_ADMIN_PASSWORD")

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)

    mall = browser.new_page(viewport={"width": 1440, "height": 1000})
    mall_failures = monitor(mall, "mall")
    for index, path in enumerate(("/", "/products", "/knowledge")):
        assert_page(mall, mall_url + path, f"mall-public-{index}", index == 0)
    login(mall, mall_url, employee_user, employee_password, admin=False)
    for index, path in enumerate((
        "/workspace/profile", "/workspace/cart", "/workspace/orders", "/workspace/wallet",
        "/workspace/notifications", "/workspace/training", "/workspace/training/progress", "/ai-service",
    )):
        assert_page(mall, mall_url + path, f"mall-authenticated-{index}", index in (0, 5))
    assert not mall_failures, "mall real E2E failures:\n" + "\n".join(mall_failures)
    mall.close()

    admin = browser.new_page(viewport={"width": 1440, "height": 1000})
    admin_failures = monitor(admin, "admin")
    login(admin, admin_url, admin_user, admin_password, admin=True)
    for index, path in enumerate((
        "/dashboard", "/users", "/organization", "/products", "/inventory", "/orders", "/wallet",
        "/knowledge", "/ai", "/training", "/notifications", "/roles", "/system", "/audit",
    )):
        assert_page(admin, admin_url + path, f"admin-{index}", index in (0, 7, 9))
    assert not admin_failures, "admin real E2E failures:\n" + "\n".join(admin_failures)
    admin.close()
    browser.close()

print(f"UI_REAL_E2E_OK mall={mall_url} admin={admin_url} screenshots={RESULTS}")
