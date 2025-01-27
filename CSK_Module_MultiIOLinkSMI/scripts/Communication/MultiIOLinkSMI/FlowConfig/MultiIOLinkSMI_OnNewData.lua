-- Block namespace
local BLOCK_NAMESPACE = "MultiIOLinkSMI_FC.OnNewData"
local nameOfModule = 'CSK_MultiIOLinkSMI'

--*************************************************************
--*************************************************************

--- Timer to start readMessage timers
local tmr = Timer.create()
tmr:setExpirationTime(5000)
tmr:setPeriodic(false)

local function handleOnExpired()
  CSK_MultiIOLinkSMI.setReadMessageTimerActive(true)
end
Timer.register(tmr, 'OnExpired', handleOnExpired)

-- Required to keep track of already allocated resource
local instanceTable = {}

local function register(handle, _ , callback)

  Container.remove(handle, "CB_Function")
  Container.add(handle, "CB_Function", callback)

  local port = Container.get(handle, 'Port')
  local readMessageName = Container.get(handle,"ReadMessageName")

  local _, portList = CSK_MultiIOLinkSMI.getInstancePortMap()
  local instanceUsed = 1
  for key, value in pairs(portList) do
    if value == port then
      instanceUsed = key
    end
  end

  local function localCallback()
    local cbFunction = Container.get(handle,"CB_Function")

    if cbFunction ~= nil then
      Script.callFunction(cbFunction, 'CSK_MultiIOLinkSMI.OnNewRawReadMessage_' .. tostring(instanceUsed) .. '_' .. tostring(port) .. '_' .. tostring(readMessageName))
    else
      _G.logger:warning(nameOfModule .. ": " .. BLOCK_NAMESPACE .. ".CB_Function missing!")
    end
  end
  Script.register('CSK_FlowConfig.OnNewFlowConfig', localCallback)

  tmr:start()

  return true
end
Script.serveFunction(BLOCK_NAMESPACE ..".register", register)

--*************************************************************
--*************************************************************

local function create(port, readMessageName)

  local fullInstanceName = tostring(port) .. '_' .. tostring(readMessageName)

  -- Check if same instance is already configured
  if instanceTable[fullInstanceName] ~= nil then
    _G.logger:warning(nameOfModule .. ": Instance invalid or already in use, please choose another one")
    return nil
  else
    -- Otherwise create handle and store the restriced resource
    local handle = Container.create()
    instanceTable[fullInstanceName] = fullInstanceName
    Container.add(handle, 'Port', port)
    Container.add(handle, 'ReadMessageName', readMessageName)
    Container.add(handle, "CB_Function", "")
    return handle
  end
end
Script.serveFunction(BLOCK_NAMESPACE .. ".create", create)

--- Function to reset instances if FlowConfig was cleared
local function handleOnClearOldFlow()
  Script.releaseObject(instanceTable)
  instanceTable = {}
end
Script.register('CSK_FlowConfig.OnClearOldFlow', handleOnClearOldFlow)