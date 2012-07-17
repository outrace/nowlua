global_ver = "dev"	--唯一的全局变量

setmetatable(_G, {
    __newindex = function (_, n)
       error("attempt to write to undeclared variable "..n, 2)
    end,
    __index = function (_, n)
       error("attempt to read undeclared variable "..n, 2)
    end,
})

local mdl_index = require("nao.index")

local flag,msg = pcall(mdl_index.execute)
if flag == false then
	ngx.say(msg)
    ngx.say("system error")
    ngx.log(ngx.ERR,msg)
end