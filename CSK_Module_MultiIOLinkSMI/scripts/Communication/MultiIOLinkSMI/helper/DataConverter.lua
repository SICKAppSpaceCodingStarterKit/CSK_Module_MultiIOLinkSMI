---@diagnostic disable: need-check-nil, missing-parameter, redundant-parameter

local helperFuncs = require('Communication/MultiIOLinkSMI/helper/funcs')
local converter = {}

local str2bool = {
  ["true"] = true,
  ["false"] = false
}

local bool2num = {
  [true] = 1,
  [false] = 0,
  ["true"] = 1,
  ["false"] = 0
}

-- Possible simple IO-Link data types: "BooleanT", "IntegerT", "UIntegerT", "Float32T", "StringT", "OctetStringT"
local function getDatatypeBitlength(datatypeInfo)
  if datatypeInfo.type == "BooleanT" then
    return 1
  elseif datatypeInfo.type == "IntegerT" or datatypeInfo.type == "UIntegerT" or datatypeInfo.type == "RecordT" then
    return tonumber(datatypeInfo.bitLength)
  elseif datatypeInfo.type == "Float32T" then
    return 32
  elseif datatypeInfo.type == "StringT" or datatypeInfo.type == "OctetStringT" then
    return tonumber(datatypeInfo.fixedLength)
  elseif datatypeInfo.type == "ArrayT" then
    return tonumber(datatypeInfo.count)*getDatatypeBitlength(datatypeInfo.Datatype)
  end
end
converter.getDatatypeBitlength = getDatatypeBitlength
-------------------------------------------------------------------------------------
-- Converts data to a binary data string
local function toBinaryData(dataType, dataLength, data)
  local l_binaryData
  if dataType == "SINT" or dataType == "INT" or dataType == "DINT" or dataType == "IntegerT" then
    data = tonumber(data)
    l_binaryData = string.pack(">i" .. dataLength, data)
  elseif dataType == "USINT" or dataType == "UINT" or dataType == "UDINT" or dataType == "UIntegerT" then
    data = tonumber(data)
    l_binaryData = string.pack(">I" .. dataLength, data)
  elseif dataType == "FLOAT" or dataType == "Float32T" then
    data = tonumber(data)
    l_binaryData = string.pack(">f", data)
  elseif dataType == "STRING" or dataType == "StringT" or dataType == "OctetStringT" then
    data = tostring(data)
    l_binaryData = string.pack("c" .. #data, data)
  elseif dataType == "BOOL" or dataType == "BooleanT" then
    if type(data) == "string" then
      data = str2bool[data]
    elseif type(data) == "number" then
      data = (data ~= 0)
    end
    local l_booleanAsNumber = 0
    if data then
      l_booleanAsNumber = 0xFF
    end
    l_binaryData = string.pack("B", l_booleanAsNumber)
  end
  return l_binaryData
end
converter.toBinaryData = toBinaryData



-------------------------------------------------------------------------------------
-- Converts binary value to a dedicated data type
local function toDataType(data, dataType)
  local l_temp
  local retValue
  if dataType == "BOOL" or dataType == "BooleanT" then
    l_temp = string.unpack("B", data)
    if l_temp == 0 then
      retValue = false
    else
      retValue = true
    end
  elseif dataType == "SINT" or dataType == "INT" or dataType == "DINT" or dataType == "IntegerT" then
    retValue = string.unpack(">i" .. #data, data)
  elseif dataType == "USINT" or dataType == "UINT" or dataType == "UDINT" or dataType == "UIntegerT" then
    retValue = string.unpack(">I" .. #data, data)
  elseif dataType == "FLOAT" or dataType == "Float32T" then
    retValue = string.unpack(">f", data)
  elseif dataType == "STRING" or dataType == "StringT" or dataType == "OctetStringT" then
    -- Remove zero termination of a a string
    local l_zeroTermination = string.find(data, utf8.char(0))
    if l_zeroTermination then
      retValue = string.sub(data, 1, l_zeroTermination - 1)
    else
      retValue = data
    end
  else
    retValue = data
  end
  return retValue
end
converter.toDataType = toDataType

-------------------------------------------------------------------------------------
-- Number to binary data string (hex)
local function toBinaryString(data, byteLength)
  local l_dataAsString = string.format("%02X", data)
  --Complete byte
  if #l_dataAsString % 2 > 0 then
    l_dataAsString = "0" .. l_dataAsString
  end
  -- Add zero padding bytes
  if #l_dataAsString < (byteLength * 2) then
    for _=1, byteLength - (#l_dataAsString /2) do
      l_dataAsString = "00" .. l_dataAsString
    end
  end
  local l_binString = ""
  local l_index = 1
  for l_idx = 1, #l_dataAsString, 2 do
    local part = string.char(
      0x2, string.unpack("B", string.sub(l_dataAsString, l_idx)),
      string.unpack("B", string.sub(l_dataAsString, l_idx + 1)))

    local num = string.unpack("s1", part, 1)
    l_binString = l_binString .. string.pack("B", tonumber(num, 16), l_index)
    l_index = l_index + 1
  end
  return l_binString
end
converter.toBinaryString = toBinaryString

-------------------------------------------------------------------------------------
-- Gets necessary bits out of the bytes
local function extract(n, field, width, byteLengthItem)
    -- Shift right by 'field' to get the bits starting at 'field' in the least significant bits
    local shifted = n << field
    -- Create a mask with 'width' bits set to 1
    local mask = (1 << width) - 1
    mask = mask << (byteLengthItem*8 - width)
    -- Apply the mask to isolate 'width' bits
    return shifted & mask
end

-- Bitwise processing of the incoming binary string
local function disassembleData(data, bitOffset, bitLength)
  local byteLength = string.len(data)
  local l_startBit = byteLength*8 - bitLength - bitOffset + 1
  local l_startByte = math.ceil(l_startBit / 8)
  local l_startBitInByte = (l_startBit-1) % 8
  local l_byteLengthItem = math.ceil(bitLength / 8)
  local l_dataAsNumber = string.unpack(">I" .. tostring(l_byteLengthItem), data, l_startByte)
  local l_extractedValue = extract(l_dataAsNumber, l_startBitInByte, bitLength, l_byteLengthItem)
  local l_asBinaryString = toBinaryString(l_extractedValue, l_byteLengthItem)

  return l_asBinaryString
end
converter.disassembleData = disassembleData

-- Read functions for each simple use case
local readConverters = {
  BooleanT = function(data)
    if string.unpack("B", data) == 0 then
      return false
    else
      return true
    end
  end,
  IntegerT = function(data)
    return string.unpack(">i" .. #data, data)
  end,
  UIntegerT = function(data)
    return string.unpack(">I" .. #data, data)
  end,
  Float32T = function(data)
    return string.unpack(">f", data)
  end,
  StringT = function(data)
    local l_zeroTermination = string.find(data, utf8.char(0))
    if l_zeroTermination then
      return string.sub(data, 1, l_zeroTermination - 1)
    else
      return data
    end
  end,
  OctetStringT = function(data)
    local l_zeroTermination = string.find(data, utf8.char(0))
    if l_zeroTermination then
      return string.sub(data, 1, l_zeroTermination - 1)
    else
      return data
    end
  end
}

-- Function for reading a subindex
local function getSimpleSubindexReadFunction(dataPointInfo, bitLength)
  local functionToReturn
  if tonumber(dataPointInfo.bitOffset) % 8 == 0 and getDatatypeBitlength(dataPointInfo) % 8 == 0 and bitLength % 8 == 0 then
    local startByteNew = bitLength / 8 - dataPointInfo.bitOffset/8 - getDatatypeBitlength(dataPointInfo)/8 + 1
    local endByteNew = bitLength / 8 - dataPointInfo.bitOffset/8
    functionToReturn = function(binData)
      return readConverters[dataPointInfo.type](string.sub(binData, startByteNew, endByteNew))
    end
  else
    local bitOffset = tonumber(dataPointInfo.bitOffset)
    local bitLength = getDatatypeBitlength(dataPointInfo)
    functionToReturn = function(binData)
      return readConverters[dataPointInfo.type](disassembleData(binData, bitOffset, bitLength))
    end
  end
  return functionToReturn
end

-- Function with no bitwise operations in case the type is simple
local function getSimpleIndexReadFunction(dataPointInfo)
  local functionToReturn = function(binData)
    return readConverters[dataPointInfo.type](binData)
  end
  return functionToReturn
end

-- Gets the fastest and simpliest function for each selected parameter
local function getParameterReadFunctions(parameterInfo)
  local parameterReadFunctions = {}
  if parameterInfo.info.type == 'ArrayT' or parameterInfo.info.type == 'RecordT' then
    for subindexId, subindexinfo in pairs(parameterInfo.subindeces) do
      parameterReadFunctions[subindexId] = {
        value = getSimpleSubindexReadFunction(subindexinfo.info, parameterInfo.info.BitLength)
      }
    end
  else
    parameterReadFunctions.value = getSimpleIndexReadFunction(parameterInfo.info)
  end
  return parameterReadFunctions
end
converter.getParameterReadFunctions = getParameterReadFunctions


-------------------------------------------------------------------------------------
-- Convert a raw binary data from IO-Link device to a meaningful Lua table
local function getReadServiceDataResult(binData, parameterInfo)
  local Result = {}
  if parameterInfo.info.type == 'ArrayT' or parameterInfo.info.type == 'RecordT' then
    for _, SingleItem in pairs(parameterInfo.subindeces) do
      local binaryData = disassembleData(binData, tonumber(SingleItem.info.bitOffset), getDatatypeBitlength(SingleItem.info))
      Result[SingleItem.info.Name] = {
        value = toDataType(binaryData, SingleItem.info.type)
      }
    end
  elseif parameterInfo.info then
    Result.value = toDataType(binData, parameterInfo.info.type)
  end
  return Result
end
converter.getReadServiceDataResult = getReadServiceDataResult

-------------------------------------------------------------------------------------
-- Convert a raw binary data from IO-Link device to a meaningful Lua table
local function getReadProcessDataResult(binData, processDataInfo)
  local resultData = {}
  for dataPointID, dataPointInfo in pairs(processDataInfo) do
    if dataPointInfo.info.type == 'RecordT' or dataPointInfo.info.type == 'ArrayT' then
      resultData[dataPointID] = getReadServiceDataResult(binData, dataPointInfo)
    else
      local offsetData = disassembleData(binData, tonumber(dataPointInfo.info.bitOffset), getDatatypeBitlength(dataPointInfo.info))
      resultData[dataPointID] = {value = toDataType(offsetData, dataPointInfo.info.type)}
    end
  end
  return resultData
end
converter.getReadProcessDataResult = getReadProcessDataResult

--Return a JSON payload of expacted format filled with null values in case reading of a Parameter has failed 
local function getFailedReadServiceDataResult(parameterInfo)
  local Result = {}
  if parameterInfo.info.type == 'ArrayT' or parameterInfo.info.type == 'RecordT' then
    for _, SingleItem in pairs(parameterInfo.subindeces) do
      Result[SingleItem.info.Name] = {
        value = "null"
      }
    end
  elseif parameterInfo.Datatype then
    Result.value = "null"
  end
  return Result
end
converter.getFailedReadServiceDataResult = getFailedReadServiceDataResult

--Return a JSON payload of expacted format filled with null values in case reading of a Process data has failed 
local function getFailedReadProcessDataResult(processDataInfo)
  local resultData = {}
  for dataPointID, dataPointInfo in pairs(processDataInfo) do
    if dataPointInfo.Datatype.type == 'RecordT' or dataPointInfo.Datatype.type == 'ArrayT' then
      resultData[dataPointID] = getFailedReadServiceDataResult(dataPointInfo)
    else
      resultData[dataPointID] = {value = "null"}
    end
  end
  return resultData
end
converter.getFailedReadProcessDataResult = getFailedReadProcessDataResult

local function toBitArrayPadded(num, bitLength)
    -- returns a table of bits, least significant first.
    local bits={} -- will contain the bits
    while num>0 do
        local rest=math.fmod(num,2)
        table.insert(bits, 1, math.ceil(rest))
        num=(num-rest)/2
    end
    while #bits<bitLength do
      table.insert(bits, 1, 0)
    end
    return bits
end

local function insertIntoBitArray(bitArray, data, dataType, startBit, bitLength)
  if  dataType == "BOOL" or dataType == "BooleanT" then
    local firstIndex =  #bitArray - startBit
    if type(data) == "number" then
      bitArray[firstIndex] = data
    else
      bitArray[firstIndex] = bool2num[data]
    end
  else
    local bitArrayToInsert = toBitArrayPadded(data, bitLength)
    local firstIndex = #bitArray - startBit - bitLength + 1
    local j = 1
    for i = firstIndex, firstIndex+bitLength-1 do
      bitArray[i] = bitArrayToInsert[j]
      j = j + 1
    end
    return bitArray
  end
end
converter.insertIntoBitArray = insertIntoBitArray

local function makeEmptyBitArray(size)
  local array = {}
  for i = 1, size do
    array[i] = 0
  end
  return array
end
converter.makeEmptyBitArray = makeEmptyBitArray

local function bitArray2Dec(bitArray)
  local bin = table.concat(bitArray)
  bin = string.reverse(bin)
  local sum = 0
  for i = 1, string.len(bin) do
    local num = string.sub(bin, i,i) == "1" and 1 or 0
    sum = sum + num * 2^(i-1)
  end
  return sum
end

local function cutFromArray(array, startIndex, endIndex)
  local result = {}
  if endIndex > #array then
    endIndex = #array
  end
  for i = startIndex, endIndex do
    table.insert(result, array[i])
  end
  return result
end

-------------------------------------------------------------------------------------
-- Conver Lua table of a complex type (array or record) to a binary data for writing to IO-Link device
local function getComplexServiceDataToWrite(parameterInfo, data)
    local bitArray
    local byteLength = math.ceil(getDatatypeBitlength(parameterInfo.info) / 8)
    if parameterInfo.info.type == 'ArrayT' or parameterInfo.info.type == 'RecordT' then
      bitArray = makeEmptyBitArray(getDatatypeBitlength(parameterInfo.info))
      for _, SingleItem in pairs(parameterInfo.subindeces) do
        insertIntoBitArray(
          bitArray,
          data[SingleItem.info.Name].value,
          SingleItem.info.type,
          tonumber(SingleItem.info.bitOffset),
          getDatatypeBitlength(SingleItem.info)
        )
      end
    end
    local bin = ''
    for i = 1, byteLength do
      local part = string.pack('I1', bitArray2Dec(cutFromArray(bitArray, (i-1)*8+1, i*8)))
      bin = bin..part
    end
    return bin
end
converter.getComplexServiceDataToWrite = getComplexServiceDataToWrite

-------------------------------------------------------------------------------------
-- Convert Lua table to a binary data for writing to IO-Link device
local function getBinaryDataToWrite(dataPointInfoInfo, data)
  if dataPointInfoInfo.info.type == 'ArrayT' or dataPointInfoInfo.info.type == 'RecordT' then
    return getComplexServiceDataToWrite(dataPointInfoInfo, data)
  else
    local test = toBinaryData(dataPointInfoInfo.info.type, math.ceil(getDatatypeBitlength(dataPointInfoInfo.info)/8), data.value)
    return test
  end
end
converter.getBinaryDataToWrite = getBinaryDataToWrite

return converter