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

write_env() {
  {
    printf 'APP_IP="%s"\n' "$(dotenv_escape app_ip)"
    printf 'APP_PORT="%s"\n' "$(option app_port)"
    printf 'BOSE_PORT="%s"\n' "$(option bose_port)"
    printf 'LOG_DIR="./config/logs"\n'
    printf 'MASS_IP="%s"\n' "$(dotenv_escape mass_ip)"
    printf 'MASS_PORT="%s"\n' "$(option mass_port)"
    printf 'MASS_USERNAME="%s"\n' "$(dotenv_escape mass_username)"
    printf 'MASS_PASSWORD="%s"\n' "$(dotenv_escape mass_password)"
    printf 'MASS_CONTAINER_NAME="%s"\n' "$(dotenv_escape mass_container_name)"
    printf 'WLA_PRESET_BYPASS="%s"\n' "$(option wla_preset_bypass)"
    printf 'AUTO_RESUME_PRESET="%s"\n' "$(option auto_resume_preset)"
  } > "${APP_CONFIG_DIR}/.env"
}

write_speakers() {
  jq '.speakers // []' "${CONFIG_PATH}" > "${APP_CONFIG_DIR}/speakers.json"
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
install_ingress_shim

if [ ! -f "${APP_CONFIG_DIR}/library.json" ] && [ -f /app/templates/library.template.json ]; then
  cp /app/templates/library.template.json "${APP_CONFIG_DIR}/library.json"
fi

bashio::log.info "Generated SoundTouch Hybrid configuration from Home Assistant app options"
exec node /app/server.js
