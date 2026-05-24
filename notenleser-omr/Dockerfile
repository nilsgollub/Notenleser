FROM python:3.11-slim-bookworm

# System libraries required by OpenCV (headless) and oemer
RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libgomp1 \
        libsm6 \
        libxext6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/requirements.txt .
# onnxruntime-gpu doesn't exist on aarch64; install CPU version first,
# then oemer without its deps so it doesn't pull onnxruntime-gpu.
RUN pip install --no-cache-dir onnxruntime && \
    pip install --no-cache-dir --no-deps oemer && \
    pip install --no-cache-dir -r requirements.txt

# Pre-download oemer ONNX models during build so the first request is fast.
RUN python -c "from oemer.inference import model_manager; model_manager.load_all()" || true

COPY app/ .
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8765
CMD ["/run.sh"]
