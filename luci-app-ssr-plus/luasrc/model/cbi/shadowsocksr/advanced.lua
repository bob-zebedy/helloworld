local uci = luci.model.uci.cursor()
local server_table = {}

uci:foreach("shadowsocksr", "servers", function(s)
	if s.alias then
		server_table[s[".name"]] = "[%s]:%s" % {string.upper(s.v2ray_protocol or s.type), s.alias}
	elseif s.server and s.server_port then
		server_table[s[".name"]] = "[%s]:%s:%s" % {string.upper(s.v2ray_protocol or s.type), s.server, s.server_port}
	end
end)

local key_table = {}
for key, _ in pairs(server_table) do
	table.insert(key_table, key)
end

table.sort(key_table)

m = Map("shadowsocksr")
-- [[ global ]]--
s = m:section(TypedSection, "global", translate("Advanced settings"))
s.anonymous = true

o = s:option(Flag, "enable_switch", translate("Enable auto switch"))
o.rmempty = false
o.default = "1"

o = s:option(Value, "switch_time", translate("Inspection cycle"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 60

o = s:option(Value, "switch_timeout", translate("Check timout"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 5

o = s:option(Value, "switch_try_count", translate("Check Try Count"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 3

o = s:option(Flag, "adblock", translate("Enable adblock"))
o.rmempty = false

o = s:option(Value, "adblock_url", translate("adblock_url"))
o:value("https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/adblock-for-dnsmasq.conf", translate("anti-AD"))
o.default = "https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/adblock-for-dnsmasq.conf"
o:depends("adblock", "1")

o = s:option(Value, "gfwlist_url", translate("gfwlist_url"))
o:value("https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt", translate("GFWList"))
o.default = "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"

o = s:option(Value, "chnroute_url", translate("chn_route_url"))
o:value("https://ispip.clang.cn/all_cn.txt", translate("ALL_CN"))
o:value("https://ispip.clang.cn/all_cn_cidr.txt", translate("ALL_CN_CIDR"))
o.default = "https://ispip.clang.cn/all_cn.txt"

o = s:option(Value, "nfip_url", translate("netflix_ip_url"))
o:value("https://raw.githubusercontent.com/deplives/Surge/master/Provider/List/Netflix/ip.txt", translate("Netflix_IP"))
o.default = "https://raw.githubusercontent.com/deplives/Surge/master/Provider/List/Netflix/ip.txt"

o = s:option(Button, "reset", translate("Reset all"))
o.rawhtml = true
o.template = "shadowsocksr/reset"

-- [[ SOCKS5 Proxy ]]--
s = m:section(TypedSection, "socks5_proxy", translate("Global SOCKS5 Proxy Server"))
s.anonymous = true

o = s:option(ListValue, "server", translate("Server"))
o:value("nil", translate("Disable"))
o:value("same", translate("Same as Global Server"))
for _, key in pairs(key_table) do
	o:value(key, server_table[key])
end
o.default = "nil"
o.rmempty = false

o = s:option(Value, "local_port", translate("Local Port"))
o.datatype = "port"
o.default = 1080
o.rmempty = false

return m
