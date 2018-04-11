#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 16.04
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install
# multiple Odoo instances in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo the version you require:
# ./odoo-install 10 or ./odoo-install 11
################################################################################

#Choose the Odoo version which you want to install. For example: 11.0, 10.0. When using 'master' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 11.0
OE_VERSION="$11"

if [$OE_VERSION != 10 && $OE_VERSION != 11 ]; then
	echo "Odoo version is invalid, please enter either 10 or 11"
	exit 1
fi

URL=$1

if [ "$URL" = "" ]; then
  echo "D: you did not supply a URL!"
  exit 1
fi


##fixed parameters
OE_USER="odoo"
OE_HOME="/home/$OE_USER"
OE_HOME_EXT="/home/$OE_USER/$OE_USER"
#Set the default Odoo port (you still have to use -c /etc/odoo.conf for example to use this.)
OE_PORT="8069"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="$OE_USER"

echo -e "\n---- Set Hostname ----"
sudo hostnamectl set-hostname $URL
sudo su - echo "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) $(hostname -f) $(hostname -s)" >> /etc/hosts

echo -e "\n---- Update Server ----"
sudo apt-get update
sudo apt-get upgrade -y

echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install python3 python3-pip -y

echo -e "\n---- Install tool packages ----"
sudo apt-get install wget git bzr python-pip gdebi-core -y

echo -e "\n---- Install python packages ----"
sudo apt-get install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil python-babel python-paramiko python-psycogreen python-ply -y

sudo pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd

echo -e "\n---- Install python libraries ----"
sudo apt-get install python3-suds -y

echo -e "\n--- Install other required packages ----"
sudo apt-get install node-clean-css -y
sudo apt-get install node-less -y
sudo apt-get install python-gevent -y

echo -e "\n--- Install and configure apache ----"
sudo apt-get install apache2 php7.0 libapache2-mod-php7.0 php7.0-xmlrpc xfonts-75dpi -y
sudo /etc/init.d/apache2 start
sudo update-rc.d apache2 defaults
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_ajp
sudo a2enmod rewrite
sudo a2enmod deflate
sudo a2enmod headers
sudo a2enmod proxy_balancer
sudo a2enmod proxy_connect
sudo a2enmod proxy_html
sudo a2dissite 000-default
sudo mkdir /var/lib/odoo
sudo chown -R odoo:root /var/lib/odoo
sudo mkdir /var/log/odoo
sudo touch /var/log/odoo/odoo.log
sudo chown -R odoo:root /var/log/odoo
sudo chown -R odoo:adm /var/log/apache2
sudo service apache2 reload

echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO ----"
sudo wget https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
sudo gdebi --n wkhtmltox-0.12.1_linux-trusty-amd64.deb
sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin

echo -e "\n---- Create ODOO user ----"
sudo adduser $OE_USER --quiet --disabled-password --gecos ""
sudo adduser $OE_USER sudo
sudo echo "$OE_USER ALL=(ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

echo -e "\n==== Installing ODOO Server ===="
if [$OE_VERSION == 10]; then
  if ! sudo git clone https://github.com/mcb30/odoo.git --depth 20 --branch import $OE_HOME_EXT/
   then
    echo >&2
    echo "Deployment halted here.  Unable to clone Odoo.";
    exit 1
  fi
  sudo mkdir -p ~/.local/share/Odoo/addons/10.0
else
	if ! sudo git clone https://www.github.com/odoo/odoo --depth 1 --branch 11.0 $OE_HOME_EXT/
		then
		echo >&2
		echo "Deployment halted here.  Unable to clone Odoo.";
    exit 1
  fi
	sudo mkdir -p ~/.local/share/Odoo/addons/11.0
fi

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"
sudo touch /etc/$OE_CONFIG.conf

echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/$OE_CONFIG.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/$OE_CONFIG.conf"
sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/$OE_CONFIG.conf"
sudo su root -c "printf 'logfile = /var/log/odoo/odoo.log\n' >> /etc/$OE_CONFIG.conf"
sudo chown $OE_USER:$OE_USER /etc/$OE_CONFIG.conf
sudo chmod 640 /etc/$OE_CONFIG.conf

echo -e "* Create init file"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# Specify the user name (Default: odoo).
USER=$OE_USER
# Specify an alternate config file (Default: /etc/odoo.conf).
CONFIGFILE="/etc/$OE_CONFIG.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* Security Init File"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "* Start ODOO on Startup"
sudo update-rc.d $OE_CONFIG defaults

echo -e "\n--- Create DocumentRoot ----"
sudo mkdir -p /var/www/vhosts/$(hostname)/httpdocs

echo -e "\n--- Create conf file ----"
sudo cat <<EOF > ~/$(hostname).conf
<Virtualhost *:80>
      ServerAdmin webmaster@localhost
      ServerName $(hostname)

      DocumentRoot /var/www/vhosts/$(hostname)/httpdocs
      ErrorLog ${APACHE_LOG_DIR}/$(hostname)_error.log
      CustomLog ${APACHE_LOG_DIR}/$(hostname)_access.log combined

      ProxyRequests Off
      SetEnv proxy-nokeepalive 1

      ProxyPass /longpolling/ http://localhost:8072/longpolling/ retry=0
      ProxyPassReverse /longpolling/ http://localhost:8072/longpolling/ retry=0
      ProxyPass /                    http://localhost:8069/ retry=0
      ProxyPassReverse /             http://localhost:8069/ retry=0
      ProxyTimeout 1800
 
      <Directory /var/www/vhosts/$(hostname)/httpdocs>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
      </Directory>

      <Location /web/database/>
            Order deny,allow
            Deny from all
      </Location>
      
</Virtualhost>
EOF

echo -e "\n--- Enable site and reload Apache ----"
sudo mv ~/$(hostname).conf /etc/apache2/sites-available/
sudo a2ensite $(hostname).conf
sudo service apache2 reload

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running."
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"