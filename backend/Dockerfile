FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
RUN groupadd --gid 10001 flow && useradd --uid 10001 --gid flow --create-home flow
COPY requirements.lock .
RUN pip install -r requirements.lock
COPY --chown=flow:flow . .
USER flow
EXPOSE 8000
CMD ["sh", "scripts/start-api.sh"]
