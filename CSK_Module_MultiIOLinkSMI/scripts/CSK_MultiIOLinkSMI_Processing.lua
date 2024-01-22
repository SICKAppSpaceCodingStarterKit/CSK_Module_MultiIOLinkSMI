---@diagnostic disable: undefined-global, need-check-nil, missing-parameter, redundant-parameter

local nameOfModule = 'CSK_MultiIOLinkSMI'

-- If App property "LuaLoadAllEngineAPI" is FALSE, use this to load and check for required APIs
-- This can improve performance of garbage collection
local availableAPIs = require('Communication/MultiIOLinkSMI/helper/checkAPIs') -- can be used to adjust function scope of the module related on available APIs of the device
-------------------------------------------------------------------------------------

_G.logger = Log.SharedLogger.create('ModuleLogger')

local converter = require('Communication/MultiIOLinkSMI/helper/DataConverter')
local json = require('Communication/MultiIOLinkSMI/helper/Json')
local helperFuncs = require "Communication.MultiIOLinkSMI.helper.funcs"

local scriptParams = Script.getStartArgument()
local multiIOLinkSMIInstanceNumber = scriptParams:get('multiIOLinkSMIInstanceNumber')
local multiIOLinkSMIInstanceNumberString = tostring(multiIOLinkSMIInstanceNumber)


local fwdEventName = "MultiIOLinkSMI_OnNewValueToForward" .. multiIOLinkSMIInstanceNumberString

Script.serveEvent("CSK_MultiIOLinkSMI.OnNewResult" .. multiIOLinkSMIInstanceNumberString, "MultiIOLinkSMI_OnNewResult" .. multiIOLinkSMIInstanceNumberString, 'bool') -- Edit this accordingly
-- Event to forward content from this thread to Controler to show e.g. on UI
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueToForward".. multiIOLinkSMIInstanceNumberString, fwdEventName, 'string, auto')

Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueUpdate" .. multiIOLinkSMIInstanceNumberString, "MultiIOLinkSMI_OnNewValueUpdate" .. multiIOLinkSMIInstanceNumberString, 'int, string, auto, int:?')

local processingParams = {}
processingParams.SMIhandle = scriptParams:get('SMIhandle')
processingParams.registeredEvent = scriptParams:get('registeredEvent')
processingParams.activeInUi = false
processingParams.name = scriptParams:get('name')
processingParams.active = scriptParams:get('active')
processingParams.port = scriptParams:get('port')
processingParams.showLiveValue = false


local ioddReadMessages = {}
local ioddReadMessagesTimers = {}
local ioddReadMessagesRegistrations = {}

local ioddReadMessagesQueue = Script.Queue.create()

local ioddLatestReadMessages = {}
local ioddReadMessagesResults = {}

local ioddWriteMessages = {}
local ioddWriteMessagesQueue = Script.Queue.create()

local ioddLatesWriteMessages = {}
local ioddWriteMessagesResults = {}

-------------------------------------------------------------------------------------
-- Reading process data -------------------------------------------------------------
-------------------------------------------------------------------------------------

--Read process data and check it's validity
local function readBinaryProcessData()
  local processData = IOLink.SMI.getPDIn(processingParams.SMIhandle, processingParams.port)
  -- Port qualifier definition
  -- Bit0 = Signal status Pin4
  -- Bit1 = Signal status Pin2
  -- Bit2-4 = Reserved
  -- Bit5 = Device available
  -- Bit6 = Device error
  -- Bit7 = Data valid
  if processData == nil then
    return nil
  end
  local portQualifier = string.byte(processData, 1)
  if portQualifier == nil then
    return nil
  end
  local dataValid = ((portQualifier & 0x80) or (portQualifier & 0xA0)) > 0
  if not dataValid then
    _G.logger:warning(nameOfModule..': failed to read process data on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString)
    return nil
  end
  return string.sub(processData, 3)
end

--Read process data with provided info from IODD interpreter (as Lua table) and convert it to a meaningful Lua table
local function readProcessData(dataPointInfo)
  local rawData = readBinaryProcessData()
  if rawData == nil then
    return nil
  end
  local success, convertedResult = pcall(converter.getReadProcessDataResult, rawData, dataPointInfo)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert process data after reading on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString)
    return nil
  end
  return convertedResult
end

--Read process data with provided info from IODD interpreter (as JSON table) and convert it to a meaningful JSON table
local function ReadProcessDataIODD(jsonDataPointInfo)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  local readData = readProcessData(dataPointInfo)
  if readData == nil then
    return nil
  end
  return json.encode(readData)
end
Script.serveFunction('CSK_MultiIOLinkSMI.ReadProcessDataIODD' .. multiIOLinkSMIInstanceNumberString, ReadProcessDataIODD, 'string:1:', 'auto:?:')

--Read process data and return it as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
local function ReadProcessDataByteArray()
  local rawData = readBinaryProcessData()
  if rawData == nil then
    return nil
  end
  local resultTable = {
    value = {}
  }
  for i = 1,#rawData do
    local byteDecValue = string.unpack('I1', string.sub(rawData, i,i))
    table.insert(resultTable.value, byteDecValue)
  end
  return json.encode(resultTable)
end
Script.serveFunction('CSK_MultiIOLinkSMI.ReadProcessDataByteArray' .. multiIOLinkSMIInstanceNumberString, ReadProcessDataByteArray, '', 'auto:?:')

-------------------------------------------------------------------------------------
-- Writing process data -------------------------------------------------------------
-------------------------------------------------------------------------------------

--Write process data and return success of writing
local function writeBinaryProcessData(data)
  -- Byte 1= Process data valid
  -- Byte 2= Byte length of data
  -- Byte 3= Data
  local l_data = string.char(0x01, #data+1) .. data
  local l_returnCode, detailErrorCode = IOLink.SMI.setPDOut(processingParams.SMIhandle, processingParams.port, l_data)
  if l_returnCode == "SUCCESSFUL" then
    return true, nil
  else
    _G.logger:warning(nameOfModule..': failed to write process data on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString ..'; code ' .. tostring(l_returnCode) .. '; error detail: ' .. tostring(detailErrorCode))
    return false, l_returnCode .. ', detailedError:' .. tostring(detailErrorCode)
  end
end

--Write process data with provided info from IODD interpreter and data to write (as Lua tables)
local function writeProcessData(dataPointInfo, dataToWrite)
  local success, rawDataToWrite = pcall(converter.getBinaryDataToWrite, dataPointInfo, dataToWrite)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert process data for writing on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString .. '; datapointInfo ' .. tostring(json.encode(dataPointInfo)) .. '; writing data ' .. tostring(json.encode(dataToWrite)))
    return false, 'failed to convert data'
  end
  return writeBinaryProcessData(rawDataToWrite)
end

--Write process data with provided info from IODD interpreter and data to write (as JSON tables)
local function WriteProcessDataIODD(jsonDataPointInfo, jsonData)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  return writeProcessData(dataPointInfo, json.decode(jsonData))
end
Script.serveFunction('CSK_MultiIOLinkSMI.WriteProcessDataIODD' .. multiIOLinkSMIInstanceNumberString, WriteProcessDataIODD, 'string:1:,string:1:', 'bool:1:,string:?:')

--Write process data as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
local function WriteProcessDataByteArray(jsonData)
  local data = json.decode(jsonData)
  local binaryDataToWrite = ''
  for _, byte in ipairs(data.value) do
    binaryDataToWrite = binaryDataToWrite .. string.pack('I1', byte)
  end
  return writeBinaryProcessData(binaryDataToWrite)
end
Script.serveFunction('CSK_MultiIOLinkSMI.WriteProcessDataByteArray' .. multiIOLinkSMIInstanceNumberString, WriteProcessDataByteArray, 'string:1:', 'bool:1:,string:?:')

-------------------------------------------------------------------------------------
-- Reading service data (Parameter) -------------------------------------------------
-------------------------------------------------------------------------------------

-- Read parameter with given index and subindex
local function readBinaryServiceData(index, subindex)
  local iolData, returnCode, errorDetails = IOLink.SMI.deviceRead(
    processingParams.SMIhandle,
    processingParams.port,
    index,
    subindex
  )
  if returnCode ~= "SUCCESSFUL" then
    _G.logger:warning(nameOfModule..': failed to read parameter on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString ..  '; code ' .. tostring(returnCode) ..'; error details info: ' .. tostring(errorDetails) .. '; index ' .. tostring(index) .. ' subindex ' .. tostring(subindex))
    return nil
  end
  return iolData
end

--Read parameter with provided info from IODD interpreter (as Lua table) and convert it to a meaningful Lua table
local function readParameter(dataPointInfo)
  local rawData = readBinaryServiceData(tonumber(dataPointInfo.index), tonumber(dataPointInfo.subindex))
  if rawData == nil then
    return nil
  end
  local success, convertedResult = pcall(converter.getReadServiceDataResult, rawData, dataPointInfo)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert parameter after reading on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString ..'; datapoint info: ' .. tostring(json.encode(dataPointInfo)))
    return nil
  end
  return convertedResult
end

--Read parameter with provided info from IODD interpreter (as JSON table) and convert it to a meaningful JSON table
local function ReadParameterIODD(index, subindex, jsonDataPointInfo)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  dataPointInfo.index = index
  dataPointInfo.subindex = subindex
  local readData = readParameter(dataPointInfo)
  if readData == nil then
    return nil
  end
  return json.encode(convertedResult)
end
Script.serveFunction('CSK_MultiIOLinkSMI.ReadParameterIODD' .. multiIOLinkSMIInstanceNumberString, ReadParameterIODD, 'auto:1:,auto:1:,string:1:', 'auto:?:')

--Read paramerter and return it as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
local function ReadParameterByteArray(index, subindex)
  local rawData = readBinaryServiceData(tonumber(index), tonumber(subindex))
  if rawData == nil then
    return nil
  end
  local resultTable = {
    value = {}
  }
  for i = 1,#rawData do
    local byteDecValue = string.unpack('I1', string.sub(rawData, i,i))
    table.insert(resultTable.value, byteDecValue)
  end
  return json.encode(resultTable)
end
Script.serveFunction('CSK_MultiIOLinkSMI.ReadParameterByteArray' .. multiIOLinkSMIInstanceNumberString, ReadParameterByteArray, 'auto:1:,auto:1:', 'auto:?:')


-------------------------------------------------------------------------------------
-- Writing service data (Parameter) -------------------------------------------------
-------------------------------------------------------------------------------------

-- Write parameter with given index and subindex
local function writeBinaryServiceData(index, subindex, binData)
  local l_returnCode, l_detailedError = IOLink.SMI.deviceWrite(
    processingParams.SMIhandle,
    processingParams.port,
    index,
    subindex,
    binData)
  if l_returnCode == "SUCCESSFUL" then
    return true
  else
    _G.logger:warning(nameOfModule..': failed to write parameter on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString ..  '; code ' .. tostring(l_returnCode) ..'; error details info: ' .. tostring(l_detailedError) .. '; index ' .. tostring(index) .. ' subindex ' .. tostring(subindex))
    return false, l_returnCode .. ', detailedError:' .. tostring(l_detailedError)
  end
end

--Write parameter with provided info from IODD interpreter and data to write (as Lua tables)
local function writeParameter(dataPointInfo, data)
  local success, rawDataToWrite = pcall(converter.getBinaryDataToWrite, dataPointInfo, data)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert parameter for writing on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString ..'; datapoint info: ' .. tostring(json.encode(dataPointInfo)) .. '; data: ' .. tostring(json.encode(data)))
    return false, 'failed to convert data'
  end
  return writeBinaryServiceData(tonumber(dataPointInfo.index), tonumber(dataPointInfo.subindex), rawDataToWrite)
end

--Write parameter with provided info from IODD interpreter and data to write (as JSON tables)
local function WriteParameterIODD(index, subindex, jsonDataPointInfo, jsonData)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  dataPointInfo.index = index
  dataPointInfo.subindex = subindex
  return writeParameter(dataPointInfo, json.decode(jsonData))
end
Script.serveFunction('CSK_MultiIOLinkSMI.WriteParameterIODD' .. multiIOLinkSMIInstanceNumberString, WriteParameterIODD, 'auto:1:,auto:1,string:1:,string:1:', 'bool:1:,string:?:')

--Write parameter as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
local function WriteParameterByteArray(index, subIndex, jsonData)
  local data = json.decode(jsonData)
  local binaryDataToWrite = ''
  for _, byte in ipairs(data.value) do
    binaryDataToWrite = binaryDataToWrite .. string.pack('I1', byte)
  end
  return writeBinaryServiceData(tonumber(index), tonumber(subIndex), binaryDataToWrite)
end
Script.serveFunction('CSK_MultiIOLinkSMI.WriteParameterByteArray' .. multiIOLinkSMIInstanceNumberString, WriteParameterByteArray, 'auto:1:,auto:1:,string:1:', 'bool:1:,string:?:')


-------------------------------------------------------------------------------------
-- Preconfigured IODD Messages scope ------------------------------------------------
-------------------------------------------------------------------------------------
-- Read Messages --------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Read preconfigured message
local function readIoddMessage(messageName)
  local success = true
  local messageContent = {}
  local includeDataMode = (ioddReadMessages[messageName].dataInfo.ProcessData and ioddReadMessages[messageName].dataInfo.Parameters)
  if ioddReadMessages[messageName].dataInfo.ProcessData then
    if includeDataMode then
      messageContent.ProcessData = {}
    end
    for dataPointID, dataPointInfo in pairs(ioddReadMessages[messageName].dataInfo.ProcessData) do
      local receivedData = readProcessData(dataPointInfo)
      if includeDataMode then
        messageContent.ProcessData[dataPointID] = receivedData
      else
        messageContent[dataPointID] = receivedData
      end
      if not receivedData then
        messageContent[dataPointID] = "nil"
        success = false
      end
    end
  end
  if ioddReadMessages[messageName].dataInfo.Parameters then
    if includeDataMode then
      messageContent.Parameters = {}
    end
    for dataPointID, dataPointInfo in pairs(ioddReadMessages[messageName].dataInfo.Parameters) do
      local receivedData = readParameter(dataPointInfo)
      if includeDataMode then
        messageContent.Parameters[dataPointID] = receivedData
      else
        messageContent[dataPointID] = receivedData
      end
      if not receivedData then
        messageContent[dataPointID] = "nil"
        success = false
      end
    end
  end
  local jsonMessageContent = json.encode(messageContent)
  ioddReadMessagesResults[messageName] = success
  ioddLatestReadMessages[messageName] = jsonMessageContent
  return success, jsonMessageContent
end
Script.serveFunction('CSK_MultiIOLinkSMI.readIoddMessage' .. multiIOLinkSMIInstanceNumberString, readIoddMessage, 'string:1:', 'bool:1:,string:?:')

-- Update configuration of read messages
local function updateIoddReadMessages()
  ioddReadMessagesResults = {}
  ioddLatestReadMessages = {}
  for messageName, ioddReadMessagesTimer in pairs(ioddReadMessagesTimers) do
    ioddReadMessagesTimer:stop()
    Script.releaseObject(ioddReadMessagesTimer)
  end
  for messageName, messageInfo in pairs(ioddReadMessagesRegistrations) do
    for eventName, functionInstance in pairs(messageInfo) do
      Script.deregister(eventName, functionInstance)
    end
  end
  ioddReadMessagesTimers = {}
  ioddReadMessagesRegistrations = {}
  for messageName, messageInfo in pairs(ioddReadMessages) do
    if helperFuncs.getTableSize(messageInfo.dataInfo) == 0 then
      goto nextMessage
    end
    for dataMode, dataModeInfo in pairs(messageInfo.dataInfo) do
      if dataMode == "ProcessData" or dataMode == "Parameters" then
        for dataPointID, dataPointInfo in pairs(dataModeInfo) do
          ioddReadMessages[messageName].dataInfo[dataMode][dataPointID] = converter.renameDatatype(dataPointInfo)
        end
      end
    end
    ::nextMessage::
  end
  local queueFunctions = {}
  for messageName, messageInfo in pairs(ioddReadMessages) do
    if helperFuncs.getTableSize(messageInfo.dataInfo) == 0 then
      goto nextMessage
    end
    local localEventName = "readMessage" .. processingParams.port .. messageName
    local crownEventName = "CSK_MultiIOLinkSMI." .. localEventName
    local function readTheMessage()
      if not processingParams.active then
        Script.notifyEvent(localEventName, false, ioddReadMessagesQueue:getSize(), 0,  nil)
        return
      end
      local timestamp1 = DateTime.getTimestamp()
      local success, jsonMessageContent = readIoddMessage(messageName)
      local errorMessage
      local queueSize = ioddReadMessagesQueue:getSize()
      if queueSize > 10 then
        _G.logger:warning(nameOfModule..': reading queue is building up, clearing the queue, port ' .. tostring(processingParams.portNumber) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString .. '; current queue: ' .. tostring(queueSize))
        errorMessage = 'Queue is building up: ' .. tostring(queueSize) ..' clearing the queue'
        ioddReadMessagesQueue:clear()
      end
      local timestamp2 = DateTime.getTimestamp()
      Script.notifyEvent(localEventName, success, queueSize, timestamp2-timestamp1,  jsonMessageContent, errorMessage)
    end
    if not Script.isServedAsEvent(crownEventName) then
      Script.serveEvent(crownEventName, localEventName, 'bool:1:,int:1:,int:1:,string:?:,string:?:')
    end
    if messageInfo.triggerType == "Periodic" then
      ioddReadMessagesTimers[messageName] = Timer.create()
      ioddReadMessagesTimers[messageName]:setPeriodic(true)
      ioddReadMessagesTimers[messageName]:setExpirationTime(messageInfo.triggerValue)
      ioddReadMessagesTimers[messageName]:register("OnExpired", readTheMessage)
      ioddReadMessagesTimers[messageName]:start()
    elseif messageInfo.triggerType == "On event" then
      Script.register(messageInfo.triggerValue, readTheMessage)
      if not ioddReadMessagesRegistrations[messageName] then
        ioddReadMessagesRegistrations[messageName] = {}
      end
      ioddReadMessagesRegistrations[messageName][messageInfo.triggerValue] = readTheMessage
    end
    table.insert(queueFunctions, readSources)
    ::nextMessage::
  end
  ioddReadMessagesQueue:setFunction(queueFunctions)
end

-- Get the latest result of readinig message
local function getReadDataResult(messageName)
  if not ioddReadMessagesResults[messageName] then
    return nil, nil
  end
  return ioddReadMessagesResults[messageName], ioddLatestReadMessages[messageName]
end
Script.serveFunction('CSK_MultiIOLinkSMI.getReadDataResult'.. multiIOLinkSMIInstanceNumberString, getReadDataResult, 'string:1:', 'bool:?:,string:?:')

-------------------------------------------------------------------------------------
-- Write Messages -------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Write preconfigured message
local function writeIoddMessage(messageName, jsonDataToWrite)
  local dataToWrite = json.decode(jsonDataToWrite)
  local errorMessage
  local messageWriteSuccess = true
  if ioddWriteMessages[messageName].dataInfo.ProcessData and ioddWriteMessages[messageName].dataInfo.Parameters == nil then
    dataToWrite = {ProcessData = dataToWrite}
  elseif ioddWriteMessages[messageName].dataInfo.ProcessData == nil and ioddWriteMessages[messageName].dataInfo.Parameters then
    dataToWrite = {Parameters = dataToWrite}
  end
  for dataMode, dataModeInfo in pairs(dataToWrite) do
    for dataPointID, dataPointDataToWrite in pairs(dataModeInfo) do
      local success = true
      local errorCode
      if dataMode == 'ProcessData' then
        success, errorCode = writeProcessData(ioddWriteMessages[messageName].dataInfo.ProcessData[dataPointID], dataPointDataToWrite)
      elseif dataMode == 'Parameters' then
        success, errorCode = writeParameter(ioddWriteMessages[messageName].dataInfo.Parameters[dataPointID], dataPointDataToWrite)
      end
      if errorCode then
        if not errorMessage then
          errorMessage = 'Error codes:'
        end 
        errorMessage = errorMessage.. '; ' .. errorCode
      end
      messageWriteSuccess = messageWriteSuccess and success
    end
  end
  ioddLatesWriteMessages[messageName] = jsonDataToWrite
  ioddWriteMessagesResults[messageName] = messageWriteSuccess
  return messageWriteSuccess, errorMessage
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeIoddMessage' .. multiIOLinkSMIInstanceNumberString, writeIoddMessage, 'string:1:,string:1:',  'bool:1:,string:?:')

-- Update configuration of write messages
local function updateIoddWriteMessages()
  ioddWriteMessagesResults = {}
  ioddLatesWriteMessages = {}
  for messageName, messageInfo in pairs(ioddWriteMessages) do
    if helperFuncs.getTableSize(messageInfo.dataInfo) == 0 then
      goto nextMessage
    end
    for dataMode, dataModeInfo in pairs(messageInfo.dataInfo) do
      if dataMode == "ProcessData" or dataMode == "Parameters" then
        for dataPointID, dataPointInfo in pairs(dataModeInfo) do
          ioddWriteMessages[messageName].dataInfo[dataMode][dataPointID] = converter.renameDatatype(dataPointInfo)
        end
      end
    end
    ::nextMessage::
  end
  local queueFunctions = {}
  for messageName, messageInfo in pairs(ioddWriteMessages) do
    local function writeDestinations(jsonDataToWrite)
      if not processingParams.active then
        return false, ioddWriteMessagesQueue:getSize(), 0
      end
      local timestamp1 = DateTime.getTimestamp()
      local messageWriteSuccess, errorMessage = writeIoddMessage(messageName, jsonDataToWrite)
      local queueSize = ioddWriteMessagesQueue:getSize()
      if queueSize > 10 then
        _G.logger:warning(nameOfModule..': writing queue is building up, clearing the queue, port ' .. tostring(processingParams.portNumber) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString .. '; current queue: ' .. tostring(queueSize))
        errorMessage = 'Queue is building up: ' .. tostring(queueSize) ..' clearing the queue'
        ioddWriteMessagesQueue:clear()
      end
      local timestamp2 = DateTime.getTimestamp()
      return messageWriteSuccess, queueSize, timestamp2-timestamp1, errorMessage
    end
    local functionName = "CSK_MultiIOLinkSMI.writeMessage" .. processingParams.port .. messageName
    if not Script.isServedAsFunction(functionName) then
      Script.serveFunction(functionName, writeDestinations, 'string:1:', 'bool:1:,int:1:,int:1,string:?:')
    end
    table.insert(queueFunctions, functionName)
  end
  ioddWriteMessagesQueue:setFunction(queueFunctions)
end

-- Get the latest result of writng message
local function getWriteDataResult(messageName)
  if not ioddWriteMessagesResults[messageName] then
    return nil, nil
  end
  return ioddWriteMessagesResults[messageName], ioddLatesWriteMessages[messageName]
end
Script.serveFunction('CSK_MultiIOLinkSMI.getWriteDataResult'.. multiIOLinkSMIInstanceNumberString, getWriteDataResult, 'string:1:', 'bool:?:,string:?:')

-------------------------------------------------------------------------------------
-- End of read write data -----------------------------------------------------------
-------------------------------------------------------------------------------------

-- Activate or deactivate instance
local function activateInstance()
  if processingParams.active and processingParams.port and processingParams.port ~= '' then
    local portConfig = IOLink.SMI.PortConfigList.create()
    portConfig:setPortMode('IOL_AUTOSTART')
    IOLink.SMI.setPortConfiguration(processingParams.SMIhandle, processingParams.port, portConfig)
  else
    local portConfig = IOLink.SMI.PortConfigList.create()
    portConfig:setPortMode('DEACTIVATED')
    IOLink.SMI.setPortConfiguration(processingParams.SMIhandle, processingParams.port, portConfig)
  end
  Script.sleep(200)
end

-- Function to handle updates of processing parameters
--@handleOnNewProcessingParameter(multiIOLinkSMINo:int,parameter:string,value:auto,internalObjectNo:int)
local function handleOnNewProcessingParameter(multiIOLinkSMINo, parameter, value, internalObjectNo)
  if multiIOLinkSMINo == multiIOLinkSMIInstanceNumber then -- set parameter only in selected script
    _G.logger:info(nameOfModule .. ": Update parameter '" .. parameter .. "' of multiIOLinkSMIInstanceNo." .. tostring(multiIOLinkSMINo) .. " to value = " .. tostring(value))
    if parameter == 'registeredEvent' then
      _G.logger:info(nameOfModule .. ": Register instance " .. multiIOLinkSMIInstanceNumberString .. " on event " .. value)
      if processingParams.registeredEvent ~= '' then
        Script.deregister(processingParams.registeredEvent, handleOnNewProcessing)
      end
      processingParams.registeredEvent = value
      Script.register(value, handleOnNewProcessing)
    elseif parameter == "readMessages" then
      ioddReadMessages = json.decode(value)
      updateIoddReadMessages()
    elseif parameter == "writeMessages" then
      ioddWriteMessages = json.decode(value)
      updateIoddWriteMessages()
    elseif parameter == 'active' then
      processingParams.active = value
      activateInstance()
    else
      processingParams[parameter] = value
    end
  elseif parameter == 'activeInUi' then
    processingParams[parameter] = false
  end
end
Script.register("CSK_MultiIOLinkSMI.OnNewProcessingParameter", handleOnNewProcessingParameter)
