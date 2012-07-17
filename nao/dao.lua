---数据访问层
module("nao.dao", package.seeall)

local mt = { __index = nao.dao}
local fw = require("nao.fw")
local mysql = require("resty.mysql")

---得到cache，优先使用本地缓存，如果没有设置则使用memcache
local function _cache_get(key)
	if ngx.ctx["cfg"]["lua_cache"] then
		local dao_cache = ngx.shared.dao
		local value, flags = dao_cache:get(key)
		return value
	elseif ngx.ctx["memc"] ~= nil then
        local res, flags, err = ngx.ctx["memc"]:get(key)
        if err then
			ngx.log(ngx.ERR,"error to get key="..key.." err="..err)
			ngx.ctx["memc"]  = nil
            return nil
        end
        if not res then
            return nil
        end
        return res
	end
end

---设置cache
local function _cache_set(key,val)
	if ngx.ctx["cfg"]["lua_cache"] then
		local dao_cache = ngx.shared.dao
		local succ, err, forcible = dao_cache:set(key, val, 720)
	elseif ngx.ctx["memc"] ~= nil then
		local ok, err = ngx.ctx["memc"]:set(key,val)
		if not ok then
			ngx.log(ngx.ERR,"error to set cache key="..key.." err="..err)
			ngx.ctx["memc"]  = nil
		end
	end
end

local function _cache_del(key)
	if ngx.ctx["cfg"]["lua_cache"] then
		local dao_cache = ngx.shared.dao
		dao_cache:delete(key)
	elseif ngx.ctx["memc"] ~= nil then
		local ok, err = ngx.ctx["memc"]:delete(key)
		if not ok then
			--ngx.log(ngx.ERR,"error to delete key="..key.." err="..err)
			--ngx.ctx["memc"]  = nil
		end
	end
end

local function _quote( str)
	local tmp = string.gsub(str,"%'","")
	--tmp = string.gsub(tmp,"%\\\"","")
	--tmp = string.gsub(tmp,"%\\","")
	return tmp
end


function new(self,o)
    return setmetatable(o, mt)
end

---得到数据配置
function _ddl(self, tbl, key, uid)
	local arr = fw.split(tbl,".")
	local cfg = require(ngx.ctx["app"]..".ddl."..arr[1])
	local ret = cfg[arr[2]]
	if ret == nil then
		fw.err("ddl not exist "..tbl)
	end
	
	local tblname = arr[2]
	if ret["split"] then
		if uid == nil then
			fw.err("need dbsuf")
		end
		tblname = tblname.."_"..tostring(ngx.crc32_short(uid)%ngx.ctx["cfg"]["suf_num"])
	end
	local cache_key = self.dbcfg[arr[1]]["database"].."_"..tblname.."_"..key
	return ret, arr[1], tblname, cache_key
end

---打开数据库
function _open(self, dbname)
	if self.db[dbname] == nil then
	    local db = mysql:new()
	    db:set_timeout(1000) -- 1 sec
	    
	    local set = self.dbcfg[dbname]
		local ok, err, errno, sqlstate = db:connect{
	        host = set.host,
	        port = set.port,
	        database = set.database,
	        user = set.user,
	        password = set.password,
	        max_packet_size = 1024 * 1024 }
	
	    if not ok then
	        fw.err("failed to connect: ", err, ": ", errno, " ", sqlstate)
	    end
	    self.db[dbname] = db
	end
end

---发送请求
function _query(self,db,sql)
	self:_open(db)
	local res, err, errno, sqlstate =  self.db[db]:query(sql)
    if not res then
		fw.err(ngx.ERR, "when query sql=["..sql.."]. get bad result:", err, ": ", errno, ": ", sqlstate, ".")
    end
    return res
end

---执行sql
function _execute(self,db,sql)
	self:_open(db)
	local res, err, errno, sqlstate = self.db[db]:query(sql)
    if not res then
        ngx.log(ngx.ERR, "when execute sql=["..sql.."]. get bad result:", err, ": ", errno, ": ", sqlstate, ".")
    end
end

---提交事务
function commit(self)
	--数据删除
	for k,v in pairs(self.trans["d"]) do
		local tbl = self.dbcfg[v.dbname]["database"]..".".."`"..v.tblname.."`"
		
		local sql = "delete from "..tbl.." where k='"..v.key.."'"
		self:_execute(v.dbname, sql)
		
		if v["cache"] then
			_cache_del(k)
		end
	end
	
	--数据新增
	for k,v in pairs(self.trans["a"]) do
		local tbl = self.dbcfg[v.dbname]["database"]..".".."`"..v.tblname.."`"
		local save_val = fw.json_encode(v.val)
		
		local sql = "insert into "..tbl.." (k,v) values ('"..v.key.."','"..save_val.."')"
		self:_execute(v.dbname, sql)
		
		if v["cache"] then
			_cache_set(k,save_val)
		end
	end
	
	--数据修改
	for k,v in pairs(self.trans["m"]) do
		local tbl = self.dbcfg[v.dbname]["database"]..".".."`"..v.tblname.."`"
		local save_val = fw.json_encode(v.val)
		
		local sql = "update "..tbl.." set v = '"..save_val.."' where k = '"..v.key.."'"
		self:_execute(v.dbname, sql)
		
		if v["cache"] then
			_cache_set(k,save_val)
		end
	end
	self:_close()
end

--回滚事务
function abort(self)
	self:_close()
end

--关闭dao,清空资源
function _close(self)
	for k,v in  pairs(self.db) do
		v:close()
	end
end

---新增数据
function add(self,tbl,key,val,uid)
    if type(key) == "table" then
    	for k,v in pairs(key) do
    		self:add(tbl, k, v, uid) 
    	end
    else
		local cfg,dbname,tblname,ck = self:_ddl(tbl, key, uid)
		
		for k,v in pairs(cfg["default"]) do
			if val[k] == nil then
				val[k] = v
			end
		end
		
		self.trans["a"][ck] = {val=val,uid=uid,dbname=dbname,tblname=tblname,key=key,cache=cfg["cache"]}
    end
end

---批量获取数据
function mget(self, tbl, keys)
	local ret = {}
	for _, key in ipairs(keys) do
		ret[key] = self:get(tbl, key, key)
	end
	return ret
end

---获取数据
function get(self, tbl, key, uid)
	local cfg,dbname,tblname,ck = self:_ddl(tbl, key, uid)
	local tbl = self.dbcfg[dbname]["database"]..".".."`"..tblname.."`"
	
	local fun = function()
		local cv = _cache_get(ck)
		local val = nil
		if cv then
			return fw.json_decode(cv)
		else
			local sql = "select k,v from "..tbl.." where k='"..key.."'"
			local rows = self:_query(dbname,sql)
			if #rows > 0 then
				if cfg["cache"] then
					_cache_set(ck,rows[1]["v"])
				end
				return fw.json_decode(rows[1]["v"])
			else
				return nil
			end
		end
	end
	
	if self.trans["m"][ck] ~= nil then
		return self.trans["m"][ck]["val"]
	elseif self.trans["a"][ck] ~= nil then
		return self.trans["a"][ck]["val"]
	else
		local val = fun()
		if val then
			for k,v in pairs(cfg["default"]) do
				if val[k] == nil then
					val[k] = v
				end
			end
			return val
		else
			return nil
		end
	end
end

---保存数据
function save(self,tbl,key,val,uid)
	if type(key) ~= "string" then
		fw.err(tbl)
	end
	local ddl,dbname,tblname,cache_key = self:_ddl(tbl, key, uid)
	self.trans["m"][cache_key] = {val=val,uid=uid,dbname=dbname,tblname=tblname,key=key,cache=ddl["cache"]}
end

--删除数据
function del(self,tbl,key,uid)
	local ddl,dbname,tblname,cache_key = self:_ddl(tbl, key, uid)
	self.trans["d"][cache_key] = {uid=uid, dbname=dbname, tblname=tblname,key=key,cache=ddl["cache"]}
end

function count(self,tbl,uid)
	local cfg,dbname,tblname,ck = self:_ddl(tbl, "", uid)
	local sname = self.dbcfg[dbname]["database"]..".".."`"..tblname.."`"
	
	local sql = "select count(k) as ttl from "..sname
	local rows = self:_query(dbname,sql)
	return rows[1]['ttl']
end

---查找前缀的总量
function precount(self,tbl, pre, uid)
	local cfg,dbname,tblname,ck = self:_ddl(tbl, "", uid)
	local sname = self.dbcfg[dbname]["database"]..".".."`"..tblname.."`"
	
	local sql = "select count(k) as ttl from "..sname.." where k like '"..pre.."%'"
	local rows = self:_query(dbname,sql)
	return rows[1]['ttl']
end

---查找前缀
function pre(self,tbl,pre,max,uid)
  	if max == nil then max = 1000 end
	local cfg,dbname,tblname,ck = self:_ddl(tbl, "", uid)
	local sname = self.dbcfg[dbname]["database"]..".".."`"..tblname.."`"
	local sql = "select k,v from "..sname.." where k like '"..pre.."%' limit "..max
	local rows = self:_query(dbname,sql)
	return self:_get_ret(rows)
end

---进行一定范围的随机查询
function random(self,tbl,start,max,uid)
	local cfg,dbname,tblname,ck = self:_ddl(tbl, "", uid)
	local sname = self.dbcfg[dbname]["database"]..".".."`"..tblname.."`"
	
	local sql = "select k,v from "..sname.." limit "..start..", "..max
	local rows = self:_query(dbname,sql)
	return self:_get_ret(rows,cfg)
end

function _get_ret(self, rows, cfg)
	local data = {}
	if not rows or #rows == 0 then
	else
		for i,row in ipairs(rows) do
			local one = fw.json_decode(row["v"])
			for k,v in pairs(cfg["default"]) do
				if one[k] == nil then
					one[k] = v
				end
			end
			data[row["k"]] = one
		end
    end
    return data
end

-- to prevent use of casual module global variables
getmetatable(nao.dao).__newindex = function (table, key, val)
    error('attempt to write to undeclared variable "' .. key .. '": '.. debug.traceback())
end