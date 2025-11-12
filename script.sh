# --- Reinicia o Serviço Dante (FORMA CORRETA NO EDGEROUTER) ---
echo "Parando instâncias antigas do danted..."
killall danted 2>/dev/null
sleep 2

echo "Iniciando o Dante como serviço persistente..."
cat > /etc/systemd/system/danted.service <<EOF
[Unit]
Description=Dante SOCKS Proxy
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/danted -f /etc/danted.conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Ativa e inicia o serviço
systemctl daemon-reload
systemctl enable danted.service
systemctl restart danted.service

# Verifica status
sleep 3
echo "Status do serviço:"
systemctl status danted.service --no-pager

echo "Verificando porta $PROXY_PORT..."
netstat -ltnp | grep danted || ss -ltnp | grep danted

echo "================================================================="
echo "Dante SOCKS5 rodando com sucesso!"
echo "Teste local: curl --socks5 localhost:1080 http://ifconfig.me"
echo "Teste remoto: curl --socks5 SEU_IP_EXTERNO:1080 http://ifconfig.me"
echo "================================================================="
