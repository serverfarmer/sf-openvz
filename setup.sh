#!/bin/bash
. /opt/farm/scripts/init
. /opt/farm/scripts/functions.install



set_openvz_option() {
	file=$1
	key=$2
	value=$3

	if ! grep -q ^$key $file; then
		echo >>$file
		echo "$key=$value" >>$file
	else
		sed -i -e "s/^\($key\)=.*/\\1=$value/" $file
	fi
}


base=/opt/farm/ext/openvz/templates/$OSVER

if [ -d /srv/vz ]; then
	echo "openvz already installed"
	exit 0
elif [ "$OSVER" != "debian-squeeze" ] && [ "$OSVER" != "debian-wheezy" ]; then
	echo "skipping openvz kernel setup, unsupported operating system version"
	exit 1
fi

if [ "$OSVER" = "debian-wheezy" ] && [ ! -f /etc/apt/sources.list.d/proxmox.list ]; then
	echo "deb http://download.proxmox.com/debian wheezy pve-no-subscription" >/etc/apt/sources.list.d/proxmox.list
	wget -O- "http://download.proxmox.com/debian/key.asc" |apt-key add -
	apt-get update
fi

/opt/farm/ext/repos/install.sh openvz

if [ ! -d /srv/vz ]; then
	/etc/init.d/vz stop
	/etc/init.d/vzeventd stop

	update-rc.d -f vz remove
	update-rc.d -f vzeventd remove

	mv /var/lib/vz /srv
	ln -s /etc/vz /srv/vz/config

	save_original_config /etc/vz/vz.conf
	set_openvz_option /etc/vz/vz.conf LOCKDIR '\/srv\/vz\/lock'
	set_openvz_option /etc/vz/vz.conf DUMPDIR '\/srv\/vz\/dump'
	set_openvz_option /etc/vz/vz.conf TEMPLATE '\/srv\/vz\/template'
	set_openvz_option /etc/vz/vz.conf VE_ROOT '\/srv\/vz\/root\/\$VEID'
	set_openvz_option /etc/vz/vz.conf VE_PRIVATE '\/srv\/vz\/private\/\$VEID'
	set_openvz_option /etc/vz/vz.conf IPTABLES '"ipt_REJECT ipt_tos ipt_limit ipt_multiport iptable_filter iptable_mangle ipt_TCPMSS ipt_tcpmss ipt_ttl ipt_length ipt_state"'
	set_openvz_option /etc/vz/vz.conf IPV6 '"no"'

	if [ "$OSVER" = "debian-wheezy" ]; then
		save_original_config /etc/vz/download.conf
		set_openvz_option /etc/vz/download.conf UPDATE_TEMPLATE '"no"'

		save_original_config /etc/init.d/vz
		sed -i -e "s/\(modify_vzconf\)$/\#\ \\1/" /etc/init.d/vz

		install_copy $base/openvz-local.tpl /etc/sysctl.d/openvz-local.conf
	fi
fi
