# Build context: workspace root
# This image packages the SharePoint Graph API, static console, and scripts.

FROM node:20-bullseye-slim

ENV NODE_ENV=production

# Install PowerShell 7 (pwsh) for validation and operational scripts.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		gnupg \
		apt-transport-https \
	&& curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg \
	&& echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/11/prod bullseye main" > /etc/apt/sources.list.d/microsoft.list \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends powershell \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies first (better layer caching)
COPY api/package*.json ./api/
RUN cd /app/api \
	&& npm install --omit=dev --no-audit --no-fund

# Copy app code + assets
COPY api ./api
COPY config ./config
COPY web ./web
COPY scripts ./scripts

# Ensure runtime directories exist
RUN mkdir -p /app/logs /app/raw /app/data /app/backup

EXPOSE 3001

WORKDIR /app/api
CMD ["node", "server.js"]
