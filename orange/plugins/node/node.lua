local socket = require("socket")
local http = require("resty.http")
local json = require("orange.utils.json")
local string_format = string.format
local encode_base64 = ngx.encode_base64


local _M = { store = {} }

-- 获取 IP
local function get_ip_by_hostname(hostname)
    local ip, resolved = socket.dns.toip(hostname)
    local ListTab = {}
    for k, v in ipairs(resolved.ip) do
        table.insert(ListTab, v)
    end
    return unpack(ListTab)
end

function _M.init(config)
    self.config = config
    ngx.log(ngx.ERR, "status")
    ngx.log(ngx.ERR, orange_db.get("node.enable"))
end

function _M.get_ip()
    if not _M.ip then
        _M.ip = get_ip_by_hostname(socket.dns.gethostname())
    end
    return _M.ip
end


-- 节点同步
local function sync_node_plugins(node, plugins)

    local sync_result = {}

    for _, plugin in pairs(plugins) do

        if plugin ~= 'stat' and plugin ~= 'node' then

            local httpc = http.new()

            -- 设置超时时间 200 ms
            httpc:set_timeout(200)

            local url = string_format("http://%s:%s", node.ip, node.port)
            local authorization = encode_base64(string_format("%s:%s", node.api_username, node.api_password))
            local path = string_format('/%s/sync', plugin)

            ngx.log(ngx.ERR, url .. path)

            local resp, err = httpc:request_uri(url, {
                method = "POST",
                path = path,
                headers = {
                    ["Authorization"] = authorization
                }
            })

            if not resp then
                ngx.log(ngx.ERR, err)
                sync_result[plugin] = false
            else
                sync_result[plugin] = resp.status == 200
                ngx.log(ngx.ERR, sync_result[plugin])
            end

            httpc:close()
        end
    end

    return sync_result
end

function _M.sync(plugins, store)

    local table_name = 'cluster_node'
    local local_ip = _M:get_ip()

    local nodes, err = store:query({
        sql = "SELECT * FROM " .. table_name .. " WHERE ip = ? LIMIT 1",
        params = { local_ip }
    })

    if not nodes or err or type(nodes) ~= "table" and #nodes ~= 1 then
        return nil
    end

    local node = nodes[1]
    local sync_result = sync_node_plugins(node, plugins)
    local s = json.encode(sync_result)

    ngx.log(ngx.ERR, s)

    local result, err = store:update({
        sql = "UPDATE " .. table_name .. " SET sync_status = ? WHERE id = ?",
        params = { s, node.id }
    })

    if not result or err then
        ngx.log(ngx.ERR, "SYNC")
    end

    return {
        ip = local_ip,
        status = node
    }
    
end

function _M.register(credentials, store)

    local table_name = 'cluster_node'
    local local_ip = _M:get_ip()

    local nodes, err = store:query({
        sql = "SELECT * FROM " .. table_name .. " WHERE ip = ? LIMIT 1",
        params = { local_ip }
    })

    if not nodes or err or type(nodes) ~= "table" or #nodes ~= 1 then
        nodes, err = store:query({
            sql = "INSERT INTO " .. table_name .. " (name, ip, port, api_username, api_password) VALUES(?,?,?,?,?) ",
            params = { local_ip, local_ip, 7777, credentials.username, credentials.password}
        })

        if not nodes or err or #nodes ~= 1 then
            return nil
        end
    end

    return nodes[1]
end

function _M.log()
    return {}
end

function _M.stat()
    return {}
end

return _M
