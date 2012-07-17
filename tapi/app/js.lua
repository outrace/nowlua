---模拟JS前台的请求响应
module("tapi.app.js",package.seeall)

---处理人人的JS前台请求
function rr()
	local ctx = ngx.ctx
    local mdl_rr = require("tapi.mdl.rr")
    mdl_rr.js_api(ctx.dao,ctx["in"])
end
