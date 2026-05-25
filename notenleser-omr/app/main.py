import logging
import os
import tempfile

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from omr import recognize_sheet_music

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Notenleser OMR", version="1.0.0")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/recognize")
async def recognize(image: UploadFile = File(...)):
    ct = image.content_type or ""
    suffix = ".png" if "png" in ct else ".jpg"
    data = await image.read()

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name

    try:
        logger.info("Starte OMR für %s (%d Bytes)", image.filename, len(data))
        result = recognize_sheet_music(tmp_path)
        logger.info("OMR abgeschlossen: %d Noten erkannt", len(result.get("notes", [])))

        if not result.get("notes"):
            raise HTTPException(
                status_code=422,
                detail="Kein Notenblatt erkannt. Bitte ein deutlicheres Foto versuchen.",
            )
        return JSONResponse(content=result)
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
