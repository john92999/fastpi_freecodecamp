from fastapi import FastAPI, Response, status, HTTPException, Depends
from fastapi.params import Body
from random import randrange
from . import models, schemas, utils
from .database import engine, SessionLocal, get_db
from sqlalchemy.orm import Session
from typing import List
from .routers import posts, users, auth, vote

app = FastAPI()

models.Base.metadata.create_all(bind=engine)

app.include_router(posts.router)
app.include_router(users.router)
app.include_router(auth.router)
app.include_router(vote.router)

@app.get("/")
async def root():
    return{"message": "welcome to my api"}

# @app.get("/posts")
# async def posts():
#     cursor.execute(""" select * from posts """)
#     posts = cursor.fetchall()
#     print(posts)
#     return {"data": posts}

# @app.post("/createpost", status_code=status.HTTP_201_CREATED)
# async def create_posts(post: Post):
#     cursor.execute(""" INSERT INTO posts (title, content, published) VALUES (%s, %s, %s) returning *""", (post.title, post.content, post.published))
#     new_post = cursor.fetchone()
#     conn.commit()
#     return{"new_post": new_post}

# @app.get("/posts/latest")
# async def get_latest_post():
#     post = my_posts[len(my_posts) - 1]
#     return post

# @app.get("/posts/{id}")
# async def get_post(id: int, response: Response):
#     cursor.execute(""" select * from posts where id = %s""", (str(id)))
#     post = cursor.fetchone()
#     if not post:
#         raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail = f"post with id: {id} not found")
#     return post

# @app.delete("/posts/{id}", status_code=status.HTTP_204_NO_CONTENT)
# async def delete_post(id: int):
#     cursor.execute(""" Delete from posts where id = %s returning *""", (str(id)))
#     post = cursor.fetchone()
#     conn.commit()
#     if post == None:
#         raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail = f"post with id: {id} not found")
#     return post

# @app.put("/posts/{id}")
# def update_post(id: int, post: Post):
#     cursor.execute(""" UPDATE posts SET title = %s, content = %s, published = %s where id = %s returning *""", 
#     (post.title, post.content, post.published, str(id)))
#     updated_post = cursor.fetchone()
#     if post == None:
#         raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail = f"post with id: {id} not found")
#     return {"data": updated_post}