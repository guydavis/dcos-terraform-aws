#!/usr/bin/env bash

## NO set -e, handle errors manually here

source `pwd`/env-setup.sh

# Install dcos-cli on all master nodes.
log "Installing DCOS CLI into /usr/local/bin"
curl -vfLsS --retry 20 -Y 100000 -y 60 https://downloads.dcos.io/binaries/cli/linux/x86-64/dcos-1.8/dcos -o /usr/local/bin/dcos && chmod +x /usr/local/bin/dcos 
log "After provisioning, to use DCOS CLI, run:  dcos config set core.dcos_url http://[MASTER_NODE_IP]"

log "Generating DCOS config..."
`pwd`/dcos_generate_config.sh
if [ $? != 0 ]; then
  log "[ERROR]: dcos_generate_config.sh failed."
  exit 200
fi

if [ -z "$(docker ps | grep bootstrap 2>/dev/null)" ]; then
  log "Starting bootstrap nginx container $BOOTSTRAP_PORT..."
  docker run -d -p $BOOTSTRAP_PORT:80 -v `pwd`/genconf/serve:/usr/share/nginx/html:ro --name=bootstrap nginx
  if [ $? != 0 ]; then
    log "[ERROR]: Failed to start bootstrap container."
    exit 201
  fi
else
  log "Bootstrap nginx container already up..."
fi

if [ ! -f /etc/systemd/system/consul.d/service-bootstrap-server.json ]; then
  log "Registering bootstrap-server service in consul..."
  tee /etc/systemd/system/consul.d/service-bootstrap-server.json <<EOF
{
  "service": {
    "id": "bootstrap-server",
    "name": "bootstrap-server",
    "port": ${BOOTSTRAP_PORT},
    "address": "${IPV4_PRIVATE}"
  }
}
EOF
  systemctl restart consul
else
  log "bootstrap-server service already registered."
fi