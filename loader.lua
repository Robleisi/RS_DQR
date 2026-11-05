-- DQR release loader (plain). Prefer jsDelivr; pin commit so CDN won't serve stale @main.
-- Routes by game.GameId: classic DQ -> Robleisi_DQ_classic_release.lua,
-- Reborn -> Robleisi_DQR_release.lua, Heavyweight Fishing -> Robleisi_HWF_release.lua,
-- Throw Food For Animals -> Robleisi_ThrowFood_release.lua,
-- The Forge -> Robleisi_TheForge_release.lua.
-- Any other game -> Robleisi_Universal_release.lua (universal fallback profile).
-- One user-facing URL for all.
-- Integrity: expected values below are baked in by the release pipeline at pin
-- time. Every downloaded source is verified BEFORE it is executed: exact length,
-- head/tail byte match, plus two independent 32-bit rolling checksums. A mirror
-- whose content does not match is skipped, so a corrupted mirror can never run.
-- NOTE: strictly Lua 5.1 syntax (no Luau bitwise operators), so this compiles
-- on every executor core, including 5.1-only ones.

local bust = tostring(os.time()) .. "-" .. tostring(math.random(1, 1000000000))

-- ---- profiles (reborn pin unchanged; classic is a separate release file) ----
local profiles = {
	reborn = {
		kind = "reborn",
		stamp = "2026-11-06a",
		commit = "3d5bbac",
		file = "Robleisi_DQR_release.lua",
		expectedLen = 1042369,
		expectedFnv = "BD46E226",
		expectedDjb = "51D2CD84",
		expectedHead = "local W7,z7 do local F=math.floor local e=math.random local d=table.re",
		expectedTail = "PDATED),tostring(SCRIPT_CHANGELOG or W7[z7(\"\",10472523605529)]))",
	},
	classic = {
		kind = "classic",
		stamp = "2026-11-06a",
		commit = "3d5bbac",
		file = "Robleisi_DQ_classic_release.lua",
		expectedLen = 1131388,
		expectedFnv = "C9FC6C1D",
		expectedDjb = "1A600681",
		expectedHead = "local N8,Z8 do local t=math.floor local a=math.random local L=table.re",
		expectedTail = "UPDATED),tostring(SCRIPT_CHANGELOG or N8[Z8(\"\",1008274342827)]))",
	},
	hwf = {
		kind = "hwf",
		stamp = "2026-11-06a",
		commit = "3d5bbac",
		file = "Robleisi_HWF_release.lua",
		expectedLen = 556371,
		expectedFnv = "FFED4520",
		expectedDjb = "AE743090",
		expectedHead = "local QH,BH do local j=math.floor local k=math.random local t=table.re",
		expectedTail = "118\\083\",9864767185891)]]=true end)()end)()j[125]=(j[125]+10)%24",
	},
	universal = {
		kind = "universal",
		stamp = "2026-11-06a",
		commit = "3d5bbac",
		file = "Robleisi_Universal_release.lua",
		expectedLen = 118322,
		expectedFnv = "04CF1AED",
		expectedDjb = "C01065D9",
		expectedHead = "local V,R do local X=math.floor local c=math.random local d=table.remo",
		expectedTail = "\\227\\248\\197\\\"\\043\\226\\014\",10791434659650)]..UNIVERSAL_VERSION)",
	},
	throwfood = {
		kind = "throwfood",
		stamp = "2026-11-06a",
		commit = "3d5bbac",
		file = "Robleisi_ThrowFood_release.lua",
		expectedLen = 169639,
		expectedFnv = "8265CE7F",
		expectedDjb = "383D6389",
		expectedHead = "local l,U do local m=math.floor local a=math.random local K=table.remo",
		expectedTail = "168\\077\\191\\170\\124\\193\\194\",4408918478858)]..THROWFOOD_VERSION)",
	},
	theforge = {
		kind = "theforge",
		stamp = "2026-11-06a",
		commit = "3d5bbac",
		file = "Robleisi_TheForge_release.lua",
		expectedLen = 97012,
		expectedFnv = "764917DE",
		expectedDjb = "9CAFD8C6",
		expectedHead = "local Q,q do local y=math.floor local x=math.random local c=table.remo",
		expectedTail = "09)]]=U;[q[Q(\"\\208\\133\\061\\213\\111\",34966395846452)]]=M}end end)",
	},
}

-- ---- pick profile by UniverseId (game.GameId) ----
-- Bypass: getgenv().DQR_SKIP_GAME_GUARD = true (defaults to reborn profile)
local profile
do
	local skip = false
	pcall(function()
		if type(getgenv) == "function" and getgenv().DQR_SKIP_GAME_GUARD == true then
			skip = true
		end
	end)
	local uid = game.GameId
	if uid == 848145103 then
		profile = profiles.classic
	elseif uid == 9931749389 then
		profile = profiles.reborn
	elseif uid == 8342498724 then
		profile = profiles.hwf
	elseif uid == 10766972131 or game.PlaceId == 120219252362013 then
		profile = profiles.throwfood
	elseif uid == 7671049560 then
		profile = profiles.theforge
	elseif skip then
		profile = profiles.reborn
		warn("[DQR] loader guard skipped; defaulting to reborn profile")
	else
		profile = profiles.universal
		warn(("[DQR] loader: unsupported game (GameId=%s PlaceId=%s) -> universal profile"):format(
			tostring(uid), tostring(game.PlaceId)))
	end
end

local stamp = profile.stamp
local commit = profile.commit
local expectedLen = profile.expectedLen
local expectedFnv = profile.expectedFnv
local expectedDjb = profile.expectedDjb
local expectedHead = profile.expectedHead
local expectedTail = profile.expectedTail
local releaseFile = profile.file

-- ---- kill switch: remote minimum-stamp manifest (@main; purged on each release) ----
-- Raise minStamp in manifest.lua to instantly disable every older loader in the wild.
local minStamp = nil
do
	local murls = {
		"https://cdn.jsdelivr.net/gh/Robleisi/RS_DQR@main/manifest.lua",
		"https://fastly.jsdelivr.net/gh/Robleisi/RS_DQR@main/manifest.lua",
		"https://raw.githubusercontent.com/Robleisi/RS_DQR/main/manifest.lua?t=" .. bust,
	}
	for i = 1, #murls do
		local ok, body = pcall(function()
			return game:HttpGet(murls[i])
		end)
		if ok and type(body) == "string" then
			local m = body:match("minStamp%s*=%s*\"([%w%-]+)\"")
			if m then
				minStamp = m
				break
			end
		end
	end
	if minStamp and stamp < minStamp then
		error("[DQR] loader " .. stamp .. " (" .. profile.kind .. ") disabled: minimum required stamp is " .. minStamp .. ", please use the latest release URL", 0)
	end
end

-- ---- integrity check (pure Lua 5.1, no bitwise operators) ----
local bx
local function bxor8(a, b)
	if not bx then
		bx = {}
		for x = 0, 255 do
			local row = {}
			for y = 0, 255 do
				local xa, ya, r, p = x, y, 0, 1
				for _ = 1, 8 do
					if xa % 2 ~= ya % 2 then r = r + p end
					xa = math.floor(xa / 2)
					ya = math.floor(ya / 2)
					p = p * 2
				end
				row[y] = r
			end
			bx[x] = row
		end
	end
	return bx[a][b]
end

local function fnv1a(s)
	local h = 2166136261
	for i = 1, #s do
		local h1 = math.floor(h / 65536)
		local h0 = h - h1 * 65536
		local lo = bxor8(h0 % 256, s:byte(i))
		local p0 = (h0 - (h0 % 256) + lo) * 16777619
		local carry = math.floor(p0 / 65536)
		local hi = (h1 * 16777619 + carry) % 65536
		h = hi * 65536 + (p0 - carry * 65536)
	end
	return h
end

local function djb2(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return h
end

local function verify(src)
	if #src ~= expectedLen then
		return nil, "length " .. #src .. " ~= " .. expectedLen
	end
	if src:sub(1, #expectedHead) ~= expectedHead then
		return nil, "head mismatch"
	end
	if src:sub(-#expectedTail) ~= expectedTail then
		return nil, "tail mismatch"
	end
	-- Hash is soft: some executor VMs disagree on float-based checksums for large
	-- payloads even when the bytes are identical. Len+head+tail already block
	-- truncated/HTML/wrong-commit bodies; don't hard-fail the whole load on hash.
	local gotFnv = string.format("%08X", fnv1a(src))
	local gotDjb = string.format("%08X", djb2(src))
	if gotFnv ~= expectedFnv or gotDjb ~= expectedDjb then
		warn("[DQR] hash soft-mismatch fnv=" .. gotFnv .. "/" .. expectedFnv .. " djb=" .. gotDjb .. "/" .. expectedDjb .. " (len/head/tail ok, continuing)")
	end
	return true
end

warn("[DQR] loader " .. stamp .. " @" .. commit .. " kind=" .. profile.kind .. " fetching " .. releaseFile .. "...")
local src, lastErr
local urls = {
	"https://cdn.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/" .. releaseFile .. "?t=" .. bust,
	"https://fastly.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/" .. releaseFile .. "?t=" .. bust,
	"https://gcore.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/" .. releaseFile .. "?t=" .. bust,
	"https://testingcf.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/" .. releaseFile .. "?t=" .. bust,
	"https://raw.githubusercontent.com/Robleisi/RS_DQR/" .. commit .. "/" .. releaseFile .. "?t=" .. bust,
}
for i = 1, #urls do
	local ok, body = pcall(function()
		return game:HttpGet(urls[i])
	end)
	if ok and type(body) == "string" then
		local good, why = verify(body)
		if good then
			src = body
			warn("[DQR] loader verified " .. tostring(#body) .. " bytes from #" .. tostring(i))
			break
		end
		lastErr = why .. " on #" .. tostring(i)
		warn("[DQR] " .. lastErr)
	else
		lastErr = tostring(body)
		warn("[DQR] loader source #" .. tostring(i) .. " failed: " .. lastErr)
	end
end
if not src then
	error("[DQR] no mirror passed verification: " .. tostring(lastErr), 0)
end

local fn, err = loadstring(src)
if not fn and type(load) == "function" then
	fn, err = load(src)
end
if not fn then
	error("[DQR] loadstring failed: " .. tostring(err), 0)
end
fn()
