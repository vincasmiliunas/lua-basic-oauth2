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
	if options and options['ssl_verifypeer'] ~= nil then
		curl:setopt_ssl_verifypeer(options['ssl_verifypeer'])
	end
	if verb then
		curl:setopt_customrequest(verb)
	end
	if headers then
		curl:setopt_httpheader(headers)
	end
	if payload and type(payload) == 'table' then
		curl:post(payload)
	elseif payload then
		curl:setopt_post(1)
		curl:setopt_postfields(payload)
		curl:setopt_postfieldsize(#payload)
	end
	local output = {}
	local code = 0
	curl:perform{
		writefunction = function(data)
			table.insert(output, data)
		end,
		headerfunction = function(data)
			if code ~= 0 then return end
			code = tonumber(data:match('^[^ ]+ ([0-9]+) '))
		end}
	return table.concat(output), code
end

return M
