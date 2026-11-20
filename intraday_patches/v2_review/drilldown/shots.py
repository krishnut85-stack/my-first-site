# Screenshots of /preview (outside, logged in): F3 sector open + share in the pane, F2 sector open, F1 chip opened, Morning pre-open,
# phone list sheet + share sheet. Real clicks / taps only. The login cookie is never printed or shown (no address bar in headless shots).
import asyncio, sys, os
from playwright.async_api import async_playwright
BASE, OUT = sys.argv[1].rstrip('/'), sys.argv[2]
os.makedirs(OUT, exist_ok=True)


async def ready(pg):
    await pg.wait_for_function('() => window.GIR && GIR.store && GIR.store.ready && GIR.store.ready() && GIR.store.val("sec.board") && GIR.SD', timeout=40000)
    await pg.wait_for_timeout(1500)


async def mclick(pg, sel, nth=0, dx=0.5):
    b = await pg.locator(sel).nth(nth).bounding_box()
    await pg.mouse.click(b['x'] + b['width'] * dx, b['y'] + b['height'] / 2); await pg.wait_for_timeout(500)


async def wheel_to(pg, sel, box):
    for i in range(30):
        r = await pg.evaluate('([s, b]) => { const e = document.querySelector(s), x = document.querySelector(b); if (!e || !x) return null; const a = e.getBoundingClientRect(), w = x.getBoundingClientRect(); return [a.top, a.bottom, w.top, w.bottom, w.left + 200] }', [sel, box])
        if not r or (r[0] >= r[2] and r[1] <= r[3]): return
        await pg.mouse.move(r[4], (r[2] + r[3]) / 2); await pg.mouse.wheel(0, 100 if r[1] > r[3] else -100); await pg.wait_for_timeout(200)


async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        cookies = []
        if 'girtrader.com' in BASE:
            sys.path.insert(0, '/home/globalbot/intraday')
            import sitelogin
            full = sitelogin.make_cookie(); val = full.split(';')[0].split('=', 1)[1]
            cookies = [{'name': 'gir_s', 'value': val, 'domain': 'girtrader.com', 'path': '/', 'secure': True, 'httpOnly': True}]
            del full, val
        for w, h in ((1366, 768), (1600, 900)):
            ctx = await b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1)
            if cookies: await ctx.add_cookies(cookies)
            pg = await ctx.new_page()
            await pg.goto(BASE + '/rotation', wait_until='domcontentloaded'); await ready(pg)
            await wheel_to(pg, '#wtb tr.row[data-s="banks"]', '#winB'); await mclick(pg, '#wtb tr.row[data-s="banks"]')
            await mclick(pg, '.sdl .sd-r', 0, 0.2)
            await pg.screenshot(path=os.path.join(OUT, 'F3_rotation_banks_share_%d.png' % w), mask=[pg.locator('#sh-pnl')])
            await pg.goto(BASE + '/sectors', wait_until='domcontentloaded'); await ready(pg)
            await wheel_to(pg, '#bdb .sec[data-id="auto"] > .srow', '#bdb'); await mclick(pg, '#bdb .sec[data-id="auto"] > .srow', 0, 0.3)
            await mclick(pg, '.sdl .sd-r', 1, 0.2)
            await pg.screenshot(path=os.path.join(OUT, 'F2_sectors_auto_open_%d.png' % w), mask=[pg.locator('#sh-pnl')])
            await pg.goto(BASE + '/desk-hunt', wait_until='domcontentloaded'); await ready(pg)
            await wheel_to(pg, '#secList .srow[data-sec="banks"]', '#secList'); await mclick(pg, '#secList .srow[data-sec="banks"]', 0, 0.3); await mclick(pg, '.sdl .sd-r', 0, 0.2)
            await pg.screenshot(path=os.path.join(OUT, 'F1_desk_chip_open_%d.png' % w), mask=[pg.locator('#sh-pnl')])
            await pg.goto(BASE + '/morning', wait_until='domcontentloaded'); await ready(pg)
            await mclick(pg, '#cards .cd .snm', 0); await mclick(pg, '.sdl .sd-r', 0, 0.2)
            await pg.screenshot(path=os.path.join(OUT, 'Morning_preopen_%d.png' % w), mask=[pg.locator('#sh-pnl')])
            await ctx.close()
        await b.close()
    print('shots in', OUT)

asyncio.run(main())
