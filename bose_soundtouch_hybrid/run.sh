#!/usr/bin/with-contenv bashio
set -euo pipefail

CONFIG_PATH=/data/options.json
APP_CONFIG_DIR=/config

mkdir -p "${APP_CONFIG_DIR}/logs"

if [ ! -L /app/config ]; then
  rm -rf /app/config
  ln -s "${APP_CONFIG_DIR}" /app/config
fi

option() {
  jq -r --arg key "$1" '.[$key] // "" | tostring' "${CONFIG_PATH}"
}

dotenv_escape() {
  jq -r --arg key "$1" '
    .[$key] // ""
    | tostring
    | gsub("\\\\"; "\\\\")
    | gsub("\""; "\\\"")
    | gsub("\n"; "\\n")
  ' "${CONFIG_PATH}"
}

detect_home_assistant_url_host() {
  node <<'NODE' || true
const http = require("http");
const token = process.env.SUPERVISOR_TOKEN;

if (!token) process.exit(0);

const req = http.request({
  hostname: "supervisor",
  path: "/core/api/config",
  method: "GET",
  headers: { Authorization: `Bearer ${token}` },
  timeout: 5000
}, (res) => {
  let body = "";
  res.setEncoding("utf8");
  res.on("data", (chunk) => body += chunk);
  res.on("end", () => {
    try {
      const payload = JSON.parse(body);
      const urls = [
        payload.internal_url,
        payload.data?.internal_url,
        payload.external_url,
        payload.data?.external_url
      ].filter(Boolean);

      for (const value of urls) {
        try {
          const host = new URL(value).hostname;
          if (host && host !== "localhost" && host !== "127.0.0.1") {
            console.log(host);
            return;
          }
        } catch (err) {}
      }
    } catch (err) {
      process.exit(0);
    }
  });
});

req.on("error", () => process.exit(0));
req.end();
NODE
}

detect_lan_ip() {
  node <<'NODE' || true
const os = require("os");

const candidates = [];
for (const addresses of Object.values(os.networkInterfaces())) {
  for (const address of addresses || []) {
    if (address.family !== "IPv4" || address.internal) continue;
    candidates.push(address.address);
  }
}

const score = (ip) => {
  if (ip.startsWith("192.168.")) return 0;
  if (ip.startsWith("10.")) return 1;
  if (/^172\.(1[6-9]|2\d|3[0-1])\./.test(ip)) return 2;
  if (ip.startsWith("169.254.")) return 100;
  return 10;
};

candidates.sort((a, b) => score(a) - score(b));
if (candidates[0]) console.log(candidates[0]);
NODE
}

resolved_app_ip() {
  local app_ip
  app_ip="$(option app_ip)"

  if [ -z "${app_ip}" ] || [ "${app_ip}" = "null" ]; then
    app_ip="$(detect_lan_ip | head -n 1)"
  fi

  if [ -z "${app_ip}" ]; then
    app_ip="$(detect_home_assistant_url_host | head -n 1)"
  fi

  printf '%s' "${app_ip}"
}

detect_home_assistant_timezone() {
  node <<'NODE' || true
const http = require("http");
const token = process.env.SUPERVISOR_TOKEN;

if (!token) process.exit(0);

const req = http.request({
  hostname: "supervisor",
  path: "/core/api/config",
  method: "GET",
  headers: { Authorization: `Bearer ${token}` },
  timeout: 5000
}, (res) => {
  let body = "";
  res.setEncoding("utf8");
  res.on("data", (chunk) => body += chunk);
  res.on("end", () => {
    try {
      const payload = JSON.parse(body);
      const timezone = payload.time_zone || payload.data?.time_zone;
      if (timezone) console.log(timezone);
    } catch (err) {
      process.exit(0);
    }
  });
});

req.on("error", () => process.exit(0));
req.end();
NODE
}

resolved_timezone() {
  local timezone
  timezone="$(detect_home_assistant_timezone | head -n 1)"

  if [ -z "${timezone}" ] && [ -n "${TZ:-}" ]; then
    timezone="${TZ}"
  fi

  if [ -z "${timezone}" ] && [ -f /etc/timezone ]; then
    timezone="$(head -n 1 /etc/timezone)"
  fi

  if [ -z "${timezone}" ]; then
    timezone="UTC"
  fi

  printf '%s' "${timezone}"
}

write_env() {
  local app_ip timezone
  app_ip="$(resolved_app_ip)"
  timezone="$(resolved_timezone)"
  export TZ="${timezone}"

  {
    printf '# .env file format: v3.5\n'
    printf 'APP_IP="%s"\n' "${app_ip}"
    printf 'APP_PORT="%s"\n' "$(option app_port)"
    printf 'BOSE_PORT="%s"\n' "$(option bose_port)"
    printf 'LOG_DIR="./config/logs"\n'
    printf 'MASS_IP="127.0.0.1"\n'
    printf 'MASS_PORT="%s"\n' "$(option mass_port)"
    printf 'MASS_USERNAME="%s"\n' "$(dotenv_escape mass_username)"
    printf 'MASS_PASSWORD="%s"\n' "$(dotenv_escape mass_password)"
    printf 'AUTO_RESUME_PRESET="%s"\n' "$(option auto_resume_preset)"
    printf 'TRUST_PROXY="%s"\n' "$(option trust_proxy)"
    printf 'TZ="%s"\n' "${timezone}"
  } > "${APP_CONFIG_DIR}/.env"

  if [ "${timezone}" = "UTC" ]; then
    bashio::log.warning "Home Assistant timezone was not auto-detected. Falling back to UTC for SoundTouch Hybrid logs."
  fi

  if [ -z "${app_ip}" ]; then
    bashio::log.warning "Home Assistant local IP was not auto-detected. Set App IP address manually for Bose speaker cloud injection."
  fi
}

patch_music_assistant_restart() {
  if [ ! -f /app/routes/mass_utils.js ]; then
    return
  fi

  node <<'NODE'
const fs = require("fs");
const file = "/app/routes/mass_utils.js";
let source = fs.readFileSync(file, "utf8");

const replacement = `function supervisorRequest(path, method = 'GET') {
    return new Promise((resolve, reject) => {
        const token = process.env.SUPERVISOR_TOKEN;

        if (!token) {
            return reject(new Error("Supervisor restart unavailable: SUPERVISOR_TOKEN missing. Check hassio_api in the Home Assistant app config and rebuild/reinstall the app."));
        }

        const options = {
            hostname: 'supervisor',
            path,
            method,
            headers: { Authorization: \`Bearer \${token}\` },
            timeout: 5000,
        };

        const req = http.request(options, (res) => {
            let body = "";
            res.setEncoding('utf8');
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    if (!body) return resolve({});
                    try {
                        return resolve(JSON.parse(body));
                    } catch (err) {
                        return resolve(body);
                    }
                }

                const hint = res.statusCode === 403
                    ? " (set hassio_role: manager in the Home Assistant app config, then rebuild/reinstall the app)"
                    : "";
                reject(new Error(\`Supervisor API Status: \${res.statusCode}\${body ? \` - \${body}\` : ""}\${hint}\`));
            });
        });

        req.on('error', (err) => reject(err));
        req.end();
    });
}

async function discoverMusicAssistantAppSlug() {
    const payload = await supervisorRequest('/addons');
    const selfPayload = await supervisorRequest('/addons/self/info').catch(() => ({}));
    const apps = payload.data?.addons || payload.addons || [];
    const self = selfPayload.data || selfPayload || {};
    const selfSlug = String(self.slug || "").toLowerCase();
    const candidates = apps.filter((app) => {
        const slug = String(app.slug || "").toLowerCase();
        const name = String(app.name || "").toLowerCase();
        if (selfSlug && slug === selfSlug) return false;
        if (slug.includes("bose_soundtouch_hybrid") || name.includes("soundtouch hybrid")) return false;
        return slug === "music_assistant" ||
            slug.endsWith("_music_assistant") ||
            slug === "music_assistant_beta" ||
            slug.endsWith("_music_assistant_beta") ||
            slug === "music_assistant_dev" ||
            slug.endsWith("_music_assistant_dev") ||
            slug === "music_assistant_nightly" ||
            slug.endsWith("_music_assistant_nightly") ||
            name === "music assistant" ||
            name.includes("music assistant");
    });

    const priority = (app) => {
        const slug = String(app.slug || "").toLowerCase();
        const installed = app.installed === true ? 0 : 100;
        if (slug === "music_assistant" || slug.endsWith("_music_assistant")) return installed + 0;
        if (slug === "music_assistant_beta" || slug.endsWith("_music_assistant_beta")) return installed + 10;
        if (slug === "music_assistant_dev" || slug.endsWith("_music_assistant_dev")) return installed + 20;
        if (slug === "music_assistant_nightly" || slug.endsWith("_music_assistant_nightly")) return installed + 30;
        return installed + 50;
    };

    const match = candidates.sort((a, b) => priority(a) - priority(b))[0];
    return match?.slug || null;
}

async function supervisorAction(action = 'restart') {
    const appSlug = await discoverMusicAssistantAppSlug();
    if (!appSlug) {
        throw new Error("Supervisor restart unavailable: Music Assistant app was not found in the installed Home Assistant apps.");
    }
    if (appSlug === "self" || appSlug.includes("bose_soundtouch_hybrid")) {
        throw new Error(\`Supervisor restart aborted: refusing to restart \${appSlug} as Music Assistant.\`);
    }

    console.log(\`[Admin] Restarting Music Assistant app via Supervisor target: \${appSlug}\`);
    await supervisorRequest(\`/addons/\${appSlug}/\${action}\`, 'POST');
    return true;
}

function dockerAction(action = 'restart') {
    return supervisorAction(action);
}

`;

if (!source.includes("function supervisorAction")) {
  const original = source;
  source = source.replace(
    /function dockerAction\(action = 'restart'\) \{[\s\S]*?\n\}\n\n\/\/ --- (?:NEW )?BULLETPROOF HEALTH CHECK ---/,
    replacement + "// --- BULLETPROOF HEALTH CHECK ---"
  );

  if (source === original) {
    console.error("[Patch] Unable to replace upstream Docker restart helper in routes/mass_utils.js");
    process.exit(1);
  }
}

fs.writeFileSync(file, source);
NODE
}

patch_boot_restart_messages() {
  if [ ! -f /app/server.js ]; then
    return
  fi

  node <<'NODE'
const fs = require("fs");
const file = "/app/server.js";
let source = fs.readFileSync(file, "utf8");
const oldDockerRestartFailure = "[Boot] ❌ " +
  "Docker" +
  " Restart Failed: ${e.message}";
const oldDockerSocketHint = "[Boot] 💡 Also ensure the " +
  "docker" +
  ".sock" +
  " volume is mapped correctly in your docker-compose.yml file.\\n";

source = source
  .replace(
    "[Boot] 🧹 Triggering Music Assistant restart for a clean network state...",
    "[Boot] 🧹 Triggering Music Assistant app restart for a clean network state..."
  )
  .replace(/\blet dockerRestartSuccess = false;/g, "let appRestartSuccess = false;")
  .replace(/\bdockerRestartSuccess = true;/g, "appRestartSuccess = true;")
  .replace(/\bdockerRestartSuccess\b/g, "appRestartSuccess")
  .replace(
    "[Boot] ⏳ Waiting for Music Assistant Docker container to boot...",
    "[Boot] ⏳ Waiting for Music Assistant app to boot..."
  )
  .replace(
    oldDockerRestartFailure,
    "[Boot] ❌ Music Assistant app restart failed: ${e.message}"
  )
  .replace(
    "const configuredName = process.env.MASS_CONTAINER_NAME || \"NOT SET\";",
    "const configuredName = \"auto-detect\";"
  )
  .replace(
    "[Boot] 💡 The app tried to restart the container named: \"${configuredName}\"",
    "[Boot] 💡 The app tried to restart Music Assistant via Supervisor target: \"${configuredName}\""
  )
  .replace(
    "[Boot] 💡 Please verify this exactly matches your Music Assistant container name in your config/.env file.",
    "[Boot] 💡 Please verify Music Assistant is installed as a Home Assistant app and visible to Supervisor."
  )
  .replace(
    oldDockerSocketHint,
    "[Boot] 💡 Also ensure hassio_api is enabled and hassio_role is manager in this app config.\\n"
  );

fs.writeFileSync(file, source);
NODE
}

write_speakers() {
  if [ "$(option auto_discover_speakers)" != "true" ]; then
    jq '.speakers // []' "${CONFIG_PATH}" > "${APP_CONFIG_DIR}/speakers.json"
    return
  fi

  CONFIG_PATH="${CONFIG_PATH}" APP_CONFIG_DIR="${APP_CONFIG_DIR}" node <<'NODE'
const dgram = require("dgram");
const fs = require("fs");
const http = require("http");

const configPath = process.env.CONFIG_PATH;
const outputPath = `${process.env.APP_CONFIG_DIR}/speakers.json`;
const options = JSON.parse(fs.readFileSync(configPath, "utf8"));

function normalizeSpeaker(speaker) {
  const name = String(speaker?.name || "").trim();
  const ip = String(speaker?.ip || "").trim();
  if (!ip) return null;
  return { name: name || `SoundTouch ${ip}`, ip };
}

function decodeXml(value) {
  return String(value || "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}

function extractTag(xml, tag) {
  const match = String(xml).match(new RegExp(`<${tag}[^>]*>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${tag}>`, "i"));
  return match ? decodeXml(match[1]).trim() : "";
}

function hostFromLocation(location) {
  try {
    return new URL(location).hostname;
  } catch (err) {
    return "";
  }
}

function discoverCandidates() {
  return new Promise((resolve) => {
    const socket = dgram.createSocket("udp4");
    const candidates = new Set();
    const message = Buffer.from([
      "M-SEARCH * HTTP/1.1",
      "HOST: 239.255.255.250:1900",
      'MAN: "ssdp:discover"',
      "MX: 2",
      "ST: ssdp:all",
      "",
      ""
    ].join("\r\n"));

    socket.on("message", (buffer, rinfo) => {
      candidates.add(rinfo.address);
      const response = buffer.toString("utf8");
      const location = response.match(/^location:\s*(.+)$/im)?.[1]?.trim();
      const host = location ? hostFromLocation(location) : "";
      if (host) candidates.add(host);
    });

    socket.on("error", () => {
      try { socket.close(); } catch (err) {}
      resolve([...candidates]);
    });

    socket.bind(() => {
      for (let i = 0; i < 3; i++) {
        socket.send(message, 1900, "239.255.255.250");
      }
    });

    setTimeout(() => {
      try { socket.close(); } catch (err) {}
      resolve([...candidates]);
    }, 3500);
  });
}

function probeSpeaker(ip) {
  return new Promise((resolve) => {
    const req = http.get({ hostname: ip, port: 8090, path: "/info", timeout: 1500 }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => body += chunk);
      res.on("end", () => {
        const text = body.toLowerCase();
        const looksLikeSoundTouch = text.includes("soundtouch") ||
          text.includes("bose") ||
          text.includes("deviceid") ||
          text.includes("margeserverurl") ||
          text.includes("margeurl");
        if (!text.includes("<info") || !looksLikeSoundTouch) {
          resolve(null);
          return;
        }

        resolve({
          name: extractTag(body, "name") || `SoundTouch ${ip}`,
          ip
        });
      });
    });

    req.on("timeout", () => {
      req.destroy();
      resolve(null);
    });
    req.on("error", () => resolve(null));
  });
}

(async () => {
  const manual = (Array.isArray(options.speakers) ? options.speakers : [])
    .map(normalizeSpeaker)
    .filter(Boolean);

  const byIp = new Map(manual.map((speaker) => [speaker.ip, speaker]));
  const candidates = await discoverCandidates();
  const discovered = (await Promise.all(candidates.slice(0, 64).map(probeSpeaker))).filter(Boolean);

  let added = 0;
  for (const speaker of discovered) {
    if (!byIp.has(speaker.ip)) {
      byIp.set(speaker.ip, speaker);
      added++;
    }
  }

  const speakers = [...byIp.values()];
  fs.writeFileSync(outputPath, `${JSON.stringify(speakers, null, 2)}\n`);
  console.log(`[Boot] Speaker auto-discovery checked ${candidates.length} candidate(s), found ${discovered.length}, added ${added}.`);
})().catch((err) => {
  fs.writeFileSync(outputPath, `${JSON.stringify((options.speakers || []).map(normalizeSpeaker).filter(Boolean), null, 2)}\n`);
  console.log(`[Boot] Speaker auto-discovery failed: ${err.message}`);
});
NODE
}

patch_cloud_injection_url() {
  local app_ip app_port app_url
  app_ip="$(resolved_app_ip)"
  app_port="$(option app_port)"
  app_url="http://${app_ip}:${app_port}"

  cat > /app/public/ha_config.js <<EOF
window.SOUNDTOUCH_HYBRID_BASE_URL = "${app_url}";
EOF

  if [ -f /app/public/tools.html ]; then
    APP_URL="${app_url}" node <<'NODE'
const fs = require("fs");
const page = "/app/public/tools.html";
const appUrl = process.env.APP_URL;
let html = fs.readFileSync(page, "utf8");

if (!html.includes("ha_config.js")) {
  html = html.replace(
    /<script src="global_ui\.js"><\/script>/,
    '<script src="ha_config.js"></script>\n  <script src="global_ui.js"></script>'
  );
}

html = html.replace(
  /const\s+SERVER_URL\s*=\s*[^;]+;/,
  `const SERVER_URL = window.SOUNDTOUCH_HYBRID_BASE_URL || "${appUrl}";`
);

html = html.replace(
  /const\s+targetUrl\s*=\s*SERVER_URL;/,
  "const targetUrl = window.SOUNDTOUCH_HYBRID_BASE_URL || SERVER_URL;"
);

fs.writeFileSync(page, html);
NODE
  fi
}

install_ingress_shim() {
  cat > /app/public/ingress.js <<'EOF'
(function () {
  function ingressBase() {
    var match = window.location.pathname.match(/^(\/api\/hassio_ingress\/[^/]+)/) ||
      window.location.pathname.match(/^(\/app\/[^/]+)/);
    return match ? match[1] : "";
  }

  window.ingressPath = function (path) {
    if (!path || path[0] !== "/") return path;
    return ingressBase() + path;
  };

  var nativeFetch = window.fetch;
  window.fetch = function (input, init) {
    if (typeof input === "string") {
      input = window.ingressPath(input);
    } else if (input && input.url && input.url.charAt(0) === "/") {
      input = new Request(window.ingressPath(input.url), input);
    }
    return nativeFetch.call(this, input, init);
  };
})();
EOF

  for page in /app/public/control.html /app/public/manager.html /app/public/admin.html /app/public/tools.html; do
    [ -f "${page}" ] || continue
    if ! grep -q 'ingress.js' "${page}"; then
      sed -i \
        -e 's#<script src="global_ui.js"></script>#<script src="ingress.js"></script>\n  <script src="global_ui.js"></script>#' \
        "${page}"
    fi
    sed -i -E \
      -e "s#window\.location\.href='(/[^']*)'#window.location.href=window.ingressPath('\1')#g" \
      -e 's#window\.location\.href="(/[^"]*)"#window.location.href=window.ingressPath("\1")#g' \
      "${page}"
  done
}

write_env
write_speakers
patch_music_assistant_restart
patch_boot_restart_messages
patch_cloud_injection_url
install_ingress_shim

if [ ! -f "${APP_CONFIG_DIR}/library.json" ] && [ -f /app/templates/library.template.json ]; then
  cp /app/templates/library.template.json "${APP_CONFIG_DIR}/library.json"
fi

bashio::log.info "Generated SoundTouch Hybrid configuration from Home Assistant app options"
exec node /app/server.js
