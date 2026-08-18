FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    vsftpd \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /var/run/vsftpd/empty && \
    mkdir -p /etc/vsftpd

# Copy configuration and script
COPY conf/vsftpd.conf /etc/vsftpd.conf
COPY tools/init-ftp.sh /usr/local/bin/init-ftp.sh
RUN chmod +x /usr/local/bin/init-ftp.sh

EXPOSE 21 21100-21110

ENTRYPOINT ["/usr/local/bin/init-ftp.sh"]
