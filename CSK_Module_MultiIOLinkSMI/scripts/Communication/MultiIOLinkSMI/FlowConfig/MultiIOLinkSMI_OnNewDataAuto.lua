-- Block namespace
local BLOCK_NAMESPACE = "MultiIOLinkSMI_FC.OnNewDataAuto"
local nameOfModule = 'CSK_MultiIOLinkSMI'

--*************************************************************
--*************************************************************

-- Required to keep track of already allocated resource
local instanceTable = {}

-- Information about IO-Link configuration made by FlowConfig blocks
local portInfos = {}

--- Timer to start readMessage timers
local tmrReadMessage = Timer.create()
tmrReadMessage:setExpirationTime(5000)
tmrReadMessage:setPeriodic(false)

--- Timer to setup IO-Link incl. power management
local tmrSetup = Timer.create()
tmrSetup:setExpirationTime(3000)
tmrSetup:setPeriodic(false)

--- Function to start periocic timer for readMessages
local function handleOnExpired()
  CSK_MultiIOLinkSMI.setReadMessageTimerActive(true)
end
Timer.register(tmrReadMessage, 'OnExpired', handleOnExpired)

--- Function to automatically setup IO-Link configuration
local function handleIOLinkSetup()

  local amount = CSK_MultiIOLinkSMI.getInstancesAmount()

  -- First reset setup if it was configured before
  for i = 1, amount do
    CSK_MultiIOLinkSMI.setSelectedInstance(i)
    CSK_MultiIOLinkSMI.deleteAllReadMessages()
    CSK_MultiIOLinkSMI.activateInstance(false)
    CSK_MultiIOLinkSMI.setPort('')
  end

  if CSK_PowerManager then
    local moduleActive = CSK_PowerManager.getStatusModuleActive()
    if moduleActive then
      for key, value in ipairs(portInfos) do
        local status = CSK_PowerManager.getCurrentPortStatus(value.port)
        if status == false then
          CSK_PowerManager.changeStatusOfPort(value.port)
        end
      end
      CSK_PowerManager.setAllStatus()
    end
  end

  for key, value in ipairs(portInfos) do
    value.portActive = false
    local instanceAmount = CSK_MultiIOLinkSMI.getInstancesAmount()
    if instanceAmount < key then
      CSK_MultiIOLinkSMI.addInstance()
    end

    CSK_MultiIOLinkSMI.setSelectedInstance(key)
    CSK_MultiIOLinkSMI.setPort(value.port)
    CSK_MultiIOLinkSMI.activateInstance(true)
  end

  tmrReadMessage:start()
end
Timer.register(tmrSetup, 'OnExpired', handleIOLinkSetup)

--- Function to setup readMessages
---@param instance int Instance ID.
---@param status string Port status.
---@param port string Port
local function handleOnNewIOLinkPortStatus(instance, status, port)
  if status == 'OPERATE' then
    for key, value in ipairs(portInfos) do
      if value.port == port then
        -- Check to only setup once, even with multiple events of OPERATION
        if value.portActive == false then
          value.portActive = true
          CSK_MultiIOLinkSMI.setSelectedInstance(instance)

          -- Add readMessages
          for subKey, subValue in ipairs(value.messageInfos.names) do
            CSK_MultiIOLinkSMI.setIODDReadMessageName(subValue)
            CSK_MultiIOLinkSMI.setReadMessageMode('NO_IODD')
            CSK_MultiIOLinkSMI.createIODDReadMessage()
            CSK_MultiIOLinkSMI.setTriggerType('Periodic')
            CSK_MultiIOLinkSMI.setTriggerValue(value.messageInfos.cycleTimes[subKey])
            CSK_MultiIOLinkSMI.setReadMessageProcessDataStartByte(value.messageInfos.startBytes[subKey])
            CSK_MultiIOLinkSMI.setReadMessageProcessDataEndByte(value.messageInfos.endBytes[subKey])
            CSK_MultiIOLinkSMI.setReadMessageProcessDataUnpackFormat(value.messageInfos.unpackFormats[subKey])
          end
        end
      end
    end
  end
end
Script.register('CSK_MultiIOLinkSMI.OnNewIOLinkPortStatus', handleOnNewIOLinkPortStatus)

local function register(handle, _ , callback)

  Container.remove(handle, "CB_Function")
  Container.add(handle, "CB_Function", callback)

  local port = Container.get(handle, 'Port')
  local cycleTime = Container.get(handle, 'CycleTime')
  local startByte = Container.get(handle, 'StartByte')
  local endByte = Container.get(handle, 'EndByte')
  local unpackFormat = Container.get(handle, 'UnpackFormat')

  local portExists = false
  local portPosition = 1

  -- Check if port config already exists
  for key, value in pairs(portInfos) do
    if value.port == port then
      portExists = true
      portPosition = key
      break
    end
  end

  if not portExists then
    -- Create new table for port configuration
    local instanceSetup = {}
    instanceSetup.port = port
    instanceSetup.portActive = false
    instanceSetup.messageInfos = {}
    instanceSetup.messageInfos.names = {}
    instanceSetup.messageInfos.cycleTimes = {}
    instanceSetup.messageInfos.startBytes = {}
    instanceSetup.messageInfos.endBytes = {}
    instanceSetup.messageInfos.unpackFormats = {}

    table.insert(portInfos, instanceSetup)
    portPosition = #portInfos
  end

  table.insert(portInfos[portPosition].messageInfos.names, 'FlowConfig' .. tostring(#portInfos[portPosition].messageInfos.names))
  local messagePos = portInfos[portPosition].messageInfos.names[#portInfos[portPosition].messageInfos.names]
  table.insert(portInfos[portPosition].messageInfos.cycleTimes, cycleTime)
  table.insert(portInfos[portPosition].messageInfos.startBytes, startByte)
  table.insert(portInfos[portPosition].messageInfos.endBytes, endByte)
  table.insert(portInfos[portPosition].messageInfos.unpackFormats, unpackFormat)

  local function localCallback()
    local cbFunction = Container.get(handle,"CB_Function")

    if cbFunction ~= nil then
      Script.callFunction(cbFunction, 'CSK_MultiIOLinkSMI.OnNewRawReadMessage_' .. tostring(portPosition) .. '_' .. port .. '_' .. messagePos)
    else
      _G.logger:warning(nameOfModule .. ": " .. BLOCK_NAMESPACE .. ".CB_Function missing!")
    end
  end
  Script.register('CSK_FlowConfig.OnNewFlowConfig', localCallback)

  tmrSetup:start()

  return true
end
Script.serveFunction(BLOCK_NAMESPACE ..".register", register)

--*************************************************************
--*************************************************************

local function create(port, cycleTime, startByte, endByte, unpackFormat)

  local fullInstanceName = tostring(port) .. '_' .. tostring(cycleTime) .. tostring(startByte) .. '_' .. tostring(endByte) .. '_' .. tostring(unpackFormat)

  -- Check if same instance is already configured
  if instanceTable[fullInstanceName] ~= nil then
    _G.logger:warning(nameOfModule .. ": Instance invalid or already in use, please choose another one")
    return nil
  else
    -- Otherwise create handle and store the restriced resource
    local handle = Container.create()
    instanceTable[fullInstanceName] = fullInstanceName
    Container.add(handle, 'Port', port)
    Container.add(handle, 'CycleTime', cycleTime)
    Container.add(handle, 'StartByte', startByte)
    Container.add(handle, 'EndByte', endByte)
    Container.add(handle, 'UnpackFormat', unpackFormat)
    Container.add(handle, "CB_Function", "")
    return handle
  end
end
Script.serveFunction(BLOCK_NAMESPACE .. ".create", create)

--- Function to reset instances if FlowConfig was cleared
local function handleOnClearOldFlow()

  Script.releaseObject(instanceTable)
  instanceTable = {}

  Script.releaseObject(portInfos)
  portInfos = {}
end
Script.register('CSK_FlowConfig.OnClearOldFlow', handleOnClearOldFlow)