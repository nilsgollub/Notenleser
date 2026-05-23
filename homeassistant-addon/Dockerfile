ARG BUILD_FROM
FROM $BUILD_FROM

# System-Pakete
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-numpy \
    fluidsynth \
    soundfont-fluid-r3-gm \
    ffmpeg \
    libgl \
    nodejs \
    npm \
    curl

# Python-Abhängigkeiten
RUN pip3 install --no-cache-dir --break-system-packages \
    fastapi "uvicorn[standard]" python-multipart \
    sqlmodel aiosqlite aiofiles \
    "opencv-python-headless>=4.9.0" Pillow \
    music21 pyfluidsynth python-dotenv pydantic-settings

# Frontend bauen
COPY frontend/ /tmp/frontend/
RUN cd /tmp/frontend && npm ci && npm run build

# Backend + gebautes Frontend
COPY backend/app /app/app
COPY --from=0 /tmp/frontend/dist /app/frontend/dist

COPY homeassistant-addon/run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8000
CMD ["/run.sh"]
