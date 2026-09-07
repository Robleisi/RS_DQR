-- DQR release loader (plain). Prefer jsDelivr; pin commit so CDN won't serve stale @main.
-- Current release stamp: 2026-09-07h
-- Integrity: expectedHash is the SHA-256 of this exact release, baked in by the
-- release pipeline at pin time. Every downloaded source is verified BEFORE it is
-- executed; a mirror whose content does not match is skipped, so a corrupted or
-- tampered mirror can never run. All mirrors failing = loud error, no blind run.
local stamp = "2026-09-07h"
local commit = "74e87da"
local expectedHash = "ce6e6930c668f6dd14bed85b127337d2543bd4e155c2302a1629c365bd24566a"
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

local urls = {
	"https://cdn.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://fastly.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://gcore.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://testingcf.jsdelivr.net/gh/Robleisi/RS_DQR@" .. commit .. "/Robleisi_DQR_release.lua",
	"https://raw.githubusercontent.com/Robleisi/RS_DQR/" .. commit .. "/Robleisi_DQR_release.lua?t=" .. bust,
}

-- ---- SHA-256 (pure Lua; no executor crypto dependency; validated vs FIPS vectors) ----
local function sha256hex(msg)
	local K = {
		0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
		0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
		0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
		0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
		0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
		0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
		0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
		0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
	}
	local H = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
	local len = #msg
	local data = msg .. "\128" .. string.rep("\0", (55 - len % 64) % 64)
	local bitLen = len * 8
	data = data .. string.char(0, 0, 0, 0,
		(bitLen >> 24) & 255, (bitLen >> 16) & 255, (bitLen >> 8) & 255, bitLen & 255)
	local M = 0xffffffff
	local function ror(x, n)
		return ((x >> n) | (x << (32 - n))) & M
	end
	local w = {}
	for block = 1, #data, 64 do
		for i = 0, 15 do
			local b1, b2, b3, b4 = string.byte(data, block + i * 4, block + i * 4 + 3)
			w[i + 1] = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
		end
		for i = 17, 64 do
			local x = w[i - 15]
			local s0 = ((ror(x, 7) ~ ror(x, 18) ~ (x >> 3))) & M
			local y = w[i - 2]
			local s1 = ((ror(y, 17) ~ ror(y, 19) ~ (y >> 10))) & M
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & M
		end
		local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
		for i = 1, 64 do
			local S1 = ((ror(e, 6) ~ ror(e, 11) ~ ror(e, 25))) & M
			local ch = ((e & f) ~ ((~e) & g)) & M
			local t1 = (h + S1 + ch + K[i] + w[i]) & M
			local S0 = ((ror(a, 2) ~ ror(a, 13) ~ ror(a, 22))) & M
			local maj = ((a & b) ~ (a & c) ~ (b & c)) & M
			local t2 = (S0 + maj) & M
			h = g
			g = f
			f = e
			e = (d + t1) & M
			d = c
			c = b
			b = a
			a = (t1 + t2) & M
		end
		H[1] = (H[1] + a) & M
		H[2] = (H[2] + b) & M
		H[3] = (H[3] + c) & M
		H[4] = (H[4] + d) & M
		H[5] = (H[5] + e) & M
		H[6] = (H[6] + f) & M
		H[7] = (H[7] + g) & M
		H[8] = (H[8] + h) & M
	end
	local out = {}
	for i = 1, 8 do
		out[i] = string.format("%08x", H[i])
	end
	return table.concat(out)
end

warn("[DQR] loader " .. stamp .. " @" .. commit .. " fetching release...")
local src, lastErr
for i = 1, #urls do
	local ok, body = pcall(function()
		return game:HttpGet(urls[i])
	end)
	if ok and type(body) == "string" and #body > 10000 then
		local hash = sha256hex(body)
		if hash == expectedHash then
			src = body
			warn("[DQR] loader verified " .. tostring(#body) .. " bytes from #" .. tostring(i))
			break
		end
		lastErr = "sha256 mismatch on #" .. tostring(i) .. " (got " .. hash .. ")"
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
