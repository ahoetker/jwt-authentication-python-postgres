FROM python:3.9.12-slim-buster as base

ENV PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1

WORKDIR /app

FROM base as builder

RUN apt-get update && \
    apt-get clean && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    sqlite3 \
    && \
    rm -rf /var/lib/apt/lists/*

ENV PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    POETRY_VERSION=1.1.4

RUN pip install "poetry==${POETRY_VERSION}"
RUN python -m venv /venv
COPY pyproject.toml poetry.lock ./
RUN poetry export -f requirements.txt | /venv/bin/pip install -r /dev/stdin
COPY . .
RUN poetry build && /venv/bin/pip install dist/*.whl

FROM builder as development

RUN poetry export -f requirements.txt --dev | /venv/bin/pip install -r /dev/stdin
COPY alembic.ini scripts/run_tests.sh ./
ENTRYPOINT ["./run_tests.sh"]

FROM base as final
LABEL org.opencontainers.image.authors andrew@hoetker.engineer
LABEL org.opencontainers.image.url https://github.com/users/ahoetker/packages/container/package/glortho
LABEL org.opencontainers.image.source https://github.com/ahoetker/glortho


RUN apt-get update && \
    apt-get clean && \
    apt-get install -y \
    libpq-dev \
    sqlite3 \
    && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /venv /venv
COPY alembic.ini /app
COPY glortho /app/glortho
COPY scripts/docker-entrypoint.sh scripts/asgi.py scripts/run_tests.sh config.py ./
RUN chmod +x docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]
