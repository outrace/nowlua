---SNS平台模拟测试环境的数据结构
local setmetatable = setmetatable
local error = error
local pairs = pairs
module("tapi.ddl.tapi")

local data = {
	user={--id是4位数字id
		field={
			name="名字",first_name="名字",last_name="姓",
			sex="性别male/female",birthday="生日",friend="好友列表"
		},
		default={
			name="",first_name="",last_name="",sex="",birthday="",friend={}
		},
		split=false,tmp=false,trans=true
	},
	udata={--id = 4位数字id_站点
		field={
			invite="邀请列表",feed="新鲜事列表",app="已经安装的app",credit="代币数量"
		},
		default={
			invite={},feed={},app={},credit=0
		},
		split=false,tmp=false,trans=true
	}
}

local proxy = {}
setmetatable(proxy, {
	__index = data,
	__pairs = function() return pairs(data) end,
	__newindex = function(t, k, v)
		error("table can not modify")
	end
})
return proxy