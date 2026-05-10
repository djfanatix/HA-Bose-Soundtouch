ARG BUILD_FROM
FROM $BUILD_FROM

ARG BUILD_VERSION
ARG BUILD_ARCH
ARG APP_REPO
ARG APP_REF

LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="app" \
  io.hass.arch="${BUILD_ARCH}"

RUN apk add --no-cache git jq nodejs npm

WORKDIR /app

RUN git clone --depth 1 --branch "${APP_REF}" "${APP_REPO}" /app

RUN npm ci --omit=dev

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
