ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache \
    python3 \
    py3-pip \
    fluidsynth \
    soundfont-fluid-r3-gm \
    ffmpeg \
    libgl \
    && pip3 install --no-cache-dir \
        fastapi uvicorn[standard] python-multipart \
        sqlmodel aiosqlite aiofiles \
        opencv-python-headless numpy Pillow \
        music21 pyfluidsynth python-dotenv

COPY backend/app /app/app
COPY homeassistant-addon/run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8000
CMD ["/run.sh"]
