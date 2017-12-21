local BaseAPI = require("orange.plugins.base_api")
local common_api = require("orange.plugins.common_api")
local node = require("orange.plugins.node.node")

local api = BaseAPI:new("node-api", 2)
api:merge_apis(common_api("node"))

api:get("/node/status", function(store)
    return function(req, res, next)
        res:json({
            success = true,
            data = {
                ip = node.get_ip()
            }
        })
    end
end)

api:post("/node/register", function(store)
    return function(req, res, next)
        res:json({
            success = true,
            data = {
                register = node.register(context.config.api.credentials[1], store)
            }
        })
    end
end)

api:post("/node/sync", function(store)
    return function(req, res, next)
        res:json({
            success = true,
            data = {
                status = node.sync(context.config.plugins, store)
            }
        })
    end
end)

api:get("/node/ping", function(store)
    return function(req, res, next)
        res:json({
            success = true
        })
    end
end)

return api
