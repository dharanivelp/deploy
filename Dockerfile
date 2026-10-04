FROM alpine/git:latest AS source
ARG SOURCE_REPO=https://github.com/dharanivelp/talkative.git
ARG SOURCE_BRANCH=deploy-test
RUN git clone --depth 1 --branch "${SOURCE_BRANCH}" "${SOURCE_REPO}" /src

FROM python:3.11-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends redis-server supervisor \
    && rm -rf /var/lib/apt/lists/* \
    && printf '%s\n' \
        '#!/bin/sh' \
        'exec redis-server --bind 127.0.0.1 --port 6379 --requirepass "$REDIS_PASSWORD" --appendonly yes --save 60 1000 --dir /data/redis' \
        > /usr/local/bin/start-redis \
    && chmod 755 /usr/local/bin/start-redis \
    && printf '%s\n' \
        '[supervisord]' \
        'nodaemon=true' \
        'logfile=/dev/null' \
        'pidfile=/tmp/supervisord.pid' \
        '' \
        '[program:redis]' \
        'command=/usr/local/bin/start-redis' \
        'autorestart=true' \
        'startsecs=2' \
        'stdout_logfile=/dev/fd/1' \
        'stdout_logfile_maxbytes=0' \
        'stderr_logfile=/dev/fd/2' \
        'stderr_logfile_maxbytes=0' \
        '' \
        '[program:web]' \
        'command=/usr/local/bin/start-web' \
        'autorestart=true' \
        'startsecs=2' \
        'stdout_logfile=/dev/fd/1' \
        'stdout_logfile_maxbytes=0' \
        'stderr_logfile=/dev/fd/2' \
        'stderr_logfile_maxbytes=0' \
        > /etc/supervisor/conf.d/talkative.conf
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    PORT=8000 \
    REDIS_URL=redis://127.0.0.1:6379/0 \
    USER_DATABASE_PATH=/data/users.db \
    ADMIN_DATABASE_PATH=/data/admin.db \
    DATABASE_PATH=/data/talkative.db
WORKDIR /app
COPY --from=source /src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --from=source /src/app.py .
COPY --from=source /src/app ./app
COPY --from=source /src/talkative_backend ./talkative_backend
RUN printf '%s\n' \
        '#!/bin/sh' \
        'exec gunicorn --bind "0.0.0.0:${PORT:-8000}" --workers 2 app:app' \
        > /usr/local/bin/start-web \
    && chmod 755 /usr/local/bin/start-web
VOLUME ["/data"]
EXPOSE 8000
CMD ["sh", "-c", "set -eu; : \"${REDIS_PASSWORD:?Set REDIS_PASSWORD}\"; : \"${SESSION_SECRET:?Set SESSION_SECRET}\"; : \"${ADMIN_PASSWORD:?Set ADMIN_PASSWORD}\"; mkdir -p /data/redis; exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf"]
