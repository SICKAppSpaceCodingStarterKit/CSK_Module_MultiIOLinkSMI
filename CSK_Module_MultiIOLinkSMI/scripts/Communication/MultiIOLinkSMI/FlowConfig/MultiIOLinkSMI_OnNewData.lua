-- Block namespace
local BLOCK_NAMESPACE = "MultiIOLinkSMI_FC.OnNewData"
local nameOfModule = 'CSK_MultiIOLinkSMI'

--*************************************************************
--*************************************************************

-- Required to keep track of already allocated resource
local instanceTable = {}

local function register(handle, _ , callback)

  Container.remove(handle, "CB_Function")
  Container.add(handle, "CB_Function", callback)

  local instance = Container.get(handle, 'Instance')
  local readMessageName = Container.get(handle,"ReadMessageName")

  -- Check if amount of instances is valid
  -- if not: add multiple additional instances
  while true do
    local amount = CSK_MultiIOLinkSMI.getInstancesAmount()
    if amount < instance then
      CSK_MultiIOLinkSMI.addInstance()
    else
      break
    end
  end

  CSK_MultiIOLinkSMI.setSelectedInstance(instance)
  local port = CSK_MultiIOLinkSMI.getPort()

  if not port or port == '' then
    return false
  else
    CSK_MultiIOLinkSMI.setIODDReadMessageName(readMessageName)
    CSK_MultiIOLinkSMI.createIODDReadMessage()

    local function localCallback()
      local cbFunction = Container.get(handle,"CB_Function")

      if cbFunction ~= nil then
        Script.callFunction(cbFunction, 'CSK_MultiIOLinkSMI.readMessage' .. tostring(port) .. tostring(readMessageName))
      else
        _G.logger:warning(nameOfModule .. ": " .. BLOCK_NAMESPACE .. ".CB_Function missing!")
      end
    end
    Script.register('CSK_FlowConfig.OnNewFlowConfig', localCallback)

    return true
  end
end
Script.serveFunction(BLOCK_NAMESPACE ..".register", register)

--*************************************************************
--*************************************************************

--local function create(instance, port, readMessageName)
local function create(instance, readMessageName)

  local fullInstanceName = tostring(instance) .. '_' .. tostring(readMessageName)

  -- Check if same instance is already configured
  if instance < 1 or instanceTable[fullInstanceName] ~= nil then
    _G.logger:warning(nameOfModule .. ": Instance invalid or already in use, please choose another one")
    return nil
  else
    -- Otherwise create handle and store the restriced resource
    local handle = Container.create()
    instanceTable[fullInstanceName] = fullInstanceName
    Container.add(handle, 'Instance', instance)
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