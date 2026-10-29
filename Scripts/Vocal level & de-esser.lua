-- Vocal level & de-esser
-- Nivelle une voix (parlée ou chantée) et atténue ses sifflantes en écrivant des courbes
-- d'automation sur un petit plugin placé sur la PRISE (avant les effets de la piste).
-- L'analyse lit tout l'item à l'avance : les corrections arrivent pile au bon moment, sans pompage.
-- Les courbes restent collées à l'item : on peut le déplacer ou le couper ensuite.
local TITLE = "Vocal level & de-esser"
local SECTION = "VOCALLEVEL"
local SR = 24000                        -- fréquence d'analyse
local FXDESC = "Vocal level & de-esser (gain"
local scriptpath = ({ reaper.get_action_context() })[2]
local scriptdir = scriptpath:match("^(.*[/\\])")
local SEP = package.config:sub(1, 1)

---------------------------------------------------------------- Réglages
local PRESETS = {
  parole = { amount = 80, range = 8, smooth = 120 },
  chant = { amount = 55, range = 6, smooth = 220 },
}
local DEF = {
  mode = "parole", auto = 1, target = -20, amount = 80, range = 8, smooth = 120,
  de_on = 1, depth = 6, sens = 50, freq = 5500, split = 1,
}
local S = {}
for k, v in pairs(DEF) do
  local s = reaper.GetExtState(SECTION, k)
  if s == "" then S[k] = v elseif type(v) == "number" then S[k] = tonumber(s) or v else S[k] = s end
end
local function save() for k in pairs(DEF) do reaper.SetExtState(SECTION, k, tostring(S[k]), true) end end

---------------------------------------------------------------- Filtres
local function biquad(kind, f, gain_db, q)
  local w = 2 * math.pi * math.min(f, SR * 0.45) / SR
  local c, s = math.cos(w), math.sin(w)
  local al = s / (2 * (q or 0.7071))
  local b0, b1, b2, a0, a1, a2
  if kind == "hp" then
    b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2; a0, a1, a2 = 1 + al, -2 * c, 1 - al
  else -- plateau aigu (RBJ)
    local A = 10 ^ (gain_db / 40); local sq = 2 * math.sqrt(A) * al
    b0 = A * ((A + 1) + (A - 1) * c + sq); b1 = -2 * A * ((A - 1) + (A + 1) * c); b2 = A * ((A + 1) + (A - 1) * c - sq)
    a0 = (A + 1) - (A - 1) * c + sq; a1 = 2 * ((A - 1) - (A + 1) * c); a2 = (A + 1) - (A - 1) * c - sq
  end
  return { b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0, 0, 0 }
end

---------------------------------------------------------------- Prises sélectionnées
local function take_key(item, take)
  local _, g = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
  return table.concat({ g, reaper.GetMediaItemInfo_Value(item, "D_LENGTH"), reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
    reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"), S.freq }, "|")
end

local function selected_takes()
  local list = {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    local tk = reaper.GetActiveTake(it)
    if tk and not reaper.TakeIsMIDI(tk) then list[#list + 1] = { item = it, take = tk } end
  end
  return list
end

local function find_fx(take)
  for i = 0, reaper.TakeFX_GetCount(take) - 1 do
    local _, name = reaper.TakeFX_GetFXName(take, i, "")
    if name:find(FXDESC, 1, true) or name:find("Vocal level.jsfx", 1, true) then return i end
  end
  return -1
end

---------------------------------------------------------------- Analyse
-- Pour chaque prise : niveau (pondéré, fenêtre glissante) toutes les 20 ms,
-- énergie totale et énergie des aigus (au-dessus de la fréquence du de-esser) toutes les 4 ms.
local HOP, FR = 480, 96                 -- 20 ms et 4 ms à 24 kHz
local cache = {}

local function analyse_take(e, on_progress)
  local item, take = e.item, e.take
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local fx = find_fx(take)
  local was = fx >= 0 and reaper.TakeFX_GetEnabled(take, fx)
  if fx >= 0 then reaper.TakeFX_SetEnabled(take, fx, false) end      -- on analyse le son d'origine
  local acc = reaper.CreateTakeAudioAccessor(take)
  local nch = math.max(1, math.min(2, reaper.GetMediaSourceNumChannels(reaper.GetMediaItemTake_Source(take))))
  local total = math.floor(len * SR)
  local BLOCK = SR
  local buf = reaper.new_array(BLOCK * nch)
  local k1, k2 = biquad("hp", 70), biquad("hs", 1500, 4, 0.7071)
  local h1, h2 = biquad("hp", S.freq), biquad("hp", S.freq)
  local lv, fe, he = {}, {}, {}                      -- énergies par bloc de 20 ms / trames de 4 ms
  local accK, nK, accF, accH, nF = 0, 0, 0, 0, 0
  local done = 0
  return function()
    local deadline = reaper.time_precise() + 0.04
    while done < total and reaper.time_precise() < deadline do
      local n = math.min(BLOCK, total - done)
      buf.clear()
      reaper.GetAudioAccessorSamples(acc, SR, nch, done / SR, n, buf)
      local t = buf.table(1, n * nch)
      local a1, a2, a3, a4, a5, z1, z2 = k1[1], k1[2], k1[3], k1[4], k1[5], k1[6], k1[7]
      local b1, b2, b3, b4, b5, y1, y2 = k2[1], k2[2], k2[3], k2[4], k2[5], k2[6], k2[7]
      local c1, c2, c3, c4, c5, u1, u2 = h1[1], h1[2], h1[3], h1[4], h1[5], h1[6], h1[7]
      local d1, d2, d3, d4, d5, v1, v2 = h2[1], h2[2], h2[3], h2[4], h2[5], h2[6], h2[7]
      for i = 1, n do
        local x
        if nch == 2 then x = (t[2 * i - 1] + t[2 * i]) * 0.5 else x = t[i] end
        -- pondération (passe-haut 70 Hz + plateau +4 dB au-dessus de 1,5 kHz)
        local p = a1 * x + z1; z1 = a2 * x - a4 * p + z2; z2 = a3 * x - a5 * p
        local k = b1 * p + y1; y1 = b2 * p - b4 * k + y2; y2 = b3 * p - b5 * k
        -- aigus (passe-haut 4e ordre à la fréquence du de-esser)
        local hh = c1 * p + u1; u1 = c2 * p - c4 * hh + u2; u2 = c3 * p - c5 * hh
        local h = d1 * hh + v1; v1 = d2 * hh - d4 * h + v2; v2 = d3 * hh - d5 * h
        -- niveau du rider : bande vocale SOUS la fréquence du de-esser (les sifflantes ne font pas baisser la voix)
        local lo = k - h
        accK = accK + lo * lo; nK = nK + 1
        accF = accF + p * p; accH = accH + h * h; nF = nF + 1
        if nF == FR then fe[#fe + 1] = accF / FR; he[#he + 1] = accH / FR; accF, accH, nF = 0, 0, 0 end
        if nK == HOP then lv[#lv + 1] = accK / HOP; accK, nK = 0, 0 end
      end
      k1[6], k1[7], k2[6], k2[7], h1[6], h1[7], h2[6], h2[7] = z1, z2, y1, y2, u1, u2, v1, v2
      done = done + n
    end
    if on_progress then on_progress(done / math.max(1, total)) end
    if done < total then return false end
    reaper.DestroyAudioAccessor(acc)
    if fx >= 0 then reaper.TakeFX_SetEnabled(take, fx, was) end
    return true, { len = len, lv = lv, fe = fe, he = he }
  end
end

---------------------------------------------------------------- Calcul des courbes
local function db(e) return 10 * math.log(e + 1e-12, 10) end
local function pct(arr, p)
  local s = {}
  for i = 1, #arr do s[i] = arr[i] end
  table.sort(s)
  if #s == 0 then return -90 end
  return s[math.max(1, math.min(#s, math.floor(#s * p + 0.5)))]
end

-- Simplification (Ramer-Douglas-Peucker) : garde les points utiles à 0,25 dB près
local function simplify(pts, tol)
  if #pts <= 2 then return pts end
  local keep = { [1] = true, [#pts] = true }
  local stack = { { 1, #pts } }
  while #stack > 0 do
    local a, b = table.unpack(table.remove(stack))
    local ta, va, tb, vb = pts[a][1], pts[a][2], pts[b][1], pts[b][2]
    local best, bi = 0, nil
    for i = a + 1, b - 1 do
      local v = va + (vb - va) * (pts[i][1] - ta) / (tb - ta)
      local d = math.abs(pts[i][2] - v)
      if d > best then best = d; bi = i end
    end
    if bi and best > tol then keep[bi] = true; stack[#stack + 1] = { a, bi }; stack[#stack + 1] = { bi, b } end
  end
  local out = {}
  for i = 1, #pts do if keep[i] then out[#out + 1] = pts[i] end end
  return out
end

local function rider_curve(A)
  local win = math.max(1, math.floor((S.mode == "chant" and 0.3 or 0.4) / 0.02 + 0.5))
  local L, n = {}, #A.lv
  local run = 0
  for i = 1, n do
    run = run + A.lv[i]
    if i > win then run = run - A.lv[i - win] end
    L[i] = db(run / math.min(i, win))
  end
  -- le niveau d'une trame décrit la fenêtre qui se termine là : on le recentre
  local Lc = {}
  for i = 1, n do Lc[i] = L[math.min(n, i + win // 2)] end
  -- bruit de fond : les blocs de 20 ms les plus calmes (respirations, silences entre les phrases)
  local raw = {}
  for i = 1, n do raw[i] = db(A.lv[i]) end
  local floor = pct(raw, 0.03)
  local hi = pct(Lc, 0.95)
  local gate = math.max(floor + 10, hi - 35)
  local voiced, vl = {}, {}
  for i = 1, n do voiced[i] = Lc[i] > gate; if voiced[i] then vl[#vl + 1] = Lc[i] end end
  if #vl == 0 then return { { 0, 0 }, { A.len, 0 } }, 0, 0, nil end
  local T = (S.auto == 1) and pct(vl, 0.5) or S.target
  local g = {}
  for i = 1, n do
    if voiced[i] then g[i] = math.max(-S.range, math.min(S.range, (T - Lc[i]) * S.amount / 100)) end
  end
  -- silences : on n'y remonte jamais le niveau (le bruit de fond resterait au même niveau)
  local nextv = {}
  local nx = nil
  for i = n, 1, -1 do if g[i] then nx = i end; nextv[i] = nx end
  local prev = nil
  for i = 1, n do
    if g[i] then prev = i
    else
      local nx = nextv[i]
      local v
      if prev and nx then v = g[prev] + (g[nx] - g[prev]) * (i - prev) / (nx - prev)
      else v = (prev and g[prev]) or (nx and g[nx]) or 0 end
      g[i] = math.min(0, v)
    end
  end
  -- lissage gaussien symétrique (pas de retard : l'analyse connaît la suite)
  local sig = math.max(1, S.smooth / 20)
  local R = math.floor(sig * 3)
  local ker, ks = {}, 0
  for k = -R, R do ker[k] = math.exp(-(k * k) / (2 * sig * sig)); ks = ks + ker[k] end
  local sm, gmin, gmax = {}, 0, 0
  for i = 1, n do
    local s = 0
    for k = -R, R do s = s + ker[k] * g[math.max(1, math.min(n, i + k))] end
    sm[i] = s / ks
    if sm[i] < gmin then gmin = sm[i] end
    if sm[i] > gmax then gmax = sm[i] end
  end
  local pts = {}
  for i = 1, n do pts[#pts + 1] = { (i - 0.5) * 0.02, sm[i] } end
  return simplify(pts, 0.25), gmin, gmax, T
end

local function deess_curve(A)
  if S.de_on ~= 1 or S.depth <= 0 then return {}, 0 end
  local n = #A.fe
  local fd, hd = {}, {}
  for i = 1, n do fd[i] = db(A.fe[i]); hd[i] = db(A.he[i]) end
  local floor = pct(fd, 0.10)
  local loud = {}
  for i = 1, n do if fd[i] > floor + 15 then loud[#loud + 1] = hd[i] end end
  if #loud == 0 then return {}, 0 end
  local href = pct(loud, 0.5)                           -- niveau habituel des aigus de cette voix
  local s = S.sens / 100
  local ratio_thr = -4 - 8 * s                          -- part des aigus dans le son (sensibilité 50 : -8 dB)
  local level_thr = href + 8 - 8 * s                    -- aigus au-dessus de leur niveau habituel (+4 dB)
  local sib = {}
  for i = 1, n do
    sib[i] = fd[i] > floor + 10 and (hd[i] - fd[i]) > ratio_thr and hd[i] > level_thr
  end
  local pts, count = {}, 0
  local i = 1
  local dt = FR / SR
  while i <= n do
    if sib[i] then
      local j = i
      while j + 1 <= n and (sib[j + 1] or (j + 3 <= n and (sib[j + 2] or sib[j + 3]))) do j = j + 1 end
      if j - i + 1 >= 3 then                            -- au moins 12 ms
        local peak = 0
        for k = i, j do local r = hd[k] - href; if r > peak then peak = r end end
        local r = math.min(S.depth, math.max(2, peak))
        local t0, t1 = (i - 1) * dt, j * dt
        local last = pts[#pts]
        if last and t0 - 0.006 <= last[1] then table.remove(pts) -- sifflantes collées : un seul creux
        else pts[#pts + 1] = { math.max(0, t0 - 0.006), 0 } end
        pts[#pts + 1] = { t0 + 0.002, r }
        pts[#pts + 1] = { math.max(t0 + 0.003, t1 - 0.002), r }
        pts[#pts + 1] = { t1 + 0.010, 0 }
        count = count + 1
      end
      i = j + 1
    else i = i + 1 end
  end
  return pts, count
end

---------------------------------------------------------------- Écriture dans REAPER
local function jsfx_name()
  -- ReaPack installe le plugin dans Effects/<dépôt>/<catégorie>/ ; on retrouve ce chemin depuis celui du script
  local res = reaper.GetResourcePath()
  local rel = scriptdir:sub(#res + 2):gsub("\\", "/")
  local inst = rel:match("^Scripts/(.*)$")
  local cands = {}
  if inst then cands[#cands + 1] = inst .. "Vocal level.jsfx" end
  cands[#cands + 1] = "Vocal level.jsfx"
  for _, c in ipairs(cands) do
    local f = io.open(res .. "/Effects/" .. c, "rb")
    if f then f:close(); return "JS:" .. c end
  end
  -- copie de secours (installation sans ReaPack) : le plugin est livré à côté du script
  local src = io.open(scriptdir .. "Vocal level.jsfx", "rb") or io.open(scriptdir .. ".." .. SEP .. "Effects" .. SEP .. "Vocal level.jsfx", "rb")
  if src then
    local data = src:read("a"); src:close()
    reaper.RecursiveCreateDirectory(res .. SEP .. "Effects", 0)
    local f = io.open(res .. SEP .. "Effects" .. SEP .. "Vocal level.jsfx", "wb")
    if f then f:write(data); f:close(); return "JS:Vocal level.jsfx" end
  end
end

local function show_env(env)
  local ok, chunk = reaper.GetEnvelopeStateChunk(env, "", false)
  if ok then
    local c2 = chunk:gsub("\nVIS %d", "\nVIS 1"):gsub("\nACT %d", "\nACT 1")
    if c2 ~= chunk then reaper.SetEnvelopeStateChunk(env, c2, false) end
  end
end

local function write_env(env, pts, conv, len)
  reaper.DeleteEnvelopePointRange(env, -1, len + 1)
  for _, p in ipairs(pts) do
    if p[1] >= 0 and p[1] <= len then reaper.InsertEnvelopePoint(env, p[1], conv(p[2]), 0, 0, false, true) end
  end
  reaper.Envelope_SortPoints(env)
  show_env(env)
end

local function apply_take(e, A)
  local take = e.take
  local fx = find_fx(take)
  if fx < 0 then
    local name = jsfx_name()
    if not name then return false, "plugin introuvable" end
    fx = reaper.TakeFX_AddByName(take, name, 1)
    if fx < 0 then return false, "plugin introuvable" end
    reaper.TakeFX_SetOpen(take, fx, false)
  end
  reaper.TakeFX_SetParamNormalized(take, fx, 2, (S.freq - 3000) / 7000)
  reaper.TakeFX_SetParamNormalized(take, fx, 3, S.split)
  local rpts, gmin, gmax = rider_curve(A)
  local dpts, count = deess_curve(A)
  local er = reaper.TakeFX_GetEnvelope(take, fx, 0, true)
  local ed = reaper.TakeFX_GetEnvelope(take, fx, 1, true)
  if er then write_env(er, rpts, function(v) return (v + 24) / 48 end, A.len) end
  if ed then
    if #dpts == 0 then dpts = { { 0, 0 } } end
    write_env(ed, dpts, function(v) return v / 24 end, A.len)
  end
  return true, { gmin = gmin, gmax = gmax, sib = count }
end

local function remove_all(list)
  reaper.Undo_BeginBlock()
  local n = 0
  for _, e in ipairs(list) do
    local fx = find_fx(e.take)
    if fx >= 0 then reaper.TakeFX_Delete(e.take, fx); n = n + 1 end
  end
  reaper.Undo_EndBlock(TITLE .. " : retrait", -1)
  reaper.UpdateArrange()
  return n
end

---------------------------------------------------------------- Interface
local W, H = 540, 650
gfx.init(TITLE, W, H)
local UI = { msg = "", progress = nil, drag = nil, mouse_was = false, stats = nil }
local takes = selected_takes()
local job = nil                                   -- analyse en cours
local function set_msg(m) UI.msg = m end

local COL = {
  bg = { 0.10, 0.105, 0.12 }, panel = { 0.14, 0.15, 0.17 }, text = { 0.93, 0.93, 0.93 }, muted = { 0.6, 0.62, 0.67 },
  accent = { 0.97, 0.6, 0.22 }, line = { 0.24, 0.25, 0.28 }, ok = { 0.3, 0.8, 0.5 },
}
local function col(c, a) gfx.set(c[1], c[2], c[3], a or 1) end
local function text(s, x, y, c, f) gfx.setfont(f or 1); col(c or COL.text); gfx.x, gfx.y = x, y; gfx.drawstr(s) end
gfx.setfont(1, "Arial", 15); gfx.setfont(2, "Arial", 13); gfx.setfont(3, "Arial", 19, string.byte("b")); gfx.setfont(4, "Arial", 13, string.byte("b"))

local function hit(x, y, w, h) return gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h end

local clicked = false
local function button(label, x, y, w, h, primary, active)
  local over = hit(x, y, w, h)
  if primary or active then col(COL.accent, over and 1 or 0.88) else col(COL.panel); end
  gfx.rect(x, y, w, h, 1)
  col(COL.line); if not (primary or active) then gfx.rect(x, y, w, h, 0) end
  gfx.setfont(4); local tw = gfx.measurestr(label)
  if primary or active then gfx.set(0.1, 0.06, 0.02) else col(COL.text) end
  gfx.x, gfx.y = x + (w - tw) / 2, y + (h - gfx.texth) / 2; gfx.drawstr(label)
  return clicked and over
end

-- curseur : renvoie true quand l'utilisateur relâche après l'avoir bougé
local function slider(id, label, key, mn, mx, step, fmt, x, y, w, disabled)
  text(label, x, y, disabled and COL.muted or COL.text, 2)
  local v = S[key]
  local vs = fmt(v)
  gfx.setfont(2); local tw = gfx.measurestr(vs)
  text(vs, x + w - tw, y, disabled and COL.muted or COL.accent, 2)
  local ty = y + 20
  col(COL.line); gfx.rect(x, ty, w, 4, 1)
  local f = (v - mn) / (mx - mn)
  if not disabled then col(COL.accent); gfx.rect(x, ty, math.floor(w * f), 4, 1) end
  col(disabled and COL.muted or COL.text); gfx.circle(x + w * f, ty + 2, 6, 1, 1)
  local released = false
  if not disabled then
    if gfx.mouse_cap & 1 == 1 then
      if UI.drag == nil and clicked and hit(x - 6, ty - 8, w + 12, 20) then UI.drag = id end
      if UI.drag == id then
        local nf = math.max(0, math.min(1, (gfx.mouse_x - x) / w))
        local nv = mn + nf * (mx - mn)
        nv = math.floor(nv / step + 0.5) * step
        S[key] = nv
      end
    elseif UI.drag == id then UI.drag = nil; released = true end
  end
  return released
end

local function apply_all()
  local ok_n, err, gmin, gmax, sib = 0, nil, 0, 0, 0
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for _, e in ipairs(takes) do
    local A = cache[take_key(e.item, e.take)]
    if A then
      local ok, r = apply_take(e, A)
      if ok then
        ok_n = ok_n + 1
        gmin = math.min(gmin, r.gmin); gmax = math.max(gmax, r.gmax); sib = sib + r.sib
      else err = r end
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock(TITLE, -1)
  reaper.UpdateArrange()
  save()
  if err and ok_n == 0 then
    set_msg("Plugin « Vocal level » introuvable : réinstallez le paquet avec ReaPack.")
  else
    UI.stats = string.format("Rider : de %+.1f à %+.1f dB · %d sifflante%s atténuée%s", gmin, gmax, sib, sib > 1 and "s" or "", sib > 1 and "s" or "")
    set_msg(string.format("Courbes écrites sur %d item%s. Écoutez, ajustez : tout se réécrit à chaque réglage.", ok_n, ok_n > 1 and "s" or ""))
  end
end

local function start_analysis()
  takes = selected_takes()
  if #takes == 0 then set_msg("Sélectionnez un ou plusieurs items audio (voix), puis « Analyser la sélection »."); return end
  local queue = {}
  for _, e in ipairs(takes) do if not cache[take_key(e.item, e.take)] then queue[#queue + 1] = e end end
  if #queue == 0 then apply_all(); return end
  local qi, step = 1, nil
  job = function()
    set_msg(string.format("Analyse… item %d / %d", qi, #queue))
    if not step then step = analyse_take(queue[qi], function(f) UI.progress = (qi - 1 + f) / #queue end) end
    local done, A = step()
    if done then
      cache[take_key(queue[qi].item, queue[qi].take)] = A
      qi = qi + 1; step = nil
      if qi > #queue then job = nil; UI.progress = nil; apply_all() end
    end
  end
end

local function draw()
  col(COL.bg); gfx.rect(0, 0, gfx.w, gfx.h, 1)
  text(TITLE, 22, 16, COL.text, 3)
  local n = #takes
  local analysed = 0
  for _, e in ipairs(takes) do if cache[take_key(e.item, e.take)] then analysed = analysed + 1 end end
  text(n == 0 and "Aucun item sélectionné" or string.format("%d item%s · %s", n, n > 1 and "s" or "", analysed == n and "analysé" .. (n > 1 and "s" or "") or "à analyser"), 22, 42, COL.muted, 2)

  local x, w = 22, W - 44
  local y = 74
  -- Rider
  col(COL.line); gfx.line(x, y, x + w, y)
  text("RIDER — niveau régulier", x, y + 10, COL.muted, 4)
  local chg = false
  if button("Parole", x + w - 170, y + 6, 80, 24, false, S.mode == "parole") then S.mode = "parole"; for k, v in pairs(PRESETS.parole) do S[k] = v end; chg = true end
  if button("Chant", x + w - 84, y + 6, 84, 24, false, S.mode == "chant") then S.mode = "chant"; for k, v in pairs(PRESETS.chant) do S[k] = v end; chg = true end
  y = y + 44
  if button(S.auto == 1 and "Cible : automatique" or "Cible : fixe", x, y, 150, 24, false, false) then S.auto = 1 - S.auto; chg = true end
  chg = slider("target", "Niveau cible", "target", -40, -8, 0.5, function(v) return string.format("%.1f dB", v) end, x + 170, y - 2, w - 170, S.auto == 1) or chg
  y = y + 46
  chg = slider("amount", "Quantité", "amount", 0, 100, 1, function(v) return string.format("%d %%", v) end, x, y, w) or chg
  y = y + 46
  chg = slider("range", "Correction maximale", "range", 1, 15, 0.5, function(v) return string.format("± %.1f dB", v) end, x, y, w) or chg
  y = y + 46
  chg = slider("smooth", "Douceur (rapide ↔ lent)", "smooth", 40, 400, 10, function(v) return string.format("%d ms", v) end, x, y, w) or chg
  y = y + 54
  -- De-esser
  col(COL.line); gfx.line(x, y, x + w, y)
  text("DE-ESSER — sifflantes", x, y + 10, COL.muted, 4)
  if button(S.de_on == 1 and "Activé" or "Désactivé", x + w - 100, y + 6, 100, 24, false, S.de_on == 1) then S.de_on = 1 - S.de_on; chg = true end
  y = y + 44
  local off = S.de_on ~= 1
  chg = slider("depth", "Atténuation maximale", "depth", 0, 15, 0.5, function(v) return string.format("%.1f dB", v) end, x, y, w, off) or chg
  y = y + 46
  chg = slider("sens", "Sensibilité", "sens", 0, 100, 1, function(v) return string.format("%d", v) end, x, y, w, off) or chg
  y = y + 46
  local fchg = slider("freq", "Fréquence", "freq", 3000, 10000, 100, function(v) return string.format("%.1f kHz", v / 1000) end, x, y, w, off)
  y = y + 44
  if button("Aigus seulement", x, y, 150, 24, false, S.split == 1) then S.split = 1; chg = true end
  if button("Tout le signal", x + 156, y, 130, 24, false, S.split == 0) then S.split = 0; chg = true end
  y = y + 40

  -- état
  if UI.progress then
    col(COL.line); gfx.rect(x, y, w, 6, 1); col(COL.accent); gfx.rect(x, y, math.floor(w * UI.progress), 6, 1)
  end
  if UI.stats then text(UI.stats, x, y + 10, COL.ok, 2) end
  text(UI.msg, x, y + 28, COL.muted, 2)
  local by = H - 46
  if button("Analyser la sélection", x, by, 190, 30, true) then start_analysis() end
  if button("Retirer", x + 200, by, 100, 30) then
    takes = selected_takes()
    local k = remove_all(takes)
    UI.stats = nil
    set_msg(k > 0 and string.format("Plugin et courbes retirés de %d item%s.", k, k > 1 and "s" or "") or "Rien à retirer sur la sélection.")
  end
  if button("Fermer", x + w - 100, by, 100, 30) then return false end

  if fchg then cache = {}; start_analysis()               -- nouvelle fréquence : il faut réécouter les aigus
  elseif chg and not job then
    local any = false
    for _, e in ipairs(takes) do if cache[take_key(e.item, e.take)] then any = true end end
    if any then apply_all() else save() end
  end
  gfx.update()
  return true
end

local function loop()
  local ch = gfx.getchar()
  if ch < 0 or ch == 27 then save(); return end
  local down = gfx.mouse_cap & 1 == 1
  clicked = down and not UI.mouse_was
  UI.mouse_was = down
  if job then job() end
  if not draw() then save(); gfx.quit(); return end
  reaper.defer(loop)
end

if #takes == 0 then
  set_msg("Sélectionnez un ou plusieurs items audio (voix), puis « Analyser la sélection ».")
else
  start_analysis()
end
reaper.defer(loop)
