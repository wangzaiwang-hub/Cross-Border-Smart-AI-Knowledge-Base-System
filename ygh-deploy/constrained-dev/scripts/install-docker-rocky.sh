#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

if podman ps -a --format '{{.ID}}' 2>/dev/null | grep -q .; then
  echo "Podman containers exist; refusing to remove Podman" >&2
  exit 2
fi

dnf remove -y podman buildah || true
dnf install -y dnf-plugins-core curl ca-certificates
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

install -d -m 0755 /etc/docker
if [[ -f /etc/docker/daemon.json ]]; then
  cp -a /etc/docker/daemon.json "/etc/docker/daemon.json.bak-$(date +%Y%m%d-%H%M%S)"
fi
cat >/etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run"
  ],
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ]
}
JSON

systemctl daemon-reload
systemctl enable --now docker
usermod -aG docker wang || true

docker version
docker compose version
docker info --format 'Docker={{.ServerVersion}} Cgroup={{.CgroupVersion}} Driver={{.Driver}}'
