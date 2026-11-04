-- UTC storage; client-local civil time only through checked native date/time.
-- No realm timezone, fixed-offset future timezone or background recurrence guess.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local T={};Z.ScheduleTime=T
local DAYS={31,28,31,30,31,30,31,31,30,31,30,31}
local WEEK={'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}
local MONTH={'January','February','March','April','May','June','July','August','September','October','November','December'}
local function leap(y)return y%4==0 and(y%100~=0 or y%400==0)end
local function monthDays(y,m)return DAYS[m]+(m==2 and leap(y)and 1 or 0)end
function T.Valid(c)
    return type(c)=='table'and A.Safe(c.year,c.month,c.day,c.hour,c.min,c.sec)
        and L.Int(c.year,1970,2099)and L.Int(c.month,1,12)and L.Int(c.day,1,monthDays(c.year,c.month))
        and L.Int(c.hour,0,23)and L.Int(c.min,0,59)and L.Int(c.sec or 0,0,59)
end
function T.Epoch(c)
    if not T.Valid(c)then return nil end
    local days=0;for y=1970,c.year-1 do days=days+(leap(y)and 366 or 365)end
    for m=1,c.month-1 do days=days+monthDays(c.year,m)end
    return(days+c.day-1)*86400+c.hour*3600+c.min*60+(c.sec or 0)
end
function T.UTC(epoch)
    if not L.Int(epoch,0,4102444799)then return nil end
    local days=math.floor(epoch/86400);local year=1970;local remaining=days
    while remaining>=(leap(year)and 366 or 365)do remaining=remaining-(leap(year)and 366 or 365);year=year+1 end
    local month=1;while remaining>=monthDays(year,month)do remaining=remaining-monthDays(year,month);month=month+1 end
    return{year=year,month=month,day=remaining+1,hour=math.floor(epoch%86400/3600),min=math.floor(epoch%3600/60),sec=epoch%60,wday=(days+4)%7+1}
end
local function same(a,b)return a and b and a.year==b.year and a.month==b.month and a.day==b.day and a.hour==b.hour and a.min==b.min and(a.sec or 0)==(b.sec or 0)end
function T.Local(epoch)
    local c=A.Call(date,'*t',epoch)
    if not A.PublicTable(c)or not T.Valid(c)then return nil end
    local offset=T.Epoch(c)-epoch;if not L.Int(offset,-14*3600,14*3600)then return nil end
    local out={year=c.year,month=c.month,day=c.day,hour=c.hour,min=c.min,sec=c.sec or 0}
    out.offset=offset;out.wday=T.UTC(T.Epoch(out)).wday;return out
end
function T.FromLocal(c)
    if not T.Valid(c)then return nil,'Date or time is invalid.'end
    local at=A.Call(time,{year=c.year,month=c.month,day=c.day,hour=c.hour,min=c.min,sec=c.sec or 0})
    if not L.Int(at,0,4102444799)or not same(c,T.Local(at))then
        at=T.Epoch(c)
        for i=1,3 do local observed=T.Local(at);if not observed then break end;at=T.Epoch(c)-observed.offset;if same(c,T.Local(at))then break end end
        if not same(c,T.Local(at))then return nil,'Local time conversion is unavailable or this clock time does not exist. Use an explicit UTC time.'end
    end
    -- Reject common repeated clock hours instead of silently choosing DST/standard.
    for _,delta in ipairs({-86400,-7200,-3600,-1800,1800,3600,7200,86400})do
        if same(c,T.Local(at+delta))then return nil,'This local clock time occurs twice. Choose an explicit UTC time.'end
    end
    return at
end
function T.Input(at,mode)
    local c=mode=='LOCAL'and T.Local(at)or T.UTC(at);if not c then return nil end
    return string.format('%04d-%02d-%02d %02d:%02d',c.year,c.month,c.day,c.hour,c.min)
end
function T.Parse(text,mode)
    if type(text)~='string'or#text>32 or(mode~='LOCAL'and mode~='UTC')then return nil,'Date or time is invalid.'end
    local y,m,d,h,n=text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$')
    local c={year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=tonumber(h),min=tonumber(n),sec=0}
    if not T.Valid(c)then return nil,'Date or time is invalid.'end
    if mode=='UTC'then return T.Epoch(c)end;return T.FromLocal(c)
end
function T.Format(at)
    local c=T.Local(at);local localTime=c~=nil;c=c or T.UTC(at);if not c then return Z.T('Unknown')end
    -- The same localized date fields and time formatter used by Blizzard's
    -- calendar. UTC storage/input remains separate from this display string.
    local weekday=A.PublicTable(CALENDAR_WEEKDAY_NAMES)and CALENDAR_WEEKDAY_NAMES[c.wday]or Z.T(WEEK[c.wday])
    local month=A.PublicTable(CALENDAR_FULLDATE_MONTH_NAMES)and CALENDAR_FULLDATE_MONTH_NAMES[c.month]or Z.T(MONTH[c.month])
    if not L.Text(weekday,64)then weekday=Z.T(WEEK[c.wday])end
    if not L.Text(month,64)then month=Z.T(MONTH[c.month])end
    local full=type(FULLDATE)=='string'and A.Safe(FULLDATE,weekday,month)and A.Call(format or string.format,FULLDATE,weekday,month,c.day,c.year,c.month)
    if not L.Text(full,192)then full=Z.T('%s, %d %s %d',weekday,c.day,month,c.year)end
    local clock=A.Call(GameTime_GetFormattedTime,c.hour,c.min,true)
    if not L.Text(clock,64)then clock=string.format('%02d:%02d',c.hour,c.min)end
    return Z.T('%s at %s',full,clock)..(localTime and''or' UTC')
end
-- A calendar day is measured through native local date conversion, including
-- short/long DST days. UTC is used consistently only if local dates are absent.
function T.DayKey(at,basis)
    local c;if basis=="LOCAL"then c=T.Local(at)elseif basis=="UTC"then c=T.UTC(at)else c=T.Local(at)or T.UTC(at)end;return c and string.format('%04d-%02d-%02d',c.year,c.month,c.day)
end
function T.DayBounds(at)
    if not L.Int(at,1,4102315199)then return nil end
    local localDate=T.Local(at);local read=localDate and T.Local or T.UTC
    local function key(epoch)local c=read(epoch);return c and string.format('%04d-%02d-%02d',c.year,c.month,c.day)end
    local today=key(at);local low,high=at,at+36*3600
    if not today or not key(high)or key(high)==today then return nil end
    while high-low>1 do local middle=math.floor((low+high)/2);local k=key(middle);if not k then return nil end;if k==today then low=middle else high=middle end end
    return today,high,localDate~=nil
end
function T.SameLocal(a,b)return same(T.Local(a),b)end
function T.Weekly(base,index)
    local c=T.Local(base);if not c or not L.Int(index,1,520)then return nil,'Local time conversion is unavailable.'end
    -- Advance a calendar date, then convert that local civil time anew. This
    -- intentionally does not advance the absolute epoch by seven days.
    local next=T.UTC(T.Epoch(c)+index*7*86400);if not next then return nil,'Date or time is invalid.'end
    return T.FromLocal(next)
end
return T
