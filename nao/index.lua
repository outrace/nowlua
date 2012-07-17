---首页运行相关的函数
module("nao.index",package.seeall)

local suf = ".do"
local fw = require("nao.fw")
local memcached = require("resty.memcached")
local dao = require("nao.dao")
	
function execute()
	local uri = string.sub(ngx.var.uri,0,-(#suf+1))
	local arr = fw.split(uri,"/") --/rr/s1/mg/admin/list
	
	--[,'平台名','分服名','游戏名','模块名','方法名']
	if #arr ~= 6 then
		ngx.say("welcome")
	else
	    ngx.ctx["site"]=arr[2]	  --站点类型
    	ngx.ctx["svr"] = arr[3]    --分服
	    ngx.ctx["app"]=arr[4]	  --应用名
	    ngx.ctx["cls"]=arr[5]	  --类模块
	    ngx.ctx["method"]=arr[6]  --方法
	    ngx.ctx["uid"]=""
	    local cfg = require(ngx.ctx["app"]..".cfg."..ngx.ctx["site"]..".cfg")
	    if cfg == nil then
	    	ngx.say("cfg error")
	    else
		    ngx.ctx["cfg"] = cfg[global_ver]
		    
		    --得到分服信息。
		    
		    --http://s213.app27036.qqopenapp.com
		    --http://app36862.qzone.qzoneapp.com&appid=36862&platform=qzone&timestamp=1332576988045,1332576988092&stat=0
		    if ngx.ctx["site"] == "py" then --朋友平台
				local host = ngx.header.host
				local harr = fw.split(host,".")
				if harr[2] == "t" then
			    	ngx.ctx["pf"]= "tapp"
				elseif harr[2] == "qzoneapp" then
			    	ngx.ctx["pf"]= "pengyou"
			    else
			    	ngx.ctx["pf"]= "qzone"
				end
		    end
		            
		    ngx.ctx["dao"]= dao:new{
		    	["trans"]={d={},m={},a={}},
		    	["db"] = {},
		    	["dbcfg"] = ngx.ctx["cfg"]["db"][ngx.ctx["svr"]]	--数据库配置信息
		    }
		    
		    if ngx.ctx["cfg"]["memcache"] ~= nil then
		        ngx.ctx["memc"] = memcached:new()
				memcache:set_timeout(1000) -- 1 sec
				memcache:set_keepalive(0, 500)
				local host = cfg["memcache"]
		        local ok, err = memcache:connect(host.h, host.p)
		        if not ok then
		            ngx.log(ngx.ERR,"failed to connect memcached")
		            ngx.ctx["memc"] = nil
		        end
		    end
			    
			local flag,msg = pcall(fw.execute)
			if flag == false then
			    ngx.say("system error")
			    ngx.log(ngx.ERR,msg)
			end
		end
	end
end