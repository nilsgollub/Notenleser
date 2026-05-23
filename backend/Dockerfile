FROM python:3.12-slim

# System-Abhängigkeiten: OpenCV, FluidSynth, Java (für Audiveris-Fallback)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    fluidsynth \
    fluid-soundfont-gm \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# oemer separat (großes Paket mit torch)
# RUN pip install --no-cache-dir oemer
# In Produktion aktivieren; für Dev läuft der Mock-Mode ohne oemer

COPY app/ ./app/

VOLUME ["/data"]
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
