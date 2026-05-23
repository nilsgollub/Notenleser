#!/usr/bin/with-contenv bashio

export OMR_ENGINE=$(bashio::config 'omr_engine')
export DATA_DIR=/data/notenleser
export SOUNDFONT_PATH=/usr/share/sounds/sf2/FluidR3_GM.sf2

mkdir -p "$DATA_DIR"/{uploads,audio,musicxml,db}

bashio::log.info "Starte Notenleser (OMR-Engine: $OMR_ENGINE)"
exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --app-dir /app
