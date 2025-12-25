FROM python:3.12-slim

WORKDIR /app

COPY te_po/proxy/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY te_po/proxy/ .
COPY .env .env.example /app/

EXPOSE 8000

CMD ["python", "main.py"]
