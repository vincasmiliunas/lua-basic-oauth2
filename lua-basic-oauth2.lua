local URL = require 'net.url'
local JSON = require 'json'
local UTILS = require 'lua-basic-oauth2.utils'

local M = {}
M.__index = M

M.google_config = {
	auth_url = 'https://accounts.google.com/o/oauth2/auth',
	token_url = 'https://accounts.google.com/o/oauth2/token',

	approval_prompt = 'force',
	access_type = 'offline',
	redirect_uri = 'urn:ietf:wg:oauth:2.0:oob',

	-- workaround missing trusted certificates in cURL/PolarSSL on OpenWRT
	curl_options = {ssl_verifypeer = 0},
}

function M.new(baseConfig, workConfig)
	local self = setmetatable({}, M)
	self.utils = UTILS.new()
	self.config = {}
	self.utils:copyTable(baseConfig, self.config)
	self.utils:copyTable(workConfig, self.config)
	return self
end

function M:init()
	self.creds = self.utils:loadJsonFile(self.config.creds_file)
	work = function() self.tokens = self.utils:loadJsonFile(self.config.tokens_file) end
	if not pcall(work) then self.tokens = {} end
end

function M:request(url, payload, headers, verb, options)
	if self:expired() then self:refreshToken() end
	local tmp = string.format('Authorization: %s %s', self.tokens.token_type, self.tokens.access_token)
	headers = headers or {}
	table.insert(headers, tmp)
	options = options or {}
	self.utils:copyTable(self.config.curl_options, options)
	return self.utils:httpRequest(url, payload, headers, verb, options)
end

function M:refreshToken()
	local params = {
		grant_type = 'refresh_token',
		refresh_token = self.tokens.refresh_token,}
	self:updateToken(params)
end

function M:authToken(code)
	local params = {
		grant_type = 'authorization_code',
		redirect_uri = self.config.redirect_uri,
		scope = self.config.scope,
		code = code,}
	self:updateToken(params)
end

function M:updateToken(params)
	params.client_id = self.creds.client_id
	params.client_secret = self.creds.client_secret

	local content, code = self.utils:httpRequest(self.config.token_url, params, nil, nil, self.config.curl_options)
	if code ~= 200 then error(string.format('bad http response code: %d', code)) end

	local resp = JSON.decode(content)
	self.tokens.access_token = resp.access_token
	self.tokens.token_type = resp.token_type
	if resp.refresh_token then
		self.tokens.refresh_token = resp.refresh_token
	end
	self.tokens.expires = os.time() + resp.expires_in

	self.utils:saveJsonFile(self.config.tokens_file, self.tokens)
end

function M:expired()
	return os.time() >= self.tokens.expires
end

function M:buildAuthUrl(state)
	local result = URL.parse(self.config.auth_url)
	local tmp = {
		response_type = 'code',
		client_id = self.creds.client_id,
		redirect_uri = self.config.redirect_uri,
		scope = self.config.scope,
		state = state,
		access_type = self.config.access_type,
		approval_prompt = self.config.approval_prompt,}
	self.utils:copyTable(tmp, result.query)
	return result
end

function M:acquireToken()
	local url = self:buildAuthUrl(os.time())
	print('Follow this url: ' .. tostring(url))
	print('Enter the authorization code:')
	local code = io.read()
	self:authToken(code)
end

return M
