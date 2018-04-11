#!/bin/bash
################################################
# Script for installing Odoo on Ubuntu 16.04
# Just pass a URL intended to reach the instance
#-----------------------------------------------
# sudo chmod +x odoo-deployment.sh
# Execute the script
# ./odoo-deployment.sh www.test.com
################################################

#You can install Odoo 10, if you wish...
ODOO_VERSION="11"

if [$ODOO_VERSION != 10 && $ODOO_VERSION != 11 ]; then
  echo "Odoo version is invalid, please enter either 10 or 11"
  exit 1
fi

URL=$1

if [ "$URL" = "" ]; then
  echo "D: you did not supply a URL!"
  exit 1
fi

ODOO_USER="odoo"
USER_HOME="/home/$ODOO_USER"
INSTALL="/home/$ODOO_USER/odoo"
ODOO_PORT="8069"
ODOO_ADMIN="admin"
ODOO_CONFIG="$ODOO_USER"

# Set Hostname
sudo hostnamectl set-hostname $URL
echo "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) $(hostname -f) $(hostname -s)" | sudo tee -a /etc/hosts

# Update/upgrade setver
sudo apt-get update
sudo apt-get upgrade -y

# Install PostgreSQL server
sudo apt-get install postgresql -y

# Create Odoo Postgres user
sudo su - postgres -c "createuser -s $ODOO_USER" 2> /dev/null || true

# Install Python3, Pip3 and tools
sudo apt-get install python3 python3-pip wget git bzr python-pip gdebi-core -y

# Install Python packages
sudo apt-get install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil python-babel python-paramiko python-psycogreen python-ply python3-suds -y
sudo pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd

# Install other packages
sudo apt-get install node-clean-css node-less python-gevent -y

# Install Apache, PHP and enable mods
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

# Install wkhtmltopdf and shortcuts
sudo wget https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
sudo gdebi --n wkhtmltox-0.12.1_linux-trusty-amd64.deb
sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin

# Create Odoo user and setup sudo
sudo adduser $ODOO_USER --quiet --disabled-password --gecos ""
sudo adduser $ODOO_USER sudo
sudo echo "$ODOO_USER ALL=(ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo

# Create log folder
sudo mkdir /var/log/$ODOO_USER
sudo chown $ODOO_USER:$ODOO_USER /var/log/$ODOO_USER

# Install Odoo
if [$ODOO_VERSION == 10]; then
  if ! sudo git clone https://www.github.com/odoo/odoo --depth 1 --branch 11.0 $INSTALL/
   then
    echo >&2
    echo "Deployment halted here.  Unable to clone Odoo.";
    exit 1
  fi
  sudo mkdir -p ~/.local/share/Odoo/addons/10.0
else
  if ! sudo git clone https://www.github.com/odoo/odoo --depth 1 --branch 11.0 $INSTALL/
    then
    echo >&2
    echo "Deployment halted here.  Unable to clone Odoo.";
    exit 1
  fi
  sudo mkdir -p ~/.local/share/Odoo/addons/11.0
fi
sudo chown -R $ODOO_USER:$ODOO_USER $USER_HOME/*

# Create Odoo conf file
cat <<EOF > ~/$ODOO_CONFIG.conf
[options]
This is the password that allows database operations:
admin_passwd = ${ODOO_ADMIN}
xmlrpc_port = ${ODOO_PORT}
logfile = /var/log/odoo/odoo.log
EOF

# Install Odoo conf file
sudo mv ~/$ODOO_CONFIG.conf /etc/$ODOO_CONFIG.conf
sudo chown $ODOO_USER:$ODOO_USER /etc/$ODOO_CONFIG.conf
sudo chmod 640 /etc/$ODOO_CONFIG.conf

# Create Odoo service file
cat <<EOF > ~/$ODOO_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $ODOO_CONFIG
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
DAEMON=$INSTALL/odoo-bin
NAME=$ODOO_CONFIG
DESC=$ODOO_CONFIG
# Specify the user name (Default: odoo).
USER=$ODOO_USER
# Specify an alternate config file (Default: /etc/odoo.conf).
CONFIGFILE="/etc/$ODOO_CONFIG.conf"
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

# Install Odoo service file
sudo mv ~/$ODOO_CONFIG /etc/init.d/$ODOO_CONFIG
sudo chmod 755 /etc/init.d/$ODOO_CONFIG
sudo chown root: /etc/init.d/$ODOO_CONFIG

# Set Odoo service to start on boot
sudo update-rc.d $ODOO_CONFIG defaults

# Make vhost document root
sudo mkdir -p /var/www/vhosts/$(hostname)/httpdocs

# Create Apache conf file
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
</Virtualhost>
EOF

# Enable site and reload Apache
sudo mv ~/$(hostname).conf /etc/apache2/sites-available/
sudo a2ensite $(hostname).conf
sudo service apache2 reload

echo "The Odoo server is up and running, with Apache."

