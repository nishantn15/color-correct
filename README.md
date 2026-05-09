# color-correct

Underwater video color correction in the browser. Single-file PWA. No app to install. **No upload — everything runs on your device.**

> Live: <https://nishantn15.github.io/color-correct/>

## What it does

Underwater footage loses red first, then orange, then yellow with depth — leaving everything green-cyan. This tool runs scene-adaptive color correction (auto white-balance, Ancuti red-channel recovery, per-channel tone LUT, temporal smoothing across frames) on your video, **directly in your browser** using:

- **WebCodecs** — hardware video decode/encode (calls the same MediaCodec stack the system uses)
- **WebGL2 fragment shader** — color processing on the GPU
- **mp4-muxer** — wraps the result back into a standard `.mp4`

Output is H.264 (High @ L5.2, yuv420p, TV range) at ~25 Mbps, with the original audio passed through unchanged. Works with H.264 and HEVC source files (anything modern Chrome can decode).

## Files

```
color-correct/
├── index.html        ← the app
├── probe.html        ← WebCodecs capability check (open this first)
├── launch.sh         ← local dev server + GitHub Pages publish helper
└── README.md
```

## Run locally

```bash
bash launch.sh probe   # capability probe in your browser
bash launch.sh         # main app
bash launch.sh stop    # kill the local server
```

The script starts `python3 -m http.server 8000`, then opens the page with a `?v=<timestamp>` cache-buster (Chrome/Samsung Internet cache HTML aggressively).

## Publish to GitHub Pages

```bash
bash launch.sh publish "your commit message"
```

Syncs the play copy into `publish/`, commits, pushes. Pages rebuilds in ~30 s.

## What the probe tests

`probe.html` runs `VideoDecoder.isConfigSupported()` and `VideoEncoder.isConfigSupported()` for HEVC, H.264, and AV1 at 4K and 1080p. The verdict at the bottom says GO / partial / STOP based on what hardware paths are available.

If your phone says GO at 4K, the main app will run real-time on hardware.

## How the main app works

```
input mp4
  → mp4box.js (demux)
  → VideoDecoder (HW)         ─┐
                                ├→ VideoFrame
                                ▼
  → WebGL2 fragment shader (color processing on GPU)
                                │
                                ▼
  → VideoEncoder (HW H.264)
  → mp4-muxer (audio passed through unchanged)
  → download blob
```

### Color algorithm

Per frame:

1. **Stats on a 480p downsample** — means, gray-world WB gains, 1st/99th percentile bounds.
2. **Temporal EMA across frames** — smooths the per-frame stats so colors don't flicker.
3. **Per-channel LUT** — bakes WB gain × percentile stretch × subtle S-curve into a 256-entry uint8 lookup.
4. **Ancuti red recovery** — `R' = R + α(meanG − meanR)(1 − R)·meanG`, computed in the GPU shader using mean-G as the cross-channel proxy.
5. **Strength blend** — `out = mix(orig, corrected, slider/100)`.

The blue channel gets a similar mild recovery only if blue is significantly depleted vs green (handles green/lake water in addition to tropical blue).

## Why a PWA

- Runs the same hardware codecs as a native app.
- No App Store, no install, no permissions.
- Iterating is just edit-and-refresh, like any web project.
- Cross-device — works on Android, iOS Safari (17.4+), desktop Chrome.
- All processing is local. Your video never leaves the device.

## Browser support

| Browser | Status |
|---|---|
| Chrome ≥ 94 (Android, desktop) | full |
| Edge ≥ 94 | full |
| Samsung Internet ≥ 26 | full |
| Safari ≥ 17.4 (iOS, macOS) | full |
| Firefox | partial — WebCodecs is rolling out gradually; check probe |

## Known limitations

- **Output is H.264 8-bit yuv420p** even from 10-bit HEVC source. Hardware HEVC encoders that expose 10-bit output to WebCodecs aren't widely available yet on phones.
- **Output bitrate is fixed at ~25 Mbps VBR** for video and the source AAC bitrate for audio. Per-clip override isn't exposed in the UI yet.
- **Long files (>5 min at 4K)** may strain memory. The pipeline streams but the muxer holds the output in `ArrayBufferTarget` until finalize. If you hit OOM, render in segments.
- **Some HEVC variants** (Main10 with HDR/HLG/PQ transfer) won't tone-map automatically. Output assumes BT.709 SDR.

## Development

The entire app is one HTML file. CSS and JS are inline; only mp4box.js and mp4-muxer come from CDN (pinned versions).

## License

MIT.
