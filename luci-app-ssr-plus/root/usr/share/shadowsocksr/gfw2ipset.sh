#!/bin/sh
. $IPKG_INSTROOT/etc/init.d/shadowsocksr

mkdir -p $TMP_DNSMASQ_PATH

if [ "$(uci_get_by_type global run_mode router)" == "oversea" ]; then
	cp -rf /etc/ssrplus/oversea.conf $TMP_DNSMASQ_PATH/
else
	cp -rf /etc/ssrplus/gfw.conf $TMP_DNSMASQ_PATH/
fi

for line in $(cat /etc/ssrplus/black_domain.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/gfw.conf; done
for line in $(cat /etc/ssrplus/white_domain.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/gfw.conf; done
for line in $(cat /etc/ssrplus/deny_domain.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/gfw.conf; done

cat /etc/ssrplus/black_domain.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1#$dns_port\nipset=\/&\/blacklist/" >$TMP_DNSMASQ_PATH/blacklist_forward.conf
cat /etc/ssrplus/white_domain.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1\nipset=\/&\/whitelist/" >$TMP_DNSMASQ_PATH/whitelist_forward.conf
cat /etc/ssrplus/deny_domain.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/address=\/&\//" >$TMP_DNSMASQ_PATH/denylist.conf

if [ "$(uci_get_by_type global adblock 0)" == "1" ]; then
	cp -f /etc/ssrplus/ad.conf $TMP_DNSMASQ_PATH/
	if [ -f "$TMP_DNSMASQ_PATH/ad.conf" ]; then
		for line in $(cat /etc/ssrplus/black_domain.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/ad.conf; done
		for line in $(cat /etc/ssrplus/white_domain.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/ad.conf; done
		for line in $(cat /etc/ssrplus/deny_domain.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/ad.conf; done
	fi
else
	rm -f $TMP_DNSMASQ_PATH/ad.conf
fi
