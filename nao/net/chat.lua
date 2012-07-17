---与聊天服务器的通信
module("nao.net.chat", package.seaall)
local mt = { __index = nao.net.chat }

local fw = require("nao.fw")
local tcp = ngx.socket.tcp
local idle_time = 8000
local conn_pool_size = 100
local random = math.random
local md5 = ngx.md5

---初始化，需包含的参数为 {host='',port='',app='',code=''}
function new(self, o)
	o["sock"] = tcp()
	o["conn"] = false
	o["rec"] = ""
    return setmetatable(o, mt)
end

local function do_send(self,cmd)
	local sock = self.sock
    local cmd_str = fw.json_encode(cmd)
    local len = 100000 + #cmd_str;
    local send_msg = tostring(len)..cmd_str
    local bytes, err = sock:send(send_msg)
    if not bytes then
        ngx.log(ngx.ERR,"send chat msg error when send msg="..send_msg)
        return nil
    else
    	local len, err = sock:receive(6)
    	if not len then
        	ngx.log(ngx.ERR,"cant get rec after login")
    	end
    	len = tonumber(len) - 10000
    	local data, err = sock:receive(len)
    	if not data then
        	ngx.log(ngx.ERR,"cant get rec msg")
    	end
    	return fw.json_decode(data)
    end
end

---发送信息到聊天服务器
--@param	to		接收方，空表示所有用户
--@param	msg		信息内容
function send(to, msg)
    local sock = self.sock
    if o["conn"] == false then
    	sock:settimeout(timeout)
    	local ok, err = sock:connect(self.host, self.port)
        if not ok then
            ngx.log(ngx.ERR,"failed to connect chat svr,host="..self.host.." port="..self.port)
            return
        end
        o["conn"] = true
        
        --设置为size=100的连接池，8秒空闲则过期
        local ok, err = sock:setkeepalive(idle_time, conn_pool_size)
        if not ok then
            ngx.log(ngx.ERR,"fail to set keepalive")
            return
        end
        
        --发送验证信息
        local rand_str = ngx.time()..tostring(random(100, 999))
        local crypt_code = md5(rand_str..self.code)
        local cmd = {cmd="login", uid="", app=self.app, code=rand_str.."|"..crypt_code}
    	local ret = _send(self.sock, cmd)
    end
    
    local cmd = {cmd="chat", from="", to=to, msg=msg}
end    