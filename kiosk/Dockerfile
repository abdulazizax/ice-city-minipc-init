# Ubuntu Server compatible Chromium kiosk image
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install Chromium and essential dependencies for Ubuntu Server
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       chromium \
       fonts-liberation \
       fontconfig \
       ca-certificates \
       wget \
       dumb-init \
       x11-utils \
       # Essential libraries for Chromium
       libnss3 \
       libgtk-3-0 \
       libx11-xcb1 \
       libxcomposite1 \
       libxdamage1 \
       libxrandr2 \
       libxss1 \
       libgconf-2-4 \
       libasound2 \
       libatspi2.0-0 \
       libdbus-1-3 \
       libxkbcommon0 \
       libxfixes3 \
       libdrm2 \
       libxcursor1 \
       libxi6 \
       libxtst6 \
       libpangocairo-1.0-0 \
       libatk1.0-0 \
       libcairo-gobject2 \
       libgdk-pixbuf2.0-0 \
       libappindicator3-1 \
    && rm -rf /var/lib/apt/lists/*

# Environment variables for Ubuntu Server compatibility
ENV LAUNCH_URL="http://localhost:8088/frontend/index.html" \
    DISPLAY=":0" \
    QT_QPA_PLATFORM="xcb" \
    GDK_BACKEND="x11"

# Create non-root user for running Chromium
RUN useradd -m -s /bin/bash kiosk \
    && mkdir -p /home/kiosk/.config/chromium \
    && chown -R kiosk:kiosk /home/kiosk

USER kiosk
WORKDIR /home/kiosk

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Make entrypoint executable
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER kiosk

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]