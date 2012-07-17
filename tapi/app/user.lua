module("tapi.app.user",package.seeall)
local mdl = require("tapi.mdl.user")
local fw = require("nao.fw")

---系统登录
function login()
	local ctx = ngx.ctx
	local uid = ctx["in"]["uid"]
	mdl.init_user(ctx.dao,uid)
	ctx["out"]["session"] = fw.set_session("tsite","zh",uid)
end

---获取玩家首页信息
function home()
	local ctx = ngx.ctx
	local util = require("nao.util_tbl")
	util.add_to_tbl(ctx.out,mdl.home(ctx.dao,ctx["in"]["site"],ctx["uid"]))
end

---模拟平台进行部分操作
function act()
	local ctx = ngx.ctx
	mdl.act(ctx)
end
