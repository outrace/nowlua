---一些时间相关的辅助函数
module("nao.util_time",package.seeall)
local fw = require("nao.fw")

---计算时间间隔
--@param    dis     string  时间间隔。格式位1d/23h/30m/20s
--@return   int
function get_dis(dis)
    local kind = string.sub(dis,-1)
    local num = tonumber(string.sub(dis,1,-2))
    if kind == "d" then
        num = num * 3600*24
    elseif kind == "h" then
        num = num * 3600
    elseif kind == "m" then
        num = num * 60
    end
    return math.ceil(num)
end

---将某个时间加上一个间隔后，得到最后结果
--@param    now     int     当前时间戳
--@param    dis     string  时间间隔。格式位1d/23h/30m/20s
function add_dis(now,dis)
    return now+get_dis(dis)
end

---获取当周的周一那天的日期，或者那天的0点0分的时间戳
--@param    time    int     一个时间戳,如果为nil则使用当前时间
--@param    type   string  返回类型，date=返回YYYY-mm-dd的时间格式，time=返回时间戳
--@usage	
--@return   string  返回的日期或者时间戳
function get_monday(time,type)
    if time == nil then time = os.time() end
    if type == nil then type = "time" end
    local num = os.date("%w",time)  --当前周几，3=周三,0=周日
    if num == 0 then num = 6 end    --修改为我们习惯的时间
    if num ~= 1 then
        time = time - (num-1)*24*60*60
    end
    if type == "date" then
        return os.date("%Y-%m-%d",time)
    else
        local y=os.date("%Y",time)
        local m=os.date("%m",time)
        local d=os.date("%d",time)
        return tostring(os.time({year=y,month=m,day=d}))
    end
end

---将yyyy-mm-dd[ hh:ii:ss]格式的时间转换成timestamp<br/>
-- 如果是yyyy-mm-dd，则默认为0点0分0秒
--@param    date    string      日期：yyyy-mm-dd[ hh:ii:ss]格式
--@return   int     timestamp
function get_time(date)
    local arr = fw.split(date," ")
    local d = fw.split(arr[1],"-")
    
    local tbl = {
    year=tonumber(d[1]),month=tonumber(d[2]),day=tonumber(d[3])
    }
    if table.getn(arr) == 2 then
        local t = fw.split(arr[2],":")
        tbl["hour"] = tonumber(t[1])
        tbl["min"] = tonumber(t[2])
        tbl["sec"] = tonumber(t[3])
    else
        tbl["hour"] = 0
        tbl["min"] = 0
        tbl["sec"] = 0
    end
    return os.time(tbl)
end
