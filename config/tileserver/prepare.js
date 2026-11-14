const fs = require("fs");
const path = require("path");

const srcConfigPath = "/data/config/tileserver/config.json";
const srcStylesRoot = "/data/styles";
const outStylesRoot = "/tmp/styles";
const outConfigPath = "/tmp/config.json";

const cfg = JSON.parse(fs.readFileSync(srcConfigPath, "utf8"));

for (const [key, entry] of Object.entries(cfg.styles || {})) {
  if (!entry || !entry.style) continue;
  const srcStylePath = path.join(srcStylesRoot, entry.style);
  if (!fs.existsSync(srcStylePath)) continue;

  const style = JSON.parse(fs.readFileSync(srcStylePath, "utf8"));

  if (style.sources && style.sources.openmaptiles) {
    style.sources.openmaptiles = {
      type: "vector",
      tiles: ["http://postserve:8090/tiles/{z}/{x}/{y}.pbf"],
      minzoom: 0,
      maxzoom: 14,
    };
  }

  if (typeof style.sprite === "string") {
    style.sprite = style.sprite.replace("http://localhost:8080/", "http://nginx/");
  }

  if (typeof style.glyphs === "string") {
    style.glyphs = style.glyphs.replace("http://localhost:8080/", "http://nginx/");
  }

  const outStylePath = path.join(outStylesRoot, entry.style);
  fs.mkdirSync(path.dirname(outStylePath), { recursive: true });
  fs.writeFileSync(outStylePath, JSON.stringify(style));
}

cfg.options = cfg.options || {};
cfg.options.paths = cfg.options.paths || {};
cfg.options.paths.styles = outStylesRoot;
cfg.options.paths.fonts = "/data/fonts";

fs.writeFileSync(outConfigPath, JSON.stringify(cfg));
