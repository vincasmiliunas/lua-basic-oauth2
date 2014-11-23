local OAUTH2 = require 'lua-basic-oauth2'

local scope = 'https://www.googleapis.com/auth/drive'
local root = '/tmp/'
local oauth2 = OAUTH2.new(OAUTH2.google_config, {scope = scope, creds_file = root..'creds.json', tokens_file = root..'tokens.json'})
local work = function()
  oauth2:init()
  oauth2:acquireToken()
end
local status, err = pcall(work)
if status then
  print('Token acquired successfully.')
else
  print('Acquisition failed: ' .. err)
end
