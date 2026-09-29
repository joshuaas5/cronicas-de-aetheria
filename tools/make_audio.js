// Renders Aetheria's music, ambience beds and sound effects to WAV.
// Usage: node tools/make_audio.js   (run from the project root)
const fs = require('fs');
const path = require('path');

const SR = 44100;
const OUT = path.resolve(__dirname, '..', 'assets', 'audio');
let seed = 1;
const rand = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
const noise = () => rand() * 2 - 1;

function note(n) {
  const m = /^([A-G])([#b]?)(-?\d)$/.exec(n);
  const b = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);
  return 440 * Math.pow(2, ((+m[3] + 1) * 12 + b - 69) / 12);
}

// ---------------------------------------------------------------- buffers
class Buf {
  constructor(sec) { this.n = Math.ceil(sec * SR); this.L = new Float32Array(this.n); this.R = new Float32Array(this.n); }
  add(i, v, pan = 0) {
    if (i < 0 || i >= this.n) return;
    this.L[i] += v * Math.min(1, 1 - pan); this.R[i] += v * Math.min(1, 1 + pan);
  }
}

// ---------------------------------------------------------------- instruments
function env(t, dur, a, r) { if (t < a) return t / a; if (t > dur) return Math.max(0, 1 - (t - dur) / r); return 1; }

function pluck(buf, t0, f, dur, vol, pan = 0, bright = 0.5) {
  // Karplus-Strong string
  const p = Math.max(2, Math.round(SR / f));
  const line = new Float32Array(p);
  for (let i = 0; i < p; i++) line[i] = noise() * (0.5 + bright * 0.5);
  const len = Math.floor((dur + 1.2) * SR); let idx = 0; let prev = 0;
  const damp = 0.996 - (1 - bright) * 0.004;
  const s0 = Math.floor(t0 * SR);
  for (let i = 0; i < len; i++) {
    const cur = line[idx];
    const nv = damp * 0.5 * (cur + prev); prev = cur; line[idx] = nv; idx = (idx + 1) % p;
    const fade = i / SR > dur ? Math.max(0, 1 - (i / SR - dur) / 1.2) : 1;
    buf.add(s0 + i, cur * vol * fade, pan);
  }
}

function flute(buf, t0, f, dur, vol, pan = 0) {
  const s0 = Math.floor(t0 * SR), len = Math.floor((dur + 0.3) * SR);
  let ph = 0, lp = 0;
  for (let i = 0; i < len; i++) {
    const t = i / SR;
    const vib = 1 + 0.006 * Math.sin(t * 2 * Math.PI * 5.2) * Math.min(1, t * 2);
    ph += f * vib / SR;
    const e = env(t, dur, 0.06, 0.25);
    lp += (noise() - lp) * 0.08;
    const v = Math.sin(2 * Math.PI * ph) * 0.8 + Math.sin(4 * Math.PI * ph) * 0.12 + lp * 0.05;
    buf.add(s0 + i, v * e * vol, pan);
  }
}

function bell(buf, t0, f, dur, vol, pan = 0) {
  const s0 = Math.floor(t0 * SR), len = Math.floor((dur + 2.5) * SR);
  for (let i = 0; i < len; i++) {
    const t = i / SR;
    const e = Math.exp(-t * 1.6) * Math.min(1, t * 400);
    const mod = Math.sin(2 * Math.PI * f * 3.5 * t) * 2.2 * Math.exp(-t * 3);
    const v = Math.sin(2 * Math.PI * f * t + mod) * 0.7 + Math.sin(2 * Math.PI * f * 2.01 * t) * 0.15 * Math.exp(-t * 2.5);
    buf.add(s0 + i, v * e * vol, pan);
  }
}

function pad(buf, t0, freqs, dur, vol, cutoff = 0.05, pan = 0) {
  const s0 = Math.floor(t0 * SR), len = Math.floor((dur + 1.5) * SR);
  const phases = freqs.flatMap(f => [[f * 0.997, rand()], [f * 1.003, rand()]]);
  let lpL = 0;
  for (let i = 0; i < len; i++) {
    const t = i / SR; let v = 0;
    for (const p of phases) { p[1] += p[0] / SR; v += (p[1] % 1) * 2 - 1; }
    v /= phases.length;
    lpL += (v - lpL) * cutoff;
    const e = env(t, dur, 0.8, 1.5);
    buf.add(s0 + i, lpL * e * vol, pan + Math.sin(t * 0.7) * 0.2);
  }
}

function bass(buf, t0, f, dur, vol) {
  const s0 = Math.floor(t0 * SR), len = Math.floor((dur + 0.2) * SR);
  for (let i = 0; i < len; i++) {
    const t = i / SR;
    const e = env(t, dur, 0.01, 0.15) * (0.7 + 0.3 * Math.exp(-t * 4));
    const v = Math.sin(2 * Math.PI * f * t) + 0.25 * Math.sin(4 * Math.PI * f * t);
    buf.add(s0 + i, v * e * vol, 0);
  }
}

function strings(buf, t0, f, dur, vol, pan = 0, cutoff = 0.12) {
  const s0 = Math.floor(t0 * SR), len = Math.floor((dur + 0.4) * SR);
  let p1 = 0, p2 = 0.3, lp = 0;
  for (let i = 0; i < len; i++) {
    const t = i / SR;
    const vib = 1 + 0.004 * Math.sin(t * 2 * Math.PI * 5.5);
    p1 += f * vib * 0.998 / SR; p2 += f * vib * 1.002 / SR;
    const v = ((p1 % 1) * 2 - 1 + (p2 % 1) * 2 - 1) * 0.5;
    lp += (v - lp) * cutoff;
    buf.add(s0 + i, lp * env(t, dur, 0.03, 0.3) * vol, pan);
  }
}

function kick(buf, t0, vol) {
  const s0 = Math.floor(t0 * SR);
  for (let i = 0; i < SR * 0.4; i++) {
    const t = i / SR; const f = 50 + 90 * Math.exp(-t * 25);
    buf.add(s0 + i, Math.sin(2 * Math.PI * f * t) * Math.exp(-t * 9) * vol);
  }
}

function drum(buf, t0, vol, f = 110) {
  const s0 = Math.floor(t0 * SR);
  let lp = 0;
  for (let i = 0; i < SR * 0.35; i++) {
    const t = i / SR; lp += (noise() - lp) * 0.2;
    buf.add(s0 + i, (Math.sin(2 * Math.PI * f * t * (1 + Math.exp(-t * 30))) * 0.7 + lp * 0.5) * Math.exp(-t * 12) * vol);
  }
}

function shaker(buf, t0, vol, pan = 0.3) {
  const s0 = Math.floor(t0 * SR); let hp = 0, last = 0;
  for (let i = 0; i < SR * 0.08; i++) {
    const n = noise(); hp = 0.8 * (hp + n - last); last = n;
    buf.add(s0 + i, hp * Math.exp(-i / SR * 50) * vol, pan);
  }
}

// ---------------------------------------------------------------- reverb (Freeverb-lite)
function reverb(buf, mix = 0.28, room = 0.84, damp = 0.35) {
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  const aps = [556, 441, 341, 225];
  const proc = (inp, spread) => {
    const out = new Float32Array(inp.length);
    const cs = combs.map(c => ({ b: new Float32Array(c + spread), i: 0, f: 0 }));
    const as = aps.map(a => ({ b: new Float32Array(a + spread), i: 0 }));
    for (let n = 0; n < inp.length; n++) {
      const x = inp[n] * 0.015; let s = 0;
      for (const c of cs) { const y = c.b[c.i]; c.f = y * (1 - damp) + c.f * damp; c.b[c.i] = x + c.f * room; c.i = (c.i + 1) % c.b.length; s += y; }
      for (const a of as) { const y = a.b[a.i]; const v = -s + y; a.b[a.i] = s + y * 0.5; a.i = (a.i + 1) % a.b.length; s = v; }
      out[n] = s;
    }
    return out;
  };
  const wl = proc(buf.L, 0), wr = proc(buf.R, 23);
  for (let n = 0; n < buf.n; n++) { buf.L[n] = buf.L[n] * (1 - mix * 0.5) + wl[n] * mix * 3; buf.R[n] = buf.R[n] * (1 - mix * 0.5) + wr[n] * mix * 3; }
}

// ---------------------------------------------------------------- output
function write(file, buf, from = 0, to = buf.n, gain = 0.9) {
  let peak = 0;
  for (let i = from; i < to; i++) peak = Math.max(peak, Math.abs(buf.L[i]), Math.abs(buf.R[i]));
  const g = peak > 0 ? gain / peak : 1;
  const n = to - from;
  const data = Buffer.alloc(44 + n * 4);
  data.write('RIFF', 0); data.writeUInt32LE(36 + n * 4, 4); data.write('WAVE', 8); data.write('fmt ', 12);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(2, 22); data.writeUInt32LE(SR, 24);
  data.writeUInt32LE(SR * 4, 28); data.writeUInt16LE(4, 32); data.writeUInt16LE(16, 34); data.write('data', 36); data.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) {
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, buf.L[from + i] * g)) * 32767), 44 + i * 4);
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, buf.R[from + i] * g)) * 32767), 46 + i * 4);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, data);
  console.log('wrote', path.relative(OUT, file), (n / SR).toFixed(1) + 's');
}

// ---------------------------------------------------------------- songs
// Each song renders two loops; the second (which carries the first loop's reverb tail) is saved,
// so the file loops seamlessly.
function song(name, bpm, beats, fn, gain = 0.8, rev = 0.3) {
  const beat = 60 / bpm, loopSec = beats * beat;
  const buf = new Buf(loopSec * 2 + 4);
  for (let pass = 0; pass < 2; pass++) fn(buf, pass * loopSec, beat);
  reverb(buf, rev);
  write(path.join(OUT, 'music', name + '.wav'), buf, Math.floor(loopSec * SR), Math.floor(loopSec * 2 * SR), gain);
}

const seq = (s) => s.trim().split(/\s+/);

function playLine(buf, t0, beat, line, stepBeats, inst) {
  const toks = seq(line);
  for (let i = 0; i < toks.length; i++) {
    const tk = toks[i];
    if (tk === '-' || tk === '.') continue;
    let len = 1; while (toks[i + len] === '.') len++;
    inst(t0 + i * stepBeats * beat, note(tk), len * stepBeats * beat);
  }
}

function makeMusic() {
  // Vila Lumen — pastoral D major: flute over harp arpeggios
  song('village', 100, 32, (b, t0, beat) => {
    const mel = 'F#5 . A5 . B5 A5 F#5 . E5 . D5 E5 F#5 . . . G5 . B5 . D6 B5 A5 . F#5 . E5 F#5 D5 . . . ' +
                'A5 . B5 . D6 . B5 A5 G5 . F#5 . E5 . . . F#5 . G5 A5 B5 . A5 G5 F#5 . E5 . D5 . . .';
    playLine(b, t0, beat, mel, 0.5, (t, f, d) => flute(b, t, f, d * 0.95, 0.22, 0.1));
    const chords = [['D3', 'F#3', 'A3', 'D4'], ['G2', 'B2', 'D3', 'G3'], ['B2', 'D3', 'F#3', 'B3'], ['A2', 'C#3', 'E3', 'A3'],
                    ['D3', 'F#3', 'A3', 'D4'], ['G2', 'B2', 'D3', 'G3'], ['E3', 'G3', 'B3', 'E4'], ['A2', 'C#3', 'E3', 'A3']];
    chords.forEach((c, k) => {
      const tc = t0 + k * 4 * beat;
      bass(b, tc, note(c[0]) / 2, beat * 3.5, 0.25);
      pad(b, tc, c.slice(1).map(note), beat * 4, 0.05, 0.03);
      for (let s = 0; s < 8; s++) pluck(b, tc + s * beat * 0.5, note(c[[0, 1, 2, 3, 2, 1, 2, 3][s]]) * 2, beat * 0.6, 0.16, -0.3, 0.6);
      for (let s = 0; s < 4; s++) shaker(b, tc + s * beat + beat * 0.5, 0.05);
    });
  }, 0.8, 0.32);

  // Bosque Sussurrante — A dorian, mysterious flute, low pad, frame drum
  song('forest', 84, 32, (b, t0, beat) => {
    const mel = 'E5 . . G5 A5 . B5 . C6 . B5 A5 G5 . E5 . D5 . . E5 G5 . A5 . G5 . E5 . D5 . . . ' +
                'E5 . . G5 A5 . B5 . D6 . C6 B5 A5 . G5 . A5 . G5 E5 D5 . E5 . A4 . . . . . . .';
    playLine(b, t0, beat, mel, 0.5, (t, f, d) => flute(b, t, f, d, 0.2, -0.1));
    const chords = [['A2', 'C3', 'E3'], ['F2', 'A2', 'C3'], ['G2', 'B2', 'D3'], ['E2', 'G2', 'B2'], ['A2', 'C3', 'E3'], ['F2', 'A2', 'C3'], ['D2', 'F2', 'A2'], ['E2', 'G#2', 'B2']];
    chords.forEach((c, k) => {
      const tc = t0 + k * 4 * beat;
      pad(b, tc, c.map(n => note(n) * 2), beat * 4, 0.08, 0.025);
      bass(b, tc, note(c[0]), beat * 3.8, 0.2);
      for (let s = 0; s < 4; s++) pluck(b, tc + s * beat + beat * 0.25, note(c[s % 3]) * 4, beat, 0.08, 0.4, 0.3);
      drum(b, tc, 0.18, 90); drum(b, tc + beat * 2.5, 0.1, 100);
    });
  }, 0.8, 0.38);

  // Taverna — G major jig with lute, fiddle and drum
  song('tavern', 132, 32, (b, t0, beat) => {
    const mel = 'G5 B5 D6 B5 G5 B5 A5 F#5 D5 F#5 A5 F#5 D5 E5 F#5 A5 G5 B5 D6 B5 E6 D6 B5 G5 A5 F#5 D5 E5 G5 . G4 . ' +
                'B5 . D6 . G6 . F#6 E6 D6 . B5 . A5 . . . G5 A5 B5 G5 E5 F#5 G5 E5 D5 E5 F#5 D5 G5 . . .';
    playLine(b, t0, beat, mel, 0.5, (t, f, d) => strings(b, t, f, d * 0.85, 0.16, 0.25, 0.2));
    const chords = [['G2', 'B2', 'D3'], ['D2', 'F#2', 'A2'], ['C2', 'E2', 'G2'], ['D2', 'F#2', 'A2'], ['G2', 'B2', 'D3'], ['E2', 'G2', 'B2'], ['C2', 'E2', 'G2'], ['D2', 'F#2', 'A2']];
    chords.forEach((c, k) => {
      const tc = t0 + k * 4 * beat;
      for (let s = 0; s < 4; s++) {
        bass(b, tc + s * beat, note(c[0]) * (s % 2 ? 1.5 : 1), beat * 0.45, 0.25);
        pluck(b, tc + s * beat + beat * 0.5, note(c[1]) * 2, beat * 0.3, 0.14, -0.35, 0.8);
        pluck(b, tc + s * beat + beat * 0.5, note(c[2]) * 2, beat * 0.3, 0.12, -0.35, 0.8);
        drum(b, tc + s * beat, s % 2 ? 0.12 : 0.2, 130);
        shaker(b, tc + s * beat + beat * 0.5, 0.05);
      }
    });
  }, 0.8, 0.22);

  // Chefe — D minor, driving strings, low brass, war drums
  song('boss', 150, 32, (b, t0, beat) => {
    const mel = 'D5 D5 F5 D5 A5 . G5 F5 E5 E5 G5 E5 C6 . A5 G5 D5 D5 F5 D5 A5 . A#5 A5 G5 F5 E5 C5 D5 . . . ' +
                'F5 F5 A5 F5 D6 . C6 A#5 A5 A5 C6 A5 E6 . D6 C6 A#5 . A5 . G5 . F5 . E5 . C#5 . D5 . . .';
    playLine(b, t0, beat, mel, 0.5, (t, f, d) => { strings(b, t, f, d * 0.8, 0.14, 0.2, 0.3); strings(b, t, f / 2, d * 0.8, 0.08, -0.2, 0.2); });
    const roots = ['D2', 'C2', 'A#1', 'A1', 'D2', 'F2', 'G2', 'A1'];
    roots.forEach((r, k) => {
      const tc = t0 + k * 4 * beat;
      for (let s = 0; s < 8; s++) strings(b, tc + s * beat * 0.5, note(r) * 2, beat * 0.3, 0.09, -0.4, 0.15);
      pad(b, tc, [note(r) * 2, note(r) * 3], beat * 4, 0.06, 0.04);
      kick(b, tc, 0.5); kick(b, tc + beat * 1.5, 0.35); kick(b, tc + beat * 2, 0.5); kick(b, tc + beat * 3.5, 0.3);
      drum(b, tc + beat, 0.25, 180); drum(b, tc + beat * 3, 0.25, 180);
      for (let s = 0; s < 8; s++) shaker(b, tc + s * beat * 0.5, 0.06, -0.2);
    });
  }, 0.85, 0.2);

  // Santuário / título — E major, bells over a shimmering pad
  const sanct = (b, t0, beat) => {
    const mel = 'B5 . . . G#5 . E5 . F#5 . . . B4 . . . C#6 . . . B5 . G#5 . A5 . F#5 . E5 . . . ' +
                'G#5 . . . B5 . E6 . D#6 . . . B5 . . . C#6 . B5 . A5 . G#5 . F#5 . . . E5 . . .';
    playLine(b, t0, beat, mel, 0.5, (t, f, d) => bell(b, t, f, d, 0.16, Math.sin(t) * 0.4));
    const chords = [['E3', 'G#3', 'B3'], ['C#3', 'E3', 'G#3'], ['A2', 'C#3', 'E3'], ['B2', 'D#3', 'F#3'], ['E3', 'G#3', 'B3'], ['G#2', 'B2', 'D#3'], ['A2', 'C#3', 'E3'], ['B2', 'D#3', 'F#3']];
    chords.forEach((c, k) => {
      const tc = t0 + k * 4 * beat;
      pad(b, tc, c.map(n => note(n) * 2), beat * 4, 0.1, 0.02);
      bass(b, tc, note(c[0]) / 2, beat * 3.8, 0.14);
      for (let s = 0; s < 8; s++) pluck(b, tc + s * beat * 0.5, note(c[s % 3]) * 4, beat * 0.8, 0.07, 0.3 * Math.sin(s), 0.4);
    });
  };
  song('sanctuary', 70, 32, sanct, 0.8, 0.45);
  song('title', 70, 32, sanct, 0.8, 0.45);

  // Mapa — C major music box
  song('map', 92, 32, (b, t0, beat) => {
    const mel = 'C6 . E6 . G6 . C7 . B6 . G6 . A6 . . . F6 . A6 . C7 . A6 . G6 . E6 . D6 . . . ' +
                'E6 . G6 . C7 . E7 . D7 . B6 . C7 . . . A6 . F6 . D6 . B5 . C6 . E6 . C6 . . .';
    playLine(b, t0, beat, mel, 0.5, (t, f, d) => bell(b, t, f, d * 0.5, 0.12, 0.2));
    const chords = [['C3', 'E3', 'G3'], ['A2', 'C3', 'E3'], ['F2', 'A2', 'C3'], ['G2', 'B2', 'D3'], ['C3', 'E3', 'G3'], ['E2', 'G2', 'B2'], ['F2', 'A2', 'C3'], ['G2', 'B2', 'D3']];
    chords.forEach((c, k) => {
      const tc = t0 + k * 4 * beat;
      pad(b, tc, c.map(n => note(n) * 2), beat * 4, 0.07, 0.03);
      for (let s = 0; s < 4; s++) pluck(b, tc + s * beat, note(c[s % 3]) * 2, beat, 0.1, -0.3, 0.5);
    });
  }, 0.8, 0.4);
}

// ---------------------------------------------------------------- ambience
function makeAmbience() {
  const dur = 24;
  const bird = (b, t0, pan) => {
    const f0 = 2500 + rand() * 2500, n = 2 + Math.floor(rand() * 5), s0 = Math.floor(t0 * SR);
    for (let k = 0; k < n; k++) {
      const off = Math.floor(k * (0.08 + rand() * 0.08) * SR);
      for (let i = 0; i < SR * 0.07; i++) {
        const t = i / SR; const f = f0 * (1 + 0.4 * Math.sin(t * 90)) * (1 - t * 3);
        b.add(s0 + off + i, Math.sin(2 * Math.PI * f * t) * Math.sin(Math.PI * t / 0.07) * 0.08, pan);
      }
    }
  };
  const wind = (b, amt, cut) => {
    let lp = 0, lp2 = 0;
    for (let i = 0; i < b.n; i++) {
      const t = i / SR;
      lp += (noise() - lp) * cut; lp2 += (lp - lp2) * cut;
      const g = amt * (0.6 + 0.4 * Math.sin(t * 2 * Math.PI / dur * 2) * Math.sin(t * 0.9));
      b.add(i, lp2 * g, Math.sin(t * 0.3) * 0.5);
    }
  };
  const loopify = (b) => { // crossfade the tail into the head
    const x = Math.floor(2 * SR), n = b.n - x;
    for (let i = 0; i < x; i++) { const k = i / x; b.L[i] = b.L[i] * k + b.L[n + i] * (1 - k); b.R[i] = b.R[i] * k + b.R[n + i] * (1 - k); }
    return n;
  };
  let b = new Buf(dur + 2); wind(b, 0.5, 0.02);
  for (let i = 0; i < 18; i++) bird(b, rand() * dur, rand() * 1.6 - 0.8);
  reverb(b, 0.35); write(path.join(OUT, 'ambience', 'forest.wav'), b, 0, loopify(b), 0.5);

  b = new Buf(dur + 2); wind(b, 0.3, 0.03);
  for (let i = 0; i < 26; i++) bird(b, rand() * dur, rand() * 1.6 - 0.8);
  reverb(b, 0.25); write(path.join(OUT, 'ambience', 'village.wav'), b, 0, loopify(b), 0.45);

  b = new Buf(dur + 2);
  for (let i = 0; i < b.n; i++) { // fire crackle + murmuring crowd
    if (rand() < 0.0009) { const a = rand() * 0.6; for (let k = 0; k < 300; k++) b.add(i + k, noise() * a * Math.exp(-k / 60), rand() * 0.6 - 0.3); }
  }
  let lp = 0, bp = 0;
  for (let i = 0; i < b.n; i++) {
    const t = i / SR; lp += (noise() - lp) * 0.05; bp += (lp - bp) * 0.3;
    b.add(i, (lp - bp) * 0.6 * (0.6 + 0.4 * Math.sin(t * 3.1) * Math.sin(t * 1.7 + 1)), 0.2);
  }
  reverb(b, 0.3); write(path.join(OUT, 'ambience', 'tavern.wav'), b, 0, loopify(b), 0.4);

  b = new Buf(dur + 2); wind(b, 0.2, 0.015);
  for (let c = 0; c < 3; c++) { // crickets
    const f = 4200 + c * 700, pan = c - 1;
    for (let t = rand(); t < dur; t += 0.9 + rand() * 0.6) {
      for (let p = 0; p < 4; p++) {
        const s0 = Math.floor((t + p * 0.045) * SR);
        for (let i = 0; i < SR * 0.03; i++) b.add(s0 + i, Math.sin(2 * Math.PI * f * i / SR) * Math.sin(Math.PI * i / (SR * 0.03)) * 0.05, pan * 0.6);
      }
    }
  }
  reverb(b, 0.4); write(path.join(OUT, 'ambience', 'night.wav'), b, 0, loopify(b), 0.45);
}

// ---------------------------------------------------------------- sfx
function sfx(name, sec, fn, rev = 0.12) {
  const b = new Buf(sec + 0.6);
  fn(b);
  if (rev > 0) reverb(b, rev);
  write(path.join(OUT, 'sfx', name + '.wav'), b, 0, b.n, 0.85);
}
function tone(b, t0, f1, f2, dur, vol, shape = 'sine', pan = 0) {
  const s0 = Math.floor(t0 * SR); let ph = 0;
  for (let i = 0; i < dur * SR; i++) {
    const t = i / SR, k = t / dur; const f = f1 * Math.pow(f2 / f1, k); ph += f / SR;
    let v = shape === 'sine' ? Math.sin(2 * Math.PI * ph) : shape === 'saw' ? (ph % 1) * 2 - 1 : shape === 'square' ? (ph % 1 < 0.5 ? 1 : -1) : 1 - 4 * Math.abs((ph % 1) - 0.5);
    b.add(s0 + i, v * vol * Math.min(1, t * 200) * Math.pow(1 - k, 1.5), pan);
  }
}
function whoosh(b, t0, dur, vol, from = 0.05, to = 0.4) {
  const s0 = Math.floor(t0 * SR); let lp = 0, lp2 = 0;
  for (let i = 0; i < dur * SR; i++) {
    const k = i / (dur * SR); const c = from + (to - from) * Math.sin(Math.PI * k);
    lp += (noise() - lp) * c; lp2 += (lp - lp2) * c;
    b.add(s0 + i, (lp - lp2 * 0.5) * vol * Math.sin(Math.PI * k), (k - 0.5) * 0.8);
  }
}
function crunch(b, t0, dur, vol, cut = 0.3) {
  const s0 = Math.floor(t0 * SR); let lp = 0;
  for (let i = 0; i < dur * SR; i++) { lp += (noise() - lp) * cut; b.add(s0 + i, lp * vol * Math.exp(-i / SR / dur * 5)); }
}
function arp(b, notes, step, inst) { notes.forEach((n, i) => inst(i * step, n)); }

function makeSfx() {
  sfx('swing', 0.35, b => whoosh(b, 0, 0.28, 0.9, 0.08, 0.6));
  sfx('hit', 0.3, b => { crunch(b, 0, 0.15, 0.8, 0.5); tone(b, 0, 180, 60, 0.18, 0.7, 'sine'); tone(b, 0, 1200, 400, 0.05, 0.2, 'square'); });
  sfx('hurt', 0.4, b => { tone(b, 0, 320, 110, 0.3, 0.4, 'saw'); crunch(b, 0, 0.2, 0.5, 0.2); });
  sfx('fire', 0.6, b => { whoosh(b, 0, 0.55, 0.9, 0.02, 0.15); tone(b, 0, 150, 420, 0.4, 0.2, 'saw'); });
  sfx('ice', 0.6, b => { for (let i = 0; i < 6; i++) tone(b, i * 0.03, 2400 + i * 300, 3200 + i * 200, 0.25, 0.12, 'sine', (i % 2) - 0.5); whoosh(b, 0, 0.3, 0.3, 0.2, 0.7); }, 0.3);
  sfx('heal', 1.2, b => arp(b, [523, 659, 784, 1047, 1319], 0.07, (t, f) => bell(b, t, f, 0.3, 0.25, 0)), 0.35);
  sfx('boom', 1.0, b => { crunch(b, 0, 0.6, 1.0, 0.08); tone(b, 0, 120, 35, 0.7, 0.9, 'sine'); }, 0.2);
  sfx('coin', 0.4, b => { tone(b, 0, 1318, 1318, 0.08, 0.3, 'square'); tone(b, 0.07, 1760, 1760, 0.2, 0.3, 'square'); }, 0.15);
  sfx('item', 1.4, b => arp(b, [659, 831, 988, 1245, 1319], 0.09, (t, f) => bell(b, t, f, 0.4, 0.25, 0)), 0.35);
  sfx('level', 1.6, b => arp(b, [392, 494, 587, 784, 988, 1175, 1568], 0.07, (t, f) => { pluck(b, t, f, 0.5, 0.3, 0, 0.9); bell(b, t, f, 0.3, 0.1); }), 0.35);
  sfx('dash', 0.3, b => whoosh(b, 0, 0.22, 0.8, 0.15, 0.5));
  sfx('orb', 0.5, b => { tone(b, 0, 700, 280, 0.35, 0.3, 'sine'); tone(b, 0, 710, 290, 0.35, 0.2, 'triangle', 0.3); }, 0.3);
  sfx('blip', 0.1, b => tone(b, 0, 880, 900, 0.05, 0.25, 'square'), 0);
  sfx('select', 0.3, b => { tone(b, 0, 660, 660, 0.06, 0.3, 'triangle'); tone(b, 0.05, 990, 990, 0.12, 0.3, 'triangle'); }, 0.1);
  sfx('die', 0.8, b => { tone(b, 0, 400, 60, 0.6, 0.35, 'square'); crunch(b, 0, 0.4, 0.3, 0.2); }, 0.2);
  sfx('roar', 1.6, b => { tone(b, 0, 95, 45, 1.4, 0.8, 'saw'); tone(b, 0, 142, 70, 1.4, 0.4, 'saw', 0.3); crunch(b, 0, 1.2, 0.5, 0.04); }, 0.3);
  sfx('bloom', 2.2, b => arp(b, [330, 494, 659, 831, 988, 1319, 1661], 0.12, (t, f) => bell(b, t, f, 1.2, 0.2, Math.sin(t * 7) * 0.5)), 0.5);
  sfx('spawn', 0.9, b => { crunch(b, 0, 0.7, 0.6, 0.06); tone(b, 0.1, 80, 160, 0.6, 0.3, 'saw'); }, 0.2);
  sfx('zap', 0.6, b => { for (let i = 0; i < 14; i++) { const t = i * 0.025; crunch(b, t, 0.03, 0.7, 0.9); tone(b, t, 3000 - i * 120, 900, 0.03, 0.3, 'square', (i % 2) - 0.5); } tone(b, 0, 180, 60, 0.4, 0.5, 'saw'); }, 0.25);
  sfx('bones', 0.7, b => { for (let i = 0; i < 9; i++) { const t = i * 0.05 + rand() * 0.03; tone(b, t, 900 + rand() * 900, 500, 0.05, 0.3, 'square', rand() - 0.5); crunch(b, t, 0.04, 0.3, 0.6); } });
}

makeSfx();
makeAmbience();
makeMusic();
console.log('done');
