FROM debian:bookworm

RUN apt-get update && apt-get install -y python3 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html/resume
COPY index.html /var/www/html/resume/


EXPOSE 8080

ENTRYPOINT ["python3", "-m", "http.server", "8080", "--directory", "/var/www/html"]
