#!/bin/bash
# EC2-B (K6 서버)에서 실행
# Docker + Docker Compose 설치 후 모니터링 스택 기동

set -euo pipefail

echo "=== Docker 설치 ==="
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

echo "=== Docker Compose 플러그인 설치 ==="
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.34.0/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "=== 설치 확인 ==="
docker --version
docker compose version

echo ""
echo "=== 완료 ==="
echo "newgrp docker 실행 후 monitoring/ 디렉토리에서 docker compose up -d"