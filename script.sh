#!/binash
# Este script configura uma VPN L2TP/IPsec no EdgeOS.
# Ele gera credenciais aleatórias e define as regras de firewall.
# Ele foi ajustado para maior compatibilidade com versões mais antigas do BusyBox (como EdgeOS v1.19.0).

# --- SEÇÃO DE CONFIGURAÇÃO OBRIGATÓRIA ---
# Você DEVE ajustar estas duas variáveis com base na saída de 'show interfaces':
# 1. WAN_INTERFACE: A interface conectada à Internet (ex: eth0, eth1, pppoe0).
#    Pela sua saída de 'show interfaces', é 'eth0'.
WAN_INTERFACE="eth0"

# 2. ROUTER_IP: O endereço IP da interface LAN principal do seu EdgeRouter.
#    Pela sua saída de 'show interfaces', a LAN principal (switch0) é '192.168.2.1'.
ROUTER_IP="192.168.2.1"

# --- CONFIGURAÇÕES DE REDE DA VPN (Ajuste se necessário) ---
VPN_IP_POOL_START="192.168.200.10" # Início do pool de IPs para clientes VPN
VPN_IP_POOL_END="192.168.200.50"   # Fim do pool de IPs para clientes VPN
DNS_SERVER_PRIMARY="$ROUTER_IP"    # O DNS primário para os clientes VPN será o próprio roteador
DNS_SERVER_SECONDARY="1.1.1.1"     # DNS secundário (Cloudflare)

# --- INÍCIO DA EXECUÇÃO DO SCRIPT ---

# Auto-correção de terminadores de linha:
# Garante que o script está usando terminadores de linha Unix (LF).
# Isso corrige o erro "bad interpreter" se o arquivo foi salvo com CRLF.
# Redireciona a si mesmo através do 'tr' para remover '\r' e re-executa.
if [[ "$(head -1 "$0" | tr -d '\n' | tail -c 1)" == $'\r' ]]; then
    echo "Corrigindo terminadores de linha (CRLF para LF)..."
    exec /bin/bash <(tr -d '\r' < "$0")
fi

echo "Iniciando a geração da configuração da VPN L2TP/IPsec..."

# --- Geração de Chave Compartilhada e Credenciais (Automatizado) ---
# Usando /dev/urandom para gerar strings aleatórias para segurança.
SHARED_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9\_ | head -c 32)
VPN_USERNAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
VPN_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9\_ | head -c 20)

echo ""
echo "--- Comandos para Colar no EdgeRouter (Modo Configuração) ---"
echo "configure"

# Regras de Firewall (WAN_LOCAL) para L2TP/IPsec
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
echo "Endereço IP do Roteador (para conexão): SEU_IP_PUBLICO_AQUI (Ex: 206.121.120.230)"
echo "Servidores DNS para Clientes VPN: $DNS_SERVER_PRIMARY (seu roteador), $DNS_SERVER_SECONDARY (Cloudflare)"
echo ""
echo "--- Próximos Passos ---"
echo "1. Salve este conteúdo como 'script.sh' no GitHub (garantindo terminadores LF se possível)."
echo "2. No seu EdgeRouter via SSH, execute:"
echo "   curl -sL https://raw.githubusercontent.com/rdkkl5/41234212412/main/script.sh | bash"
echo "3. O script irá imprimir os comandos de configuração. Copie tudo entre 'configure' e 'exit'."
echo "4. Cole esses comandos no terminal do EdgeRouter (no prompt ctcadmin@ubnt:~$)."
echo "5. Anote as 'Informações da VPN Geradas para o Cliente' para configurar seu dispositivo."
echo "6. Lembre-se de substituir 'SEU_IP_PUBLICO_AQUI' pelo IP público da sua rede para a conexão do cliente."
echo ""
