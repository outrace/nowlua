---朋友网前台，后台接口模拟模块
module("tapi.mdl.py",package.seeall)
local fw = require("nao.fw")

local sns_invite_ok = "/invite/rr"
--local sns_invite_ok = "http://mg.nowtest.tk/mg/rr/mg/page/rr_invite_ok.do"
local sns_avatar_url = "http://sg.nowtest.tk/sgimg/user.png"

---模拟人人网的rest api
--@param    dao         table       数据访问呢对象
--@param    indata      table       输入参数
--@return   any 各接口的返回会有差异
function rest_api(dao,indata)
    local sexobj = {male="1",female="0"}
    local method = indata["method"]
    if method == "users.getInfo" then   --获取多个玩家的信息
        local uids = fw.split(indata["uids"],",")
        local users = dao:mget("tapi.user",uids)
        local ret = {}
        for k,v in pairs(users) do
            table.insert(ret,{
             ["uid"]=k,
             ["name"]=v["name"],
             ["zidou"]="0",
             ["star"]="1",
             ["tinyurl"]=sns_avatar_url,
             ["headurl"]=sns_avatar_url,
             ["birthday"]=v["birthday"],
             ["sex"]=sexobj[v["sex"]]
            })
        end
        return encode.json_encode(ret)
    elseif method == "pages.isFan" then --判断玩家是否某个页面的粉丝
        local uid = indata["uid"]
        local appid = indata["api_key"]
        local udataid = uid.."rr"
        local udata = dao:get("tapi.udata",udataid)
        if udata[udataid] == nil then return "0" end
        if udata[udataid]["App"][appid] ~= nil and
           udata[udataid]["App"][appid] == "Y"  then
            return "1"
        end
        return "0"
    elseif method == "friends.getAppUsers" then    --获取app好友
        local uid = indata["session_key"]
		if uid == nil or uid=='' then
			fw.err("id为空")
		end
        local appid = indata["api_key"]
        local users = dao:get("tapi.user",uid)
        local ret = {}
        for i,fid in ipairs(users[uid]["friend"]) do
            local udataid = fid.."_rr"
            local tmp = dao:get("tapi.udata",udataid)
            if tmp[udataid] ~= nil and tmp[udataid]["App"][appid] ~= nil then
                table.insert(ret,fid)
            end
        end
        return encode.json_encode(ret)
    elseif method == "friends.getFriends" then     --获取所有好友
        local uid = indata["session_key"]
        local usrs = dao:get("tapi.user",uid)
        local friends = dao:get("tapi.user",usrs[uid]["friend"])
        local ret = {}
        for fid,friend in pairs(friends) do
            
        end
    elseif method == "pay4Test.regOrder" then      --测试新增订单
    	return "{'token':'10'}"
    elseif method == "pay4Test.isCompleted" then   --测试检验订单是否完成
    	return "{'result':1}"
    end
end

---提供人人网平台前段测试用的js api后台回调
--@param    dao         table       数据访问对象
--@param    para        table       参数
--@return	void
function js_api(dao,para)
    local method = para["method"]
    if method == "feed" then        --发送新鲜事
        
    elseif method == "gift" then    --发送免费礼物
        --参数有 uid/gid/toId   toId=空，就标识发送给所有玩家
        local uid = string.sub(para["uid"],3)
        _invite(dao,uid,para["toid"],para["game"],para["gid"])
    elseif method == "invite" then  --发送邀请
        --参数位  uid/toId  toId=空，就表示发送给所有好友
        local uid = string.sub(para["uid"],3)
        _invite(dao,uid,para["toid"],para["game"],"")
    end
end

--发送邀请
--@param    dao     table   数据访问对象
--@param    uid     stirng  角色ID
--@param    toid    string  被邀请ID
--@param    gid     string  免费礼物ID。空表示普通邀请
function _invite(dao,uid,toid,game,gid)
    --参数有 uid/gid/toId   toId=空，就标识发送给所有玩家
    local toids = {}
    if toid == "" then --给所有好友
        local rec = dao:get("tapi.user",uid)
        local friends = dao:get("tapi.user",rec[uid]["friend"])
        for fid,friend in pairs(friends) do
            table.insert(toids,fid)
        end
    else
        toids = fw.split(toid,",")
    end
    for i,fid in ipairs(toids) do --给好友发礼物
        local udataid = fid.."_rr"
        local tmp = dao:get("tapi.udata",udataid)
        if tmp[udataid] == nil then
	        dao:add("tapi.udata",{[udataid]={}})
	        tmp = dao:get("tapi.udata",udataid)
        end
        --invite="邀请列表",feed="新鲜事列表",app="已经安装的app",credit="代币数量"
        local old = tmp[udataid]
        old["invite"][tostring(dao.now)] = {from=uid,gid=gid,game=game}
        dao:save("tapi.udata",{[udataid]=old},udataid)
    end
end





