-- Block namespace
local BLOCK_NAMESPACE = 'MultiIOLinkSMI_FC.WriteProcessData'
local nameOfModule = 'CSK_MultiIOLinkSMI'

--*************************************************************
--*************************************************************

-- Required to keep track of already allocated resource
local instanceTable = {}

local function writeProcessData(handle, source)

  local port = Container.get(handle, 'Port')
  local writeMessageName = Container.get(handle, 'WriteMessageName')

  local _, portList = CSK_MultiIOLinkSMI.getInstancePortMap()
  local instanceUsed = 1
  for key, value in pairs(portList) do
    if value == port then
      instanceUsed = key
    end
  end

  CSK_MultiIOLinkSMI.setSelectedInstance(instanceUsed)
  CSK_MultiIOLinkSMI.setSelectedIODDWriteMessage(writeMessageName)
  CSK_MultiIOLinkSMI.setIODDWriteMessageEventName(source)

end
Script.serveFunction(BLOCK_NAMESPACE .. '.writeProcessData', writeProcessData)

--*************************************************************
--*************************************************************

local function create(port, writeMessageName)

  local fullInstanceName = tostring(port) .. '_' .. tostring(writeMessageName)

  -- Check if same instance is already configured
  if instanceTable[fullInstanceName] ~= nil then
    _G.logger:warning(nameOfModule .. ": Instance invalid or already in use, please choose another one")
    return nil
  else
    -- Otherwise create handle and store the restriced resource
    local handle = Container.create()
    instanceTable[fullInstanceName] = fullInstanceName
    Container.add(handle, 'Port', port)
    Container.add(handle, 'WriteMessageName', writeMessageName)
    return handle
  end
end
Script.serveFunction(BLOCK_NAMESPACE .. '.create', create)

--- Function to reset instances if FlowConfig was cleared
local function handleOnClearOldFlow()
  Script.releaseObject(instanceTable)
  instanceTable = {}
end
Script.register('CSK_FlowConfig.OnClearOldFlow', handleOnClearOldFlow)