ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.20
FROM $BUILD_FROM

# Alpine-kompatible Pakete (kein libgl, kein fluidsynth – nicht im Alpine-Repo)
RUN apk add --no-cache \
    python3 py3-pip py3-numpy \
    nodejs npm \
    git curl ffmpeg \
    libstdc++ glib

# Quellcode laden
ARG BUILD_REF=main
RUN git clone --depth 1 --branch ${BUILD_REF} \
    https://github.com/nilsgollub/notenleser /src

# Frontend bauen
RUN cd /src/frontend && npm install && npm run build

# Python-Pakete (HA-Subset: kein opencv, kein pyfluidsynth – beide Alpine-inkompatibel)
# Audio-Wiedergabe läuft über Tone.js im Browser (kein FluidSynth nötig)
RUN pip3 install --no-cache-dir --break-system-packages \
    "fastapi>=0.111.0" \
    "uvicorn[standard]>=0.29.0" \
    "python-multipart>=0.0.9" \
    "pydantic-settings>=2.3.0" \
    "sqlmodel>=0.0.18" \
    "aiosqlite>=0.20.0" \
    "aiofiles>=23.2.1" \
    "Pillow>=10.3.0" \
    "music21>=9.1.0" \
    "python-dotenv>=1.0.0" \
    "httpx>=0.27.0"

# App zusammenstellen
RUN mkdir -p /app/frontend/dist \
 && cp -r /src/backend/app /app/app \
 && cp -r /src/frontend/dist/. /app/frontend/dist/

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8000
CMD ["/run.sh"]
