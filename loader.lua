-- DQR release loader (plain). Prefer jsDelivr; pin commit so CDN won't serve stale @main.
-- Current release stamp: 2026-09-10c
-- Integrity: expected values below are baked in by the release pipeline at pin
-- time. Every downloaded source is verified BEFORE it is executed: exact length,
-- head/tail byte match, plus two independent 32-bit rolling checksums. A mirror
-- whose content does not match is skipped, so a corrupted mirror can never run.
-- NOTE: strictly Lua 5.1 syntax (no Luau bitwise operators), so this compiles
-- on every executor core, including 5.1-only ones.
local stamp = "2026-09-10c"
local commit = "70475b9"
local expectedLen = 1515818
local expectedFnv = "1D0ABD73"
local expectedDjb = "701DA857"
local expectedHead = "return(function(...)local Pu={\"\\089\\106\\118\\068\",\"\\097\\119\\090\\"
local expectedTail = "u[Zu(xu(-642157-(-583218)),27993302773211-(-866299))]))end)(...)"
local bust = tostring(os.time()) .. "-" .. tostring(math.random(1, 1000000000))

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
		error("[DQR] loader " .. stamp .. " disabled: minimum required stamp is " .. minStamp .. ", please use the latest release URL", 0)
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
	if string.format("%08X", fnv1a(src)) ~= expectedFnv then
		return nil, "fnv mismatch"
	end
	if string.format("%08X", djb2(src)) ~= expectedDjb then
		return nil, "djb mismatch"
	end
	return true
end

warn("[DQR] loader " .. stamp .. " @" .. commit .. " fetching release...")
local src, lastErr
local urls = {
	"https://cdn.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://fastly.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://gcore.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://testingcf.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://raw.githubusercontent.com/Robleisi/RS_DQR/" .. commit .. "/Robleisi_DQR_release.lua?t=" .. bust,
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
if not fn then
	error("[DQR] loadstring failed: " .. tostring(err), 0)
end
fn()
