# Use a base image that includes Python
FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Install system dependencies needed for Chrome and the webdriver
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Add Google Chrome repository and install Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list
RUN apt-get update && apt-get install -y google-chrome-stable

# Install the correct version of chromedriver
# Check for the latest stable version if this build fails in the future
RUN wget -O /tmp/chromedriver.zip https://storage.googleapis.com/chrome-for-testing-public/125.0.6422.78/linux64/chromedriver-linux64.zip && \
    unzip /tmp/chromedriver.zip -d /usr/bin && \
    mv /usr/bin/chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
    rm /tmp/chromedriver.zip

# Copy and install Python requirements
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Set the entrypoint for the container
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]