from fastapi import FastAPI, Response, status, HTTPException, Depends, APIRouter
from .. import models, schemas, utils, oauth2
from sqlalchemy.orm import Session
from ..database import engine, SessionLocal, get_db

router = APIRouter(
    tags=['Votes']
)

@router.post("/vote", status_code=status.HTTP_201_CREATED)
async def vote(vote: schemas.Vote, db: Session = Depends(get_db), get_current_user: int = Depends(oauth2.get_current_user)):
    post = db.query(models.Post).filter(models.Post.id == vote.post_id).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail = f'post with {vote.post_id} doesnot exist')
    vote_query = db.query(models.Votes).filter(models.Votes.post_id == vote.post_id, models.Votes.user_id == get_current_user.id)
    found_vote = vote_query.first()
    if (vote.dir == 1):
        if found_vote:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail= f'user {get_current_user.id} has already voted on {vote.post_id}')
        new_vote = models.Votes(post_id = vote.post_id, user_id = get_current_user.id)
        db.add(new_vote)
        db.commit()
        return "successfully added vote"
    else:
        if not found_vote:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="vote doesnot exist")
        vote_query.delete(synchronize_session=False)
        db.commit()
        return "successfully deleted vote"