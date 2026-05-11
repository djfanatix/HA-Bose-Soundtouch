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

detect_music_assistant_addon_slug() {
  node <<'NODE' || true
const http = require("http");
const token = process.env.SUPERVISOR_TOKEN;

if (!token) process.exit(0);

const req = http.request({
  hostname: "supervisor",
  path: "/addons",
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
      const addons = payload.data?.addons || payload.addons || [];
      const candidates = addons.filter((addon) => {
        const slug = String(addon.slug || "").toLowerCase();
        const name = String(addon.name || "").toLowerCase();
        return slug === "music_assistant" ||
          slug === "music_assistant_beta" ||
          slug === "music_assistant_dev" ||
          slug === "music_assistant_nightly" ||
          name === "music assistant" ||
          name.includes("music assistant");
      });

      const priority = (addon) => {
        const slug = String(addon.slug || "").toLowerCase();
        const installed = addon.installed === true ? 0 : 100;
        if (slug === "music_assistant") return installed + 0;
        if (slug === "music_assistant_beta") return installed + 10;
        if (slug === "music_assistant_dev") return installed + 20;
        if (slug === "music_assistant_nightly") return installed + 30;
        return installed + 50;
      };

      const match = candidates.sort((a, b) => priority(a) - priority(b))[0];
      if (match && match.slug) console.log(match.slug);
    } catch (err) {
      process.exit(0);
    }
  });
});

req.on("error", () => process.exit(0));
req.end();
NODE
}

resolved_mass_ip() {
  local mass_ip
  mass_ip="$(option mass_ip)"

  if [ -z "${mass_ip}" ] && [ "$(option music_assistant_addon)" = "true" ]; then
    printf '127.0.0.1'
    return
  fi

  printf '%s' "${mass_ip}"
}

resolved_mass_addon_slug() {
  local addon_slug

  if [ "$(option music_assistant_addon)" = "true" ]; then
    addon_slug="$(detect_music_assistant_addon_slug | head -n 1)"
    if [ -n "${addon_slug}" ]; then
      printf '%s' "${addon_slug}"
      return
    fi
  fi
}

write_env() {
  local mass_ip mass_addon_slug
  mass_ip="$(resolved_mass_ip)"
  mass_addon_slug="$(resolved_mass_addon_slug)"

  {
    printf 'APP_IP="%s"\n' "$(dotenv_escape app_ip)"
    printf 'APP_PORT="%s"\n' "$(option app_port)"
    printf 'BOSE_PORT="%s"\n' "$(option bose_port)"
    printf 'LOG_DIR="./config/logs"\n'
    printf 'MASS_IP="%s"\n' "${mass_ip}"
    printf 'MASS_PORT="%s"\n' "$(option mass_port)"
    printf 'MASS_USERNAME="%s"\n' "$(dotenv_escape mass_username)"
    printf 'MASS_PASSWORD="%s"\n' "$(dotenv_escape mass_password)"
    printf 'MASS_ADDON_SLUG="%s"\n' "${mass_addon_slug}"
    printf 'WLA_PRESET_BYPASS="%s"\n' "$(option wla_preset_bypass)"
    printf 'AUTO_RESUME_PRESET="%s"\n' "$(option auto_resume_preset)"
  } > "${APP_CONFIG_DIR}/.env"

  if [ -z "${mass_addon_slug}" ] && [ "$(option music_assistant_addon)" = "true" ]; then
    bashio::log.warning "Music Assistant app was not auto-detected. Restart controls will be skipped."
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

const replacement = `function supervisorAction(action = 'restart') {
    return new Promise((resolve, reject) => {
        const addonSlug = process.env.MASS_ADDON_SLUG;
        const token = process.env.SUPERVISOR_TOKEN;

        if (!addonSlug || !token) {
            return reject(new Error("Supervisor restart unavailable: MASS_ADDON_SLUG or SUPERVISOR_TOKEN missing"));
        }

        const options = {
            hostname: 'supervisor',
            path: \`/addons/\${addonSlug}/\${action}\`,
            method: 'POST',
            headers: { Authorization: \`Bearer \${token}\` },
            timeout: 5000,
        };

        const req = http.request(options, (res) => {
            if (res.statusCode >= 200 && res.statusCode < 300) resolve(true);
            else reject(new Error(\`Supervisor API Status: \${res.statusCode}\`));
        });

        req.on('error', (err) => reject(err));
        req.end();
    });
}

function dockerAction(action = 'restart') {
    return supervisorAction(action);
}

`;

if (!source.includes("function supervisorAction")) {
  source = source.replace(
    /function dockerAction\(action = 'restart'\) \{[\s\S]*?\n\}\n\n\/\/ --- NEW BULLETPROOF HEALTH CHECK ---/,
    replacement + "// --- NEW BULLETPROOF HEALTH CHECK ---"
  );
}

fs.writeFileSync(file, source);
NODE
}

write_speakers() {
  jq '.speakers // []' "${CONFIG_PATH}" > "${APP_CONFIG_DIR}/speakers.json"
}

patch_cloud_injection_url() {
  local app_ip app_port app_url
  app_ip="$(option app_ip)"
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
    var match = window.location.pathname.match(/^(\/api\/hassio_ingress\/[^/]+)/);
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
patch_cloud_injection_url
install_ingress_shim

if [ ! -f "${APP_CONFIG_DIR}/library.json" ] && [ -f /app/templates/library.template.json ]; then
  cp /app/templates/library.template.json "${APP_CONFIG_DIR}/library.json"
fi

bashio::log.info "Generated SoundTouch Hybrid configuration from Home Assistant app options"
exec node /app/server.js
