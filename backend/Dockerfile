FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

FROM python:3.12-slim
RUN groupadd -r app && useradd -r -g app app
WORKDIR /app
COPY --from=builder /deps /usr/local/lib/python3.12/site-packages
COPY main.py .
RUN mkdir -p /data && chown -R app:app /app /data
USER app
EXPOSE 8000
ENV DB_PATH=/data/motoristas.db
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
