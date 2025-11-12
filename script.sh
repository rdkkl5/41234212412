#!/bin/bash
# Script Dante SOCKS5 para EdgeRouter - VERSÃO CORRIGIDA E TESTADA
PROXY_USER="3ffd402d17b2"
PROXY_PASS="a4Psc6USLJN2bvQjOD"
PROXY_PORT="1080"
WAN_INTERFACE="eth0"   # Mude se sua WAN for pppoe0, eth1, etc.

echo "=== Instalando/Atualizando dante-server ==="
apt-get update -y
apt-get install -y dante-server

echo "=== Criando usuário $PROXY_USER ==="
if id "$PROXY_USER" &>/dev/null; then
    echo "$PROXY_USER:$PROXY_PASS" | chpasswd
else
    adduser --disabled-password --gecos "" "$PROXY_USER"
    echo "$PROXY_USER:$PROXY_PASS" | chpasswd
fi

echo "=== Configurando /etc/danted.conf ==="
cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $PROXY_PORT
external: $WAN_INTERFACE
socksmethod: username
clientmethod: none
user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOF

echo "=== Criando serviço systemd (funciona no EdgeOS 1.10+ e 2.x) ==="
cat > /etc/systemd/system/danted.service <<EOF
[Unit]
Description=Dante SOCKS5 Proxy
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/danted -f /etc/danted.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "=== Iniciando serviço ==="
killall danted 2>/dev/null
systemctl daemon-reload
systemctl enable danted.service
systemctl restart danted.service

sleep 3
echo "=== Status do serviço ==="
systemctl status danted.service --no-pager

echo "=== Verificando porta $PROXY_PORT ==="
netstat -ltnp | grep danted || ss -ltnp | grep ":$PROXY_PORT"

echo "=== TESTE RÁPIDO ==="
echo "IP local via proxy: $(curl -s --socks5 localhost:$PROXY_PORT http://ifconfig.me || echo 'FALHOU')"

echo "==================================================================="
echo "PRONTO! Dante SOCKS5 rodando na porta $PROXY_PORT"
echo "Não esqueça da regra de firewall (execute no CLI):"
echo "configure"
echo "set firewall name WAN_LOCAL rule 30 action accept"
echo "set firewall name WAN_LOCAL rule 30 protocol tcp"
echo "set firewall name WAN_LOCAL rule 30 destination port $PROXY_PORT"
echo "set firewall name WAN_LOCAL rule 30 description \"SOCKS5 Proxy\""
echo "commit; save; exit"
echo "==================================================================="
