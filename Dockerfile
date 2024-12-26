# Use the official slim Python 3.11 image as the base image
FROM python:3.13-slim as base

#################### construct a "base" image with poetry

# update 11/5/24, now install certain poetry packages
FROM base as poetry_base
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_CACHE_DIR='/var/cache/pypoetry' \
    POETRY_HOME='/usr/local'

RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata \
    && apt-get install -y openssh-client \
    && apt-get -y clean \
    && apt-get -y autoclean

# Install Poetry
RUN python3 -m pip config set global.break-system-packages true \
    && pip install poetry


#################### install python packages via poetry

# if building for dev (testing) specify DEV=1 as an argument "--without dev"
FROM poetry_base as builder
ARG DEV
RUN if [ -z "$DEV" ]; then DEV="--without dev"; fi && echo "DEV=$DEV" >> /etc/environment

# Copy the pyproject.toml and poetry.lock files to the container
WORKDIR /app
COPY pyproject.toml poetry.lock /app/

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_CACHE_DIR='/var/cache/pypoetry' \
    POETRY_HOME='/usr/local'

# Trick for credential stamping here... https://stackoverflow.com/a/55761914
RUN mkdir -p /root/.ssh/ \
    && touch /root/.ssh/known_hosts \
    && ssh-keyscan github.com >> /root/.ssh/known_hosts 
# Install dependencies and poetry (without dev libraries unless DEV is set)
RUN --mount=type=ssh,id=github_ssh_key \
    python3 -m pip config set global.break-system-packages true \
    && poetry install --no-root


#################### update our actual code, set up runtime

# Set the command to run the application
FROM base as runtime
WORKDIR /app

ENV VIRTUAL_ENV=/usr/local \
    PATH="/usr/local/bin:$PATH"

COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}

ENV PYTHONUNBUFFERED 1

# Copy the rest of the application code to the container
COPY  . /app

ENTRYPOINT []
CMD ["python3", "-c", "openwebui_discord_bot.main"]
