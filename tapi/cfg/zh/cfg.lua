---最重要的各版本基础配置
local setmetatable = setmetatable
local error = error
local pairs = pairs
module("tapi.cfg.zh.cfg",package.seeall)
 
local data = {
	pro = {--生产版本相关的配置信息
		--一些通用性质的配置
		max_msg=80, --在消息中最多保存多少笔记录
		db_path="/nndb/tsite/pro/",
		appid="93470",
		apikey="dfe5225bac7b46639c9e2301363f5c2f",
		secret="4efa9f07dd194284b37d9ac7f04b8943",
		apiurl="http://api.xiaonei.com/restserver.do",
		
		--平台特定的配置信息
		secret="11"
	},

	test = {--测试机
		--一些通用性质的配置
		max_msg=80, --在消息中最多保存多少笔记录
		db_path="/nndb/test1/tsite/",
		appid="93470",
		apikey="dfe5225bac7b46639c9e2301363f5c2f",
		secret="4efa9f07dd194284b37d9ac7f04b8943",
		apiurl="http://api.xiaonei.com/restserver.do",
		
		--平台特定的配置信息
		secret="11"
	},
	
	dev = {--开发机
		--一些通用性质的配置
		app_id="1000",
		api_key="1000",
		api_secret="1000",
		api_url="http://mg.now1game.tk/tsite/zh/tsite/page/rr",
		app_url="http://mg.now1game.tk/mg/rr/mg/page/index",
		page_url="http://mg.now1game.tk/mg/rr/mg/page/index2",
		
		--平台特定的配置信息
		secret="11",
		db={
			s1={
				tapi={host="192.168.56.1",port="3306",database="zh_s1_tapi",user="root",password=""},
			},
			s2={
				tapi={host="127.0.0.1",port="3306",database="zh_s2_tapi",user="root",password=""},
			}
		},
		lua_cache=true,--使用什么缓存，默认使用ngx_lua自带的缓存，并缓存8小时
		suf_num=1,
	},
}

local proxy = {}
setmetatable(proxy, {
   __index = data,
    __pairs = function() return pairs(data) end,
    __newindex = function(t, k, v)
            error('table can not modify')
       end
})
return proxy
