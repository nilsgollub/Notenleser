#!/usr/bin/with-contenv bashio

LOG_LEVEL="$(bashio::config 'log_level' 'info' 2>/dev/null || echo 'info')"

bashio::log.info "Starte Notenleser OMR auf Port 8765 (log-level: ${LOG_LEVEL})"

exec uvicorn main:app \
    --host 0.0.0.0 \
    --port 8765 \
    --log-level "${LOG_LEVEL}"
