---sns平台模拟系统的虚拟玩家相关处理模块
module("tapi.mdl.user",package.seeall)

local fw = require("nao.fw")

local app_list = {
["mg"] = "西部小镇",
["king"]="海盗",
["sg"]="三国",
}
local sns_site = {"rr","fbtw","baidu"}
local sns_url = {
rr="http://mg.nowtest.tk/mg/rr/mg/page/rr_index.do?",
fbtw="http://mg.nowtest.tk/mg/fbtw/mg/page/fbtw_index.do?"
}

---获取某个账号的好友列表
--@param    id      string      账号id
--@param    mod     int         账号id最后一位处以5后的余数
--@usage	
--@return   table   该账号id的好友id列表
local function _get_friend(id,mod)
  local ret = {}
  local i = 0
  while i < 10 do
    if i ~= mod then
      table.insert(ret,tostring(id+i))
    end
    i = i + 1
  end
  return ret
end

---初始化sns测试用户
--@param    dao     table       数据操作对象
--@param    uid     string      账号id
--@usage	
--@return   void
function init_user(dao,uid)
  if tonumber(uid) < 1000 or tonumber(uid) > 1999 then
    fw.err("玩家ID输入1000-1999")
  end
          
  local user = dao:get("tapi.user",uid)
  if user == nil then
    local tid = ""
    local left = ""
    local usr = {}
    local newdata = {}
    for i=1000,1009 do
      tid = tostring(i)
      left = string.sub(tid,-1)
      usr = {name="玩家"..tid}
      usr.sex =  (tonumber(left)>5 and "1") or "0"
      usr.birthday = "1990-01-01"
      usr.first_name = tid
      usr.last_name = "usr"
      usr.friend = _get_friend(i-tonumber(left),tonumber(left))
      dao:add("tapi.user", tid, usr)
    end
  end
end

---获取某个玩家的所有信息
--@param    dao     table       数据操作对象
--@param	site	string		平台站点
--@param    uid     string      账号id
--@usage	
--@return   table  {user={},friend={},feed={},invite={}}
function home(dao,site,uid)
	local out = {}
	local tbl_util = require("nao.util_tbl")
	local ret = dao:get("tapi.user", uid)
	if ret == nil then
		init_user(dao,uid)
		ret = dao:get("tapi.user",uid)
	end
	--得到好友列表
	local fr = {}
	for i,fid in pairs(ret[uid]["friend"]) do
		local tmp = {fid=fid,fname="user"..fid}
		table.insert(fr,tmp)
	end
	out["friend"] = fr
	--得到自身信息
	ret[uid]["friend"] = nil
	out["user"] = ret[uid]
	
	--得到玩家平台相关信息
	local udataid = uid.."_"..site
	local ret = dao:get("tapi.udata",udataid)
	if ret[udataid] == nil then
		dao:add("tapi.udata", udataid, {} )
		ret = dao:get("tapi.udata",udataid)
	end
	
	--返回游戏信息
	out["user"]["credit"] = ret[udataid]["credit"]
	local app = {}
	for k in pairs(app_list) do
		v = app_list[k]
		local tmp = {appid=k,name=v,add="N",fan="N"}
		if ret[udataid]["app"][k] ~= nil then
			tmp["add"] = "Y"
			tmp["fan"] = ret[udataid]["app"][k]
		end
		table.insert(app,tmp)
	end
	
	out["app"] = app
	
	--返回邀请信息
	out["invite"] = {}
	for k,v in pairs(ret[udataid]["invite"]) do
	    table.insert(out["invite"],{
	     id=k,from=v["from"],gid=v["gid"],game=v["game"]
	    })
	end
	
	--todo 返回新鲜事
	out["feed"] = {}
	return out
end

---处理一些模拟平台的请求
--@param    ctx     table       请求的上下文
--@usage	
--@return   void
function act(ctx)
    local site = ctx["in"]["site"]
    local udataid = ctx["uid"].."_"..site
    local uid = ctx["uid"]
    init_user(ctx.dao,ctx["uid"])
    
    local udatas = ctx.dao:get("tapi.udata",udataid)
    if udatas[udataid] == nil then
        ctx.dao:add("tapi.udata",udataid, {} )
        udatas = ctx.dao:get("tapi.udata",udataid)
    end
    local act = ctx["in"]["act"]
    local old = udatas[udataid]
    if act == "add_app" then    --新增app
        old["app"][ctx["in"]["appid"]] = "N"
        ctx.dao:save("tapi.udata",{[udataid]=old})
    elseif act == "del_app" then   --删除app
        old["app"][ctx["in"]["appid"]] = nil
        ctx.dao:save("tapi.udata",{[udataid]=old})
    elseif act == "add_fan" then --成为粉丝
        old["app"][ctx["in"]["appid"]] = "Y"
        ctx.dao:save("tapi.udata",{[udataid]=old})
    elseif act == "del_fan" then   --不再成为粉丝
        old["app"][ctx["in"]["appid"]] = "N"
        ctx.dao:save("tapi.udata",{[udataid]=old})
    elseif act == "mdf_credit" then    --更改代币数量
        ctx.dao:mdf("tapi.udata",udataid,{["credit"]=ctx["in"]["credit"]})
        --local tmp = ctx.dao:pre("tapi.udata","100",10)
        --fw.err(tmp["1000_rr"]["credit"])
        --ctx.dao:add("tapi.udata",aa, {k='dd'} )
        --ctx.dao:del("tapi.udata","aa")
        --fw.err("hi")
    elseif act == "del_invite" then    --删除一份邀请
        local fid = ctx["in"]["delid"]
        if old["invite"][fid] ~= nil then
            old["invite"][fid] = nil
            local appid = ctx["in"]["appid"]
            local isadd = "N"                
            --检查自己是否已经安装了此应用
            if old["app"][appid] ~= nil then
                isadd = "Y"
            end
            ctx.dao:save("tapi.udata",udataid, old)
            
            if ctx["in"]["kind"] == "accept" then --如果是接受邀请
                local gid = ctx["in"]["gid"]  --礼物ID
                local from = ctx["in"]["from"] --这个人邀请的我
                
                local url = _get_page(site,uid,isadd)
                url = url.."&_fid="..from.."&_gid="..gid
                ctx["out"]["url"] = url
            end
        end
    elseif act == "del_feed" then -- 删除一份新鲜事
        local fid = ctx["in"]["delid"]
        if old["feed"][fid] ~= nil then
            old["feed"][fid] = nil
            ctx.dao:save("tapi.udata", udataid, old)
        end
    elseif act == "get_page" then  --获取某个site，某个app的测试地址
        local isadd = ctx["in"]["add"]
        ctx["out"]["url"] = _get_page(site,uid,isadd)
    end
end

--获取进入首页的URL
function _get_page(site,uid,isadd)
    if site == "rr" then
        local query = "xn_sig_user=%s&xn_sig_session_key=%s&xn_sig_added=%s"
        local added = "0"
        if isadd == "Y" then
            added = "1"
        end
        return sns_url[site]..string.format(query,uid,uid,added)
    elseif site == "fbtw" then
    end
end


