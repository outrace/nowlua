module("tapi.app.page",package.seeall)
local fw = require("nao.fw")
local mdl_rr = require("tapi.mdl.rr")

---模拟人人网的restapi
function rr()
	local ctx = ngx.ctx
    local para = ngx.ctx["in"]["post"]
	
	--local para = fw.json_decode('{"sig":"d279eb0d1643d42c64ead982105dbc4b","format":"JSON","fields":"uid","call_id":"1001","v":"1.0","session_key":"1000","api_key":"1000","method":"friends.getAppUsers"}')
    ctx["out"] = mdl_rr.rest_api(ctx.dao,para)
end

function kk()
	local ctx = ngx.ctx
	ctx["out"] = ctx["in"]["get"]
end
