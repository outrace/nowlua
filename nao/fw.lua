---主框架基础函数
module("nao.fw",package.seeall)
local cjson = require("cjson")
local len = string.len
local sub = string.sub
local insert = table.insert
--cjson.encode_sparse_array(true)

---进行json编码
function json_encode(tbl)
	return cjson.encode(tbl)
end

---进行json解码
function json_decode(str)
	return cjson.decode(str)
end

---字符串切割。以后可以换为系统所提供的 ngx.re.split  这里只支持单字符串的
function split(str,delimiter)	
	local s = ""
	local mi = len(str) + 1
	local tmp = ""
	local i = 1
	local result = {}
	while i < mi do
		tmp = sub(str,i,i)
		if tmp == delimiter  then
			insert(result,s)
			s = ""
			i = i + 1
		else
			s = s .. tmp
			i = i + 1
		end
	end
	insert(result,s)
	return result
end

--action执行之前，执行这里
local function before()
	local ctx = ngx.ctx
    if type(ctx["in"]) == "table" then --说明是游戏应用，我们检查sessionkey和令牌
        if ctx["method"] == "login" or ctx["method"] == "test" then --登录的方法，我们不检查
            return
        end
        
		--页面访问我们默认不检查登录情况，如果需要检查，请在请求函数中处理
        if ctx["cls"] == "page" then
            return
        end
        
        if ctx["uid"] == "" then
            err("请先登录",1)
        end
        local headers = ngx.req.get_headers()
        if headers["nowr"] == nil or headers["nowk"] == nil then
        	err("header error")
        end
        local tmp = tostring(ngx.crc32_short(ngx.var.request_body..headers["nowr"]))
        if tmp ~= headers["nowk"] then
        	err("sign key error"..tmp)
        end
        
        local old = ctx.dao:get(ngx.ctx["app"]..".session",ctx["uid"],ctx["uid"])
        if old == nil then
            err("需要登录",1)
        end
        if ctx["in"]["_u"] ~= old["key"] then
            err("session err",1)
        end
    end
end

---抛出异常
--@param    msg     string      错误信息
--@param    code    int         错误代码
--@return   void
function err(msg,code)
    if code == nil then code = 1 end
	if msg == nil then msg = 'err' end
	
	if ngx.ctx["cls"]=="page" and string.find(ngx.ctx["method"],"_index")~=nil then --首页异常，进行刷新
		local tpl = "%s|%s|%s"
		ngx.log(ngx.ERR,string.format(tpl,tostring(code),tostring(ngx.ctx.uid),tostring(msg)))
		ngx.print('<html><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" /><script type="text/javascript">function reload_page(){window.location.reload();}</script></head><body>服务器繁忙，<a href="javascript:void()" onclick="reload_page()">点击这里重新进入游戏。</a></body></html>')
	else
		ngx.print(json_encode({_m=msg,_c=code,_time=ngx.time()}))
		local tpl = "%s|%s|%s"
		ngx.log(ngx.ERR,string.format(tpl,tostring(code),tostring(ngx.ctx.uid),tostring(msg)))
	end
	error('zzz')
end

--对输入参数进行nil检查
function check_in(para)
	local tmp = nil
	for k,v in ipairs(para)	do
		tmp = ngx.ctx["in"][k]
		if tmp == nil then
			err("参数"..v.."未正确传入")
		elseif v ~= "" then
			
		end
	end
end

---得到模板数据
--@param    app     string  游戏名称
--@param    site    string  平台名称
--@param    page    string  页面名称
--@param    tname   string  模板名称
--@param    data    table   模板数据内容
function get_tpl(app,site,page,tname,data)
    local mdl = require(app..".tpl."..site.."."..page)
    local tpl = mdl[tname]
    local ret = tpl
    
    for k in pairs(data) do
        if type(data[k]) == "string" then
            ret = string.gsub(ret,"{"..k.."}",data[k])
        else
            for kk in pairs(data[k]) do
                ret = string.gsub(ret,"{"..k.."."..kk.."}",data[k][kk])
            end
        end
    end
    
    return ret
end

---我们用一个字符串作为玩家标记，格式为  随机数+|+用户id+|+签名
--@param    uid     string      玩家id【是角色id，不是账号id】
--@return   void
function set_session(uid)
    local rand = tostring(ngx.time() + math.random(1000,9999))
    local sign = tostring(ngx.crc32_short(rand..uid..ngx.ctx["cfg"]["api_secret"]))
    return rand.."|"..uid.."|"..sign
end

---根据传过来的参数来确认当前会话的玩家
--@param    str     string       传过来的session字符串
--@return   string  空表示无法得到正确的session，否则返回当前session的uid
function get_session(str)
    if str == nil then return '' end
    local arr = split(str,"|")
    
    if #arr ~= 3 then
        return ''
    end
    local sign = tostring(ngx.crc32_short(arr[1]..arr[2]..ngx.ctx["cfg"]["api_secret"]))
    if sign == arr[3] then
        return arr[2]
    else
        return ''
    end
end

function debug(key,val)
	if global_ver ~= "pro" then
		ngx.header['debug_'..key] = json_encode(val)
	end
end

--使用ngx_lua内置的非阻塞http方式发送一次http请求,并得到返回结果
--@param    url         string  请求的URL
--@param    para   		table  请求的参数
--@param    is_post     boolean 是否是POST方式
function http_send(url,para,is_post)
	ngx.req.set_header("Accept-Encoding", "")
	
	if is_post then
		local str = ""
		if type(para) ~= "string" then
			str = ngx.encode_args(para)
		else
			str = para
		end
		ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded")
		res = ngx.location.capture(url,{method = ngx.HTTP_POST, body=str})
	else
		res = ngx.location.capture(url,{method = ngx.HTTP_GET})
	end
	
	if res.status ~= 200 then
		error("error to fetch url="..url.." status="..tostring(res.status))
	end
	return res.body
end

---所有页面请求的主入口
function execute()
    if ngx.ctx["cls"] == "page" then --/mg/rr/mg/admin/list  以page作为页面入口
		ngx.ctx["in"] = {}
		if ngx.var.request_method == "POST" then
			ngx.ctx["in"]["post"] = ngx.req.get_post_args()
		else
			ngx.ctx["in"]["post"] = {}
		end
		ngx.ctx["in"]["get"] = ngx.req.get_uri_args()
		ngx.ctx["out"] = ""
    else
		ngx.ctx["in"] = {}
		ngx.ctx["out"] = {_v=ngx.ctx["cfg"]["v"]}
		if ngx.var.request_method == "POST" then
			ngx.ctx["in"] = json_decode(ngx.var.request_body)
			ngx.ctx["uid"] = get_session(ngx.ctx["in"]["_u"])
		end
    end
	
	local doaction = function()
		--ngx.say(ngx.ctx["app"]..".app."..ngx.ctx["cls"])
		local cls = require(ngx.ctx["app"]..".app."..ngx.ctx["cls"])
		before()
		cls[ngx.ctx["method"]]()
	end
	
	local ret,msg = pcall(doaction)
    if ret == false then
        ngx.ctx.dao:abort()
		if sub(msg,-3) ~= 'zzz' then --说明是程序异常，而不是逻辑异常
			local logmsg = string.format("%s|%s|%s",'999',tostring(ngx.ctx.uid),msg)
			ngx.log(ngx.ERR,logmsg)
			ngx.print(json_encode({_m=msg,_c=1,_time=ngx.time(),_t=ngx.ctx["out"]["_t"]}))
		end
    else
        ngx.ctx.dao:commit()
        if type(ngx.ctx["out"]) == "table" then
          ngx.ctx["out"]["_time"] = ngx.time()
          ngx.print(json_encode(ngx.ctx["out"]))
        else
          ngx.print(ngx.ctx["out"])
        end
    end

end
