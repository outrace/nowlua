---人人网的接口
module("nao.sns.rr",package.seeall)

local mt = { __index = nao.sns.rr}
local fw = require("nao.fw")
local pairs = pairs
local tostring = tostring
local table = table

function new(self,o)
	o["format"] = "json"
	o["v"]= "1.0"
	o["callid"] = ngx.time()
    return setmetatable(o, mt)
end

--发送http请求到人人网的服务器，并得到返回结果
--@param    method      string      方法名
--@param    para        table       参数信息
--@usage	
--@return   table       人人rest服务器返回的结果集
function _post(self, method, para)
	self.callid = self.callid + 1
	para["method"] = method
	para["format"] = self.format
	para["api_key"] = self.apikey
	para["v"] = self.v
	para["call_id"] = tostring(self.callid)
	
	local tmp = {}
	for k in pairs(para) do table.insert(tmp,k) end
	table.sort(tmp)
	local sorted = {}
	for i,n in ipairs(tmp) do
		table.insert(sorted,n..'='..para[n])
	end
	table.insert(sorted,self.secret)
	para["sig"] = ngx.md5(table.concat(sorted))
	
   local rec = fw.http_send(self.apiurl,para,true)
    local ret = fw.json_decode(rec)
    
    if ret==nil or ret["error_code"]~=nil then
    	error("人人网服务器验证错误。"..ret["error_code"])
    end
    return ret
end

---检查人人网请求的签名是否正确
--@param    para    table   人人网所有的GET参数信息
--@usage	
--@return   boolean 是否人人网签名请求
function check_sig(self, para)
    local sig = para["xn_sig"]
    local tmp = {}
    for k in pairs(para) do
        if string.sub(k,0,7) == "xn_sig_" then
            table.insert(tmp,k)
        end
    end
    table.sort(tmp)
    local sorted = {}
    for i,n in ipairs(tmp) do
        table.insert(sorted,string.sub(n,8)..'='..para[n])
    end
    table.insert(sorted,self.secret)
    return sig == ngx.md5(table.concat(sorted))
end

---获取某个玩家的详细信息
--@param    uid     string  需要获取的uid信息
--@param    session string  登录玩家的session key
--@usage	
--@return   table   所查询的玩家详细信息
function get_user(self, uid, session)
    local param = {
    fields="uid,name,tinyurl,headurl,sex,birthday,zidou,star",
    uids=uid,
    session_key=session
    }
    local tmp = self:_post("users.getInfo",param)
    if tmp ~= nil then
        local sex = tostring(tmp[1]["sex"])
        if sex ~= "1" and sex ~= "0" then
            sex = "2"
        end
        local ret = {
        name=tmp[1]["name"],
        sex=sex,
        birthday=tmp[1]["birthday"],
        avatar=tmp[1]["tinyurl"],
        mavatar=tmp[1]["headurl"],
        other={zidou=tmp[1]["zidou"],star=tmp[1]["star"]}
        }
        return ret
    else
        return nil
    end
end

---获取当前玩家的  app好友列表
--@param    session     string  登录玩家的session key
--@usage	
--@return   table   好友列表
function appfriend(self, session)
    local param = {session_key=session}
    local tmp = self:_post("friends.getAppFriends",param)
    local ret = {}
    for k,n in pairs(tmp) do
        table.insert(ret,tostring(n))
    end
    return ret
end

---注册一个订单号，得到人人网给的token
--@param    para    table   参数，格式为{orderid:订单号,amount:人人豆,test:是否测试}
--@usage	
--@return   string  人人网给的token，以后将根据此token结束订单
function regorder(self, session, para)
    local param = {session_key=session,order_id=para["orderid"],amount=para["amount"]}
    local ret = {}
    if para["test"] then
        ret = self:_post("pay4Test.regOrder",param)
    else
        ret = self:_post("pay.regOrder",param)
    end
    return ret["token"]
end

---检查一笔订单是否已经结束
--@param    para    table   订单参数，格式为：{orderid:订单号,test:是否测试}
--@usage	
--@return   boolean 是否已经结束
function complete(self, para)
    local param = {order_id=para["orderid"]}
    local ret = {}
    if para["test"] then
        ret = self:_post("pay4Test.isCompleted",param)
    else
        ret = self:_post("pay.isCompleted",param)
    end
    return (tostring(ret["result"]) == "1")
end

getmetatable(nao.sns.rr).__newindex = function (table, key, val)
    error('attempt to write to undeclared variable "' .. key .. '": '.. debug.traceback())
end
