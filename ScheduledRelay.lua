-- Scheduled events while their organizer is offline: applications, sign-offs and decisions travel through the
-- confirmed participants of the event and are merged per person, so nothing is lost when people were online at
-- different times.
--
--   member statement   apply / sign off, written by the member, ordered by the member's own sequence number
--   decision           status of one member, written by the organizer, ordered by its application revision
--
-- A member who cannot reach the organizer asks its reachable contacts who is a confirmed participant of the event
-- (P / Y), leaves its statement with up to three of them (M, receipt R) and keeps it itself. A participant hands
-- the statements it holds to the organizer as soon as it meets them (M); the organizer treats each like a direct
-- one: the highest sequence number of a member counts, older or repeated ones change nothing. The organizer leaves
-- the decisions for members it cannot reach with its confirmed participants (D), who pass each on to its member;
-- the member keeps the one with the highest revision.
--
-- Trust: a statement that came this way is a claim until the organizer and the member have met directly. The
-- member's own record is never overwritten by it (follow.relayed stands beside the verified state and is shown as
-- "carried on, not yet confirmed by the organizer"). The organizer accepts statements only from its confirmed
-- participants; like a carried decision, a carried statement rests on their word until member and organizer meet.
-- All messages are direct ones of kind SX on verified routes (ScheduledGroups.Receive, same envelope as SA / SS).
local Z, L, A = ZenialCommunity, ZenialCommunity.Logic, ZenialCommunity.Adapter
local S = Z.ScheduledGroups
if type(S) ~= 'table' or type(S.internal) ~= 'table' then
    return
end
local I = S.internal
local R = { MAX_BOX = 40, MAX_DEPOSITS = 3, MAX_PROBES = 16, PROBE_EVERY = 120, MAX_HANDS = 3, MAX_TRIES = 20 }
Z.ScheduledRelay = R
local MAX = I.MAX
local ACTIVE = { REQUESTED = true, CONFIRMED = true, WAITLIST = true }
local STATES = { REQUESTED = true, CONFIRMED = true, WAITLIST = true, DECLINED = true, WITHDRAWN = true }

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end
-- Key of a character named on the wire: the known contact, otherwise the key that name will get as a contact.
local function keyOf(target)
    if not L.Text(target, 49) or not L.Identity(target) then
        return nil
    end
    return Z.ResolvePeerKey(target) or L.ScopeKey(target, Z.me.realm, Z.me.faction)
end
local function targetOf(key)
    local c = Z.db.contacts[key]
    return c and c.target or nil
end
-- The organizer's character name: the contact, otherwise the one the public announcement of the event carries.
local function ownerTargetOf(ownerKey, eventID)
    local t = targetOf(ownerKey)
    if t then
        return t
    end
    local e = S.Get(ownerKey, eventID)
    local o = e and e.ownerTarget
    return o and L.Text(o, 49) and L.Identity(o) and o or nil
end
local function send(key, fields, priority, dedupe)
    local route, contact = I.currentRoute(key)
    if not route or not route.scheduledGroups then
        return false
    end
    local values = { '1', Z.session, route.session }
    for _, v in ipairs(fields) do
        values[#values + 1] = v
    end
    return Z.Network3.QueueDirect(contact.target, 'SX', Z.Network3.Pack(values), priority or 80, dedupe) ~= nil
end
local function ownerOffline(ownerKey)
    return I.currentRoute(ownerKey) == nil
end

-- Stored statements of a confirmed participant (follow.box) and the carried decision of a member
-- (follow.relayed): only well-formed values survive loading.
local function cleanStatement(m)
    if type(m) ~= 'table' or not L.Int(m.seq, 1, MAX) or (m.action ~= 'APPLY' and m.action ~= 'WITHDRAW') or not I.validRole(m.role)
        or not L.Int(m.content, 1, MAX) or not I.id(m.nonce) or not L.Text(m.proof or '', 32, true) or not L.Int(m.at, 1, 4102444799) then
        return nil
    end
    return { seq = m.seq, action = m.action, role = m.role, content = m.content, nonce = m.nonce, proof = m.proof or '', at = m.at, done = m.done == true,
        tries = L.Int(m.tries, 0, 1000) and m.tries or 0 }
end
local function cleanDecision(d)
    if type(d) ~= 'table' or not STATES[d.state] or not I.validRole(d.role) or not L.Int(d.appRevision, 1, MAX) or not L.Int(d.ackSeq, 0, MAX)
        or not L.Int(d.at, 1, 4102444799) then
        return nil
    end
    return { state = d.state, role = d.role, appRevision = d.appRevision, ackSeq = d.ackSeq, at = d.at, done = d.done == true,
        tries = L.Int(d.tries, 0, 1000) and d.tries or 0 }
end
function R.CleanBox(raw)
    if type(raw) ~= 'table' then
        return nil
    end
    local out, n = {}, 0
    for key, row in pairs(raw) do
        if n < R.MAX_BOX and L.ValidIdentityKey(key) and type(row) == 'table' and L.Text(row.target, 49) and L.Identity(row.target) then
            local m, d = cleanStatement(row.m), cleanDecision(row.d)
            if m or d then
                out[key] = { target = row.target, m = m, d = d }
                n = n + 1
            end
        end
    end
    return n > 0 and out or nil
end
function R.CleanRelayed(raw)
    local d = cleanDecision(raw)
    if d then
        d.done, d.tries = nil, nil
    end
    return d
end

-- State of the player's own application as far as it is known: the verified one, or a newer decision that was
-- carried on. Returns state, role, carried (true when it is not verified by the organizer).
function R.Effective(r)
    if not r then
        return 'NONE', '', false
    end
    local d = r.relayed
    if d and d.appRevision > (r.appRevision or 0) and (not r.pending or d.ackSeq >= r.pending.seq) then
        return d.state, d.role, true
    end
    return r.state, r.role, false
end
function R.EffectiveState(owner, eventID)
    return R.Effective(S.Follow(owner, eventID))
end

-- Applying and signing off while the organizer cannot be reached -------------------------------------------
function R.CanApply(owner, eventID)
    if owner == Z.me.key or not S.Enabled() or not ownerOffline(owner) then
        return false
    end
    local e = S.Get(owner, eventID)
    if not e or e.status ~= 'OPEN' or e.startsAt <= A.Now() or not ownerTargetOf(owner, eventID) then
        return false
    end
    local r = S.Follow(owner, eventID)
    local state = R.Effective(r)
    return not ACTIVE[state] and not (r and r.pending and r.pending.action == 'APPLY') and (not r or r.seq < MAX)
end
function R.Apply(owner, eventID, role)
    if not R.CanApply(owner, eventID) or not I.validRole(role) then
        return false, 'This event is not open for applications right now.'
    end
    local e = S.Get(owner, eventID)
    if e.roleSlots[role] < 1 then
        return false, 'This role has no scheduled slot.'
    end
    local r = I.ensureFollow(e)
    if not r then
        return false, 'Scheduled subscription storage is unavailable or full.'
    end
    r.seq = r.seq + 1
    r.pending = { action = 'APPLY', role = role, seq = r.seq, contentRevision = r.snapshot.contentRevision, nonce = L.NextID(Z.db, A.Now()), attempts = 0, next = 0 }
    r.updatedAt = A.Now()
    r.delivery = 'offline'
    R.probeAt[S.Token(owner, eventID)] = 0
    I.changed()
    return true
end
function R.CanWithdraw(owner, eventID)
    local r = S.Follow(owner, eventID)
    if not r or not ownerOffline(owner) or r.seq >= MAX or r.snapshot.status ~= 'OPEN' or r.snapshot.endsAt <= A.Now() or not ownerTargetOf(owner, eventID) then
        return false
    end
    local state = R.Effective(r)
    return ACTIVE[state] and not (r.pending and r.pending.action == 'WITHDRAW') or r.pending ~= nil and r.pending.action == 'APPLY'
end
function R.Withdraw(owner, eventID)
    if not R.CanWithdraw(owner, eventID) then
        return false, 'No active scheduled application to withdraw.'
    end
    local r = S.Follow(owner, eventID)
    local _, role = R.Effective(r)
    r.seq = r.seq + 1
    r.pending = { action = 'WITHDRAW', role = L.Role(role) or r.pending and r.pending.role or 'DAMAGER', seq = r.seq, contentRevision = r.snapshot.contentRevision,
        nonce = L.NextID(Z.db, A.Now()), attempts = 0, next = 0 }
    r.updatedAt = A.Now()
    r.delivery = 'offline'
    R.probeAt[S.Token(owner, eventID)] = 0
    I.changed()
    return true
end

-- Wire -----------------------------------------------------------------------------------------------------
local function statementFields(ownerTarget, eventID, memberTarget, m)
    return { 'M', ownerTarget, eventID, memberTarget, m.seq, m.action, m.role, m.content, m.nonce, m.proof or '', m.at }
end
local function decisionFields(ownerTarget, eventID, memberTarget, d)
    return { 'D', ownerTarget, eventID, memberTarget, d.state, d.role, d.appRevision, d.ackSeq, d.at }
end
local function receipt(key, ownerTarget, eventID, memberTarget, number, who)
    return send(key, { 'R', ownerTarget, eventID, memberTarget, number, who }, 70)
end
-- Own pending operation as a statement; proof is the nonce of the last operation the organizer accepted.
local function ownStatement(r)
    local p = r.pending
    return { seq = p.seq, action = p.action, role = p.role, content = p.contentRevision, nonce = p.nonce, proof = r.operationNonce or '', at = r.updatedAt }
end

local function receiveProbe(key, f)
    if #f ~= 7 or not I.id(f[6]) or not L.Int(tonumber(f[7]), 0, MAX) then
        return false
    end
    local ownerKey = keyOf(f[5])
    local r = ownerKey and S.Follow(ownerKey, f[6])
    if not r or r.state ~= 'CONFIRMED' or r.pending or r.snapshot.status ~= 'OPEN' or r.snapshot.endsAt <= A.Now() then
        return true -- not a confirmed participant of that event: no answer
    end
    send(key, { 'Y', f[5], f[6] }, 75, 'SCHEDULERELAYY:' .. key .. ':' .. f[6])
    local row = r.box and r.box[key]
    if row and row.d and row.d.appRevision > tonumber(f[7]) then
        send(key, decisionFields(f[5], f[6], Z.db.contacts[key].target, row.d), 80)
    end
    return true
end
local function receiveYes(key, f)
    if #f ~= 6 or not I.id(f[6]) then
        return false
    end
    local ownerKey = keyOf(f[5])
    local tok = ownerKey and S.Token(ownerKey, f[6])
    local r = tok and S.store.following[tok]
    if not r or not r.pending or not ownerOffline(ownerKey) then
        return true
    end
    local given = R.deposits[tok]
    if not given or given.seq ~= r.pending.seq then
        given = { seq = r.pending.seq, to = {} }
        R.deposits[tok] = given
    end
    if given.to[key] or count(given.to) >= R.MAX_DEPOSITS then
        return true
    end
    if send(key, statementFields(f[5], f[6], Z.me.target, ownStatement(r)), 90) then
        given.to[key] = true
    end
    return true
end
local function receiveStatement(key, f)
    if #f ~= 14 or not I.id(f[6]) then
        return false
    end
    local m = cleanStatement({ seq = tonumber(f[8]), action = f[9], role = f[10], content = tonumber(f[11]), nonce = f[12], proof = f[13], at = tonumber(f[14]) })
    local ownerKey, memberKey = keyOf(f[5]), keyOf(f[7])
    if not m or not ownerKey or not memberKey or memberKey == Z.me.key or Z.db.blocked[memberKey] or m.at > A.Now() + 120 then
        return false
    end
    if ownerKey == Z.me.key then
        -- The organizer: accepted from a confirmed participant only, and treated like a direct operation.
        local e = S.GetOwned(f[6])
        local carrier = e and e.participants[key]
        if memberKey == key then
            return false
        end
        if not e or not carrier or carrier.state ~= 'CONFIRMED' then
            receipt(key, f[5], f[6], f[7], m.seq, 'N') -- refused for good: the carrier stops handing it over
            return true
        end
        if not e.participants[memberKey] and m.action == 'WITHDRAW' and e.status == 'OPEN' and e.public and A.Now() < e.endsAt and m.content == e.contentRevision
            and count(e.participants) < S.MAX_PARTICIPANTS then
            -- A sign-off that arrives before the application it follows: remember it, so the older application
            -- that arrives later through another carrier changes nothing (the direct way would answer STALE).
            e.participants[memberKey] = { state = 'WITHDRAWN', role = m.role, seq = m.seq, revision = 1, lastNonce = m.nonce, lastAction = 'WITHDRAW',
                lastContentRevision = m.content, ackEventRevision = 0, ackAppRevision = 1, reason = 'OK' }
            I.changed()
        else
            I.receiveAction(memberKey, { '1', '', '', f[6], m.content, m.seq, m.action, m.role, m.nonce })
        end
        local p = e.participants[memberKey]
        if p and p.seq == m.seq and p.lastNonce == m.nonce then
            p.via, p.relayedAt, p.target = key, m.at, f[7]
        end
        receipt(key, f[5], f[6], f[7], m.seq, 'O')
        return true
    end
    -- A confirmed participant: keeps what the member itself leaves with it.
    local r = S.Follow(ownerKey, f[6])
    if not r or r.state ~= 'CONFIRMED' or memberKey ~= key or r.snapshot.status ~= 'OPEN' or r.snapshot.endsAt <= A.Now() then
        return false
    end
    r.box = r.box or {}
    local row = r.box[memberKey]
    if not row then
        if count(r.box) >= R.MAX_BOX then
            return false
        end
        row = { target = f[7] }
        r.box[memberKey] = row
    end
    if not row.m or m.seq > row.m.seq then
        row.m = m
        I.changed()
    end
    receipt(key, f[5], f[6], f[7], m.seq, 'C')
    return true
end
local function receiveDecision(key, f)
    if #f ~= 12 or not I.id(f[6]) then
        return false
    end
    local d = cleanDecision({ state = f[8], role = f[9], appRevision = tonumber(f[10]), ackSeq = tonumber(f[11]), at = tonumber(f[12]) })
    local ownerKey, memberKey = keyOf(f[5]), keyOf(f[7])
    if not d or not ownerKey or not memberKey or d.at > A.Now() + 120 then
        return false
    end
    local r = S.Follow(ownerKey, f[6])
    if not r then
        return false
    end
    if memberKey == Z.me.key then
        -- The member: a carried decision stands beside the verified state until the organizer confirms it.
        if d.ackSeq > r.seq or d.appRevision <= (r.appRevision or 0) or r.relayed and d.appRevision <= r.relayed.appRevision then
            receipt(key, f[5], f[6], f[7], d.appRevision, 'A')
            return true
        end
        local before = R.Effective(r)
        r.relayed = { state = d.state, role = d.role, appRevision = d.appRevision, ackSeq = d.ackSeq, at = d.at }
        if R.Effective(r) ~= before then
            I.notify(r.snapshot, 'SCHEDULE_STATUS', ownerKey, 'relay', d.appRevision)
        end
        I.changed()
        receipt(key, f[5], f[6], f[7], d.appRevision, 'A')
        return true
    end
    -- A confirmed participant keeps the organizer's decision for a member the organizer cannot reach.
    if key ~= ownerKey or r.state ~= 'CONFIRMED' or Z.db.blocked[memberKey] then
        return false
    end
    r.box = r.box or {}
    local row = r.box[memberKey]
    if not row then
        if count(r.box) >= R.MAX_BOX then
            return false
        end
        row = { target = f[7] }
        r.box[memberKey] = row
    end
    if not row.d or d.appRevision > row.d.appRevision then
        row.d = d
        I.changed()
    end
    receipt(key, f[5], f[6], f[7], d.appRevision, 'C')
    return true
end
local function receiveReceipt(key, f)
    if #f ~= 9 or not I.id(f[6]) or not L.Int(tonumber(f[8]), 0, MAX) then
        return false
    end
    local ownerKey, memberKey, number, who = keyOf(f[5]), keyOf(f[7]), tonumber(f[8]), f[9]
    if not ownerKey or not memberKey then
        return false
    end
    if ownerKey == Z.me.key then
        -- A participant took a decision into keeping.
        if who == 'C' then
            R.pushed[f[6] .. ':' .. memberKey .. ':' .. key] = number
        end
        return true
    end
    local r = S.Follow(ownerKey, f[6])
    if not r then
        return true
    end
    if memberKey == Z.me.key then
        -- On the pending operation itself: the direct retry keeps rewriting r.delivery while the organizer is away.
        if who == 'C' and r.pending and r.pending.seq == number and not r.pending.deposited then
            r.pending.deposited = true
            I.changed()
        end
        return true
    end
    local row = r.box and r.box[memberKey]
    if row and (who == 'O' or who == 'N') and key == ownerKey and row.m and row.m.seq <= number then
        row.m.done = true
        I.changed()
    elseif row and who == 'A' and key == memberKey and row.d and row.d.appRevision <= number then
        row.d.done = true
        I.changed()
    end
    return true
end
-- Called by ScheduledGroups.Receive for kind SX after the envelope was verified.
function R.Receive(key, route, f)
    if not S.store or not S.Enabled() or Z.db.blocked[key] then
        return false
    end
    local op = f[4]
    if op == 'P' then
        return receiveProbe(key, f)
    elseif op == 'Y' then
        return receiveYes(key, f)
    elseif op == 'M' then
        return receiveStatement(key, f)
    elseif op == 'D' then
        return receiveDecision(key, f)
    elseif op == 'R' then
        return receiveReceipt(key, f)
    end
    return false
end

-- Periodic work ----------------------------------------------------------------------------------------------
R.probeAt, R.deposits, R.pushed, R.handAt = {}, {}, {}, {}
R.probeFrom, R.tried = {}, {}
local function probe(tok, r, clock)
    local ownerTarget = ownerTargetOf(r.ownerKey, r.id)
    if not ownerTarget then
        R.probeAt[tok] = clock + R.PROBE_EVERY
        return false
    end
    local keys = {}
    for key in pairs(Z.db.contacts) do
        if key ~= r.ownerKey and key ~= Z.me.key and not Z.db.blocked[key] then
            local route = I.currentRoute(key)
            if route and route.scheduledGroups then
                keys[#keys + 1] = key
            end
        end
    end
    table.sort(keys)
    local sent, start, used = 0, #keys > 0 and (R.probeFrom[tok] or 0) % #keys or 0, 0
    for i = 0, #keys - 1 do
        if sent >= R.MAX_PROBES then
            break
        end
        local key = keys[(start + i) % #keys + 1]
        used = i + 1
        if send(key, { 'P', ownerTarget, r.id, math.max(r.appRevision or 0, r.relayed and r.relayed.appRevision or 0) }, 60, 'SCHEDULERELAYP:' .. tok .. ':' .. key) then
            sent = sent + 1
        end
    end
    R.probeFrom[tok] = start + used -- the next round starts with the contacts this one did not reach
    R.probeAt[tok] = clock + R.PROBE_EVERY
    return true
end
-- Forget bookkeeping of events that are over.
local function sweep(now, clock)
    local live, tokens = {}, {}
    for tok, r in pairs(S.store.following) do
        if r.snapshot.status == 'OPEN' and r.snapshot.endsAt > now then
            live[#live + 1], live[#live + 2], tokens[tok] = tok, r.id, true
        end
    end
    for _, e in pairs(S.store.owned) do
        if e.status == 'OPEN' and e.endsAt > now then
            live[#live + 1] = e.id
        end
    end
    local function alive(mark)
        for _, prefix in ipairs(live) do
            if mark:sub(1, #prefix + 1) == prefix .. ':' then
                return true
            end
        end
        return false
    end
    for _, t in ipairs({ R.handAt, R.pushed, R.tried }) do
        for mark in pairs(t) do
            if not alive(mark) then
                t[mark] = nil
            end
        end
    end
    for _, t in ipairs({ R.probeAt, R.deposits, R.probeFrom }) do
        for tok in pairs(t) do
            if not tokens[tok] then
                t[tok] = nil
            end
        end
    end
end
function R.Tick(now, clock)
    if clock < (R.nextTick or 0) or not S.store or not S.Enabled() then
        return
    end
    R.nextTick = clock + 5
    if clock >= (R.sweepAt or 0) then
        R.sweepAt = clock + 300
        sweep(now, clock)
    end
    local sent, probed = 0, false
    for tok, r in pairs(S.store.following) do
        local open = r.snapshot.status == 'OPEN' and r.snapshot.endsAt > now and not Z.db.blocked[r.ownerKey]
        -- Member: while the organizer is away, look for confirmed participants to leave the own operation with and
        -- to ask for a decision. One event per pass: the send limiter refills slowly.
        if not probed and open and ownerOffline(r.ownerKey) and (r.pending or ACTIVE[R.Effective(r)]) and clock >= (R.probeAt[tok] or 0) then
            if probe(tok, r, clock) then
                probed = true
                if not r.pending then
                    R.probeAt[tok] = clock + 5 * R.PROBE_EVERY -- nothing to leave, only a decision to ask for
                end
            end
        end
        -- Confirmed participant: hand statements to the organizer and decisions to their members, as long as the
        -- own verified state is confirmed and the event is open.
        if r.box then
            if r.state ~= 'CONFIRMED' or r.snapshot.status ~= 'OPEN' or now >= r.snapshot.endsAt then
                r.box = nil
                I.changed()
            elseif sent < R.MAX_HANDS then
                local ownerTarget = targetOf(r.ownerKey)
                for memberKey, row in pairs(r.box) do
                    local mark = tok .. ':' .. memberKey
                    if ownerTarget and clock >= (R.handAt[mark] or 0) and sent < R.MAX_HANDS then
                        if row.m and not row.m.done then
                            if (row.m.tries or 0) >= R.MAX_TRIES then
                                row.m.done = true
                                I.changed()
                            elseif send(r.ownerKey, statementFields(ownerTarget, r.id, row.target, row.m), 90) then
                                row.m.tries = (row.m.tries or 0) + 1
                                R.handAt[mark] = clock + 30
                                sent = sent + 1
                            end
                        end
                        if row.d and not row.d.done and sent < R.MAX_HANDS then
                            if (row.d.tries or 0) >= R.MAX_TRIES then
                                row.d.done = true
                                I.changed()
                            elseif send(memberKey, decisionFields(ownerTarget, r.id, row.target, row.d), 85) then
                                row.d.tries = (row.d.tries or 0) + 1
                                R.handAt[mark] = clock + 30
                                sent = sent + 1
                            end
                        end
                    end
                end
            end
        end
    end
    -- Organizer: leave decisions for members who cannot be reached with the confirmed participants who can.
    for _, e in pairs(S.store.owned) do
        if e.status == 'OPEN' and e.public and e.endsAt > now and sent < R.MAX_HANDS then
            for memberKey, p in pairs(e.participants) do
                local memberTarget = targetOf(memberKey) or p.target
                if memberTarget and STATES[p.state] and I.validRole(p.role) and p.revision > (p.ackAppRevision or 0) and not I.currentRoute(memberKey) then
                    for carrierKey, carrier in pairs(e.participants) do
                        local mark = e.id .. ':' .. memberKey .. ':' .. carrierKey
                        local tried = R.tried[mark]
                        if not tried or tried.revision ~= p.revision then
                            tried = { revision = p.revision, n = 0 }
                            R.tried[mark] = tried
                        end
                        if carrierKey ~= memberKey and carrier.state == 'CONFIRMED' and (R.pushed[mark] or 0) < p.revision and tried.n < R.MAX_TRIES
                            and clock >= (R.handAt[mark] or 0) and sent < R.MAX_HANDS then
                            local d = { state = p.state, role = p.role, appRevision = p.revision, ackSeq = p.seq or 0, at = now }
                            if send(carrierKey, decisionFields(Z.me.target, e.id, memberTarget, d), 85) then
                                tried.n = tried.n + 1
                                R.handAt[mark] = clock + 60
                                sent = sent + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

return R
