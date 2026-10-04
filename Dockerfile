FROM alpine/git:latest AS source
ARG SOURCE_REPO=https://github.com/dharanivelp/talkative.git
ARG SOURCE_BRANCH=deploy-test
RUN git clone --depth 1 --branch "${SOURCE_BRANCH}" "${SOURCE_REPO}" /src

FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    USER_DATABASE_PATH=/data/users.db \
    ADMIN_DATABASE_PATH=/data/admin.db \
    DATABASE_PATH=/data/talkative.db
WORKDIR /app
COPY --from=source /src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --from=source /src/app.py .
COPY --from=source /src/app ./app
COPY --from=source /src/talkative_backend ./talkative_backend
VOLUME ["/data"]
EXPOSE 8000
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-8000} --workers 2 app:app"]
