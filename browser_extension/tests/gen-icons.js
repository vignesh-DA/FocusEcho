/**
 * @fileoverview Generate placeholder extension icons as valid PNG files.
 * Pure Node.js — no npm dependencies. Uses built-in zlib for deflate.
 *
 * Color: #0D9488 (teal-600) — FocusEcho brand placeholder.
 * Sizes: 16, 32, 48, 128 px (all sizes referenced in manifest.json).
 *
 * Usage:  node browser_extension/tests/gen-icons.js
 */

import { deflateSync } from 'zlib';
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ICON_DIR = join(__dirname, '..', 'src', 'assets', 'icons');

// FocusEcho teal placeholder: rgb(13, 148, 136) = #0D9488
const R = 13, G = 148, B = 136;
const SIZES = [16, 32, 48, 128];

// ---------------------------------------------------------------------------
// CRC-32 (required by PNG spec for chunk integrity)
// ---------------------------------------------------------------------------
function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (const byte of buf) {
    c ^= byte;
    for (let i = 0; i < 8; i++) {
      c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
  }
  return (c ^ 0xFFFFFFFF) >>> 0;
}

// ---------------------------------------------------------------------------
// PNG chunk builder
// ---------------------------------------------------------------------------
function pngChunk(type, data) {
  const typeBuf = Buffer.from(type, 'ascii');
  const lenBuf  = Buffer.alloc(4);
  const crcBuf  = Buffer.alloc(4);
  lenBuf.writeUInt32BE(data.length, 0);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([lenBuf, typeBuf, data, crcBuf]);
}

// ---------------------------------------------------------------------------
// Build a solid-colour PNG with raw (unfiltered) scanlines
// ---------------------------------------------------------------------------
function makeSolidPNG(size, r, g, b) {
  // 8-byte PNG signature
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR: width(4) height(4) bitDepth(1) colorType(1=palette,2=RGB) comp(1) filter(1) interlace(1)
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8]  = 8; // bit depth
  ihdr[9]  = 2; // colour type: RGB (truecolour)
  ihdr[10] = 0; // compression method
  ihdr[11] = 0; // filter method
  ihdr[12] = 0; // interlace: none

  // Raw pixel data: each row = filter byte (0 = None) + width*3 bytes (RGB)
  const rowLen = 1 + size * 3;
  const raw    = Buffer.alloc(size * rowLen, 0);
  for (let y = 0; y < size; y++) {
    const base = y * rowLen;
    raw[base] = 0; // filter: None
    for (let x = 0; x < size; x++) {
      raw[base + 1 + x * 3]     = r;
      raw[base + 1 + x * 3 + 1] = g;
      raw[base + 1 + x * 3 + 2] = b;
    }
  }

  const idat = deflateSync(raw);

  return Buffer.concat([
    sig,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', idat),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

// ---------------------------------------------------------------------------
// Generate icons
// ---------------------------------------------------------------------------
mkdirSync(ICON_DIR, { recursive: true });

for (const size of SIZES) {
  const path = join(ICON_DIR, `icon-${size}.png`);
  const png  = makeSolidPNG(size, R, G, B);
  writeFileSync(path, png);
  console.log(`  created ${path}  (${png.length} bytes)`);
}

console.log(`\nAll ${SIZES.length} icons written to: ${ICON_DIR}`);
console.log('Colour: #0D9488 (teal placeholder — replace with real Echo mascot icons in Phase 2)');
