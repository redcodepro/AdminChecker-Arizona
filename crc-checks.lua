-- Adm Checker v1.0

local ev = require 'lib.samp.events'
local inicfg = require 'inicfg'

local set = inicfg.load({
  main =
  {
	show_list	= true,
	show_cqueue = false,
	timeout		= 20
  },
  list = 
  {
    pos_x		= 2,
    pos_y		= 500,
	fontface	= 'Tahoma',
	fontsize	= 10
  }
}, 'crc-checks\\crc-checks')

local hThread1 = nil

local isArizona = false

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
	while not isSampAvailable() do wait(100) end
	hThread1 = lua_thread.create_suspended(checker_func)
	sampRegisterChatCommand('cc.go', function() hThread1:terminate() hThread1:run() end)
	sampRegisterChatCommand('cc.show', function() set.main.show_list = not set.main.show_list end)
	sampRegisterChatCommand('cc.queue', function() set.main.show_cqueue = not set.main.show_cqueue end)
	sampRegisterChatCommand('cc.timeout', function(p) local tmp = tonumber(p) if tmp ~= nil and tmp >= 0 and tmp <= 300 then sampAddChatMessage(set.main.timeout..' => '..tmp, 0xFFBE2D2D) set.main.timeout = tmp end end)
	loadFromFile()
	if sampGetCurrentServerName():find('Arizona') then
		isArizona = true
	end
	wait(-1)
end

-- Checker stuff
local ctable = {}
local cqueue = {}
local file_list = {}

local show_progress = false
local temp_id = 0
local isAdm = false
local checks = false

function checker_func()
	if not isArizona then return end
	checks = true
	ctable, cqueue = {}, {}
	for i = 0, 1004, 1 do
		if i > sampGetMaxPlayerId(false) then break end
		if sampPlayerIsListed(i) then
			table.insert(ctable, i)
		end
	end
	wait(500)
	show_progress = true
	for i = 0, 1004, 1 do
		if i > sampGetMaxPlayerId(false) then break end
		if sampIsPlayerConnected(i) then
			temp_id = i
			sampSendChat('/id '..temp_id)
			isAdm = nil
			while isAdm == nil do wait(8) end
			if isAdm then
				if not sampPlayerIsListed(temp_id) then
					table.insert(file_list, sampGetPlayerNickname(temp_id))
				end
				if not sampPlayerIsAdmin(temp_id) then
					table.insert(ctable, temp_id)
					table.sort(ctable)
				end
			end
		end
	end
	show_progress = false
	while true do
		for i, v in ipairs(cqueue) do
			if sampIsPlayerConnected(v[1]) then
				if sampGetPlayerScore(v[1]) > 0 then
					if v[2] == 0 then
						if sampPlayerIsListed(v[1]) then
							if not sampPlayerIsAdmin(v[1]) then
								table.insert(ctable, v[1])
								table.sort(ctable)
							end
							table.remove(cqueue, i)
						else
							v[2] = os.clock()
						end
					elseif os.clock() - v[2] >= set.main.timeout then
						temp_id = v[1]
						sampSendChat('/id '..temp_id)
						isAdm = nil
						while isAdm == nil do wait(10) end
						if isAdm then
							if not sampPlayerIsAdmin(temp_id) then
								table.insert(ctable, temp_id)
								table.sort(ctable)
							end
							if not sampPlayerIsListed(temp_id) then
								table.insert(file_list, sampGetPlayerNickname(temp_id))
							end
							table.remove(cqueue, i)
						else
							table.remove(cqueue, i)
						end
					end
				end
			else
				table.remove(cqueue, i)
			end
			wait(25)
		end
		wait(500)
	end
end

local auto_go = false
function ev.onSendClientJoin()
	if not auto_go then
		hThread1:terminate()
		saveToFile()
	end
	isArizona = false
	checks = false
	auto_go = true
end

function ev.onSendSpawn()
	if sampGetCurrentServerName():find('Arizona') then
		isArizona = true
		if auto_go then
			loadFromFile()
			hThread1:run()
			auto_go = false
		end
	end
end

function ev.onPlayerJoin(ID)
	if checks then
		table.insert(cqueue, {ID, 0})
	end
end

function ev.onPlayerQuit(ID)
	if checks then
		for i, v in ipairs(ctable) do
			if ID == v then
				table.remove(ctable, i)
			end
		end
		for i, v in ipairs(cqueue) do
			if ID == v[1] then
				table.remove(cqueue, i)
			end
		end
	end
end

function ev.onServerMessage(clr, msg)
	if isAdm == nil then
		if clr == -1104335361 and msg:find('Игрок \'ID: ' .. temp_id .. '\' не в сети!') then
			if sampIsPlayerConnected(temp_id) then
				isAdm = true
			else
				isAdm = false
			end
			return false
		elseif msg:find(sampGetPlayerNickname(temp_id) .. ' | Уровень: ') then
			isAdm = false
			return false
		end
	end
end

function onExitScript()
	saveToFile()
end

-- Graphic stuff
local function curInZone(x, y, x1, y1)
	local curX, curY = getCursorPos()
	if curX >= x and curX <= x1 and curY >= y and curY <= y1 then return true end
end

local font = renderCreateFont(set.list.fontface, set.list.fontsize, 4)
local move, offpnt = false, {0, 0}

function onD3DPresent()
	if not isArizona or not set.main.show_list or isPauseMenuActive() or isKeyDown(0x77) or sampIsScoreboardOpen() or isKeyDown(0x79) then return end
	
	local header = #ctable == 0 and 'Нет админов в сети' or string.format('Админы в сети [%d]', #ctable)
	local header_length = renderGetFontDrawTextLength(font, header)
	
	if move then
		if isKeyDown(1) then
			local curX, curY = getCursorPos()
			set.list.pos_x = curX - offpnt[1]
			set.list.pos_y = curY - offpnt[2]
		else
			local sX, sY = getScreenResolution()
			if set.list.pos_x < 0 then set.list.pos_x = 0 end
			if set.list.pos_y < 0 then set.list.pos_y = 0 end
			if set.list.pos_x + header_length > sX then set.list.pos_x = sX - header_length end
			if set.list.pos_y + renderGetFontDrawHeight(font) > sY then set.list.pos_y = sY - renderGetFontDrawHeight(font) end
			move = false
		end
	elseif sampIsCursorActive() then
		if isKeyDown(1) and curInZone(set.list.pos_x, set.list.pos_y, set.list.pos_x + header_length, set.list.pos_y + renderGetFontDrawHeight(font)) then
			local curX, curY = getCursorPos()
			offpnt[1] = curX - set.list.pos_x
			offpnt[2] = curY - set.list.pos_y
			move = true
		end
	end
	renderFontDrawText(font, header, set.list.pos_x, set.list.pos_y, #ctable > 0 and 0xFFFFFFFF or 0xA0FFFFFF)
	if show_progress then renderFontDrawText(font, string.format('%d/%d', temp_id, sampGetMaxPlayerId(false)), set.list.pos_x + header_length + renderGetFontCharWidth(font, ' '), set.list.pos_y, 0xFFA00000) end
	if #ctable > 0 then
		for i, id in ipairs(ctable) do
			local color, nick = 0xA0FFFFFF, 'Whoops...'
			if sampIsPlayerConnected(id) then
				if sampGetCharHandleBySampPlayerId(id) then 
					color = 0xFFFF0000
				else
					color = bit.band(sampGetPlayerColor(id), 0xFFFFFF)
				end
				nick = sampGetPlayerNickname(id)
			end
			renderFontDrawText(font, string.format('[%03d] {%06x}%s', id, color, nick), set.list.pos_x, set.list.pos_y + (i * (renderGetFontDrawHeight(font) - 2)) + 4, -1)
		end
	end
	if set.main.show_cqueue then
		for i, v in ipairs(cqueue) do
			local t = v[2] ~= 0 and os.clock() - v[2] or 0
			local col = 0
			if t == 0 then col = 0xFFAAAAAA
			elseif t < set.main.timeout / 2 then col = 0xFF10D10D
			elseif t < set.main.timeout then col = 0xFFFAF200
			else col = 0XFFDA0A0A end
			renderFontDrawText(font, string.format('%03d %02d', v[1], t), set.list.pos_x + 200, set.list.pos_y + ((i - 1) * (renderGetFontDrawHeight(font) - 4)), col)
		end
	end
end

function table.find(_a, _v)
	for i, v in ipairs(_a) do
		if v == _v then
			return i
		end
	end
	return nil
end

function sampPlayerIsListed(_id)
	if sampIsPlayerConnected(_id) then
		return table.find(file_list, sampGetPlayerNickname(_id))
	end
	return nil
end

function sampPlayerIsAdmin(_id)
	return table.find(ctable, _id)
end

local DIR = getWorkingDirectory()..'\\config\\crc-checks'

function loadFromFile()
	file_list = {}
	local ip, port = sampGetCurrentServerAddress()
	local f = io.open(string.format('%s\\crc-list-%s-%d.txt', DIR, ip, port), 'r')
	if f ~= nil then
		for line in f:lines() do
			table.insert(file_list, tostring(line))
		end
		f:close()
	end
end

function saveToFile()
	if not isArizona then return end
	if not doesDirectoryExist(DIR) then
		createDirectory(DIR)
	end
	local ip, port = sampGetCurrentServerAddress()
	local fn = string.format('%s\\crc-list-%s-%d.txt', DIR, ip, port)
	local f = io.open(fn, 'a+')
	local arr = {}
	for str in f:lines() do
		table.insert(arr, tostring(str))
	end
	f:close()
	for _, nick in ipairs(file_list) do
		if not table.find(arr, nick) then
			table.insert(arr, nick)
		end
	end
	table.sort(arr)
	f = io.open(fn, 'w+')
	for _, nick in ipairs(arr) do
		f:write(nick..'\n')
	end
	f:close()
	inicfg.save(set, 'crc-checks\\crc-checks')
end

-- (с) 2019-2020 Си Эр Си Скриптс