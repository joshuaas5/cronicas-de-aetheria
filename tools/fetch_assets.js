// Downloads the CC0 assets used by Aetheria from Poly Haven.
// Usage: node tools/fetch_assets.js   (run from the project root)
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', 'assets');

const MODELS = [
  'island_tree_01', 'island_tree_02',
  'shrub_01', 'shrub_02', 'shrub_03', 'shrub_04', 'fern_02',
  'grass_medium_01', 'grass_medium_02', 'dandelion_01', 'celandine_01', 'nettle_plant', 'moss_01',
  'boulder_01', 'rock_07', 'rock_09', 'namaqualand_boulder_02',
  'tree_stump_01', 'tree_stump_02', 'dead_tree_trunk', 'dead_tree_trunk_02', 'root_cluster_01', 'pine_roots',
  'Barrel_01', 'Barrel_02', 'WoodenTable_01', 'WoodenChair_01', 'Lantern_01', 'Shelf_01',
  'brass_candleholders', 'modular_fort_01',
];

const TEXTURES = [
  'forest_leaves_02', 'leafy_grass', 'sparse_grass', 'stony_dirt_path', 'farm_soil',
  'bark_willow_02', 'bark_brown_02', 'mossy_rock', 'cobblestone_floor_08', 'medieval_blocks_02',
  'worn_planks', 'wood_trunk_wall', 'plastered_wall_04', 'medieval_wood', 'roof_tiles_14', 'rock_wall_08',
];

const HDRIS = [
  'kloofendal_48d_partly_cloudy_puresky', 'forest_slope', 'sunset_forest',
  'qwantani_night_puresky', 'warm_restaurant_night',
];

async function get(url) {
  for (let i = 0; i < 4; i++) {
    try {
      const r = await fetch(url);
      if (!r.ok) throw new Error(r.status + ' ' + url);
      return Buffer.from(await r.arrayBuffer());
    } catch (e) {
      if (i === 3) throw e;
      await new Promise(res => setTimeout(res, 1500 * (i + 1)));
    }
  }
}

async function save(url, file) {
  if (fs.existsSync(file) && fs.statSync(file).size > 0) return 0;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const buf = await get(url);
  fs.writeFileSync(file, buf);
  return buf.length;
}

async function files(id) {
  return JSON.parse((await get('https://api.polyhaven.com/files/' + id)).toString());
}

async function model(id) {
  const j = await files(id);
  const res = j.gltf['1k'] ? '1k' : Object.keys(j.gltf)[0];
  const g = j.gltf[res].gltf;
  const dir = path.join(ROOT, 'models', id);
  let n = await save(g.url, path.join(dir, id + '.gltf'));
  for (const [rel, inc] of Object.entries(g.include || {})) n += await save(inc.url, path.join(dir, rel));
  return n;
}

async function texture(id) {
  const j = await files(id);
  const dir = path.join(ROOT, 'textures', id);
  const pick = (k) => j[k] && j[k]['2k'] && (j[k]['2k'].jpg || j[k]['2k'].png);
  let n = 0;
  const maps = { albedo: 'Diffuse', normal: 'nor_gl', arm: 'arm', rough: 'Rough', ao: 'AO' };
  for (const [name, key] of Object.entries(maps)) {
    if ((name === 'rough' || name === 'ao') && pick('arm')) continue;
    const f = pick(key);
    if (f) n += await save(f.url, path.join(dir, name + path.extname(f.url)));
  }
  return n;
}

async function hdri(id) {
  const j = await files(id);
  const f = j.hdri['2k'].hdr;
  return save(f.url, path.join(ROOT, 'hdri', id + '.hdr'));
}

(async () => {
  let total = 0;
  const run = async (kind, list, fn) => {
    for (const id of list) {
      try {
        const n = await fn(id);
        total += n;
        console.log(`${kind.padEnd(8)} ${id.padEnd(40)} ${(n / 1e6).toFixed(1)} MB`);
      } catch (e) {
        console.log(`${kind.padEnd(8)} ${id.padEnd(40)} FAILED: ${e.message}`);
      }
    }
  };
  await run('hdri', HDRIS, hdri);
  await run('texture', TEXTURES, texture);
  await run('model', MODELS, model);
  console.log(`DONE ${(total / 1e6).toFixed(0)} MB`);
})();
