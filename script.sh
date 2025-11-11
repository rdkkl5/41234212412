#!/bin/bash

# --- Configurações que você pode ajustar (se não forem detectadas) ---
# WAN_INTERFACE="eth0" # Será detectado automaticamente
# ROUTER_IP="192.168.1.1" # Será detectado automaticamente

VPN_IP_POOL_START="192.168.200.10" # Início do pool de IPs para clientes VPN
VPN_IP_POOL_END="192.168.200.50" # Fim do pool de IPs para clientes VPN
DNS_SERVER_PRIMARY="" # Será definido para o ROUTER_IP detectado
DNS_SERVER_SECONDARY="1.1.1.1" # DNS secundário (Cloudflare)

# --- Detecção Automática de WAN_INTERFACE e ROUTER_IP ---
echo "Detectando WAN_INTERFACE e ROUTER_IP..."

# Tenta detectar a interface WAN principal com IP público
# Isso é uma heurística e pode precisar de ajuste dependendo da sua configuração.
# Procura por interfaces que não são loopback, não são virtuais (como br-lan), e que possuem um gateway padrão.
WAN_INTERFACE=$(ip route show default | awk '/default via/ {print $5}' | head -n 1)

if [ -z "$WAN_INTERFACE" ]; then
    echo "AVISO: Não foi possível detectar automaticamente a interface WAN. Usando 'eth0' como padrão. Por favor, ajuste se necessário."
    WAN_INTERFACE="eth0"
else
    echo "WAN_INTERFACE detectada: $WAN_INTERFACE"
fi

# Tenta detectar o IP da interface LAN que está ativa (geralmente a que o SSH está conectado ou a que serve como gateway para a LAN)
# Iremos assumir que a interface LAN é aquela que tem um IP no mesmo segmento da interface de gerenciamento, ou a primeira interface que não é a WAN.
# Uma forma mais robusta é pegar o IP da interface onde o roteador está escutando para SSH, ou o IP da interface padrão da LAN.
# Para EdgeOS, 'show interfaces' é o mais confiável para ver IPs configurados.
# Para fins de script, vamos pegar o IP da interface WAN (pode ser o IP externo, ou o IP interno se for PPPoE/DHCP cliente)
# Ou, melhor, o IP da interface que o EdgeOS está usando para o encaminhamento DNS.
# Vamos pegar o IP da interface que não é a WAN, e que tem um IP configurado.
ROUTER_IP=$(ip -4 addr show dev $(ip route show default | awk '/default via/ {print $3}' | xargs -I {} ip route get {} | awk '/src/ {print $5}') | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# Se a detecção do ROUTER_IP falhar, usa um padrão.
if [ -z "$ROUTER_IP" ]; then
    echo "AVISO: Não foi possível detectar automaticamente o ROUTER_IP. Usando '192.168.1.1' como padrão. Por favor, ajuste se necessário."
    ROUTER_IP="192.168.1.1" # IP LAN padrão para muitos EdgeRouters
else
    echo "ROUTER_IP detectado: $ROUTER_IP"
fi

# Define o DNS primário como o ROUTER_IP detectado
DNS_SERVER_PRIMARY="$ROUTER_IP"

# --- Geração de Chave Compartilhada e Credenciais (Automatizado) ---
SHARED_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9\_ | head -c 32)
VPN_USERNAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
VPN_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9\_ | head -c 20)

# --- Início da Configuração EdgeOS ---
echo ""
echo "--- Comandos para Colar no EdgeRouter ---"
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

echo "--- Informações da VPN Geradas para o Cliente ---"
echo "Chave Pré-Compartilhada (IPsec): $SHARED_SECRET"
echo "Nome de Usuário (L2TP): $VPN_USERNAME"
echo "Senha (L2TP): $VPN_PASSWORD"
echo "Endereço IP do Roteador (para conexão): $ROUTER_IP (ou seu IP Público WAN)"
echo "Servidores DNS para Clientes VPN: $DNS_SERVER_PRIMARY (seu roteador), $DNS_SERVER_SECONDARY (Cloudflare)"
echo ""
echo "--- Próximos Passos ---"
echo "1. Copie o bloco de comandos acima (entre 'configure' e 'exit')."
echo "2. Conecte-se ao seu EdgeRouter via SSH."
echo "3. Cole os comandos copiados diretamente no terminal do EdgeRouter e pressione Enter."
echo "4. As configurações serão aplicadas e salvas automaticamente."
echo "5. Anote as 'Informações da VPN Geradas para o Cliente' para configurar seu dispositivo."
echo ""
