sudo bash -c 'cat > install_dante.sh' <<'EOF'
#!/bin/bash

# --- Variáveis de Configuração ---
PROXY_USER="3ffd402d17b2"
PROXY_PASS="a4Psc6USLJN2bvQjOD"
PROXY_PORT="1080"
WAN_INTERFACE="eth0" # AJUSTE AQUI SE SUA INTERFACE WAN NÃO FOR ETH0

# --- Criação do Usuário para Autenticação SOCKS5 ---
echo "Criando ou atualizando usuário '$PROXY_USER'..."
if id "$PROXY_USER" &>/dev/null; then
    echo "Usuário '$PROXY_USER' já existe. Atualizando senha."
    echo -e "$PROXY_PASS\n$PROXY_PASS" | passwd "$PROXY_USER"
else
    adduser --disabled-password --gecos "" "$PROXY_USER"
    echo -e "$PROXY_PASS\n$PROXY_PASS" | passwd "$PROXY_USER"
fi

# --- Criação do Arquivo de Configuração do Dante ---
echo "Criando o arquivo de configuração /etc/danted.conf..."
cat > /etc/danted.conf <<EOCONF # Removidas as aspas simples para expansão de variáveis
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = ${PROXY_PORT}
external: ${WAN_INTERFACE}

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
EOCONF # Este deve corresponder ao delimitador de abertura

# --- Reinicia o Serviço Dante ---
echo "Reiniciando o serviço Dante..."
killall danted 2>/dev/null
/usr/sbin/danted -D -f /etc/danted.conf

echo "Verificando se o Dante está escutando na porta $PROXY_PORT..."
netstat -ltnp | grep "$PROXY_PORT"

echo "Configuração do Dante SOCKS5 concluída."
echo "****************************************************************"
echo "Lembre-se: Você AINDA PRECISA configurar a regra de firewall no EdgeRouter para a porta $PROXY_PORT."
echo "Comandos (execute no CLI do EdgeRouter):"
echo "configure"
echo "set firewall name WAN_LOCAL rule 30 description \"SOCKS5 proxy\""
echo "set firewall name WAN_LOCAL rule 30 action accept"
echo "set firewall name WAN_LOCAL rule 30 destination port ${PROXY_PORT}"
echo "set firewall name WAN_LOCAL rule 30 protocol tcp"
echo "commit"
echo "save"
echo "exit"
echo "****************************************************************"
EOF
