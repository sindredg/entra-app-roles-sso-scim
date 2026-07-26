FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
# Non-root user: the bridge needs no privileges
RUN useradd -r scim
USER scim
EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "--access-logfile", "-", "app:app"]
