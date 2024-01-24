---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter
--*****************************************************************
-- Inside of this script, you will find the module definition
-- including its parameters and functions
--*****************************************************************
local json = require('Communication/MultiIOLinkSMI/helper/Json')
local helperFuncs = require "Communication.MultiIOLinkSMI.helper.funcs"
local converter = require('Communication/MultiIOLinkSMI/helper/DataConverter')
--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************
local nameOfModule = 'CSK_MultiIOLinkSMI'

local multiIOLinkSMI = {}
multiIOLinkSMI.__index = multiIOLinkSMI

-- IO-Link SMI handle used by all instances
if _G.availableAPIs.ioLinkSmi then
  multiIOLinkSMI.IOLinkSMIhandle = IOLink.SMI.create()
end
-- Registering function to be called when any port event occurs 
local function handleOnNewPortEvent(port, eventType, eventCode)
  CSK_MultiIOLinkSMI.handleOnNewPortEvent(port, eventType, eventCode)
end
if multiIOLinkSMI.IOLinkSMIhandle then
  multiIOLinkSMI.IOLinkSMIhandle:register('OnPortEvent', handleOnNewPortEvent)
end

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

--- Function to get device identification from set of parameters available for almost any IO-Link device
---@param port string IO-Link port with connected device of interest
---@return table[] deviceInfo Table with device identification
function multiIOLinkSMI.getDeviceIdentification(port)
  local deviceInfo = {
    firmwareVersion = '',
    hardwareVersion = '',
    serialNumber = '',
    vendorId = '',
    vendorName = '',
    vendorText = '',
    deviceId = '',
    productName = '',
    productText = '',
    statusInfo = ''
  }
  local portStatus = multiIOLinkSMI.IOLinkSMIhandle:getPortStatus(port)
  deviceInfo.statusInfo = portStatus:getPortStatusInfo()
  if deviceInfo.statusInfo == 'OPERATE' then
    deviceInfo.deviceId = tostring(portStatus:getDeviceID())
    deviceInfo.vendorId = tostring(portStatus:getVendorID())
    local vendorName = multiIOLinkSMI.IOLinkSMIhandle:deviceRead(port, 16, 0)
    if vendorName then
      deviceInfo.vendorName = converter.toDataType(vendorName, 'StringT')
    end
    local vendorText = multiIOLinkSMI.IOLinkSMIhandle:deviceRead(port, 17, 0)
    if vendorText then
      deviceInfo.vendorText = converter.toDataType(vendorText, 'StringT')
    end
    local productName = multiIOLinkSMI.IOLinkSMIhandle:deviceRead(port, 18, 0)
    if productName then
      deviceInfo.productName = converter.toDataType(productName, 'StringT')
    end
    local productText = multiIOLinkSMI.IOLinkSMIhandle:deviceRead(port, 20, 0)
    if productText then
      deviceInfo.productText = converter.toDataType(productText, 'StringT')
    end
    local serialNumber = multiIOLinkSMI.IOLinkSMIhandle:deviceRead(port, 21, 0)
    if serialNumber then
      deviceInfo.serialNumber = converter.toDataType(serialNumber, 'StringT')
    end
    local hardwareVersion = multiIOLinkSMI.IOLinkSMIhandle:deviceRead(port, 22, 0)
    if hardwareVersion then
      deviceInfo.hardwareVersion = converter.toDataType(hardwareVersion, 'StringT')
    end
    local firmwareVersion = multiIOLinkSMI.IOLinkSMIhandle:deviceRead(port, 23, 0)
    if firmwareVersion then
      deviceInfo.firmwareVersion = converter.toDataType(firmwareVersion, 'StringT')
    end
  end
  return deviceInfo
end

--- Function to create new instance
---@param multiIOLinkSMIInstanceNo int Number of instance
---@return table[] self Instance of multiIOLinkSMI
function multiIOLinkSMI.create(multiIOLinkSMIInstanceNo)

  local self = {}
  setmetatable(self, multiIOLinkSMI)

  -- Check if CSK_PersistentData module can be used if wanted
  self.persistentModuleAvailable = CSK_PersistentData ~= nil or false

  -- Check if CSK_UserManagement module can be used if wanted
  self.userManagementModuleAvailable = CSK_UserManagement ~= nil or false

  self.multiIOLinkSMIInstanceNo = multiIOLinkSMIInstanceNo -- Number of this instance
  self.multiIOLinkSMIInstanceNoString = tostring(self.multiIOLinkSMIInstanceNo) -- Number of this instance as string
  self.helperFuncs = require('Communication/MultiIOLinkSMI/helper/funcs') -- Load helper functions

    -- Create parameters etc. for this module instance

  self.status = 'PORT_NOT_ACTIVE' -- Latest port status to show in UI
  self.activeInUi = false -- Check if this instance is currently active in UI

  -- Default values for persistent data
  -- If available, following values will be updated from data of CSK_PersistentData module (check CSK_PersistentData module for this)
  self.parametersName = 'CSK_MultiIOLinkSMI_Parameter' .. self.multiIOLinkSMIInstanceNoString -- name of parameter dataset to be used for this module
  self.parameterLoadOnReboot = false -- Status if parameter dataset should be loaded on app/device reboot

  -- Parameters to be saved permanently if wanted
  self.parameters = {}
  self.parameters.name = 'Sensor'.. self.multiIOLinkSMIInstanceNoString -- for future use
  self.parameters.processingFile = 'CSK_MultiIOLinkSMI_Processing'
  self.parameters.port = '' -- IOLink port used
  self.parameters.active = false -- Parameter showing if instance is activated or not
  self.parameters.ioddInfo = nil -- Table containing IODD information
  self.parameters.ioddReadMessages = {} -- Table contatining information about read messages. Each read message has its own IODD Interpreter instance
  self.parameters.ioddWriteMessages = {} -- Table contatining information about write messages. Each write message has its own IODD Interpreter instance

  -- Parameters to give to the processing script
  self.multiIOLinkSMIProcessingParams = Container.create()
  self.multiIOLinkSMIProcessingParams:add('multiIOLinkSMIInstanceNumber', multiIOLinkSMIInstanceNo, "INT")
  self.multiIOLinkSMIProcessingParams:add('SMIhandle', multiIOLinkSMI.IOLinkSMIhandle, 'OBJECT')
  self.multiIOLinkSMIProcessingParams:add('name', self.parameters.name, 'STRING')
  self.multiIOLinkSMIProcessingParams:add('active', self.parameters.active, 'BOOL')
  self.multiIOLinkSMIProcessingParams:add('port', self.parameters.port, 'STRING')

  -- Handle processing
  Script.startScript(self.parameters.processingFile, self.multiIOLinkSMIProcessingParams)

  return self
end

--- Function to apply a new device identification when a new device is connected 
function multiIOLinkSMI:applyNewDeviceIdentification()
  for messageName, _ in pairs(self.parameters.ioddReadMessages) do
    self:deleteIODDReadMessage(messageName)
  end
  for messageName, _ in pairs(self.parameters.ioddWriteMessages) do
    self:deleteIODDWriteMessage(messageName)
  end
  local foundMatchingIODD, ioddName = CSK_IODDInterpreter.findIODDMatchingVendorIdDeviceIdVersion(
    self.parameters.deviceIdentification.vendorId,
    self.parameters.deviceIdentification.deviceId
  )
  if self.parameters.ioddInfo and self.parameters.ioddInfo.ioddInstanceId then
    CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddInfo.ioddInstanceId)
    CSK_IODDInterpreter.deleteInstance()
  end
  self.parameters.ioddInfo = nil
  if not foundMatchingIODD then
    return
  end
  self.parameters.ioddInfo = {}
  self.parameters.ioddInfo.ioddName = ioddName
  self.parameters.ioddInfo.ioddInstanceId = 'ioLinkPort_' .. self.parameters.port
  CSK_IODDInterpreter.addInstance()
  CSK_IODDInterpreter.setInstanceName(self.parameters.ioddInfo.ioddInstanceId)
  CSK_IODDInterpreter.setSelectedIODD(ioddName)
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddInfo.ioddInstanceId)
  self.parameters.ioddInfo.isProcessDataVariable =  CSK_IODDInterpreter.getIsProcessDataVariable()
  if self.parameters.ioddInfo.isProcessDataVariable then
    local fullProcessDataConditionInfo = json.decode(CSK_IODDInterpreter.getProcessDataConditionInfo())
    self.parameters.ioddInfo.processDataConditionInfo = {
      index = fullProcessDataConditionInfo.Index,
      subindex = fullProcessDataConditionInfo.Subindex,
      info = fullProcessDataConditionInfo.Info
    }
    self.parameters.ioddInfo.processDataConditionList = CSK_IODDInterpreter.getProcessDataConditionList()
    for _ = 1,2 do
      local readSuccess, jsonConditionValue = CSK_MultiIOLinkSMI.readParameter(
        tonumber(self.parameters.ioddInfo.processDataConditionInfo.index),
        tonumber(self.parameters.ioddInfo.processDataConditionInfo.subindex)
      )
      if readSuccess then
        local unpackedValue = json.decode(jsonConditionValue)
        self.parameters.ioddInfo.currentCondition = CSK_IODDInterpreter.getProcessDataConditionNameFromValue(tostring(unpackedValue.value))
        CSK_IODDInterpreter.changeProcessDataStructureOptionValue(unpackedValue.value)
        break
      else
        _G.logger:warning(nameOfModule .. " failed to get Process data condition, instance " .. self.multiIOLinkSMIInstanceNoString .. '; deviceIdentification ' .. json.encode(self.parameters.deviceIdentification) .. '; ioddInfo: ' .. json.encode(self.parameters.ioddInfo))
      end
    end
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewDeviceIdentificationApplied', self.multiIOLinkSMIInstanceNo, json.encode(self.parameters))
end

--- Function to apply a new process data condition value to change a structure of a process data
---@param newConditionValue auto Condition value of the parameter responsible for process data selection to be written.  
---@return bool success Success of changing the process data structure.
function multiIOLinkSMI:setProcessDataConditionValue(newConditionValue)
  local dataToWrite = {
    value = newConditionValue
  }
  local writeSuccess = CSK_MultiIOLinkSMI.writeParameter(
    tonumber(self.parameters.ioddInfo.processDataConditionInfo.index),
    tonumber(self.parameters.ioddInfo.processDataConditionInfo.subindex),
    json.encode(dataToWrite)
  )
  if not writeSuccess then return false end
  local readSuccess, jsonConditionValue = CSK_MultiIOLinkSMI.readParameter(
    tonumber(self.parameters.ioddInfo.processDataConditionInfo.index),
    tonumber(self.parameters.ioddInfo.processDataConditionInfo.subindex)
  )
  if not readSuccess then return false end
  local conditionValueFormat = json.decode(jsonConditionValue)
  if tostring(conditionValueFormat.value) ~= tostring(newConditionValue) then
    return false
  end
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddInfo.ioddInstanceId)
  CSK_IODDInterpreter.changeProcessDataStructureOptionValue(newConditionValue)
  for messageName, messageConfig in pairs(self.parameters.ioddReadMessages) do
    CSK_IODDInterpreter.setSelectedInstance(messageConfig.ioddInstanceId)
    CSK_IODDInterpreter.changeProcessDataStructureOptionValue(newConditionValue)
  end
  for messageName, messageConfig in pairs(self.parameters.ioddWriteMessages) do
    CSK_IODDInterpreter.setSelectedInstance(messageConfig.ioddInstanceId)
    CSK_IODDInterpreter.changeProcessDataStructureOptionValue(newConditionValue)
  end
  return true
end

-- Function to apply a new process data condition string name to change a structure of a process data.
---@param newConditionName auto Condition name of the new process data structure.  
function multiIOLinkSMI:setProcessDataConditionName(newConditionName)
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddInfo.ioddInstanceId)
  local newConditionValue = CSK_IODDInterpreter.getProcessDataConditionValueFromName(newConditionName)
  local success = self:setProcessDataConditionValue(newConditionValue)
  if success then
    self.parameters.ioddInfo.currentCondition = newConditionName
  end
end

--*************************************************************************
--******************** IODD Read messages scope ***************************
--*************************************************************************

--- Function to create a read message and instance for the message in CSK_Module_IODDInterpreter
function multiIOLinkSMI:createIODDReadMessage()
  local index = 0
  local messageName = 'input_data'
  while self.parameters.ioddReadMessages[messageName] do
    index = index + 1
    messageName = 'input_data' .. tostring(index)
  end
  self.parameters.ioddReadMessages[messageName] = {
    triggerType = 'Periodic',
    triggerValue = 1000,
    ioddInstanceId = self.parameters.ioddInfo.ioddInstanceId .. '_ReadMessage_' .. messageName
  }
  CSK_IODDInterpreter.addInstance()
  CSK_IODDInterpreter.setInstanceName(self.parameters.ioddReadMessages[messageName].ioddInstanceId)
  CSK_IODDInterpreter.setSelectedIODD(self.parameters.ioddInfo.ioddName)
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddReadMessages[messageName].ioddInstanceId)
  if self.parameters.ioddInfo.isProcessDataVariable then
    CSK_IODDInterpreter.changeProcessDataStructureOptionName(
      self.parameters.ioddInfo.currentCondition
    )
  end
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddReadMessages[messageName].ioddInstanceId)
  return messageName
end

--- Function to rename an IODD message and instance in CSK_Module_IODDInterpreter
---@param oldName string Current name of the IODD message to be renamed
---@param newName string New name of the IODD message
function multiIOLinkSMI:renameIODDReadMessage(oldName, newName)
  self.parameters.ioddReadMessages[newName] = helperFuncs.copy(self.parameters.ioddReadMessages[oldName])
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddReadMessages[oldName].ioddInstanceId)
  self.parameters.ioddReadMessages[newName].ioddInstanceId = self.parameters.ioddInfo.ioddInstanceId .. '_ReadMessage_' .. newName
  CSK_IODDInterpreter.setInstanceName(self.parameters.ioddReadMessages[newName].ioddInstanceId)
  self.parameters.ioddReadMessages[oldName] = nil
end

--- Function to delete an IODD message and instance in CSK_Module_IODDInterpreter
---@param messageToDelete string Message to delete
function multiIOLinkSMI:deleteIODDReadMessage(messageToDelete)
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddReadMessages[messageToDelete].ioddInstanceId)
  CSK_IODDInterpreter.deleteInstance()
  self.parameters.ioddReadMessages[messageToDelete] = nil
end

--*************************************************************************
--******************** IODD Write messages scope **************************
--*************************************************************************

--- Function to create a write message and instance for the message in CSK_Module_IODDInterpreter
function multiIOLinkSMI:createIODDWriteMessage()
  local index = 0
  local messageName = 'output_data'
  while self.parameters.ioddWriteMessages[messageName] do
    index = index + 1
    messageName = 'output_data' .. tostring(index)
  end
  self.parameters.ioddWriteMessages[messageName] = {
    triggerType = 'Periodic',
    triggerValue = 1000,
    ioddInstanceId = self.parameters.ioddInfo.ioddInstanceId .. '_WriteMessage_' .. messageName
  }
  CSK_IODDInterpreter.addInstance()
  CSK_IODDInterpreter.setInstanceName(self.parameters.ioddWriteMessages[messageName].ioddInstanceId)
  CSK_IODDInterpreter.setSelectedIODD(self.parameters.ioddInfo.ioddName)
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddWriteMessages[messageName].ioddInstanceId)
  if self.parameters.ioddInfo.isProcessDataVariable then
    CSK_IODDInterpreter.changeProcessDataStructureOptionName(
      self.parameters.ioddInfo.currentCondition
    )
  end
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddWriteMessages[messageName].ioddInstanceId)
  return messageName
end

--- Function to rename an IODD message and instance in CSK_Module_IODDInterpreter
---@param oldName string Current name of the IODD message to be renamed
---@param newName string New name of the IODD message
function multiIOLinkSMI:renameIODDWriteMessage(oldName, newName)
  self.parameters.ioddWriteMessages[newName] = helperFuncs.copy(self.parameters.ioddWriteMessages[oldName])
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddWriteMessages[oldName].ioddInstanceId)
  self.parameters.ioddWriteMessages[newName].ioddInstanceId = self.parameters.ioddInfo.ioddInstanceId .. '_WriteMessage_' .. newName
  CSK_IODDInterpreter.setInstanceName(self.parameters.ioddWriteMessages[newName].ioddInstanceId)
  self.parameters.ioddWriteMessages[oldName] = nil
end

--- Function to delete an IODD message and instance in CSK_Module_IODDInterpreter
---@param messageToDelete string Message to delete
function multiIOLinkSMI:deleteIODDWriteMessage(messageToDelete)
  CSK_IODDInterpreter.setSelectedInstance(self.parameters.ioddWriteMessages[messageToDelete].ioddInstanceId)
  CSK_IODDInterpreter.deleteInstance()
  self.parameters.ioddWriteMessages[messageToDelete] = nil
end

return multiIOLinkSMI
--*************************************************************************
--********************** End Function Scope *******************************
--*************************************************************************