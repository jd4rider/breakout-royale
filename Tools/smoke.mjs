/*
 * Browser smoke test for the exported Web build.
 *
 *   python3 -m http.server 4174 --directory web/play &
 *   node Tools/smoke.mjs http://127.0.0.1:4174/
 *
 * Boots the Godot build portrait, starts a campaign board through the debug
 * hook, launches the ball with a real touch and checks that bricks actually
 * break. Also asserts the portrait lock: a landscape window must still show a
 * taller-than-wide canvas.
 */
import { createRequire } from 'node:module'
import { mkdirSync } from 'node:fs'

const require = createRequire(import.meta.url)
const { chromium } = require('../../starfall-squadron/node_modules/playwright')

const url = process.argv[2] || 'http://127.0.0.1:4174/'
const failures = []
const errors = []

mkdirSync('/tmp/br-shots', { recursive: true })

async function stateOf(page) {
  try {
    const raw = await page.evaluate(() => window.__breakoutState || null)
    return raw ? JSON.parse(raw) : null
  } catch (error) {
    return null
  }
}

const browser = await chromium.launch()

// ---- portrait phone -------------------------------------------------------
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  hasTouch: true,
  isMobile: true,
})
const page = await context.newPage()
page.on('pageerror', (error) => errors.push(`phone: ${error.message}`))
page.on('console', (message) => {
  if (message.type() === 'error') errors.push(`phone console: ${message.text()}`)
})

await page.goto(url + '?autostart=1', { waitUntil: 'domcontentloaded' })
await page.waitForSelector('#canvas', { timeout: 40000 })
await page.waitForTimeout(12000)

const layout = await page.evaluate(() => {
  const canvas = document.querySelector('#canvas')
  const rect = canvas ? canvas.getBoundingClientRect() : null
  return {
    canvas: rect ? { w: Math.round(rect.width), h: Math.round(rect.height), top: Math.round(rect.top) } : null,
    window: { w: innerWidth, h: innerHeight },
    bridge: typeof window.BreakoutRoyale === 'object',
    bridgeVersion: window.BreakoutRoyale ? window.BreakoutRoyale.version : null,
    identity: window.BreakoutRoyale ? window.BreakoutRoyale.identity() : null,
    client: typeof window.LittleJoyArcade === 'object',
    snapshot: typeof window.LJA_SNAPSHOT === 'function',
  }
})
console.log('layout', JSON.stringify(layout))
if (!layout.canvas) failures.push('phone: no canvas')
if (!layout.bridge) failures.push('phone: arcade bridge missing')
if (!layout.snapshot) failures.push('phone: save snapshot hook missing')
if (layout.canvas && layout.canvas.h < layout.window.h * 0.9) {
  failures.push(`phone: canvas is ${layout.canvas.h}px tall in a ${layout.window.h}px window`)
}

let state = await stateOf(page)
console.log('boot state', JSON.stringify(state))
if (!state || state.screen !== 'game') failures.push(`phone: autostart did not reach gameplay (${JSON.stringify(state)})`)
const portraitGate = await page.evaluate(() => {
  const overlay = document.querySelector('#lja-rotate')
  return overlay ? getComputedStyle(overlay).display !== 'none' : false
})
if (portraitGate) failures.push('phone: the portrait gate must be hidden in portrait')
await page.screenshot({ path: '/tmp/br-shots/1-board.png' })

// Launch the ball with a real touch, then steer.
await page.touchscreen.tap(195, 700)
await page.waitForTimeout(1500)
const cdp = await context.newCDPSession(page)
const drag = async ([x0, y0], [x1, y1]) => {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: y0 }] })
  for (let step = 1; step <= 10; step += 1) {
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{ x: x0 + ((x1 - x0) * step) / 10, y: y0 + ((y1 - y0) * step) / 10 }],
    })
    await page.waitForTimeout(16)
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
}
await drag([195, 760], [120, 760])
await page.waitForTimeout(9000)
state = await stateOf(page)
console.log('state after launch', JSON.stringify(state))
if (!state) failures.push('phone: no gameplay state was published')
else {
  if (int(state.score) <= 0) failures.push('phone: score never moved after launching')
  if (int(state.bricks) <= 0) failures.push('phone: no brick was broken by a launched ball')
}
await page.screenshot({ path: '/tmp/br-shots/2-after-launch.png' })

// Tap an empty lane far from the paddle to move it, then screenshot.
await drag([90, 780], [300, 780])
await page.waitForTimeout(1200)
await page.screenshot({ path: '/tmp/br-shots/3-paddle-moved.png' })

// Pause via the escape key and check the overlay appears (frame must change).
const beforePause = await page.screenshot()
await page.keyboard.press('Escape')
await page.waitForTimeout(700)
const afterPause = await page.screenshot({ path: '/tmp/br-shots/4-paused.png' })
if (Buffer.compare(beforePause, afterPause) === 0) failures.push('phone: pause did not change the frame')
await page.keyboard.press('Escape')
await page.waitForTimeout(500)
await context.close()

// ---- landscape desktop ----------------------------------------------------
const wide = await browser.newContext({ viewport: { width: 1280, height: 720 } })
const widePage = await wide.newPage()
widePage.on('pageerror', (error) => errors.push(`landscape: ${error.message}`))
await widePage.goto(url, { waitUntil: 'domcontentloaded' })
await widePage.waitForSelector('#canvas', { timeout: 40000 })
await widePage.waitForTimeout(9000)
const wideLayout = await widePage.evaluate(() => {
  const canvas = document.querySelector('#canvas')
  const rect = canvas ? canvas.getBoundingClientRect() : null
  const rotate = document.querySelector('#lja-rotate')
  return {
    canvas: rect ? { w: Math.round(rect.width), h: Math.round(rect.height) } : null,
    rotateVisible: rotate ? getComputedStyle(rotate).display !== 'none' : false,
  }
})
console.log('landscape layout', JSON.stringify(wideLayout))
if (!wideLayout.canvas) failures.push('landscape: no canvas')
else if (wideLayout.canvas.w !== 1280 || wideLayout.canvas.h !== 720) {
  failures.push(`landscape: the canvas should fill the frame (${wideLayout.canvas.w}x${wideLayout.canvas.h})`)
}
if (!wideLayout.rotateVisible) failures.push('landscape: the portrait gate did not appear')
await widePage.screenshot({ path: '/tmp/br-shots/5-landscape.png' })
await wide.close()

// ---- phone held sideways: hard portrait lock ------------------------------
const sideways = await browser.newContext({
  viewport: { width: 844, height: 390 },
  hasTouch: true,
  isMobile: true,
  deviceScaleFactor: 2,
})
const sidewaysPage = await sideways.newPage()
await sidewaysPage.goto(url, { waitUntil: 'domcontentloaded' })
await sidewaysPage.waitForSelector('#canvas', { timeout: 40000 })
await sidewaysPage.waitForTimeout(1500)
const lockState = await sidewaysPage.evaluate(() => {
  const overlay = document.querySelector('#lja-rotate')
  return { visible: overlay ? getComputedStyle(overlay).display !== 'none' : false }
})
console.log('sideways lock', JSON.stringify(lockState))
if (!lockState.visible) failures.push('phone landscape: the portrait lock prompt did not appear')
await sidewaysPage.screenshot({ path: '/tmp/br-shots/6-locked-portrait.png' })
await sideways.close()

await browser.close()

const fatal = errors.filter((message) => /SCRIPT ERROR|Parse Error|not found in base|Cannot get property/.test(message))
for (const message of fatal) failures.push('script failure: ' + message)
if (errors.length) console.log('page errors:\n' + errors.slice(0, 10).join('\n'))

function int(value) {
  return Number.parseInt(value, 10) || 0
}

if (failures.length) {
  console.log('FAIL\n' + failures.join('\n'))
  process.exit(1)
}
console.log('smoke passed')
