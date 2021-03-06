!/bin/bash
# Usage:
# From the system to register, as root
# [root@somehost]# curl -s http://satellite.fqdn/pub/bootstrap-wrapper.sh | bash
#
######## VARS ########
SATELLITE=satellite.local
ORG_LABEL=Startx
LOCATION="Europe/Paris"
AK=AK_RHEL7
HG=HG_RHEL7
REX_USER=remote_user
OS=$(cat /etc/redhat-release | grep -oE '[0-9].[0-9]{1,2}')
TIMESTAMP=$(date +%Y%m%d%H%M)
EXT=bak.$TIMESTAMP
SUDOERS=/etc/sudoers.d/nopasswd
######## MAIN ########

((EUID == 0)) || {
        printf 'FATAL: You must be the super-user\n'
exit 1
}

rpm -q subscription-manager &> /dev/null || {
        printf 'FATAL: Package subscription-manager is not installed\n'
exit 2
}

shopt -s nullglob

printf '==> Backing up repos configuration\n'
for repo in /etc/yum.repos.d/*.repo;
do
        mv "$repo" "$repo"."$EXT"
done

printf '==> Disabling subscription-manager plugin for yum\n'
sed -ri '/^enabled\>/ s/=.*/ = 0/' /etc/yum/pluginconf.d/subscription-manager.conf

printf '==> Remove any previous registration data\n'
rm -f /etc/pki/consumer/cert.pem
rm -f /etc/sysconfig/rhn/systemid

printf '==> Clean the subscription manager config\n'
subscription-manager clean

printf '==> Create remote execution user\n'
if id $REX_USER &>/dev/null;
then
	printf '==> Remote execution user already exists\n'
else
	useradd -m -e '' $REX_USER
	echo "$REX_USER ALL = (root) NOPASSWD : ALL" >> $SUDOERS
fi

printf '==> Registering to Satellite\n'
curl -s http://$SATELLITE/pub/bootstrap.py | python - --server "$SATELLITE" \
--organization "$ORG_LABEL" \
--location "$LOCATION" \
--activationkey "$AK" \
--download-method http \
--rex --rex-user "$REX_USER" \
--enablerepos "*" \
--hostgroup "$HG" \
--skip katello-agent \
--skip puppet \
--operatingsystem "RHEL Server $OS" \
--fqdn $(hostname -f) \
--force \
--login admin
