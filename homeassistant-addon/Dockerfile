ARG BUILD_FROM
FROM $BUILD_FROM

# System-Pakete
RUN apk add --no-cache \
    python3 py3-pip nodejs npm git curl \
    fluidsynth soundfont-fluid-r3-gm ffmpeg \
    libgl

# Quellcode aus dem Repo laden (HA baut nur mit dem Addon-Ordner als Context)
ARG BUILD_REF=main
RUN git clone --depth 1 --branch ${BUILD_REF} \
    https://github.com/nilsgollub/notenleser /src

# Frontend bauen
RUN cd /src/frontend && npm install && npm run build

# Python-Abhängigkeiten
RUN pip3 install --no-cache-dir --break-system-packages \
    -r /src/backend/requirements.txt

# App zusammenstellen
RUN mkdir -p /app/frontend/dist \
 && cp -r /src/backend/app /app/app \
 && cp -r /src/frontend/dist/. /app/frontend/dist/

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8000
CMD ["/run.sh"]
