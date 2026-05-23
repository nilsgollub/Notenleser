from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models.song import Song

router = APIRouter(prefix="/songs", tags=["songs"])


@router.get("/", response_model=List[Song])
async def list_songs(
    q: Optional[str] = None,
    session: AsyncSession = Depends(get_session),
):
    stmt = select(Song)
    if q:
        stmt = stmt.where(Song.title.contains(q))
    result = await session.execute(stmt)
    return result.scalars().all()


@router.get("/{song_id}", response_model=Song)
async def get_song(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await session.get(Song, song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Lied nicht gefunden")
    return song


@router.delete("/{song_id}", status_code=204)
async def delete_song(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await session.get(Song, song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Lied nicht gefunden")
    await session.delete(song)
    await session.commit()
