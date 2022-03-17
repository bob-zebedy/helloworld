#!/usr/bin/lua

require "luci.model.uci"
require "nixio"
require "luci.util"
require "luci.sys"
require "luci.jsonc"

local tinsert = table.insert
local ssub, slen, schar, sbyte, sformat, sgsub = string.sub, string.len, string.char, string.byte, string.format, string.gsub
local jsonParse, jsonStringify = luci.jsonc.parse, luci.jsonc.stringify
local b64decode = nixio.bin.b64decode
local cache = {}
local nodeResult = setmetatable({}, {
    __index = cache
})
local name = 'shadowsocksr'
local uciType = 'servers'
local ucic = luci.model.uci.cursor()
local proxy = ucic:get_first(name, 'server_subscribe', 'proxy', '0')
local switch = ucic:get_first(name, 'server_subscribe', 'switch', '1')
local subscribe_url = ucic:get_first(name, 'server_subscribe', 'subscribe_url', {})
local filter_words = ucic:get_first(name, 'server_subscribe', 'filter_words', '过期时间|剩余流量|官网')
local save_words = ucic:get_first(name, 'server_subscribe', 'save_words', '')
local v2_ss = luci.sys.exec('type -t -p ss-redir sslocal') ~= "" and "ss" or "v2ray"
local v2_tj = luci.sys.exec('type -t -p trojan') ~= "" and "trojan" or "v2ray"
local log = function(...)
    print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "]  " .. table.concat({
        ...
    }, " "))
end
local encrypt_methods_ss = {
    -- aead
    "aes-128-gcm",
    "aes-192-gcm",
    "aes-256-gcm",
    "chacha20-ietf-poly1305",
    "xchacha20-ietf-poly1305"
    --[[ stream
	"table",
	"rc4",
	"rc4-md5",
	"aes-128-cfb",
	"aes-192-cfb",
	"aes-256-cfb",
	"aes-128-ctr",
	"aes-192-ctr",
	"aes-256-ctr",
	"bf-cfb",
	"camellia-128-cfb",
	"camellia-192-cfb",
	"camellia-256-cfb",
	"salsa20",
	"chacha20",
	"chacha20-ietf" ]]
}
-- 分割字符串
local function split(full, sep)
    full = full:gsub("%z", "") -- 这里不是很清楚 有时候结尾带个\0
    local off, result = 1, {}
    while true do
        local nStart, nEnd = full:find(sep, off)
        if not nEnd then
            local res = ssub(full, off, slen(full))
            if #res > 0 then
                tinsert(result, res)
            end
            break
        else
            tinsert(result, ssub(full, off, nStart - 1))
            off = nEnd + 1
        end
    end
    return result
end
-- urlencode
local function get_urlencode(c)
    return sformat("%%%02X", sbyte(c))
end

local function urlEncode(szText)
    local str = szText:gsub("([^0-9a-zA-Z ])", get_urlencode)
    str = str:gsub(" ", "+")
    return str
end

local function get_urldecode(h)
    return schar(tonumber(h, 16))
end
local function UrlDecode(szText)
    return szText:gsub("+", " "):gsub("%%(%x%x)", get_urldecode)
end

-- trim
local function trim(text)
    if not text or text == "" then
        return ""
    end
    return (sgsub(text, "^%s*(.-)%s*$", "%1"))
end
-- md5
local function md5(content)
    local stdout = luci.sys.exec('echo \"' .. urlEncode(content) .. '\" | md5sum | cut -d \" \" -f1')
    return trim(stdout)
end
-- base64
local function base64Decode(text)
    local raw = text
    if not text then
        return ''
    end
    text = text:gsub("%z", "")
    text = text:gsub("_", "/")
    text = text:gsub("-", "+")
    local mod4 = #text % 4
    text = text .. string.sub('====', mod4 + 1)
    local result = b64decode(text)
    if result then
        return result:gsub("%z", "")
    else
        return raw
    end
end
-- 检查数组(table)中是否存在某个字符值
local function checkTabValue(tab)
    local revtab = {}
    for k, v in pairs(tab) do
        revtab[v] = true
    end
    return revtab
end
-- 处理数据
local function processData(szType, content)
    local result = {
        type = szType,
        local_port = 1024,
        kcp_param = '--nocomp'
    }
    if szType == 'ssr' then
        local dat = split(content, "/%?")
        local hostInfo = split(dat[1], ':')
        result.server = hostInfo[1]
        result.server_port = hostInfo[2]
        result.protocol = hostInfo[3]
        result.encrypt_method = hostInfo[4]
        result.obfs = hostInfo[5]
        result.password = base64Decode(hostInfo[6])
        local params = {}
        for _, v in pairs(split(dat[2], '&')) do
            local t = split(v, '=')
            params[t[1]] = t[2]
        end
        result.obfs_param = base64Decode(params.obfsparam)
        result.protocol_param = base64Decode(params.protoparam)
        local group = base64Decode(params.group)
        if group then
            result.alias = "[" .. group .. "] "
        end
        result.alias = result.alias .. base64Decode(params.remarks)
    elseif szType == 'vmess' then
        local info = jsonParse(content)
        result.type = 'v2ray'
        result.v2ray_protocol = 'vmess'
        result.server = info.add
        result.server_port = info.port
        result.transport = info.net
        result.vmess_id = info.id
        result.alias = info.ps
        if info.net == 'ws' then
            result.ws_host = info.host
            result.ws_path = info.path
        end
        if info.net == 'h2' then
            result.h2_host = info.host
            result.h2_path = info.path
        end
        if info.net == 'tcp' then
            if info.type and info.type ~= "http" then
                info.type = "none"
            end
            result.tcp_guise = info.type
            result.http_host = info.host
            result.http_path = info.path
        end
        if info.net == 'kcp' then
            result.kcp_guise = info.type
            result.mtu = 1350
            result.tti = 50
            result.uplink_capacity = 5
            result.downlink_capacity = 20
            result.read_buffer_size = 2
            result.write_buffer_size = 2
        end
        if info.net == 'quic' then
            result.quic_guise = info.type
            result.quic_key = info.key
            result.quic_security = info.securty
        end
        if info.security then
            result.security = info.security
        end
        if info.tls == "tls" or info.tls == "1" then
            result.tls = "1"
            result.tls_host = info.host
            result.insecure = 1
        else
            result.tls = "0"
        end
    elseif szType == "ss" then
        local idx_sp = 0
        local alias = ""
        if content:find("#") then
            idx_sp = content:find("#")
            alias = content:sub(idx_sp + 1, -1)
        end
        local info = content:sub(1, idx_sp - 1)
        local hostInfo = split(base64Decode(info), "@")
        local host = split(hostInfo[2], ":")
        local userinfo = base64Decode(hostInfo[1])
        local method = userinfo:sub(1, userinfo:find(":") - 1)
        local password = userinfo:sub(userinfo:find(":") + 1, #userinfo)
        result.alias = UrlDecode(alias)
        result.type = v2_ss
        result.password = password
        result.server = host[1]
        if host[2]:find("/%?") then
            local query = split(host[2], "/%?")
            result.server_port = query[1]
            local params = {}
            for _, v in pairs(split(query[2], '&')) do
                local t = split(v, '=')
                params[t[1]] = t[2]
            end
            if params.plugin then
                local plugin_info = UrlDecode(params.plugin)
                local idx_pn = plugin_info:find(";")
                if idx_pn then
                    result.plugin = plugin_info:sub(1, idx_pn - 1)
                    result.plugin_opts = plugin_info:sub(idx_pn + 1, #plugin_info)
                else
                    result.plugin = plugin_info
                end
                if result.plugin == "simple-obfs" then
                    result.plugin = "obfs-local"
                end
            end
        else
            result.server_port = host[2]:gsub("/", "")
        end
        if not checkTabValue(encrypt_methods_ss)[method] then
            result.server = nil
        elseif v2_ss == "v2ray" then
            result.v2ray_protocol = "shadowsocks"
            result.encrypt_method_v2ray_ss = method
        else
            result.encrypt_method_ss = method
        end
    elseif szType == "sip008" then
        result.type = v2_ss
        result.server = content.server
        result.server_port = content.server_port
        result.password = content.password
        result.plugin = content.plugin
        result.plugin_opts = content.plugin_opts
        result.alias = content.remarks
        if not checkTabValue(encrypt_methods_ss)[content.method] then
            result.server = nil
        elseif v2_ss == "v2ray" then
            result.v2ray_protocol = "shadowsocks"
            result.encrypt_method_v2ray_ss = content.method
        else
            result.encrypt_method_ss = content.method
        end
    elseif szType == "ssd" then
        result.type = v2_ss
        result.server = content.server
        result.server_port = content.port
        result.password = content.password
        result.plugin_opts = content.plugin_options
        result.alias = "[" .. content.airport .. "] " .. content.remarks
        if content.plugin == "simple-obfs" then
            result.plugin = "obfs-local"
        else
            result.plugin = content.plugin
        end
        if not checkTabValue(encrypt_methods_ss)[content.encryption] then
            result.server = nil
        elseif v2_ss == "v2ray" then
            result.v2ray_protocol = "shadowsocks"
            result.encrypt_method_v2ray_ss = content.method
        else
            result.encrypt_method_ss = content.method
        end
    elseif szType == "trojan" then
        local idx_sp = 0
        local alias = ""
        if content:find("#") then
            idx_sp = content:find("#")
            alias = content:sub(idx_sp + 1, -1)
        end
        local info = content:sub(1, idx_sp - 1)
        local hostInfo = split(info, "@")
        local host = split(hostInfo[2], ":")
        local userinfo = hostInfo[1]
        local password = userinfo
        result.alias = UrlDecode(alias)
        result.type = v2_tj
        result.v2ray_protocol = "trojan"
        result.server = host[1]
        result.insecure = "0"
        result.tls = "1"
        if host[2]:find("?") then
            local query = split(host[2], "?")
            result.server_port = query[1]
            local params = {}
            for _, v in pairs(split(query[2], '&')) do
                local t = split(v, '=')
                params[t[1]] = t[2]
            end
            if params.sni then
                result.tls_host = params.sni
            end
        else
            result.server_port = host[2]
        end
        result.password = password
    elseif szType == "vless" then
        local idx_sp = 0
        local alias = ""
        if content:find("#") then
            idx_sp = content:find("#")
            alias = content:sub(idx_sp + 1, -1)
        end
        local info = content:sub(1, idx_sp - 1)
        local hostInfo = split(info, "@")
        local host = split(hostInfo[2], ":")
        local uuid = hostInfo[1]
        if host[2]:find("?") then
            local query = split(host[2], "?")
            local params = {}
            for _, v in pairs(split(UrlDecode(query[2]), '&')) do
                local t = split(v, '=')
                params[t[1]] = t[2]
            end
            result.alias = UrlDecode(alias)
            result.type = 'v2ray'
            result.v2ray_protocol = 'vless'
            result.server = host[1]
            result.server_port = query[1]
            result.vmess_id = uuid
            result.vless_encryption = params.encryption or "none"
            result.transport = params.type and (params.type == 'http' and 'h2' or params.type) or "tcp"
            if not params.type or params.type == "tcp" then
                if params.security == "xtls" then
                    result.xtls = "1"
                    result.tls_host = params.sni
                    result.vless_flow = params.flow
                else
                    result.xtls = "0"
                end
            end
            if params.type == 'ws' then
                result.ws_host = params.host
                result.ws_path = params.path or "/"
            end
            if params.type == 'http' then
                result.h2_host = params.host
                result.h2_path = params.path or "/"
            end
            if params.type == 'kcp' then
                result.kcp_guise = params.headerType or "none"
                result.mtu = 1350
                result.tti = 50
                result.uplink_capacity = 5
                result.downlink_capacity = 20
                result.read_buffer_size = 2
                result.write_buffer_size = 2
                result.seed = params.seed
            end
            if params.type == 'quic' then
                result.quic_guise = params.headerType or "none"
                result.quic_key = params.key
                result.quic_security = params.quicSecurity or "none"
            end
            if params.type == 'grpc' then
                result.serviceName = params.serviceName
            end
            if params.security == "tls" then
                result.tls = "1"
                result.tls_host = params.sni
            else
                result.tls = "0"
            end
        else
            result.server_port = host[2]
        end
    end
    if not result.alias then
        if result.server and result.server_port then
            result.alias = result.server .. ':' .. result.server_port
        else
            result.alias = "NULL"
        end
    end
    local alias = result.alias
    result.alias = nil
    local switch_enable = result.switch_enable
    result.switch_enable = nil
    result.hashkey = md5(jsonStringify(result))
    result.alias = alias
    result.switch_enable = switch_enable
    return result
end
local function wget(url)
    local stdout = luci.sys.exec('wget -q --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36" --no-check-certificate -O- "' .. url .. '"')
    return trim(stdout)
end

local function check_filer(result)
    do
        -- 过滤的关键词列表
        local filter_word = split(filter_words, "|")
        -- 保留的关键词列表
        local check_save = false
        if save_words ~= nil and save_words ~= "" and save_words ~= "NULL" then
            check_save = true
        end
        local save_word = split(save_words, "|")

        -- 检查结果
        local filter_result = false
        local save_result = true

        -- 检查是否存在过滤关键词
        local filter_word = split(filter_words, "|")

        for i, v in pairs(filter_word) do
            if tostring(result.alias):find(v, nil, true) then
                filter_result = true
            end
        end

        -- 检查是否打开了保留关键词检查，并且进行过滤
        if check_save == true then
            for i, v in pairs(save_word) do
                if tostring(result.alias):find(v, nil, true) then
                    save_result = false
                end
            end
        else
            save_result = false
        end

        -- 不等时返回
        if filter_result == true or save_result == true then
            return true
        else
            return false
        end
    end
end

local execute = function()
    -- exec
    do
        if proxy == '0' then -- 不使用代理更新的话先暂停
            log('不使用代理更新')
            luci.sys.init.stop(name)
        end
        for k, url in ipairs(subscribe_url) do
            local raw = wget(url)
            if #raw > 0 then
                local nodes, szType
                local groupHash = md5(url)
                cache[groupHash] = {}
                tinsert(nodeResult, {})
                local index = #nodeResult
                if raw:find('ssd://') then
                    szType = 'ssd'
                    local nEnd = select(2, raw:find('ssd://'))
                    nodes = base64Decode(raw:sub(nEnd + 1, #raw))
                    nodes = jsonParse(nodes)
                    local extra = {
                        airport = nodes.airport,
                        port = nodes.port,
                        encryption = nodes.encryption,
                        password = nodes.password
                    }
                    local servers = {}
                    for _, server in ipairs(nodes.servers) do
                        tinsert(servers, setmetatable(server, {
                            __index = extra
                        }))
                    end
                    nodes = servers
                elseif jsonParse(raw) then
                    nodes = jsonParse(raw).servers or jsonParse(raw)
                    if nodes[1].server and nodes[1].method then
                        szType = 'sip008'
                    end
                else
                    nodes = split(base64Decode(raw):gsub(" ", "_"), "\n")
                end
                for _, v in ipairs(nodes) do
                    if v then
                        local result
                        if szType then
                            result = processData(szType, v)
                        elseif not szType then
                            local node = trim(v)
                            local dat = split(node, "://")
                            if dat and dat[1] and dat[2] then
                                local dat3 = ""
                                if dat[3] then
                                    dat3 = "://" .. dat[3]
                                end
                                if dat[1] == 'ss' or dat[1] == 'trojan' then
                                    result = processData(dat[1], dat[2] .. dat3)
                                else
                                    result = processData(dat[1], base64Decode(dat[2]))
                                end
                            end
                        else
                            log('跳过未知类型: ' .. szType)
                        end
                        if result then
                            if not result.server or not result.server_port or result.alias == "NULL" or check_filer(result) or result.server:match("[^0-9a-zA-Z%-%.%s]") or cache[groupHash][result.hashkey] then
                                log('丢弃无效 ' .. result.type .. ' 节点: ' .. result.alias)
                            else
                                result.grouphashkey = groupHash
                                tinsert(nodeResult[index], result)
                                cache[groupHash][result.hashkey] = nodeResult[index][#nodeResult[index]]
                            end
                        end
                    end
                end
                log('成功解析节点数量: ' .. #nodes)
            else
                log(url .. ': 获取内容为空')
            end
        end
    end
    -- diff
    do
        if next(nodeResult) == nil then
            log("无可用节点信息")
            if proxy == '0' then
                luci.sys.init.start(name)
                log('更新订阅失败')
            end
            return
        end
        local add, del = 0, 0
        ucic:foreach(name, uciType, function(old)
            if old.grouphashkey or old.hashkey then -- 没有 hash 的不参与删除
                if not nodeResult[old.grouphashkey] or not nodeResult[old.grouphashkey][old.hashkey] then
                    ucic:delete(name, old['.name'])
                    del = del + 1
                else
                    local dat = nodeResult[old.grouphashkey][old.hashkey]
                    ucic:tset(name, old['.name'], dat)
                    -- 标记一下
                    setmetatable(nodeResult[old.grouphashkey][old.hashkey], {
                        __index = {
                            _ignore = true
                        }
                    })
                end
            else
                if not old.alias then
                    if old.server or old.server_port then
                        old.alias = old.server .. ':' .. old.server_port
                        log('忽略手动添加的节点: ' .. old.alias)
                    else
                        ucic:delete(name, old['.name'])
                    end
                else
                    log('忽略手动添加的节点: ' .. old.alias)
                end
            end
        end)
        for k, v in ipairs(nodeResult) do
            for kk, vv in ipairs(v) do
                if not vv._ignore then
                    local section = ucic:add(name, uciType)
                    ucic:tset(name, section, vv)
                    ucic:set(name, section, "switch_enable", switch)
                    add = add + 1
                end
            end
        end
        ucic:commit(name)
        -- 如果原有服务器节点已经不见了就尝试换为第一个节点
        local globalServer = ucic:get_first(name, 'global', 'global_server', '')
        if globalServer ~= "nil" then
            local firstServer = ucic:get_first(name, uciType)
            if firstServer then
                if not ucic:get(name, globalServer) then
                    luci.sys.call("/etc/init.d/" .. name .. " stop > /dev/null 2>&1 &")
                    ucic:commit(name)
                    ucic:set(name, ucic:get_first(name, 'global'), 'global_server', ucic:get_first(name, uciType))
                    ucic:commit(name)
                    log('主服务器已被删除, 自动更换当前第一个节点')
                    luci.sys.call("/etc/init.d/" .. name .. " start > /dev/null 2>&1 &")
                else
                    log('维持当前主服务器节点')
                    luci.sys.call("/etc/init.d/" .. name .. " restart > /dev/null 2>&1 &")
                end
            else
                log('无可用服务器节点, 停止服务')
                luci.sys.call("/etc/init.d/" .. name .. " stop > /dev/null 2>&1 &")
            end
        end
        log('新增节点数量: ' .. add, '删除节点数量: ' .. del)
        log('订阅更新成功')
    end
end

if subscribe_url and #subscribe_url > 0 then
    xpcall(execute, function(e)
        log(e)
        log(debug.traceback())
        log('发生错误, 正在恢复服务')
        local firstServer = ucic:get_first(name, uciType)
        if firstServer then
            luci.sys.call("/etc/init.d/" .. name .. " restart > /dev/null 2>&1 &")
            log('重启服务成功')
        else
            luci.sys.call("/etc/init.d/" .. name .. " stop > /dev/null 2>&1 &")
            log('停止服务成功')
        end
    end)
end
