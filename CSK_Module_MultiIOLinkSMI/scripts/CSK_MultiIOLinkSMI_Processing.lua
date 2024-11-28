---@diagnostic disable: undefined-global, need-check-nil, missing-parameter, redundant-parameter

local nameOfModule = 'CSK_MultiIOLinkSMI'

-- If App property "LuaLoadAllEngineAPI" is FALSE, use this to load and check for required APIs
-- This can improve performance of garbage collection
local availableAPIs = require('Communication/MultiIOLinkSMI/helper/checkAPIs') -- can be used to adjust function scope of the module related on available APIs of the device
-------------------------------------------------------------------------------------

--Logger
_G.logger = Log.SharedLogger.create('ModuleLogger')

local converter = require('Communication/MultiIOLinkSMI/helper/DataConverter')
local json = require('Communication/MultiIOLinkSMI/helper/Json')
local helperFuncs = require "Communication.MultiIOLinkSMI.helper.funcs"

local scriptParams = Script.getStartArgument() -- Get parameters from model

local multiIOLinkSMIInstanceNumber = scriptParams:get('multiIOLinkSMIInstanceNumber') -- number of this instance
local multiIOLinkSMIInstanceNumberString = tostring(multiIOLinkSMIInstanceNumber) -- number of this instance as string

-- Event to notify result of processing
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewResult" .. multiIOLinkSMIInstanceNumberString, "MultiIOLinkSMI_OnNewResult" .. multiIOLinkSMIInstanceNumberString, 'bool') -- Edit this accordingly
-- Event to forward content from this thread to Controller to show e.g. on UI
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueToForward".. multiIOLinkSMIInstanceNumberString, "MultiIOLinkSMI_OnNewValueToForward" .. multiIOLinkSMIInstanceNumberString, 'string, auto')
-- Event to forward update of e.g. parameter update to keep data in sync between threads
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueUpdate" .. multiIOLinkSMIInstanceNumberString, "MultiIOLinkSMI_OnNewValueUpdate" .. multiIOLinkSMIInstanceNumberString, 'int, string, auto, int:?')

local processingParams = {}
processingParams.SMIhandle = scriptParams:get('SMIhandle')
processingParams.activeInUi = false
processingParams.name = scriptParams:get('name')
processingParams.active = scriptParams:get('active')
processingParams.port = scriptParams:get('port')
processingParams.showLiveValue = false

local ioddReadMessages = {} -- table with configured read messages
local ioddReadMessagesTimers = {} -- table with timers for read messages with periodic type
local ioddReadMessagesRegistrations = {} --  table with local functions registrations of read messages to be able to deregister the events

local ioddReadMessagesQueue = Script.Queue.create() -- Queue of read messages requests to control the queue overflow

local ioddLatestReadMessages = {} -- table with latest read messages
local ioddReadMessagesResults = {} -- table with latest results of reading messages

local ioddWriteMessages = {} -- table with configured write messages
local ioddWriteMessagesQueue = Script.Queue.create() -- Queue of write messages requests to control the queue overflow

local ioddLatesWriteMessages = {} -- table with latest write messages
local ioddWriteMessagesResults = {} -- table with latest results of writing messages

local portStatus = 'PORT_NOT_ACTIVE' -- Status of port
local readMessageTimerActive = true -- -- Status if read Message timers should run

-------------------------------------------------------------------------------------
-- Reading process data -------------------------------------------------------------
-------------------------------------------------------------------------------------

--- Read process data and check it's validity
---@return binary? Raw received process data
local function readBinaryProcessData()
  if portStatus ~= 'NO_DEVICE' and portStatus ~= 'DEACTIVATED' and portStatus ~= 'PORT_NOT_ACTIVE' and portStatus ~= 'PORT_POWER_OFF' and portStatus ~= 'NOT_AVAILABLE' then
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
  else
    return nil
  end
end

--- Read process data with provided info from IODD interpreter (as Lua table) and convert it to a meaningful Lua table
---@param dataPointInfo table Table containing process data info from IODD file
---@return bool success Read success
---@return table? convertedResult Interpted read data
local function readProcessData(dataPointInfo)
  local rawData = readBinaryProcessData()
  if rawData == nil then
    return false, converter.getFailedReadProcessDataResult(dataPointInfo)
  end
  local success, convertedResult = pcall(converter.getReadProcessDataResult, rawData, dataPointInfo)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert process data after reading on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString)
    return false, converter.getFailedReadProcessDataResult(dataPointInfo)
  end
  return success, convertedResult
end

--- Read process data with provided info from IODD interpreter (as JSON table) and convert it to a meaningful JSON table.
---@param jsonDataPointInfo string JSON table containing process data info from IODD file
---@return string? convertedResult JSON table with interpted read data
local function readProcessDataIODD(jsonDataPointInfo)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  local success, readData = readProcessData(dataPointInfo)
  if not success then
    return nil
  end
  return json.encode(readData)
end
Script.serveFunction('CSK_MultiIOLinkSMI.readProcessDataIODD_' .. multiIOLinkSMIInstanceNumberString, readProcessDataIODD, 'string:1:', 'auto:?:')

--Read process data and return it as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
---@return string? byteArrayData JSON array with decimal values
local function readProcessDataByteArray()
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
Script.serveFunction('CSK_MultiIOLinkSMI.readProcessDataByteArray_' .. multiIOLinkSMIInstanceNumberString, readProcessDataByteArray, '', 'auto:?:')

-------------------------------------------------------------------------------------
-- Writing process data -------------------------------------------------------------
-------------------------------------------------------------------------------------

--- Write process data and return success of writing
---@param data binary Process data to be written
---@return bool success Success of writing
---@return string? details Detailed error if writing is not successful
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

--- Write process data with provided info from IODD interpreter and data to write (as Lua tables)
---@param dataPointInfo table Table containing process data info from IODD file
---@param dataToWrite table Table with process data to be written
---@return bool success Success of writing
---@return string? details Detailed error if writing is not successful
local function writeProcessData(dataPointInfo, dataToWrite)
  local success, rawDataToWrite = pcall(converter.getBinaryDataToWrite, dataPointInfo, dataToWrite)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert process data for writing on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString .. '; datapointInfo ' .. tostring(json.encode(dataPointInfo)) .. '; writing data ' .. tostring(json.encode(dataToWrite)))
    return false, 'failed to convert data'
  end
  return writeBinaryProcessData(rawDataToWrite)
end

--Write process data with provided info from IODD interpreter and data to write (as JSON tables)
---@param jsonDataPointInfo string JSON table containing process data info from IODD file.
---@param jsonData string JSON table with process data to be written.
---@return bool success Success of writing.
---@return string? details Detailed error if writing is not successful.
local function writeProcessDataIODD(jsonDataPointInfo, jsonData)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  return writeProcessData(dataPointInfo, json.decode(jsonData))
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeProcessDataIODD_' .. multiIOLinkSMIInstanceNumberString, writeProcessDataIODD, 'string:1:,string:1:', 'bool:1:,string:?:')

--Write process data as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
---@param jsonData string JSON byte array with process data to be written.
---@return bool success Success of writing.
---@return string? details Detailed error if writing is not successful.
local function writeProcessDataByteArray(jsonData)
  local data = json.decode(jsonData)
  local binaryDataToWrite = ''
  for _, byte in ipairs(data.value) do
    binaryDataToWrite = binaryDataToWrite .. string.pack('I1', byte)
  end
  return writeBinaryProcessData(binaryDataToWrite)
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeProcessDataByteArray_' .. multiIOLinkSMIInstanceNumberString, writeProcessDataByteArray, 'string:1:', 'bool:1:,string:?:')

-------------------------------------------------------------------------------------
-- Reading service data (Parameter) -------------------------------------------------
-------------------------------------------------------------------------------------

--- Read parameter with given index and subindex
---@param index int Index of the parameter to read
---@param subindex int Subindex of the parameter to read
---@return binary? Raw received parameter value
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

--- Read parameter with provided info from IODD interpreter (as Lua table) and convert it to a meaningful Lua table
---@param dataPointInfo table Table containing parameter info from IODD file
---@return bool success Read success
---@return table? convertedResult Interpted parameter value
local function readParameter(dataPointInfo)
  local rawData = readBinaryServiceData(tonumber(dataPointInfo.index), tonumber(dataPointInfo.subindex))
  if rawData == nil then
    return false, converter.getFailedReadServiceDataResult(dataPointInfo)
  end
  local success, convertedResult = pcall(converter.getReadServiceDataResult, rawData, dataPointInfo)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert parameter after reading on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString ..'; datapoint info: ' .. tostring(json.encode(dataPointInfo)))
    return false, converter.getFailedReadServiceDataResult(dataPointInfo)
  end
  return true, convertedResult
end

--Read parameter with provided info from IODD interpreter (as JSON table) and convert it to a meaningful JSON table
---@param index auto Index of the parameter.
---@param subindex auto Subindex of the parameter.
---@param jsonDataPointInfo string JSON table containing parameter info from IODD file.
---@return string? jsonData JSON table with interpted parameter value.
local function readParameterIODD(index, subindex, jsonDataPointInfo)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  dataPointInfo.index = index
  dataPointInfo.subindex = subindex
  local success, readData = readParameter(dataPointInfo)
  if not success then
    return nil
  end
  return json.encode(readData)
end
Script.serveFunction('CSK_MultiIOLinkSMI.readParameterIODD_' .. multiIOLinkSMIInstanceNumberString, readParameterIODD, 'auto:1:,auto:1:,string:1:', 'string:?:')

--Read paramerter and return it as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
---@param index auto Index of the parameter.
---@param subindex auto Subindex of the parameter.
---@return string? byteArrayData JSON array with decimal values.
local function readParameterByteArray(index, subindex)
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
Script.serveFunction('CSK_MultiIOLinkSMI.readParameterByteArray_' .. multiIOLinkSMIInstanceNumberString, readParameterByteArray, 'auto:1:,auto:1:', 'auto:?:')

-------------------------------------------------------------------------------------
-- Writing service data (Parameter) -------------------------------------------------
-------------------------------------------------------------------------------------

--- Write parameter with given index and subindex
---@param index auto Index of the parameter.
---@param subindex auto Subindex of the parameter.
---@param binData binary Parameter value to be written
---@return bool success Success of writing
---@return string? details Detailed error if writing is not successful
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

--- Write parameter with provided info from IODD interpreter and data to write (as Lua tables)
---@param dataPointInfo table Table containing parameter info from IODD file
---@param dataToWrite table Table with parameter value to be written
---@return bool success Success of writing
---@return string? details Detailed error if writing is not successful
local function writeParameter(dataPointInfo, dataToWrite)
  local success, binDataToWrite = pcall(converter.getBinaryDataToWrite, dataPointInfo, dataToWrite)
  if not success then
    _G.logger:warning(nameOfModule..': failed to convert parameter for writing on port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString ..'; datapoint info: ' .. tostring(json.encode(dataPointInfo)) .. '; data: ' .. tostring(json.encode(dataToWrite)))
    return false, 'failed to convert data'
  end
  return writeBinaryServiceData(tonumber(dataPointInfo.index), tonumber(dataPointInfo.subindex), binDataToWrite)
end

--Write parameter with provided info from IODD interpreter and data to write (as JSON tables).
---@param index auto Index of the parameter.
---@param subindex auto Subindex of the parameter.
---@param jsonDataPointInfo string JSON table containing parameter info from IODD file.
---@param jsonDataToWrite string JSON table with parameter value to be written.
---@return bool success Success of writing.
---@return string? details Detailed error if writing is not successful.
local function writeParameterIODD(index, subindex, jsonDataPointInfo, jsonDataToWrite)
  local dataPointInfo = converter.renameDatatype(json.decode(jsonDataPointInfo))
  dataPointInfo.index = index
  dataPointInfo.subindex = subindex
  return writeParameter(dataPointInfo, json.decode(jsonDataToWrite))
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeParameterIODD_' .. multiIOLinkSMIInstanceNumberString, writeParameterIODD, 'auto:1:,auto:1,string:1:,string:1:', 'bool:1:,string:?:')

--Write parameter as byte array in IO-Link JSON standard, for example:
--{
--  "value":[232,12,1]
--}
---@param index auto Index of the parameter.
---@param subindex auto Subindex of the parameter.
---@param jsonDataToWrite string JSON byte array with parameter value to be written.
---@return bool success Success of writing.
---@return string? details Detailed error if writing is not successful.
local function writeParameterByteArray(index, subindex, jsonDataToWrite)
  local dataToWrite = json.decode(jsonDataToWrite)
  local binaryDataToWrite = ''
  for _, byte in ipairs(dataToWrite.value) do
    binaryDataToWrite = binaryDataToWrite .. string.pack('I1', byte)
  end
  return writeBinaryServiceData(tonumber(index), tonumber(subindex), binaryDataToWrite)
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeParameterByteArray_' .. multiIOLinkSMIInstanceNumberString, writeParameterByteArray, 'auto:1:,auto:1:,string:1:', 'bool:1:,string:?:')

-------------------------------------------------------------------------------------
-- Preconfigured IODD Messages scope ------------------------------------------------
-------------------------------------------------------------------------------------
-- Read Messages --------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Read preconfigured message
---@param messageName string Name of the message to read.
---@return bool success Success of reading.
---@return string? jsonMessageContent JSON table with received message content.
local function readIODDMessage(messageName)
  if not ioddReadMessages[messageName] or not ioddReadMessages[messageName].dataInfo then
    return false, "No data selected for read"
  end
  local success = true
  local messageContent = {}
  local includeDataMode = (ioddReadMessages[messageName].dataInfo.ProcessData and ioddReadMessages[messageName].dataInfo.Parameters)
  if ioddReadMessages[messageName].dataInfo.ProcessData then
    local readSuccess, receivedData = readProcessData(ioddReadMessages[messageName].dataInfo.ProcessData)
    if not readSuccess then
      success = false
    end
    if includeDataMode then
      messageContent.ProcessData = receivedData
    else
      messageContent = receivedData
    end
  end
  if ioddReadMessages[messageName].dataInfo.Parameters then
    if includeDataMode then
      messageContent.Parameters = {}
    end
    for dataPointID, dataPointInfo in pairs(ioddReadMessages[messageName].dataInfo.Parameters) do
      local readSuccess, receivedData = readParameter(dataPointInfo)
      if not readSuccess then
        success = false
      end
      if includeDataMode then
        messageContent.Parameters[dataPointID] = receivedData
      else
        messageContent[dataPointID] = receivedData
      end
    end
  end
  local jsonMessageContent = json.encode(messageContent)
  ioddReadMessagesResults[messageName] = success
  ioddLatestReadMessages[messageName] = jsonMessageContent
  return success, jsonMessageContent
end
Script.serveFunction('CSK_MultiIOLinkSMI.readIODDMessage' .. multiIOLinkSMIInstanceNumberString, readIODDMessage, 'string:1:', 'bool:1:,string:?:')

--- Update configuration of read messages
local function updateIODDReadMessages()
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
    local localEventName = "OnNewReadMessage_" .. processingParams.port .. '_' .. messageName
    local crownEventName = "CSK_MultiIOLinkSMI." .. localEventName

    local function readTheMessage()
      if not processingParams.active then
        Script.notifyEvent(localEventName, false, ioddReadMessagesQueue:getSize(), 0,  nil, 'IOLink port is not active')
        return
      end
      local timestamp1 = DateTime.getTimestamp()
      local success, jsonMessageContent = readIODDMessage(messageName)
      local errorMessage = ''
      local queueSize = ioddReadMessagesQueue:getSize()
      if not success then
        errorMessage = errorMessage .. ' Failed to read data from device;'
      end
      if queueSize > 10 then
        _G.logger:warning(nameOfModule..': reading queue is building up, clearing the queue, port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString .. '; current queue: ' .. tostring(queueSize))
        errorMessage = errorMessage .. 'Queue is building up: ' .. tostring(queueSize) ..' clearing the queue'
        ioddReadMessagesQueue:clear()
      end
      local timestamp2 = DateTime.getTimestamp()
      Script.notifyEvent(localEventName, success, queueSize, timestamp2-timestamp1, jsonMessageContent, errorMessage)
    end

    if not Script.isServedAsEvent(crownEventName) then
      Script.serveEvent(crownEventName, localEventName, 'bool:1:,int:1:,int:1:,string:?:,string:?:')
    end
    if messageInfo.triggerType == "Periodic" then
      ioddReadMessagesTimers[messageName] = Timer.create()
      ioddReadMessagesTimers[messageName]:setPeriodic(true)
      ioddReadMessagesTimers[messageName]:setExpirationTime(messageInfo.triggerValue)
      ioddReadMessagesTimers[messageName]:register("OnExpired", readTheMessage)
      if readMessageTimerActive then
        ioddReadMessagesTimers[messageName]:start()
      end
    elseif messageInfo.triggerType == "On event" then
      Script.register(messageInfo.triggerValue, readTheMessage)
      if not ioddReadMessagesRegistrations[messageName] then
        ioddReadMessagesRegistrations[messageName] = {}
      end
      ioddReadMessagesRegistrations[messageName][messageInfo.triggerValue] = readTheMessage
    end
    table.insert(queueFunctions, readTheMessage)
    ::nextMessage::
  end
  ioddReadMessagesQueue:setFunction(queueFunctions)
end

-- Get the latest result of readinig message.
---@param messageName string Name of the message to get the latest data about.
---@return bool? success Latest success of reading.
---@return string? jsonMessageContent Latest JSON table with received message content.
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
-- Write preconfigured message.
---@param messageName string Name of the message to read.
---@param jsonDataToWrite string JSON table with message to be written.
---@return bool success Success of writing.
---@return string? details Detailed error if writing is not successful.
local function writeIODDMessage(messageName, jsonDataToWrite)
  local decodeSuccess, dataToWrite = pcall(json.decode, jsonDataToWrite)
  if not decodeSuccess then
    return false, 'The payload is not in required JSON format'
  end
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
      if not success and not errorMessage and errorCode then
        errorMessage = 'Error code:' .. errorCode .. ';'
      end
      messageWriteSuccess = messageWriteSuccess and success
    end
  end
  ioddLatesWriteMessages[messageName] = jsonDataToWrite
  ioddWriteMessagesResults[messageName] = messageWriteSuccess
  return messageWriteSuccess, errorMessage
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeIODDMessage' .. multiIOLinkSMIInstanceNumberString, writeIODDMessage, 'string:1:,string:1:',  'bool:1:,string:?:')

--- Update configuration of write messages
local function updateIODDWriteMessages()
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
      local errorMessage = ''
      local messageWriteSuccess, messageWriteErrorMessage = writeIODDMessage(messageName, jsonDataToWrite)
      local queueSize = ioddWriteMessagesQueue:getSize()
      if not messageWriteSuccess then
        errorMessage = errorMessage .. 'Failed to write data to device;'
      end
      if messageWriteErrorMessage then
        errorMessage = errorMessage .. messageWriteErrorMessage
      end

      if queueSize > 10 then
        _G.logger:warning(nameOfModule..': writing queue is building up, clearing the queue, port ' .. tostring(processingParams.port) .. ' instancenumber ' .. multiIOLinkSMIInstanceNumberString .. '; current queue: ' .. tostring(queueSize))
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
---@param messageName string Name of the message to get the latest data about.
---@return bool? success Latest success of writing.
---@return string? jsonMessageContent JSON table with latest sent message content.
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

--- Activate or deactivate instance
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

--- Function to handle updates of processing parameters from Controller
---@param multiIOLinkSMINo int Number of instance to update
---@param parameter string Parameter to update
---@param value auto Value of parameter to update
---@param internalObjectNo int? Number of object
local function handleOnNewProcessingParameter(multiIOLinkSMINo, parameter, value, internalObjectNo)

  if parameter == 'readMessageTimers' then
    readMessageTimerActive = value
    for readMessageName in pairs(ioddReadMessagesTimers) do
      if value == false then
        ioddReadMessagesTimers[readMessageName]:stop()
      else
        ioddReadMessagesTimers[readMessageName]:start()
      end
    end
  elseif multiIOLinkSMINo == multiIOLinkSMIInstanceNumber then -- set parameter only in selected script
    _G.logger:fine(nameOfModule .. ": Update parameter '" .. parameter .. "' of multiIOLinkSMIInstanceNo." .. tostring(multiIOLinkSMINo) .. " to value = " .. tostring(value))
    if parameter == "readMessages" then
      ioddReadMessages = json.decode(value)
      updateIODDReadMessages()
    elseif parameter == "writeMessages" then
      ioddWriteMessages = json.decode(value)
      updateIODDWriteMessages()
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

--- Function to react on change of port status
---@param instance int Instance ID.
---@param status string Port status.
local function handleOnNewIOLinkPortStatus(instance, status)
  if instance == multiIOLinkSMIInstanceNumber then
    portStatus = status
  end
end
Script.register('CSK_MultiIOLinkSMI.OnNewIOLinkPortStatus', handleOnNewIOLinkPortStatus)
