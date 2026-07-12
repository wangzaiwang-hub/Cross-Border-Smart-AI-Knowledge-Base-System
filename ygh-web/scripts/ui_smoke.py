from pathlib import Path
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "test-results" / "ui-smoke"
RESULTS.mkdir(parents=True, exist_ok=True)


def inspect(page, base_url: str, paths: list[str], prefix: str) -> None:
    errors: list[str] = []
    page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
    page.on("pageerror", lambda error: errors.append(str(error)))
    for index, path in enumerate(paths):
        page.goto(f"{base_url}{path}", wait_until="networkidle")
        assert page.locator("body").inner_text().strip(), f"empty page: {path}"
        assert "页面未找到" not in page.locator("body").inner_text(), f"unexpected 404: {path}"
        if index in (0, len(paths) - 1):
            page.screenshot(path=RESULTS / f"{prefix}-{index}.png", full_page=True)
    assert not errors, f"browser errors in {prefix}: {errors}"


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    mall = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
    inspect(mall, "http://127.0.0.1:5173", ["/", "/products", "/products/10001", "/knowledge", "/knowledge/k-101", "/ai-service"], "mall-public")
    mall.goto("http://127.0.0.1:5173/login", wait_until="networkidle")
    mall.get_by_role("button", name="登录平台").click()
    mall.wait_for_url("**/workspace/profile")
    inspect(mall, "http://127.0.0.1:5173", ["/workspace/cart", "/workspace/orders", "/workspace/wallet", "/workspace/training", "/workspace/training/courses/c1", "/workspace/training/progress"], "mall-workspace")

    admin = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
    admin.goto("http://127.0.0.1:5174/login", wait_until="networkidle")
    admin.get_by_role("button", name="进入运营后台").click()
    admin.wait_for_url("**/dashboard")
    inspect(admin, "http://127.0.0.1:5174", ["/dashboard", "/products", "/orders", "/knowledge", "/ai", "/training", "/roles", "/audit"], "admin")
    browser.close()

print("UI_SMOKE_OK mall_public=6 mall_workspace=6 admin=8")
