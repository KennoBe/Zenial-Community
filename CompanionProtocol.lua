-- One-way, printable chat-log frames. No network/file API or executable imports.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local P={VERSION=1,MAX_LINE=240,MAX_BODY=65536,MAX_PARTS=1024};Z.CompanionProtocol=P
local ARRAY={};local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function P.Array(t)return setmetatable(t or{},ARRAY)end
function P.Checksum(s)
    local a,b=0,0
    for i=1,#s do a=(a+s:byte(i))%255;b=(b+a)%255 end
    return string.format('%04x',b*256+a)
end
function P.Source(key)
    local a,b=5381,7919
    for i=1,#key do local n=key:byte(i);a=(a*33+n)%4294967291;b=(b*131+n)%4294967291 end
    return string.format('%08x%08x',a,b)
end
function P.Base64(s)
    local out={}
    for i=1,#s,3 do
        local a,b,c=s:byte(i,i+2);local n=a*65536+(b or 0)*256+(c or 0)
        local x,y,z,w=math.floor(n/262144)%64,math.floor(n/4096)%64,math.floor(n/64)%64,n%64
        out[#out+1]=alphabet:sub(x+1,x+1)..alphabet:sub(y+1,y+1)..(b and alphabet:sub(z+1,z+1)or'=')..(c and alphabet:sub(w+1,w+1)or'=')
    end
    return table.concat(out)
end
local function quoted(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'end
        return string.format('\\u%04x',c:byte())
    end)..'"'
end
function P.Json(value)
    local seen={};local nodes=0
    local function encode(v,depth)
        nodes=nodes+1;if nodes>20000 or depth>16 or not A.Safe(v)then error('inaccessible or excessive export')end
        local kind=type(v)
        if v==nil then return 'null'elseif kind=='boolean'then return v and'true'or'false'
        elseif kind=='string'then return quoted(v)
        elseif kind=='number'then if v~=v or math.abs(v)>1e15 then error('non-finite export')end;return string.format('%.10g',v):gsub(',','.')
        elseif kind~='table'or not A.PublicTable(v)or seen[v]then error('invalid export value')end
        seen[v]=true;local out={};local array=getmetatable(v)==ARRAY
        if array then for i=1,#v do out[#out+1]=encode(v[i],depth+1)end
        else
            local keys={};for k in pairs(v)do if not A.Safe(k)or type(k)~='string'then error('invalid export key')end;keys[#keys+1]=k end
            table.sort(keys);for _,k in ipairs(keys)do out[#out+1]=quoted(k)..':'..encode(v[k],depth+1)end
        end
        seen[v]=nil;return(array and'['or'{')..table.concat(out,',')..(array and']'or'}')
    end
    local out=encode(value,0);if#out>P.MAX_BODY then error('export exceeds 64 KiB')end;return out
end
function P.Frames(source,session,sequence,topic,at,body)
    if not source:match('^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$')or not session:match('^%d+%.%d+%.%d+$')or not topic:match('^[a-z]+$')then return nil,'invalid header'end
    if sequence<1 or sequence>2147483646 or at<1 or at>4102444800 or#body>P.MAX_BODY then return nil,'invalid bounds'end
    local payload=P.Base64(body)
    local prefix=table.concat({'ZC5','1',source,session,tostring(sequence),topic,tostring(at)},'~')
    local check=P.Checksum(prefix..'~'..payload)
    -- Reserve four digits each for part/total. Every chunk splits on a Base64 boundary.
    local room=math.floor((P.MAX_LINE-#prefix-#'~1024/1024~0000~')/4)*4
    if room<32 then return nil,'header too long'end
    local total=math.max(1,math.ceil(#payload/room));if total>P.MAX_PARTS then return nil,'too many fragments'end
    local lines={};for i=1,total do lines[i]=prefix..'~'..i..'/'..total..'~'..check..'~'..payload:sub((i-1)*room+1,i*room)end
    return lines
end
