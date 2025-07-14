# Use Python 3.11 slim image for smaller size
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies for Qt6 and database
RUN apt-get update && apt-get install -y \
    libxcb1 \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-xfixes0 \
    libxcb-xinerama0 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libpq-dev \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p logs data/exports

# Set environment variables
ENV DISPLAY=:99
ENV QT_QPA_PLATFORM=xcb

# Expose port for potential web interface
EXPOSE 8080

# Create startup script
RUN echo '#!/bin/bash\n\
# Start virtual display for headless Qt\n\
Xvfb :99 -screen 0 1024x768x24 &\n\
sleep 2\n\
# Start the application\n\
python main.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f "python main.py" > /dev/null || exit 1

# Run the application
CMD ["/app/start.sh"]
