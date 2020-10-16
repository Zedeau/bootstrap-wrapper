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
#OS=$(sed -e 's/^"//' -e 's/"$//' <<< $(awk -F= '$1=="VERSION_ID" {print $2 ;}' /etc/os-release))
OS=$(cat /etc/redhat-release | grep -oE '[0-9].[0-9]{1,2}')
TIMESTAMP=$(date + '%Y%m%d%H%M' )
EXT=sat-registration. $TIMESTAMP
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

printf '==> Update subscription-manager before enrolling\n'
yum update subscription-manager -y

printf '==> Backing up repos configuration\n'
for repo in /etc/yum.repos.d/*.repo;
do
        mv "$repo" "$repo"."$EXT"
done

printf '==> Getting rid of proxy configurations\n'
for conf in /etc/{yum,rhsm/rhsm}.conf;
do
        cp -a "$conf" "$conf"."$EXT"
        sed -ri '/^proxy(_|\>)/ s/^/#/' "$conf"
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
	echo "$REX_USER ALL = (root) NOPASSWD : ALL" >> /etc/sudoers.d/nopasswd_users
fi

# The bootstrap script takes care of this
#printf '==> Install the consumer RPM to download content from the Satellite\n'
#curl --insecure --output /tmp/katello-ca-consumer-latest.noarch.rpm https://$SATELLITE/pub/katello-ca-consumer-latest.noarch.rpm
#rpm -i /tmp/katello-ca-consumer-latest.noarch.rpm


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
