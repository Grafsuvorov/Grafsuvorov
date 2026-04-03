from playwright.sync_api import sync_playwright
import pandas as pd

url = "https://fbref.com/en/matches/93e6be72/Aston-Villa-Chelsea-March-4-2024-Premier-League"

with sync_playwright() as p:

    browser = p.chromium.launch(headless=False)

    page = browser.new_page()

    page.goto(url, timeout=60000)

    page.wait_for_timeout(5000)

    html = page.content()

    tables = pd.read_html(html)

    print("Tables:", len(tables))

    if tables:
        print(tables[0].head())

    browser.close()