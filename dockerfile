FROM python:3.14
RUN apt-get update && git clone https://github.com/john92999/fastpi_freecodecamp.git
WORKDIR /fastpi_freecodecamp
RUN pip install -r requirments.txt
EXPOSE 8000
CMD bash -c "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"
