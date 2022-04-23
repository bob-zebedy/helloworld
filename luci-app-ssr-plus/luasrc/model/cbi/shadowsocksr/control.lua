require "luci.ip"
require "nixio.fs"
local m, s, o

m = Map("shadowsocksr")

s = m:section(TypedSection, "access_control")
s.anonymous = true

-- Interface control
s:tab("Interface", translate("Interface control"))
o = s:taboption("Interface", DynamicList, "Interface", translate("Interface"))
o.template = "cbi/network_netlist"
o.widget = "checkbox"
o.nocreate = true
o.unspecified = true

-- Part of WAN
s:tab("wan_ac", translate("WAN IP AC"))

o = s:taboption("wan_ac", DynamicList, "wan_bp_ips", translate("WAN White List IP"))
o.datatype = "ip4addr"

o = s:taboption("wan_ac", DynamicList, "wan_fw_ips", translate("WAN Force Proxy IP"))
o.datatype = "ip4addr"

-- Part of LAN
s:tab("lan_ac", translate("LAN IP AC"))

o = s:taboption("lan_ac", ListValue, "lan_ac_mode", translate("LAN Access Control"))
o:value("0", translate("Disable"))
o:value("w", translate("Allow listed only"))
o:value("b", translate("Allow all except listed"))
o.rmempty = false

o = s:taboption("lan_ac", DynamicList, "lan_ac_ips", translate("LAN Host List"))
o.datatype = "ipaddr"
luci.ip.neighbors({
    family = 4
}, function(entry)
    if entry.reachable then
        o:value(entry.dest:string())
    end
end)
o:depends("lan_ac_mode", "w")
o:depends("lan_ac_mode", "b")

o = s:taboption("lan_ac", DynamicList, "lan_bp_ips", translate("LAN Bypassed Host List"))
o.datatype = "ipaddr"
luci.ip.neighbors({
    family = 4
}, function(entry)
    if entry.reachable then
        o:value(entry.dest:string())
    end
end)

o = s:taboption("lan_ac", DynamicList, "lan_fp_ips", translate("LAN Force Proxy Host List"))
o.datatype = "ipaddr"
luci.ip.neighbors({
    family = 4
}, function(entry)
    if entry.reachable then
        o:value(entry.dest:string())
    end
end)

o = s:taboption("lan_ac", DynamicList, "lan_udp_ips", translate("UDP Host List"))
o.datatype = "ipaddr"
luci.ip.neighbors({
    family = 4
}, function(entry)
    if entry.reachable then
        o:value(entry.dest:string())
    end
end)

s:tab("esc", translate("Bypass Domain List"))
local escconf = "/etc/ssrplus/white_domain.list"
o = s:taboption("esc", TextValue, "escconf")
o.rows = 30
o.wrap = "off"
o.rmempty = true
o.cfgvalue = function(self, section)
    return nixio.fs.readfile(escconf) or ""
end
o.write = function(self, section, value)
    nixio.fs.writefile(escconf, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
    nixio.fs.writefile(escconf, "")
end

s:tab("block", translate("Black Domain List"))
local blockconf = "/etc/ssrplus/black_domain.list"
o = s:taboption("block", TextValue, "blockconf")
o.rows = 30
o.wrap = "off"
o.rmempty = true
o.cfgvalue = function(self, section)
    return nixio.fs.readfile(blockconf) or " "
end
o.write = function(self, section, value)
    nixio.fs.writefile(blockconf, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
    nixio.fs.writefile(blockconf, "")
end

s:tab("denydomain", translate("Deny Domain List"))
local denydomainconf = "/etc/ssrplus/deny_domain.list"
o = s:taboption("denydomain", TextValue, "denydomainconf")
o.rows = 30
o.wrap = "off"
o.rmempty = true
o.cfgvalue = function(self, section)
    return nixio.fs.readfile(denydomainconf) or " "
end
o.write = function(self, section, value)
    nixio.fs.writefile(denydomainconf, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
    nixio.fs.writefile(denydomainconf, "")
end

return m
