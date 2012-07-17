---腾讯朋友网的接口
module("nao.sns.py",package.seeall)

local mt = { __index = nao.sns.py}
local fw = require("nao.fw")

function new(self,o)
	o["format"] ="json"
	o["pf"]="pengyou"
	o["userip"]="127.0.0.1"
    return setmetatable(o, mt)
end

local function _rpl(str)
	local s = ""
	local mi = string.len(str) + 1
	local tmp = ""
	local i = 1
	while i < mi do
		tmp = string.sub(str,i,i)
		if tmp == "%" then
			s = s .. tmp .. string.upper(string.sub(str,i+1,i+2))
			i = i + 3
		elseif tmp == "*" then
			s = s .. "%2A"
			i = i + 1
		else
			s = s .. tmp
			i = i + 1
		end
	end
	return s
end

local function _encode(str)
	--string.format('%X',string.byte('-'))
	local s = ""
	local mi = string.len(str) + 1
	local tmp = ""
	local i = 1
	while i < mi do
		tmp = string.sub(str,i,i)
		if tmp == "-" then
			s = s .. "%2D"
			i = i + 1
		else
			s = s .. tmp
			i = i + 1
		end
	end
	return s
end

--发送http请求到人人网的服务器，并得到返回结果
--@param    method      string      方法名
--@param    para        table       参数信息
--@usage	
--@return   table       人人rest服务器返回的结果集
local function _post(self, method,para)
	para["appid"] = self.appid
	para["pf"] = self.pf
	para["format"] = self.format
	para["userip"] = self.userip
	
	local tmp = {}
	for k in pairs(para) do table.insert(tmp,k) end
	table.sort(tmp)
	local sorted = {}
	local sorted2 = {}
	for i,n in ipairs(tmp) do
		table.insert(sorted,n..'='..para[n])
		table.insert(sorted2,n..'='..rpl(ngx.escape_uri(para[n])))
	end
	local pstr = table.concat(sorted,"&")
	local pstr2 = table.concat(sorted2,"&")
	local encode_str = "GET&"..ngx.escape_uri(method).."&"..ngx.escape_uri(pstr)
	encode_str = rpl(encode_str)
	local digest  = ngx.hmac_sha1(secret.."&", encode_str)
	local sig = rpl(ngx.escape_uri(ngx.encode_base64(digest)))
    local url = apiurl
    if method == "/v3/pay/buy_goods" then
    	url = url .. "_pay"
    end
    url  = url..method.."?"..pstr2.."&sig="..sig
	ngx.req.set_header("Accept-Encoding", "")
	
	local resp = ngx.location.capture(url,{method = ngx.HTTP_GET})
	if res.status ~= 200 then
		error("error to fetch url="..url.." status="..tostring(res.status))
	end
	local ret = resp.body
    if para["pf"] == "tapp" then
    	ret = string.gsub(ret,":null",":[]")
    end
    local js = encode.json_decode(ret)
  	if js == nil or js["ret"] ~=0 then
  		fw.err("朋友接口异常："..tostring(ret).." url="..url)
  	end
    return js
end

---进行预购买，得到token等信息
function buy_goods(self, para)
	para["device"] = "0"
	para["appmode"] = "1"   --表示玩家不能修改数量
	para["ts"] = ngx.time()
    return self:_post("/v3/pay/buy_goods",para)
end

function get_sig(self, method,para)
	local tmp = {}
	for k in pairs(para) do table.insert(tmp,k) end
	table.sort(tmp)
	
	local sorted = {}
	for i,n in ipairs(tmp) do
		table.insert(sorted,n..'='.._encode(para[n]))
	end
	local pstr = table.concat(sorted,"&")
	local encode_str = "GET&"..ngx.escape_uri(method).."&"..ngx.escape_uri(pstr)
	encode_str = rpl(encode_str)
	local digest  = ngx.hmac_sha1(secret.."&", encode_str)
	return ngx.encode_base64(digest)
end

---获取某个玩家的详细信息
--@param    uid     	string  	openid
--@param    session 	string  	openkey
--@usage	
--@return   table   所查询的玩家详细信息
function get_user(self, uid, session)
	local tmp = fw.split(session,"|")
    local param = {
    openid=tmp[1],
    openkey=tmp[2]
    }
    local tmp = self:_post("/v3/user/get_info",param)
    
    if tmp ~= nil then
        if tostring(tmp["gender"])  == "男" then
        	sex = "1"
       	else
            sex = "0"
        end
        
        if tmp["nickname"] == nil or tmp["nickname"] == "" then
        	tmp["nickname"] = "朋友"
        end
        
        if tmp["figureurl"] == nil or tmp["figureurl"] == "" then
         	local cfg = require(ngx.ctx.app..".cfg.py.cfg")
         	local fw = require("nao.fw")
        	tmp["figureurl"] = cfg[fw.ver]["img_url"].."ui/avatar.png"
        end
		tmp["nickname"] = string.gsub(tmp["nickname"],"%'","")
		tmp["nickname"] = string.gsub(tmp["nickname"],'%"',"")
		tmp["nickname"] = string.gsub(tmp["nickname"],"%\\","")
        local ret = {
        name=tmp["nickname"],
        sex=sex,
        birthday='2011-01-01',
        avatar=tmp["figureurl"],
        mavatar=tmp["figureurl"],
        other={is_yellow_vip=tmp["is_yellow_vip"],is_yellow_year_vip=tmp["is_yellow_year_vip"],yellow_vip_level=tmp["yellow_vip_level"]}
        }
		ret["other"][self.pf.."_avatar"] = tmp["figureurl"]
   		ret["other"][self.pf.."_name"] = tmp["nickname"]
   		
        return ret
    else
        return nil
    end
end

---获取当前玩家的  app好友列表，只返回id
--@param    session     string  包含openid|open key
--@usage	
--@return   table   好友列表
function appfriend(session)
	local tmp = fw.split(session,"|")
    local param = {
    openid=tmp[1],
    openkey=tmp[2],
    infoed=0,
    apped=1,
    page=0
    }
    local tmp1 = self:_post("/v3/relation/get_app_friends",param)
    local ret = {}
    for i,usr in ipairs(tmp1["items"]) do
        table.insert(ret, usr["openid"])
    end
    return ret
end

getmetatable(nao.sns.py).__newindex = function (table, key, val)
    error('attempt to write to undeclared variable "' .. key .. '": '.. debug.traceback())
end
