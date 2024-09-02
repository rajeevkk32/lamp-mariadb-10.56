#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# SELinux Configuration
echo "Disabling SELinux..."
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
echo "SELinux set to permissive. Rebooting system..."
setenforce 0
#sudo reboot

# Check if qemu-guest-agent is installed before attempting to install it
#if ! systemctl is-active --quiet qemu-guest-agent; then
#    echo "Installing and starting qemu-guest-agent..."
#    sudo dnf install qemu-guest-agent -y
#    sudo systemctl start qemu-guest-agent
#    sudo systemctl enable qemu-guest-agent
#else
#    echo "qemu-guest-agent is already installed and running."
#fi

# Update and Configure Repositories
echo "Updating system and configuring repositories..."
sudo dnf upgrade --refresh -y
sudo dnf config-manager --set-enabled crb

# Install EPEL and Remi Repositories
if ! rpm -q epel-release remi-release &> /dev/null; then
    echo "Installing EPEL and Remi repositories..."
    sudo dnf install -y \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
        https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm \
        dnf-utils \
        http://rpms.remirepo.net/enterprise/remi-release-9.rpm
else
    echo "EPEL and Remi repositories are already installed."
fi

# Clean and Update System
echo "Cleaning and updating system..."
sudo dnf update -y
sudo dnf config-manager --set-enabled crb
sudo dnf install epel-release epel-next-release -y
sudo dnf repolist
sudo dnf update -y
timedatectl set-timezone Asia/Kolkata
sudo dnf install -y epel-release bind-utils traceroute
sudo dnf upgrade -y
#sudo dnf config-manager --set-enabled PowerTools

# Install Additional Packages
echo "Installing additional packages..."
sudo dnf install -y epel-release git nmap smartmontools telnet unzip wget yum-utils zip htop perl sendmail tcpdump bind-utils net-tools tar chrony

# Install and Configure httpd
if ! systemctl is-active --quiet httpd; then
    echo "Installing and configuring httpd..."
    sudo dnf install httpd -y
    sudo systemctl enable httpd
    sudo systemctl start httpd
    sudo yum install mod_ssl openssl -y
    sudo systemctl restart httpd
else
    echo "httpd is already installed and running."
fi

# Change SSH Port
if ! grep -q "^Port 5322" /etc/ssh/sshd_config; then
    echo "Changing SSH port to 5322..."
    sudo sed -i 's/#Port 22/Port 5322/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
else
    echo "SSH port is already set to 5322."
fi

# Install PHP 8.3
if ! php -v | grep -q "PHP 8.3"; then
    echo "Installing PHP 8.3..."
    sudo dnf update -y
    sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y
    sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-9.rpm -y
    sudo dnf module enable php:remi-8.3 -y
    sudo dnf install php php-cli php-common php-fpm php-mysqlnd php-zip php-devel php-gd php-mcrypt php-mbstring php-curl php-xml php-pear php-bcmath php-json php-process -y
    sudo systemctl restart httpd
    php -v
else
    echo "PHP 8.3 is already installed."
fi

# Disable Firewalld
if systemctl is-active --quiet firewalld; then
    echo "Disabling firewalld..."
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
else
    echo "firewalld is already disabled."
fi

# Install CSF
if ! [ -d "/etc/csf" ]; then
    echo "Installing CSF..."
    cd /tmp
    sudo dnf install wget iptables -y
    #sudo dnf install @perl -y
    wget https://download.configserver.com/csf.tgz
    sudo dnf install perl-libwww-perl.noarch perl-LWP-Protocol-https.noarch perl-GDGraph -y
    sudo tar -xvzf csf.tgz
    cd csf
    sudo sh install.sh
    perl csftest.pl
else
    echo "CSF is already installed."
fi

# MariaDB 10.11 Installation
if ! systemctl is-active --quiet mariadb; then
    echo "Configuring and installing MariaDB 10.11..."
    sudo tee /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = https://mariadb.gb.ssimn.org/yum/10.5/centos/\$releasever/\$basearch
gpgkey = https://mariadb.gb.ssimn.org/yum/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOF

    sudo dnf install MariaDB-server MariaDB-client mariadb-backup -y
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    #sudo mariadb-secure-installation
    sudo systemctl restart mariadb
else
    echo "MariaDB 10.11 is already installed and running."
fi

# PHPMyAdmin Installation
if [ ! -d "/usr/share/phpmyadmin" ]; then
    echo "Installing phpMyAdmin..."
    cd /usr/share
    sudo wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-english.zip
    sudo unzip phpMyAdmin-5.2.1-english.zip
    sudo mv phpMyAdmin-5.2.1-english phpmyadmin
    cd phpmyadmin/
    sudo dnf install -y wget php-pdo php-pecl-zip php-json php-common php-fpm php-mbstring php-cli php-mysqlnd
    sudo cp -pr /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php
    sudo mkdir /usr/share/phpmyadmin/tmp
    sudo chmod 777 /usr/share/phpmyadmin/tmp
    sudo chown -R apache:apache /usr/share/phpmyadmin
    sudo systemctl restart httpd
    sudo tee /etc/httpd/conf.d/phpmyadmin.conf <<EOF
Alias /db-ssq /usr/share/phpmyadmin
<Directory /usr/share/phpmyadmin/>
    AddDefaultCharset UTF-8
    <IfModule mod_authz_core.c>
      <RequireAny>
        Require all granted
        Require ip 127.0.0.1
        Require ip ::1
      </RequireAny>
    </IfModule>
    <IfModule !mod_authz_core.c>
      Order Deny,Allow
      Deny from All
      Allow from 127.0.0.1
      Allow from ::1
    </IfModule>
</Directory>
<Directory /usr/share/phpmyadmin/setup/>
    <IfModule mod_authz_core.c>
      <RequireAny>
        Require ip 127.0.0.1
        Require ip ::1
      </RequireAny>
    </IfModule>
    <IfModule !mod_authz_core.c>
      Order Deny,Allow
      Deny from All
      Allow from 127.0.0.1
      Allow from ::1
    </IfModule>
</Directory>
<Directory /usr/share/phpmyadmin/libraries/>
    Order Deny,Allow
    Deny from All
    Allow from None
</Directory>
<Directory /usr/share/phpmyadmin/setup/lib/>
    Order Deny,Allow
    Deny from All
    Allow from None
</Directory>
<Directory /usr/share/phpmyadmin/setup/frames/>
    Order Deny,Allow
    Deny from All
    Allow from None
</Directory>
EOF

    sudo systemctl restart httpd
    sudo systemctl restart php-fpm
else
    echo "phpMyAdmin is already installed."
fi

if ! systemctl is-active --quiet openvpn; then
    echo "Installing OpenVPN..."
    sudo yum install openvpn -y
else
    echo "OpenVPN is already installed."
fi

netstat -tlpn

echo "Setup completed successfully!"

echo 'udp|out|d=3789|d=192.46.208.8' >> /etc/csf/csf.allow

sudo mariadb-secure-installation
