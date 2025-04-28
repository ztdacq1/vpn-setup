#!/bin/bash

# 必须以 root 运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本。"
  exit 1
fi

# 安装必要的软件包
yum install -y epel-release
yum install -y ppp pptpd iptables-services

# 配置pptpd
cat > /etc/pptpd.conf <<EOF
option /etc/ppp/options.pptpd
logwtmp
localip 192.168.0.1
remoteip 192.168.0.100-200
EOF

# 配置PPP选项
cat > /etc/ppp/options.pptpd <<EOF
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 114.114.114.114
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd
EOF

# 配置VPN账户
echo "请输入VPN用户名:"
read vpnuser
echo "请输入VPN密码:"
read vpnpassword

echo "${vpnuser} pptpd ${vpnpassword} *" >> /etc/ppp/chap-secrets

# 开启IP转发
sed -i '/^net.ipv4.ip_forward/s/0/1/' /etc/sysctl.conf
sysctl -p

# 配置防火墙规则
firewall-cmd --permanent --add-service=ppp
firewall-cmd --permanent --add-port=1723/tcp
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p gre -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -p gre -j ACCEPT
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload

# 设置NAT转发
EXTERNAL_IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
iptables -t nat -A POSTROUTING -o $EXTERNAL_IFACE -j MASQUERADE
service iptables save

# 启动pptpd
systemctl enable pptpd
systemctl restart pptpd

echo "PPTP VPN 安装完成！"
echo "服务器IP: $(curl -s ifconfig.me)"
echo "用户名: $vpnuser"
echo "密码: $vpnpassword"
