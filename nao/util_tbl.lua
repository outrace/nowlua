---table相关的一些辅助函数
module("nao.util_tbl",package.seeall)

---检查值是否存在于table中
--@param    tbl     table   对应的table
--@param    val     any     需要检查的value
--@usage	
--@return   true/false  
function in_tbl(tbl,val)
    for n in pairs(tbl) do
        if tbl[n] == val then return true end
    end
    return false
end

---将一个table的值增加到另外一个table中
--@param	tbl		table	目标表
--@param	newdata	table	被合并的table
--@usage	
--@return void
function add_to_tbl(tbl,newdata)
	for n in pairs(newdata) do
		tbl[n] = newdata[n]
	end
end

---根据key重新排序table项
--@param    tbl     table   需要排序的map类型数组
--@usage	
--@return   table   已经根据key排序过的数组
function sort_by_key(tbl)
  local tmp = {}
  for k in pairs(tbl) do
     table.insert(tmp,k)
  end
  table.sort(tmp)
  local sorted = {}
  for i,n in ipairs(tmp) do
    table.insert(sorted,n)
  end
  return sorted
end

---将k={}的数组转成纯数组
--@param    tbl     table   map类型的数组，key是string val是table
--@param    key     string  一个
--@usage	local mdl = require("nao.util.tbl") <br/>
--			local tbl = {k1={f1="v1",f2="v2",f3="v3"}}<br/>
--			local ret = mdl.map_to_arr(tbl})
--@return   table
function map_to_arr(tbl,key)
    if key == nil then key = "id" end
    local newt = {}
    for k in pairs(tbl) do
        local v = tbl[k]
        v[key] = k
        table.insert(newt,v)
    end
    return newt
end

function npairs(t)
	local oldpairs = pairs
	local mt = getmetatable(t)
	if mt==nil then
		return oldpairs(t)
	elseif type(mt.__pairs) ~= "function" then
		return oldpairs(t)
	end
	return mt.__pairs()
end

function copy(t)
	if type(t) ~= 'table' then return t end
	local res = {}
	for k,v in npairs(t) do
		if type(v) == 'table' then
			v = copy(v)
		end
		res[k] = v
	end
	return res
end

---移除table项中的某些字段，方便返回前台时候隐藏部分字段内容
--@param    tbl     table   需要进行筛选的表
--@param    fields  table   需要移除的字段
--@usage	local mdl = require("nao.util.tbl") <br/>
--			local tbl = {k1="v1",k2="v2",k3="v3"}<br/>
--			mdl.mv_tbl_field(tbl,{"k1","k2"})<br/>
--			local tbl2 = {{k1="v1",k2="v2"},{k1="vv1",k2="vv2"}}<br/>
--			mdl.mv_tbl_field(tbl2,{"k1"})
--@return   void
function mv_fields(tbl,fields)
    if table.getn(tbl) == 0 then --一般空的table和hash的table都会返回0
        for f in pairs(fields) do
            tbl[f] = nil
        end
    else
        for i,k in ipairs(tbl) do
            for f in pairs(fields) do
                tbl[i][f] = nil
            end
        end
    end
end
