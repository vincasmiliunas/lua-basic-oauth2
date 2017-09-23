local JSON = require 'json'
local CURL = require 'cURL'

local M = {}
M.__index = M

function M.new()
	return setmetatable({}, M)
end

function M:copyTable(source, target)
	for k, v in pairs(source) do
		target[k] = v
	end
end

function M:loadFile(name)
	local f, err = io.open(name, 'rb')
	if not f then error(err) end
	local ret = f:read('*all')
	f:close()
	if not ret then error(string.format('f:read on %s failed.', name)) end
	return ret
end

function M:loadJsonFile(name)
	local ret = self:loadFile(name)
	if #ret == 0 then error(string.format('self:loadFile read an empty file: %s', name)) end
	return JSON.decode(ret)
end

function M:saveFile(name, content)
	if not content then error(string.format('Empty content to write to %s', name)) end
	local f, err = io.open(name, 'wb')
	if not f then error(err) end
	local ret = f:write(content)
	f:close()
	if not ret then error(string.format('f:write on %s failed.', name)) end
end

function M:saveJsonFile(name, content)
	local ret = JSON.encode(content)
	self:saveFile(name, ret)
end

function M:httpRequest(url, payload, headers, verb, options)
	local curl = CURL.easy_init()
	curl:setopt_url(tostring(url))

	local output = {}
	local code = 0

	local perform = {
		writefunction = function(data)
			if options and type(options.write) == 'function' then
				options.write(data)
			elseif options and type(options.write) == 'thread' then
				coroutine.resume(options.write, data)
			elseif options and type(options.write) ~= 'nil' then
				error(string.format('Invalid type for stream writer: %s', type(options.write)))
			else
				table.insert(output, data)
			end
		end,
		headerfunction = function(data)
			-- skip empty lines and other header lines once code is set to a non-100-Continue value
			if #data <= 2 or not (code == 0 or code == 100) then return end
			code = tonumber(data:match('^[^ ]+ ([0-9]+) '))
		end
	}

	if payload then
		curl:setopt_post(1)
	end
	if type(payload) == 'table' then
		-- form
		curl:post(payload)
	elseif type(payload) == 'string' then
		curl:setopt_postfields(payload, #payload)
--		curl:setopt_postfieldsize(#payload)
	elseif type(payload) == 'function' or type(payload) == 'thread' then
		-- chunked transfer encoding
		headers = headers or {}
		table.insert(headers, 'Transfer-Encoding: chunked')

		perform.readfunction = type(payload) == 'function' and payload or function()
			local ok, ret = coroutine.resume(payload)
			if not ok then error(ret) end
			return ret
		end
	elseif type(payload) ~= 'nil' then
		error(string.format('Unknown type for payload: %s', type(payload)))
	end

	if options and options['ssl_verifypeer'] ~= nil then
		curl:setopt_ssl_verifypeer(options['ssl_verifypeer'])
	end
	if verb then
		curl:setopt_customrequest(verb)
	end
	if headers then
		curl:setopt_httpheader(headers)
	end

	curl:perform(perform)

	return table.concat(output), code
end

return M
