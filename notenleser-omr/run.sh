#!/bin/bash
set -e

LOG_LEVEL="${LOG_LEVEL:-info}"

echo "Starte Notenleser OMR auf Port 8765 (log-level: ${LOG_LEVEL})"

exec uvicorn main:app \
    --host 0.0.0.0 \
    --port 8765 \
    --log-level "${LOG_LEVEL}"
