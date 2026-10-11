local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local cfg = {
	on = true,
	mode = "3D Box",
	thick = 2,
	names = true,
	levels = true,
	textSize = 14,
	rescan = 30,
	maxDist = 0,

	packOn = true,
	packHealth = true,
	packAmmo = true,
	packNames = true,
	packDist = 0,
	packHealthColor = "Green",
	packAmmoColor = "Yellow",
	packRescan = 0.25,
}

local colors = {
	Red = Color3.fromRGB(255, 50, 50),
	Green = Color3.fromRGB(70, 255, 120),
	Blue = Color3.fromRGB(70, 140, 255),
	Cyan = Color3.fromRGB(60, 235, 235),
	Yellow = Color3.fromRGB(255, 220, 60),
	Purple = Color3.fromRGB(170, 100, 255),
	Orange = Color3.fromRGB(255, 150, 50),
	White = Color3.fromRGB(255, 255, 255),
}
local colorList = {"Red", "Green", "Blue", "Cyan", "Yellow", "Purple", "Orange", "White"}

local mouseY = 0

local defs = {
	{ name = "Sentry", label = "Sentry", color = "Red", x = 4, y = 4, z = 4 },
	{ name = "Dispenser", label = "Dispenser", color = "Green", x = 3, y = 4.5, z = 2 },
	{ name = "Teleporter Entrance", label = "Tele Entrance", color = "Blue", x = 4, y = 1, z = 4 },
	{ name = "Teleporter Exit", label = "Tele Exit", color = "Yellow", x = 4, y = 1, z = 4 },
}

local EDGES = {
	{0,1},{2,3},{4,5},{6,7},
	{0,2},{1,3},{4,6},{5,7},
	{0,4},{1,5},{2,6},{3,7},
}
local TOP = {2, 3, 6, 7}

local blds = {}
for i, b in ipairs(defs) do
	b.on = true
	b.frame = 0
	b.skew = (i - 1) * 7
	b.lines = {}
	for n = 1, 12 do
		local l = Drawing.new("Line")
		l.Thickness = cfg.thick
		l.Transparency = 1
		l.Color = colors[b.color]
		l.Visible = false
		b.lines[n] = l
	end
	local t = Drawing.new("Text")
	t.Text = ""
	t.Color = Color3.fromRGB(255, 255, 255)
	t.Size = cfg.textSize
	t.Outline = true
	t.Center = true
	t.Transparency = 1
	t.Visible = false
	pcall(function() t.Font = Drawing.Fonts.System end)
	b.text = t
	blds[i] = b
end

local cx, cy, cz
local m00, m01, m02, m10, m11, m12, m20, m21, m22
local hw, hh, focal = 0, 0, 0
local lastFov, tf = -1, 1

local function camUpdate()
	cam = workspace.CurrentCamera
	if not cam then return false end
	local vp, fov = cam.ViewportSize, cam.FieldOfView
	hw, hh = vp.X * .5, vp.Y * .5
	if fov ~= lastFov then
		lastFov = fov
		tf = math.tan(math.rad(fov) * .5)
	end
	focal = hh / tf
	cx, cy, cz, m00, m01, m02, m10, m11, m12, m20, m21, m22 = cam.CFrame:GetComponents()
	return true
end

local function project(x, y, z)
	local dx, dy, dz = x - cx, y - cy, z - cz
	local depth = -(m02 * dx + m12 * dy + m22 * dz)
	if depth < .01 then return end
	local s = focal / depth
	return hw + (m00 * dx + m10 * dy + m20 * dz) * s, hh - (m01 * dx + m11 * dy + m21 * dz) * s
end

local visState = setmetatable({}, {__mode = "k"})
local function setVisible(o, v)
	if visState[o] ~= v then
		visState[o] = v
		o.Visible = v
	end
end

local function hide(b)
	for _, l in ipairs(b.lines) do setVisible(l, false) end
	setVisible(b.text, false)
end

local function scan(b, model)
	local x0, y0, z0 = math.huge, math.huge, math.huge
	local x1, y1, z1 = -math.huge, -math.huge, -math.huge
	local any = false
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local p, s = d.Position, d.Size
			if p and s then
				any = true
				local hx, hy, hz = s.X * .5, s.Y * .5, s.Z * .5
				x0 = math.min(x0, p.X - hx)
				y0 = math.min(y0, p.Y - hy)
				z0 = math.min(z0, p.Z - hz)
				x1 = math.max(x1, p.X + hx)
				y1 = math.max(y1, p.Y + hy)
				z1 = math.max(z1, p.Z + hz)
			end
		end
	end
	if any then
		b.cx, b.cy, b.cz = (x0 + x1) * .5, (y0 + y1) * .5, (z0 + z1) * .5
	else
		b.cx = nil
	end
end

local px, py, ok = {}, {}, {}

local segState = setmetatable({}, {__mode = "k"})
local function seg(l, x0, y0, x1, y1)
	local s = segState[l]
	if not s then
		s = {nil, nil, nil, nil}
		segState[l] = s
	end
	if s[1] ~= x0 or s[2] ~= y0 then
		s[1], s[2] = x0, y0
		l.From = Vector2.new(x0, y0)
	end
	if s[3] ~= x1 or s[4] ~= y1 then
		s[3], s[4] = x1, y1
		l.To = Vector2.new(x1, y1)
	end
	setVisible(l, true)
end

local function draw(b)
	if not b.on then return hide(b) end

	if b.col ~= b.color or b.th ~= cfg.thick then
		b.col, b.th = b.color, cfg.thick
		for _, l in ipairs(b.lines) do
			l.Color = colors[b.color]
			l.Thickness = cfg.thick
		end
	end
	if b.ts ~= cfg.textSize then
		b.ts = cfg.textSize
		b.text.Size = cfg.textSize
	end

	local m = b.model
	if not (m and m.Parent) then
		m = workspace:FindFirstChild(lp.Name .. "'s " .. b.name)
	end
	if not m then
		b.model, b.cx = nil, nil
		return hide(b)
	end

	b.frame += 1
	if m ~= b.model or b.frame >= cfg.rescan or not b.cx then
		if m ~= b.model then b.lvl = nil end
		b.model = m
		b.frame = -b.skew
		scan(b, m)
	end
	if not b.cx then return hide(b) end

	if cfg.maxDist > 0 then
		local dx, dy, dz = b.cx - cx, b.cy - cy, b.cz - cz
		if dx * dx + dy * dy + dz * dz > cfg.maxDist * cfg.maxDist then
			return hide(b)
		end
	end

	local hx, hy, hz = b.x * .5, b.y * .5, b.z * .5
	local x0, y0, z0 = b.cx - hx, b.cy - hy, b.cz - hz
	local x1, y1, z1 = b.cx + hx, b.cy + hy, b.cz + hz

	for i = 0, 7 do
		local sx, sy = project(
			i % 2 == 0 and x0 or x1,
			math.floor(i / 2) % 2 == 0 and y0 or y1,
			i < 4 and z0 or z1)
		ok[i] = sx ~= nil
		if sx then
			px[i], py[i] = sx, sy
		end
	end

	local ax, ay
	local lines = b.lines

	if cfg.mode == "2D Box" then
		local l, t, r, d = math.huge, math.huge, -math.huge, -math.huge
		for i = 0, 7 do
			if not ok[i] then return hide(b) end
			l = math.min(l, px[i])
			r = math.max(r, px[i])
			t = math.min(t, py[i])
			d = math.max(d, py[i])
		end
		seg(lines[1], l, t, r, t)
		seg(lines[2], r, t, r, d)
		seg(lines[3], r, d, l, d)
		seg(lines[4], l, d, l, t)
		for i = 5, 12 do setVisible(lines[i], false) end
		ax, ay = (l + r) * .5, t
	else
		local n = 0
		for _, e in ipairs(EDGES) do
			local a, c = e[1], e[2]
			if ok[a] and ok[c] then
				n += 1
				seg(lines[n], px[a], py[a], px[c], py[c])
			end
		end
		for i = n + 1, 12 do setVisible(lines[i], false) end

		local sx, sy, k = 0, 0, 0
		for _, t in ipairs(TOP) do
			if ok[t] then
				sx += px[t]
				sy += py[t]
				k += 1
			end
		end
		if k > 0 then ax, ay = sx / k, sy / k end
	end

	local txt = cfg.names and b.label or ""
	local lv
	if cfg.levels then
		lv = b.lvl
		if not (lv and lv.Parent) then
			lv = m:FindFirstChild("Level")
			b.lvl = lv
		end
	end
	if lv then
		txt = txt .. (txt ~= "" and " " or "") .. "Lvl: " .. tostring(lv.Value)
	end

	if ax and txt ~= "" then
		if b.text.Text ~= txt then b.text.Text = txt end
		b.text.Position = Vector2.new(ax, ay - cfg.textSize - 6)
		setVisible(b.text, true)
	else
		setVisible(b.text, false)
	end
end

local PACK_POOL = 64
local packKinds = {
	MediumHP = { kind = "health", label = "Medium HP" },
	SmallHP = { kind = "health", label = "Small HP" },
	SmallAmmo = { kind = "ammo", label = "Small Ammo" },
	MediumAmmo = { kind = "ammo", label = "Medium Ammo" },
	LargeAmmo = { kind = "ammo", label = "Large Ammo" },
}

local packPool = {}
for i = 1, PACK_POOL do
	local box = Drawing.new("Square")
	box.Thickness = 1
	box.Filled = false
	box.Transparency = 1
	box.Visible = false
	local tag = Drawing.new("Text")
	tag.Size = 13
	tag.Center = true
	tag.Outline = true
	tag.Transparency = 1
	tag.Visible = false
	pcall(function() tag.Font = Drawing.Fonts.System end)
	packPool[i] = { box = box, tag = tag }
end

local packRunning = true
local packCache = {}
local packConns = {}
local hookedItems

local function getItems()
	local good, items = pcall(function() return workspace.Map.Items end)
	if good and items then return items end
end

local function scanPacks()
	local items = getItems()
	if not items then
		packCache = {}
		return
	end
	local list = {}
	local good, kids = pcall(function() return items:GetChildren() end)
	if good and kids then
		for _, part in ipairs(kids) do
			local info = packKinds[part.Name]
			if info and part:IsA("MeshPart") then
				list[#list + 1] = { part = part, info = info }
			end
		end
	end
	packCache = list
end

local function hookItems()
	local items = getItems()
	if items and items ~= hookedItems then
		hookedItems = items
		pcall(function()
			packConns[#packConns + 1] = items.ChildAdded:Connect(scanPacks)
			packConns[#packConns + 1] = items.ChildRemoved:Connect(scanPacks)
		end)
		scanPacks()
	end
end

task.spawn(function()
	while packRunning do
		if cfg.packOn then
			hookItems()
			scanPacks()
		end
		task.wait(math.max(cfg.packRescan, 0.05))
	end
end)

local function hidePacks(from)
	for i = from or 1, PACK_POOL do
		local e = packPool[i]
		setVisible(e.box, false)
		setVisible(e.tag, false)
	end
end

local function drawPacks()
	if not cfg.packOn then return hidePacks() end

	local n = 0
	local maxD2 = cfg.packDist * cfg.packDist

	for i = 1, #packCache do
		if n >= PACK_POOL then break end
		local c = packCache[i]
		local part, info = c.part, c.info

		if part.Parent and part.Transparency < 1
			and ((info.kind == "health" and cfg.packHealth) or (info.kind == "ammo" and cfg.packAmmo)) then
			local pos, size = part.Position, part.Size
			local visible = true

			if cfg.packDist > 0 then
				local dx, dy, dz = pos.X - cx, pos.Y - cy, pos.Z - cz
				if dx * dx + dy * dy + dz * dz > maxD2 then visible = false end
			end

			if visible then
				local halfY = size.Y * .5
				local tx, ty = project(pos.X, pos.Y + halfY, pos.Z)
				local bx, by = project(pos.X, pos.Y - halfY, pos.Z)

				if tx and bx then
					n += 1
					local e = packPool[n]
					local h = by - ty
					local w = math.max(h * .5, 4)

					local cname = info.kind == "health" and cfg.packHealthColor or cfg.packAmmoColor
					if e.cname ~= cname then
						e.cname = cname
						e.box.Color = colors[cname]
						e.tag.Color = colors[cname]
					end

					e.box.Position = Vector2.new(tx - w * .5, ty)
					e.box.Size = Vector2.new(w, math.max(h, 4))
					setVisible(e.box, true)

					if cfg.packNames then
						if e.label ~= info.label then
							e.label = info.label
							e.tag.Text = info.label
						end
						e.tag.Position = Vector2.new(tx, ty - 17)
						setVisible(e.tag, true)
					else
						setVisible(e.tag, false)
					end
				end
			end
		end
	end

	hidePacks(n + 1)
end

local espConn = RunService.RenderStepped:Connect(function()
	if not camUpdate() then
		for _, b in ipairs(blds) do hide(b) end
		hidePacks()
		return
	end
	if cfg.on then
		for _, b in ipairs(blds) do draw(b) end
	else
		for _, b in ipairs(blds) do hide(b) end
	end
	drawPacks()
end)

local bind = { kc = Enum.KeyCode.Insert, vk = 0x2D, name = "Insert" }
local listening = false
local prevKey = false
local dirty = true

local inputConn
pcall(function()
	inputConn = UIS.InputBegan:Connect(function(i)
		if listening and i.UserInputType == Enum.UserInputType.Keyboard then
			bind = { kc = i.KeyCode, name = i.KeyCode.Name }
			dirty = true
			listening = false
			prevKey = true
		end
	end)
end)

local function keyDown()
	if bind.kc then
		local good, r = pcall(function() return UIS:IsKeyDown(bind.kc) end)
		if good and r then return true end
	end
	if bind.vk and iskeypressed then
		local good, r = pcall(iskeypressed, bind.vk)
		return good and r or false
	end
	return false
end

local function mouse()
	local good, p = pcall(function() return UIS:GetMouseLocation() end)
	if good and p and type(p.X) == "number" and type(p.Y) == "number" then
		return p.X, p.Y + mouseY
	end
	local good2, m = pcall(function() return lp:GetMouse() end)
	if good2 and m and type(m.X) == "number" and type(m.Y) == "number" then
		return m.X, m.Y + mouseY
	end
	return nil, nil
end

local function mouseDown()
	local good, r = pcall(function()
		return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	end)
	if good and r then return true end
	local f = ismouse1pressed or isleftpressed
	if f then
		local good2, r2 = pcall(f)
		return good2 and r2 or false
	end
	return false
end

local function hit(mx, my, x, y, w, h)
	if type(mx) ~= "number" or type(my) ~= "number"
		or type(x) ~= "number" or type(y) ~= "number"
		or type(w) ~= "number" or type(h) ~= "number" then
		return false
	end
	return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function clamp(v, lo, hi)
	return v < lo and lo or (v > hi and hi or v)
end

local th = {
	bg = Color3.fromRGB(16, 16, 20),
	panel = Color3.fromRGB(24, 24, 30),
	pill = Color3.fromRGB(36, 36, 46),
	line = Color3.fromRGB(46, 46, 58),
	accent = Color3.fromRGB(138, 99, 255),
	text = Color3.fromRGB(232, 232, 238),
	dim = Color3.fromRGB(130, 130, 145),
	off = Color3.fromRGB(54, 54, 66),
	white = Color3.fromRGB(255, 255, 255),
}

local win = { x = 60, y = 120, w = 320, h = 0, open = true, tab = 1 }
local headH, tabH, pad, footH = 38, 30, 14, 24

local drawn = {}
local function mk(class, props, z)
	local d = Drawing.new(class)
	props.Transparency = 1
	props.Visible = false
	props.ZIndex = 1000 + (z or 0)
	for k, v in pairs(props) do
		pcall(function() d[k] = v end)
	end
	drawn[#drawn + 1] = d
	return d
end

local bg = mk("Square", {Filled = true, Color = th.bg}, 0)
local head = mk("Square", {Filled = true, Color = th.panel}, 1)
local bar = mk("Square", {Filled = true, Color = th.accent}, 2)
local title = mk("Text", {Text = "TC2 ESP", Size = 14, Color = th.text, Outline = false}, 3)
local sep = mk("Square", {Filled = true, Color = th.line}, 2)
local footer = mk("Text", {Text = "", Size = 11, Color = th.dim, Outline = false}, 3)
local frame = mk("Square", {Filled = false, Color = th.line, Thickness = 1}, 5)

local tabs = {}

local function Tab(name)
	local t = {
		widgets = {},
		txt = mk("Text", {Text = name, Size = 13, Color = th.dim, Outline = false, Center = true}, 3),
		under = mk("Square", {Filled = true, Color = th.accent}, 3),
	}
	tabs[#tabs + 1] = t
	return t
end

local function add(tab, w)
	tab.widgets[#tab.widgets + 1] = w
end

local function Header(tab, text)
	local t = mk("Text", {Text = string.upper(text), Size = 11, Color = th.accent, Outline = false}, 3)
	add(tab, {
		h = 26,
		objs = {t},
		layout = function(x, y)
			t.Position = Vector2.new(x, y + 8)
		end,
	})
end

local function Toggle(tab, text, t, k)
	local lbl = mk("Text", {Text = text, Size = 13, Color = th.text, Outline = false}, 3)
	local track = mk("Square", {Filled = true, Size = Vector2.new(30, 14), Color = th.off}, 3)
	local knob = mk("Square", {Filled = true, Size = Vector2.new(10, 10), Color = th.white}, 4)
	add(tab, {
		h = 30,
		objs = {lbl, track, knob},
		layout = function(x, y, w)
			local v = t[k]
			lbl.Position = Vector2.new(x, y + 8)
			track.Position = Vector2.new(x + w - 30, y + 8)
			track.Color = v and th.accent or th.off
			knob.Position = Vector2.new(x + w - 30 + (v and 18 or 2), y + 10)
		end,
		click = function() t[k] = not t[k] end,
	})
end

local function Slider(tab, text, t, k, lo, hi, step, suffix)
	local lbl = mk("Text", {Text = text, Size = 13, Color = th.text, Outline = false}, 3)
	local val = mk("Text", {Text = "", Size = 13, Color = th.dim, Outline = false, Center = true}, 3)
	local track = mk("Square", {Filled = true, Size = Vector2.new(10, 4), Color = th.off}, 3)
	local fill = mk("Square", {Filled = true, Size = Vector2.new(10, 4), Color = th.accent}, 4)
	local knob = mk("Square", {Filled = true, Size = Vector2.new(8, 12), Color = th.white}, 5)
	local w = { h = 44, objs = {lbl, val, track, fill, knob} }
	function w.layout(x, y, ww)
		local f = clamp((t[k] - lo) / (hi - lo), 0, 1)
		lbl.Position = Vector2.new(x, y + 6)
		val.Text = string.format("%g", t[k]) .. (suffix or "")
		val.Position = Vector2.new(x + ww - 22, y + 6)
		track.Position = Vector2.new(x, y + 29)
		track.Size = Vector2.new(ww, 4)
		fill.Position = Vector2.new(x, y + 29)
		fill.Size = Vector2.new(math.max(1, ww * f), 4)
		knob.Position = Vector2.new(x + ww * f - 4, y + 25)
	end
	function w.drag(mx)
		if not w.x or not w.w then return end
		local v = lo + clamp((mx - w.x) / w.w, 0, 1) * (hi - lo)
		t[k] = clamp(math.floor(v / step + .5) * step, lo, hi)
	end
	add(tab, w)
end

local function pill(tab, text, getText, onClick)
	local lbl = mk("Text", {Text = text, Size = 13, Color = th.text, Outline = false}, 3)
	local bgp = mk("Square", {Filled = true, Size = Vector2.new(92, 20), Color = th.pill}, 3)
	local val = mk("Text", {Text = "", Size = 12, Color = th.text, Outline = false, Center = true}, 4)
	add(tab, {
		h = 30,
		objs = {lbl, bgp, val},
		layout = function(x, y, w)
			lbl.Position = Vector2.new(x, y + 8)
			bgp.Position = Vector2.new(x + w - 92, y + 5)
			val.Text = getText()
			val.Position = Vector2.new(x + w - 46, y + 8)
		end,
		click = onClick,
	})
end

local function Choice(tab, text, t, k, opts)
	pill(tab, text, function() return tostring(t[k]) end, function()
		local at = 1
		for i, o in ipairs(opts) do
			if o == t[k] then at = i end
		end
		t[k] = opts[at % #opts + 1]
	end)
end

local function Bind(tab, text)
	pill(tab, text, function()
		return listening and "press a key" or bind.name
	end, function()
		listening = not listening
	end)
end

local function layout()
	local x, y, w = win.x, win.y, win.w
	local cur = tabs[win.tab]

	local ch = 0
	for _, wd in ipairs(cur.widgets) do ch += wd.h end
	win.h = headH + tabH + pad + ch + footH

	bg.Position = Vector2.new(x, y)
	bg.Size = Vector2.new(w, win.h)
	frame.Position = Vector2.new(x, y)
	frame.Size = Vector2.new(w, win.h)
	head.Position = Vector2.new(x, y)
	head.Size = Vector2.new(w, headH)
	bar.Position = Vector2.new(x, y)
	bar.Size = Vector2.new(w, 2)
	title.Position = Vector2.new(x + pad, y + 11)
	sep.Position = Vector2.new(x, y + headH + tabH - 1)
	sep.Size = Vector2.new(w, 1)

	local tw = w / #tabs
	for i, t in ipairs(tabs) do
		local active = i == win.tab
		t.txt.Position = Vector2.new(x + tw * (i - .5), y + headH + 8)
		t.txt.Color = active and th.text or th.dim
		t.under.Position = Vector2.new(x + tw * (i - 1) + 8, y + headH + tabH - 2)
		t.under.Size = Vector2.new(tw - 16, 2)
		t.under.Visible = active
		for _, wd in ipairs(t.widgets) do
			for _, o in ipairs(wd.objs) do o.Visible = active end
		end
	end

	local wy = y + headH + tabH + pad * .5
	for _, wd in ipairs(cur.widgets) do
		wd.x, wd.y, wd.w = x + pad, wy, w - pad * 2
		wd.layout(wd.x, wd.y, wd.w)
		wy += wd.h
	end

	footer.Text = string.upper(bind.name) .. "  toggles menu"
	footer.Position = Vector2.new(x + pad, y + win.h - 18)
end

local prevDown, wasOpen = false, false
local drag, slid

local menuConn = RunService.RenderStepped:Connect(function()
	if listening and iskeypressed then
		for vk = 8, 254 do
			local good, r = pcall(iskeypressed, vk)
			if good and r then
				bind = { vk = vk, name = string.format("VK 0x%02X", vk) }
				dirty = true
				listening = false
				prevKey = true
				break
			end
		end
	end

	local k = keyDown()
	if k and not prevKey and not listening then win.open = not win.open end
	prevKey = k

	if not win.open then
		if wasOpen then
			for _, o in ipairs(drawn) do o.Visible = false end
			wasOpen = false
		end
		prevDown = mouseDown()
		drag, slid = nil, nil
		return
	end

	if not wasOpen then
		for _, o in ipairs(drawn) do o.Visible = true end
		wasOpen = true
		dirty = true
	end

	local down = mouseDown()
	local mx, my = mouse()

	if not mx or not my then
		prevDown = down
		if dirty then
			layout()
			dirty = false
		end
		return
	end

	local click = down and not prevDown
	prevDown = down
	if click then dirty = true end

	if click then
		if hit(mx, my, win.x, win.y, win.w, headH) then
			drag = {mx - win.x, my - win.y}
		elseif hit(mx, my, win.x, win.y + headH, win.w, tabH) then
			win.tab = clamp(math.floor((mx - win.x) / (win.w / #tabs)) + 1, 1, #tabs)
		else
			for _, wd in ipairs(tabs[win.tab].widgets) do
				if hit(mx, my, wd.x, wd.y, wd.w, wd.h) then
					if wd.drag then
						slid = wd
						wd.drag(mx)
					elseif wd.click then
						wd.click()
					end
					break
				end
			end
		end
	end

	if not down then drag, slid = nil, nil end

	if drag then
		local vp = cam and cam.ViewportSize
		local nx, ny = mx - drag[1], my - drag[2]
		if vp then
			nx = clamp(nx, 0, vp.X - win.w)
			ny = clamp(ny, 0, vp.Y - math.max(win.h, 60))
		end
		win.x, win.y = nx, ny
	end
	if slid then slid.drag(mx) end

	if dirty or drag or slid or listening then
		layout()
		dirty = false
	end
end)

local box = Tab("Box")
Header(box, "General")
Toggle(box, "Building ESP", cfg, "on")
Choice(box, "Mode", cfg, "mode", {"3D Box", "2D Box"})
Slider(box, "Thickness", cfg, "thick", 1, 5, 1, "px")
Bind(box, "Menu key")

local builds = Tab("Builds")
Header(builds, "Show")
for _, b in ipairs(blds) do Toggle(builds, b.label, b, "on") end
Header(builds, "Colors")
for _, b in ipairs(blds) do Choice(builds, b.label, b, "color", colorList) end

local packsTab = Tab("Packs")
Header(packsTab, "Pickups")
Toggle(packsTab, "Pickup ESP", cfg, "packOn")
Toggle(packsTab, "Health packs", cfg, "packHealth")
Toggle(packsTab, "Ammo packs", cfg, "packAmmo")
Toggle(packsTab, "Show names", cfg, "packNames")
Header(packsTab, "Colors")
Choice(packsTab, "Health color", cfg, "packHealthColor", colorList)
Choice(packsTab, "Ammo color", cfg, "packAmmoColor", colorList)
Slider(packsTab, "Max distance (0 = off)", cfg, "packDist", 0, 1000, 10)

local text = Tab("Label")
Header(text, "Text")
Toggle(text, "Show name", cfg, "names")
Toggle(text, "Show level", cfg, "levels")
Slider(text, "Text size", cfg, "textSize", 10, 24, 1, "px")

local perf = Tab("Perf")
Header(perf, "Lag control")
Slider(perf, "Rescan every", cfg, "rescan", 1, 120, 1, "f")
Slider(perf, "Max distance (0 = off)", cfg, "maxDist", 0, 1000, 10)
Slider(perf, "Pickup rescan", cfg, "packRescan", 0.05, 2, 0.05, "s")

layout()
prevDown = true

function cleanup()
	espConn:Disconnect()
	menuConn:Disconnect()
	if inputConn then pcall(function() inputConn:Disconnect() end) end

	for _, b in ipairs(blds) do
		for _, l in ipairs(b.lines) do
			l.Visible = false
			pcall(function() l:Remove() end)
		end
		b.text.Visible = false
		pcall(function() b.text:Remove() end)
	end
	for _, o in ipairs(drawn) do
		o.Visible = false
		pcall(function() o:Remove() end)
	end

	packRunning = false
	for _, c in ipairs(packConns) do pcall(function() c:Disconnect() end) end
	for _, e in ipairs(packPool) do
		e.box.Visible = false
		e.tag.Visible = false
		pcall(function() e.box:Remove() end)
		pcall(function() e.tag:Remove() end)
	end
end
