-- Load all relevant APIs for this module
-- By doing this the internal garbage collection will perform better
--**************************************************************************

local availableAPIs = {}

-- Function to load all default APIs
local function loadAPIs()
  CSK_MultiIOLinkSMI = require 'API.CSK_MultiIOLinkSMI'

  Log = require 'API.Log'
  Log.Handler = require 'API.Log.Handler'
  Log.SharedLogger = require 'API.Log.SharedLogger'

  Container = require 'API.Container'
  DateTime = require 'API.DateTime'
  Engine = require 'API.Engine'
  File = require 'API.File'
  Object = require 'API.Object'
  Timer = require 'API.Timer'

  -- Check if related CSK modules are available to be used
  local appList = Engine.listApps()
  for i = 1, #appList do
    if appList[i] == 'CSK_Module_PersistentData' then
      CSK_PersistentData = require 'API.CSK_PersistentData'
    elseif appList[i] == 'CSK_Module_IODDInterpreter' then
      local checkVersion = Script.isServedAsFunction('CSK_IODDInterpreter.sendInstancesListParameters')
      if checkVersion then
        CSK_IODDInterpreter = require 'API.CSK_IODDInterpreter'
      end
    elseif appList[i] == 'CSK_Module_UserManagement' then
      CSK_UserManagement = require 'API.CSK_UserManagement'
    elseif appList[i] == 'CSK_Module_FlowConfig' then
      CSK_FlowConfig = require 'API.CSK_FlowConfig'
    elseif appList[i] == 'CSK_Module_PowerManager' then
      CSK_PowerManager = require 'API.CSK_PowerManager'
    end
  end
end

-- Function to load IO-Link SMI specific APIs
local function loadSMISpecificAPIs()
  IOLink = {}
  IOLink.SMI = require 'API.IOLink.SMI'
  IOLink.SMI.PortConfigList = require 'API.IOLink.SMI.PortConfigList'
  IOLink.SMI.PortStatus = require 'API.IOLink.SMI.PortStatus'
end

-- Function to load IO-Link SGI specific APIs
local function loadSGISpecificAPIs()
  IOLink.SMI.EventQualifier = require 'API.IOLink.SMI.EventQualifier'
  IOLink.SGI = {}
  IOLink.SGI.Client = require 'API.IOLink.SGI.Client'
end

availableAPIs.default = xpcall(loadAPIs, debug.traceback)
availableAPIs.specificSMI = xpcall(loadSMISpecificAPIs, debug.traceback)
availableAPIs.specificSGI = xpcall(loadSGISpecificAPIs, debug.traceback)

return availableAPIs
--**************************************************************************