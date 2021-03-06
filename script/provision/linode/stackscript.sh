#!/bin/bash

# Verbose bash ouput.  See commands as they are run.
# set -x

# Leave commented for Linode.  Uncomment if debugging.
# [[ $UID -ne 0 ]] && echo "Must be run as root!" && exit 1

# Leave commented for Linode.  Uncomment if debugging.
# Abort script on ctrl+c.
# trap "echo Signal trap. Abort!; exit 1;" SIGINT SIGTERM

# The UDF format is used by Linode to accept parameters when running.
# These lines look commented, but WILL WORK CORRECTLY in the Linode web UI.

#<UDF name="new_hostname"                         label="Hostname" />
#<UDF name="ssh_key"                              label="Paste in your public SSH key so you can log into box after provisioning" />
#<UDF name="notify_email"                         label="Email address to notify when boostrap is complete" />

#<UDF name="github_username"                      label="Enter your github username (so we can add this machine's SSH key to github)" />
#<UDF name="github_password"                      label="Enter your github password (so we can add this machine's SSH key to github)" />
#<UDF name="github_repo"                          label="Enter your github repo name (so we can check your code out)" />
#<UDF name="git_branch"      default="master"     label="Git branch to check out" />

#<UDF name="node_env"        default="production" label="NODE_ENV"/>

##### Locals.

SCRIPT_NAME="** linode_stackscript"
APP_ROOT="/home/deploy/app/current"
APP_USER="deploy"

##### Exports.

export IP=`ifconfig eth0 | grep "inet addr" | awk '{ print $2 }' | awk 'BEGIN { FS=":" } { print $2 }'`
export NODE_ENV=$NODE_ENV

##### Stackscript log.

exec &> /root/stackscript.log

##### Begin.

echo "$SCRIPT_NAME: Running $GITHUB_REPO linode bootstrap script."
date

##### Local functions

function lower {
  echo $1 | tr '[:upper:]' '[:lower:]'
}

function system_sshd_edit_bool {
  # $1 - param name
  # $2 - Yes/No
  VALUE=`lower $2`
  if [ "$VALUE" == "yes" ] || [ "$VALUE" == "no" ]; then
    sed -i "s/^#*\($1\).*/\1 $VALUE/" /etc/ssh/sshd_config
  fi
}

##### Configure bash

sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc
sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc

##### Ubuntu setup # Keep these in sync with the vagrant version

echo "$SCRIPT_NAME: set timezone"
ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime

echo "$SCRIPT_NAME: update sources"
apt-get update -y

echo "$SCRIPT_NAME: upgrade os"
apt-get upgrade -y

echo "$SCRIPT_NAME: install packages"

# Linux core
apt-get install -y dkms

# Source compilation
apt-get install -y build-essential
apt-get install -y automake
apt-get install -y pkg-config
apt-get install -y gcc
apt-get install -y g++
apt-get install -y libkrb5-dev

# Source control
apt-get install -y git-core

# Common utils
apt-get install -y curl
apt-get install -y expect
apt-get install -y less
apt-get install -y lsof
apt-get install -y vim
apt-get install -y wget

# Security
apt-get install -y libssl-dev
apt-get install -y ufw

##### Setup hostname.

echo "$SCRIPT_NAME: setting hostname to $NEW_HOSTNAME"
hostnamectl set-hostname "$NEW_HOSTNAME"
echo -e "\n127.0.0.1 $NEW_HOSTNAME.local $NEW_HOSTNAME\n" >> /etc/hosts

##### Create some directories.

echo "$SCRIPT_NAME: creating scratch directories"
mkdir -p {src,scratch}

##### Firewall.

echo "$SCRIPT_NAME: set up firewall"

cat <<EOF > scratch/ufw_expect.sh
#!/usr/bin/expect

set timeout 60
spawn ufw enable
while {1} {
  expect {
    eof                        {break}
    "Proceed with operation"   {send "y\r"}
  }
}
wait
EOF

chmod +x scratch/ufw_expect.sh
scratch/ufw_expect.sh
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow 8000
ufw default deny

##### Postfix.

echo "$SCRIPT_NAME: set up postfix"

# These prevent the dreaded pseudo-gui setup screens that can ruin a headless install.
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string localhost" | debconf-set-selections
echo "postfix postfix/destinations string localhost.localdomain, localhost" | debconf-set-selections

apt-get install -y mailutils
aptitude -y install postfix

/usr/sbin/postconf -e "inet_interfaces = loopback-only"

#### Lock down SSHD.

echo "$SCRIPT_NAME: deny root ssh"

system_sshd_edit_bool "PermitRootLogin" "no"
system_sshd_edit_bool "PasswordAuthentication" "no"
system_sshd_edit_bool "PubkeyAuthentication" "yes"

##### Set up deploy user.

echo "$SCRIPT_NAME: add deploy user"

useradd -U -s /bin/bash -m deploy
mkdir -p /home/deploy/{.ssh,src,scratch,app/current,app/shared/logs}
touch /home/deploy/app/shared/logs/node.log

echo "$SCRIPT_NAME: set up deploy user's ssh keys"

chmod 0700 /home/deploy/.ssh
echo $SSH_KEY >> /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

echo "$SCRIPT_NAME: set up deploy user's sudo privileges"

echo "deploy ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "$SCRIPT_NAME: chown deploy home directory"

chown -R deploy:deploy /home/deploy/

##### Github

echo "$SCRIPT_NAME: set up github hosts"

cat <<EOF > /home/deploy/.ssh/known_hosts
|1|w8rL5TpJWjFsLe/KELv1839MbwU=|UCFegywpxF4ziwmF/GPYhuII4j4= ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
|1|vP9WJ+xqyudty0nl6qqM+23NF+Q=|JsLmCcxKptEgKuPjUPmje6VrN28= ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
EOF

echo "$SCRIPT_NAME: set up github server key so we can pull app updates via ssh"

cat <<EOF > /home/deploy/scratch/ssh-keygen_expect.sh
#!/usr/bin/expect

set timeout 60
set name [lindex $argv 0]
spawn ssh-keygen -t rsa -C "$name" -f /home/deploy/.ssh/id_rsa
while {1} {
  expect {
    eof            {break}
    "passphrase"   {send "\r"}
  }
}
wait
EOF

chmod +x /home/deploy/scratch/ssh-keygen_expect.sh

/home/deploy/scratch/ssh-keygen_expect.sh DEPLOY@$NEW_HOSTNAME

export KEY=`cat /home/deploy/.ssh/id_rsa.pub`
export DATA=''"'"'{"title":"DEPLOY-'$NEW_HOSTNAME'", "key":"'$KEY'"}'"'"''

eval curl -X POST -u "$GITHUB_USERNAME:$GITHUB_PASSWORD" "https://api.github.com/repos/$GITHUB_USERNAME/$GITHUB_REPO/keys" -d "$DATA"

chown -R deploy:deploy /home/deploy/.ssh

##### Git checkout

su - deploy -c "(cd /home/$APP_USER/app/current && git clone git@github.com:Homefinder/openhomepro-v2.git . && git checkout $GIT_BRANCH)"

##### Bootstrap

cd "$APP_ROOT/script/component/bash"

echo "$SCRIPT_NAME: copy various config files to home directory"

cp "./command_prompt.bash"             "/home/$APP_USER/.command_prompt"
cp "./environment_vars.$NODE_ENV.bash" "/home/$APP_USER/.environment_vars"
cp "./profile.bash"                    "/home/$APP_USER/.profile"

echo "$SCRIPT_NAME: run setup script as $APP_USER"
sudo -u "$APP_USER" -H bash -l -c "$APP_ROOT/script/component/install_all.sh"

#### Restart SSH

echo "restarting ssh to permanently disable root access"
service ssh restart

##### Notify.

echo "Bootstrap script complete."

mail -s "Your Linode VPS is configured" "$NOTIFY_EMAIL" <<EOD
Hola!

You are all ready to roll on your new server. Your username is 'deploy'.

Laters!
EOD

##### Clean up.

history -c && rm -f ~/.bash_history

##### Exit.

exit 0
