#!/bin/bash

# --- Configurações que você pode ajustar ---
WAN_INTERFACE="eth0" # Altere para a sua interface WAN (ex: eth1, pppoe0)
ROUTER_IP="192.168.1.1" # Altere para o IP do seu EdgeRouter (interface LAN)
VPN_IP_POOL_START="192.168.200.10" # Início do pool de IPs para clientes VPN
VPN_IP_POOL_END="192.168.200.50" # Fim do pool de IPs para clientes VPN
DNS_SERVER_PRIMARY="$ROUTER_IP" # O DNS primário para os clientes VPN será o próprio roteador
DNS_SERVER_SECONDARY="1.1.1.1" # DNS secundário (Cloudflare)

# --- Geração de Chave Compartilhada e Credenciais (Automatizado) ---
SHARED_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9\_ | head -c 32)
VPN_USERNAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
VPN_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9\_ | head -c 20)

# --- Início da Configuração EdgeOS ---
echo "Iniciando a configuração da VPN L2TP/IPsec no EdgeOS..."

# Entra no modo de configuração
echo "configure"

# Regras de Firewall (WAN_LOCAL)
echo "set firewall name WAN_LOCAL rule 30 action accept"
echo "set firewall name WAN_LOCAL rule 30 description ike"
echo "set firewall name WAN_LOCAL rule 30 destination port 500"
echo "set firewall name WAN_LOCAL rule 30 log disable"
echo "set firewall name WAN_LOCAL rule 30 protocol udp"

echo "set firewall name WAN_LOCAL rule 40 action accept"
echo "set firewall name WAN_LOCAL rule 40 description esp"
echo "set firewall name WAN_LOCAL rule 40 log disable"
echo "set firewall name WAN_LOCAL rule 40 protocol esp"

echo "set firewall name WAN_LOCAL rule 50 action accept"
echo "set firewall name WAN_LOCAL rule 50 description nat-t"
echo "set firewall name WAN_LOCAL rule 50 destination port 4500"
echo "set firewall name WAN_LOCAL rule 50 log disable"
echo "set firewall name WAN_LOCAL rule 50 protocol udp"

echo "set firewall name WAN_LOCAL rule 60 action accept"
echo "set firewall name WAN_LOCAL rule 60 description l2tp"
echo "set firewall name WAN_LOCAL rule 60 destination port 1701"
echo "set firewall name WAN_LOCAL rule 60 ipsec match-ipsec"
echo "set firewall name WAN_LOCAL rule 60 log disable"
echo "set firewall name WAN_LOCAL rule 60 protocol udp"

# Configuração L2TP/IPsec Remote Access
echo "set vpn l2tp remote-access ipsec-settings authentication mode pre-shared-secret"
echo "set vpn l2tp remote-access ipsec-settings authentication pre-shared-secret \"$SHARED_SECRET\""

echo "set vpn l2tp remote-access authentication mode local"
echo "set vpn l2tp remote-access authentication local-users username \"$VPN_USERNAME\" password \"$VPN_PASSWORD\""

echo "set vpn l2tp remote-access client-ip-pool start \"$VPN_IP_POOL_START\""
echo "set vpn l2tp remote-access client-ip-pool stop \"$VPN_IP_POOL_END\""

echo "set vpn l2tp remote-access dns-servers server-1 \"$DNS_SERVER_PRIMARY\""
echo "set vpn l2tp remote-access dns-servers server-2 \"$DNS_SERVER_SECONDARY\""

echo "set vpn l2tp remote-access outside-address 0.0.0.0"

# Habilita IPsec na interface WAN
echo "set vpn ipsec ipsec-interfaces interface \"$WAN_INTERFACE\""

# Configura o serviço DNS forwarding
echo "set service dns forwarding options \"listen-address=$ROUTER_IP\""

# Aplica e salva as configurações
echo "commit ; save"

# Sai do modo de configuração
echo "exit"

echo ""
echo "--- Informações da VPN Geradas ---"
echo "Chave Pré-Compartilhada (IPsec): $SHARED_SECRET"
echo "Nome de Usuário (L2TP): $VPN_USERNAME"
echo "Senha (L2TP): $VPN_PASSWORD"
echo "Endereço IP do Roteador (para conexão): $ROUTER_IP (ou seu IP Público)"
echo "Pool de IPs para Clientes VPN: $VPN_IP_POOL_START - $VPN_IP_POOL_END"
echo "Servidores DNS para Clientes VPN: $DNS_SERVER_PRIMARY, $DNS_SERVER_SECONDARY"
echo ""
echo "--- Como Usar o Script ---"
echo "1. Salve o conteúdo acima em um arquivo .sh (ex: 'config_vpn.sh')."
echo "2. Torne-o executável: 'chmod +x config_vpn.sh'."
echo "3. Execute-o: './config_vpn.sh'."
echo "4. Copie a saída completa do terminal (tudo entre 'configure' e 'exit')."
echo "5. Conecte-se ao seu EdgeRouter via SSH."
echo "6. Cole a saída copiada diretamente no terminal do EdgeRouter."
echo "7. As configurações serão aplicadas e salvas."
echo ""