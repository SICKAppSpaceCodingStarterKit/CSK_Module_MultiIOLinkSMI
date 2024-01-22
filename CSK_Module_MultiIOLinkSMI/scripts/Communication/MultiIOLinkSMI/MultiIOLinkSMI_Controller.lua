---@diagnostic disable: need-check-nil, missing-parameter, redundant-parameterm, ignore Script _APPNAME
--luacheck: no max line length, ignore CSK_PersistentData

--***************************************************************
-- Inside of this script, you will find the necessary functions,
-- variables and events to communicate with the MultiIOLinkSMI_Model and _Instances
--***************************************************************

--**************************************************************************
--************************ Start Global Scope ******************************
--**************************************************************************
local nameOfModule = 'CSK_MultiIOLinkSMI'

local funcs = {}

local json = require('Communication/MultiIOLinkSMI/helper/Json')
local helperFuncs = require('Communication/MultiIOLinkSMI/helper/funcs')
local jsonTableViewer = require('Communication.MultiIOLinkSMI.helper.jsonTableViewer')

local tmrMultiIOLinkSMI = Timer.create()
tmrMultiIOLinkSMI:setExpirationTime(500)
tmrMultiIOLinkSMI:setPeriodic(false)

local CrownName = 'CSK_MultiIOLinkSMI'

local PORT_EVENT_CODES = {
  [0x1800] = {name="No device", remark=""},
  [0x1801] = {name="Startup parametrization error", remark="Check parameter"},
  [0x1802] = {name="Incorrect VendorID", remark="Inspection Level mismatch"},
  [0x1803] = {name="Incorrect DeviceID", remark="Inspection Level mismatch"},
  [0x1804] = {name="Short circuit at C/Q", remark="Check wire connection"},
  [0x1805] = {name="PHY overtemperature", remark=""},
  [0x1806] = {name="Short circuit at L+", remark="Check wire connection"},
  [0x1807] = {name="Over current at L+", remark="Check power supply (e.g. L1+)"},
  [0x1808] = {name="Device Event overflow", remark=""},
  [0x1809] = {name="Backup inconsistency", remark="Memory out of range (2048 octets)"},
  [0x180A] = {name="Backup inconsistency", remark="Identity fault"},
  [0x180B] = {name="Backup inconsistency", remark="Data Storage unspecific error"},
  [0x180C] = {name="Backup inconsistency", remark="Upload fault"},
  [0x180D] = {name="Parameter inconsistency", remark="Download fault"},
  [0x180E] = {name="P24 (Class B) missing or undervoltage", remark=""},
  [0x180F] = {name="Short circuit at P24 (Class B)", remark="Check wire connection (e.g. L2+)"},
  [0x1810] = {name="Short circuit at I/Q", remark="Check wiring"},
  [0x1811] = {name="Short circuit at C/Q (if digital output)", remark="Check wiring"},
  [0x1812] = {name="Overcurrent at I/Q", remark="Check load"},
  [0x1813] = {name="Overcurrent at C/Q (if digital output)", remark="Check load"},
  [0x1F01] = {name="0x1F00 - 0x1FFF vendor specific", remark="Level of C/Q configured as digital in has changed"},
  [0x1F02] = {name="0x1F00 - 0x1FFF vendor specific", remark="Level of I/Q configured as digital in has changed"},
  [0x6000] = {name="Invalid cyclic time", remark=""},
  [0x6001] = {name="IOL revision fault", remark=""},
  [0x6002] = {name="ISDU batch failed", remark=""},
  [0xFF26] = {name="Port status changed", remark=""},
  [0xFF27] = {name="Content of data storage has been changed by any client", remark=""}
}

local availableIOLinkPorts = {}

-- Reference to global handle
local multiIOLinkSMI_Model
local multiIOLinkSMI_Instances
local selectedInstance = 1
local selectedIoddReadMessage = ''
local selectedIoddWriteMessage = ''
local selectedTab = 0
local testWriteProcessData = ''
local testReadParameterIndex = 0
local testReadParameterSubindex = 0
local testWriteParameterData = ''
local testWriteParameterIndex = 0
local testWriteParameterSubindex = 0
local testIoddMessageToWrite = ''
-- ************************ UI Events Start ********************************
-- Only to prevent WARNING messages, but these are only examples/placeholders for dynamically created events/functions
----------------------------------------------------------------
local function emptyFunction()
end
Script.serveFunction("CSK_MultiIOLinkSMI.processInstanceNUM", emptyFunction)
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewResultNUM", "MultiIOLinkSMI_OnNewResultNUM")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueToForwardNUM", "MultiIOLinkSMI_OnNewValueToForwardNUM")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueUpdateNUM", "MultiIOLinkSMI_OnNewValueUpdateNUM")

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewSelectedTab',                      'MultiIOLinkSMI_OnNewSelectedTab')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewDeviceIdentificationApplied',      'MultiIOLinkSMI_OnNewDeviceIdentificationApplied')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewIOLinkPortStatus',                 'MultiIOLinkSMI_OnNewIOLinkPortStatus')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPortStatus',                       'MultiIOLinkSMI_OnNewPortStatus')
Script.serveEvent('CSK_MultiIOLinkSMI.IsNewDeviceFound',                      'MultiIOLinkSMI_IsNewDeviceFound')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPortEvent',                        'MultiIOLinkSMI_OnNewPortEvent')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPortDropdown',                     'MultiIOLinkSMI_OnNewPortDropdown')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPort',                             'MultiIOLinkSMI_OnNewPort')
Script.serveEvent('CSK_MultiIOLinkSMI.isInstanceActive',                      'MultiIOLinkSMI_isInstanceActive')

Script.serveEvent('CSK_MultiIOLinkSMI.isCskIoddInterpreterAvailable',         'MultiIOLinkSMI_isCskIoddInterpreterAvailable')
Script.serveEvent('CSK_MultiIOLinkSMI.isIoddMatchFound',                      'MultiIOLinkSMI_isIoddMatchFound')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewFirmwareVersion',                  'MultiIOLinkSMI_OnNewFirmwareVersion')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewHardwareVersion',                  'MultiIOLinkSMI_OnNewHardwareVersion')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewSerialNumber',                     'MultiIOLinkSMI_OnNewSerialNumber')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewVendorId',                         'MultiIOLinkSMI_OnNewVendorId')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewVendorName',                       'MultiIOLinkSMI_OnNewVendorName')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewVendorText',                       'MultiIOLinkSMI_OnNewVendorText')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewProductId',                        'MultiIOLinkSMI_OnNewProductId')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewProductName',                      'MultiIOLinkSMI_OnNewProductName')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewProductText',                      'MultiIOLinkSMI_OnNewProductText')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceFirmwareVersion',         'MultiIOLinkSMI_OnNewNewDeviceFirmwareVersion')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceHardwareVersion',         'MultiIOLinkSMI_OnNewNewDeviceHardwareVersion')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceProductId',               'MultiIOLinkSMI_OnNewNewDeviceProductId')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceProductName',             'MultiIOLinkSMI_OnNewNewDeviceProductName')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceProductText',             'MultiIOLinkSMI_OnNewNewDeviceProductText')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceSerialNumber',            'MultiIOLinkSMI_OnNewNewDeviceSerialNumber')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceVendorId',                'MultiIOLinkSMI_OnNewNewDeviceVendorId')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceVendorText',              'MultiIOLinkSMI_OnNewNewDeviceVendorText')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewNewDeviceVendorName',              'MultiIOLinkSMI_OnNewNewDeviceVendorName')

Script.serveEvent('CSK_MultiIOLinkSMI.isProcessDataVariable',                 'MultiIOLinkSMI_isProcessDataVariable')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewProcessDataCondition',             'MultiIOLinkSMI_OnNewProcessDataCondition')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewListProcessDataCondition',         'MultiIOLinkSMI_OnNewListProcessDataCondition')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewListIoddReadMessages',             'MultiIOLinkSMI_OnNewListIoddReadMessages')
Script.serveEvent('CSK_MultiIOLinkSMI.isIoddReadMessageSelected',             'MultiIOLinkSMI_isIoddReadMessageSelected')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewSelectedIoddReadMessage',          'MultiIOLinkSMI_OnNewSelectedIoddReadMessage')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewTriggerType',                      'MultiIOLinkSMI_OnNewTriggerType')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewTriggerValue',                     'MultiIOLinkSMI_OnNewTriggerValue')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewListIoddWriteMessages',            'MultiIOLinkSMI_OnNewListIoddWriteMessages')
Script.serveEvent('CSK_MultiIOLinkSMI.isIoddWriteMessageSelected',            'MultiIOLinkSMI_isIoddWriteMessageSelected')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewSelectedIoddWriteMessage',         'MultiIOLinkSMI_OnNewSelectedIoddWriteMessage')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewTestWriteIoddMessage',             'MultiIOLinkSMI_OnNewTestWriteIoddMessage')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewReadMessageEventName',             'MultiIOLinkSMI_OnNewReadMessageEventName')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewWriteMessageFunctionName',         'MultiIOLinkSMI_OnNewWriteMessageFunctionName')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewReadJSONTemplate',                 'MultiIOLinkSMI_OnNewReadJSONTemplate')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewWriteJSONTemplate',                'MultiIOLinkSMI_OnNewWriteJSONTemplate')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewReadDataMessage',                  'MultiIOLinkSMI_OnNewReadDataMessage')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewReadDataSuccess',                  'MultiIOLinkSMI_OnNewReadDataSuccess')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewWriteDataMessage',                 'MultiIOLinkSMI_OnNewWriteDataMessage')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewWriteDataSuccess',                 'MultiIOLinkSMI_OnNewWriteDataSuccess')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewReadParameterByteArray',           'MultiIOLinkSMI_OnNewReadParameterByteArray')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewReadProcessDataByteArray',         'MultiIOLinkSMI_OnNewReadProcessDataByteArray')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewTestCommandState',                 'MultiIOLinkSMI_OnNewTestCommandState')

Script.serveEvent("CSK_MultiIOLinkSMI.OnNewStatusLoadParameterOnReboot", "MultiIOLinkSMI_OnNewStatusLoadParameterOnReboot")
Script.serveEvent("CSK_MultiIOLinkSMI.OnPersistentDataModuleAvailable", "MultiIOLinkSMI_OnPersistentDataModuleAvailable")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewParameterName", "MultiIOLinkSMI_OnNewParameterName")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewInstanceList", "MultiIOLinkSMI_OnNewInstanceList")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewProcessingParameter", "MultiIOLinkSMI_OnNewProcessingParameter")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewSelectedInstance", "MultiIOLinkSMI_OnNewSelectedInstance")
Script.serveEvent("CSK_MultiIOLinkSMI.OnDataLoadedOnReboot", "MultiIOLinkSMI_OnDataLoadedOnReboot")
Script.serveEvent("CSK_MultiIOLinkSMI.OnUserLevelOperatorActive", "MultiIOLinkSMI_OnUserLevelOperatorActive")
Script.serveEvent("CSK_MultiIOLinkSMI.OnUserLevelMaintenanceActive", "MultiIOLinkSMI_OnUserLevelMaintenanceActive")
Script.serveEvent("CSK_MultiIOLinkSMI.OnUserLevelServiceActive", "MultiIOLinkSMI_OnUserLevelServiceActive")
Script.serveEvent("CSK_MultiIOLinkSMI.OnUserLevelAdminActive", "MultiIOLinkSMI_OnUserLevelAdminActive")
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusModuleIsActive', 'MultiIOLinkSMI_OnNewStatusModuleIsActive')


--**************************************************************************
-- ************************ UI Events End **********************************
--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

-- Functions to forward logged in user roles via CSK_UserManagement module (if available)
-- ***********************************************
local function handleOnUserLevelOperatorActive(status)
  Script.notifyEvent("MultiIOLinkSMI_OnUserLevelOperatorActive", status)
end

local function handleOnUserLevelMaintenanceActive(status)
  Script.notifyEvent("MultiIOLinkSMI_OnUserLevelMaintenanceActive", status)
end

local function handleOnUserLevelServiceActive(status)
  Script.notifyEvent("MultiIOLinkSMI_OnUserLevelServiceActive", status)
end

local function handleOnUserLevelAdminActive(status)
  Script.notifyEvent("MultiIOLinkSMI_OnUserLevelAdminActive", status)
end
-- ***********************************************


-- Function to get access to the MultiIOLinkSMI_Model object
--@setMultiIOLinkSMI_Model_Handle(handle:table):
local function setMultiIOLinkSMI_Model_Handle(handle)
  multiIOLinkSMI_Model = handle
  Script.releaseObject(handle)
end
funcs.setMultiIOLinkSMI_Model_Handle = setMultiIOLinkSMI_Model_Handle

-- Function to forward updates from instance threads e.g. to UI
--@handleOnNewValueToForward(eventname:string,value:auto)
local function handleOnNewValueToForward(eventname, value)
  if eventname == 'MultiIOLinkSMI_OnNewReadJSONTemplate' then
    multiIOLinkSMI_Instances[selectedInstance].parameters.ReadJSONTemplate = value
  elseif eventname == 'MultiIOLinkSMI_OnNewWriteJSONTemplate' then
    multiIOLinkSMI_Instances[selectedInstance].parameters.WriteJSONTemplate = value
  end
  Script.notifyEvent(eventname, value)
end

-- Optionally
-- Only use if needed for extra internal objects -  see also Model
--@handleOnNewValueUpdate(instance:int,parameter:string,value:auto,selectedObject:int)
local function handleOnNewValueUpdate(instance, parameter, value, selectedObject)
  multiIOLinkSMI_Instances[instance].parameters.internalObject[selectedObject][parameter] = value
end

-- Function to get access to the MultiIOLinkSMI_Instances
--@setMultiIOLinkSMI_Instances_Handle(handle:table):
local function setMultiIOLinkSMI_Instances_Handle(handle)
  multiIOLinkSMI_Instances = handle
  if multiIOLinkSMI_Instances[selectedInstance].userManagementModuleAvailable then
    -- Register on events of CSK_UserManagement module if available
    Script.register('CSK_UserManagement.OnUserLevelOperatorActive', handleOnUserLevelOperatorActive)
    Script.register('CSK_UserManagement.OnUserLevelMaintenanceActive', handleOnUserLevelMaintenanceActive)
    Script.register('CSK_UserManagement.OnUserLevelServiceActive', handleOnUserLevelServiceActive)
    Script.register('CSK_UserManagement.OnUserLevelAdminActive', handleOnUserLevelAdminActive)
  end
  Script.releaseObject(handle)
  for i = 1, #multiIOLinkSMI_Instances do
    Script.register("CSK_MultiIOLinkSMI.OnNewValueToForward" .. tostring(i) , handleOnNewValueToForward)
    Script.register("CSK_MultiIOLinkSMI.OnNewValueUpdate" .. tostring(i) , handleOnNewValueUpdate)
  end
end
funcs.setMultiIOLinkSMI_Instances_Handle = setMultiIOLinkSMI_Instances_Handle

local function updateUserLevel()
  if multiIOLinkSMI_Instances[selectedInstance].userManagementModuleAvailable then
    -- Trigger CSK_UserManagement module to provide events regarding user role
    --CSK_UserManagement.pageCalled()
  else
    -- If CSK_UserManagement is not active, show everything
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelAdminActive", true)
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelMaintenanceActive", true)
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelServiceActive", true)
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelOperatorActive", true)
  end
end

local function updateAvailablePortList()
  availableIOLinkPorts = Engine.getEnumValues('IOLinkMasterPorts')
  for instanceNumber, instanceInfo in ipairs(multiIOLinkSMI_Instances) do
    if instanceNumber ~= selectedInstance then
      for i, portName in ipairs(availableIOLinkPorts) do
        if portName == instanceInfo.parameters.port then
          table.remove(availableIOLinkPorts, i)
          break
        end
      end
    end
  end
end

local bugFixCntr = 0

-- Function to send all relevant values to UI on resume
--@handleOnExpiredTmrMultiIOLinkSMI()
local function handleOnExpiredTmrMultiIOLinkSMI()
  if bugFixCntr == 1 then
    bugFixCntr = 2
  elseif bugFixCntr == 2 then
    bugFixCntr = 0
    return
  end
  if not _G.availableAPIs.ioLinkSmi then
    Script.notifyEvent('MultiIOLinkSMI_OnNewStatusModuleIsActive', false)
    return
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewStatusModuleIsActive', true)

  testWriteProcessData = ''
  testReadParameterIndex = 0
  testReadParameterSubindex = 0
  testWriteParameterData = ''
  testWriteParameterIndex = 0
  testWriteParameterSubindex = 0

  Script.notifyEvent('MultiIOLinkSMI_OnNewSelectedTab', selectedTab)
  Script.notifyEvent('MultiIOLinkSMI_isInstanceActive', multiIOLinkSMI_Instances[selectedInstance].parameters.active)
  Script.notifyEvent('MultiIOLinkSMI_OnNewPortStatus', multiIOLinkSMI_Instances[selectedInstance].status)
  Script.notifyEvent("MultiIOLinkSMI_OnNewParameterName", multiIOLinkSMI_Instances[selectedInstance].parametersName)
  Script.notifyEvent("MultiIOLinkSMI_OnNewInstanceList", helperFuncs.createStringListBySize(#multiIOLinkSMI_Instances))
  Script.notifyEvent('MultiIOLinkSMI_OnNewSelectedInstance', selectedInstance)
  Script.notifyEvent("MultiIOLinkSMI_OnNewStatusLoadParameterOnReboot", multiIOLinkSMI_Instances[selectedInstance].parameterLoadOnReboot)
  Script.notifyEvent("MultiIOLinkSMI_OnPersistentDataModuleAvailable", multiIOLinkSMI_Instances[selectedInstance].persistentModuleAvailable)
  updateAvailablePortList()
  Script.notifyEvent('MultiIOLinkSMI_OnNewPortDropdown', json.encode(availableIOLinkPorts))
  Script.notifyEvent('MultiIOLinkSMI_OnNewPort', multiIOLinkSMI_Instances[selectedInstance].parameters.port)

  if multiIOLinkSMI_Instances[selectedInstance].parameters.deviceIdentification then
    local deviceInfo = multiIOLinkSMI_Instances[selectedInstance].parameters.deviceIdentification
    Script.notifyEvent('MultiIOLinkSMI_OnNewFirmwareVersion', deviceInfo.firmwareVersion)
    Script.notifyEvent('MultiIOLinkSMI_OnNewHardwareVersion', deviceInfo.hardwareVersion)
    Script.notifyEvent('MultiIOLinkSMI_OnNewSerialNumber', deviceInfo.serialNumber)
    Script.notifyEvent('MultiIOLinkSMI_OnNewVendorId', deviceInfo.vendorId)
    Script.notifyEvent('MultiIOLinkSMI_OnNewVendorName', deviceInfo.vendorName)
    Script.notifyEvent('MultiIOLinkSMI_OnNewVendorText', deviceInfo.vendorText)
    Script.notifyEvent('MultiIOLinkSMI_OnNewProductId', deviceInfo.deviceId)
    Script.notifyEvent('MultiIOLinkSMI_OnNewProductName', deviceInfo.productName)
    Script.notifyEvent('MultiIOLinkSMI_OnNewProductText', deviceInfo.productText)
  end
  Script.notifyEvent('MultiIOLinkSMI_IsNewDeviceFound', (multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification ~= nil))
  if multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification then
    local deviceInfo = multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceFirmwareVersion', deviceInfo.firmwareVersion)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceHardwareVersion', deviceInfo.hardwareVersion)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceSerialNumber', deviceInfo.serialNumber)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceVendorId', deviceInfo.vendorId)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceVendorName', deviceInfo.vendorName)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceVendorText', deviceInfo.vendorText)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceProductId', deviceInfo.deviceId)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceProductName', deviceInfo.productName)
    Script.notifyEvent('MultiIOLinkSMI_OnNewNewDeviceProductText', deviceInfo.productText)
  end
  Script.notifyEvent('MultiIOLinkSMI_isCskIoddInterpreterAvailable', (CSK_IODDInterpreter ~= nil))
  Script.notifyEvent('MultiIOLinkSMI_isIoddMatchFound', (multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo ~= nil))
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    Script.notifyEvent('MultiIOLinkSMI_isProcessDataVariable', false)
    return
  end
  Script.notifyEvent('MultiIOLinkSMI_isProcessDataVariable', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.isProcessDataVariable)
  if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.isProcessDataVariable then
    Script.notifyEvent('MultiIOLinkSMI_OnNewListProcessDataCondition', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.processDataConditionList)
    if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.currentCondition then
      Script.notifyEvent('MultiIOLinkSMI_OnNewProcessDataCondition', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.currentCondition)
    end
  end
  if selectedTab == 1 then
    local nameList = {}
    for name,_ in pairs(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages) do
      table.insert(nameList, name)
    end
    table.sort(nameList)
    Script.notifyEvent('MultiIOLinkSMI_OnNewListIoddReadMessages', json.encode(nameList))
    Script.notifyEvent('MultiIOLinkSMI_isIoddReadMessageSelected', selectedIoddReadMessage ~= '')
    Script.notifyEvent('MultiIOLinkSMI_OnNewSelectedIoddReadMessage', selectedIoddReadMessage)
    if selectedIoddReadMessage ~= '' then
      Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerType', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerType)
      Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerValue', tostring(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerValue))
      Script.notifyEvent('MultiIOLinkSMI_OnNewReadMessageEventName', "CSK_MultiIOLinkSMI.readMessage" .. multiIOLinkSMI_Instances[selectedInstance].parameters.port .. selectedIoddReadMessage)
      CSK_IODDInterpreter.pageCalledReadData()
      Script.notifyEvent('MultiIOLinkSMI_OnNewReadJSONTemplate', jsonTableViewer.jsonLine2Table(
        multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].jsonTemplate)
      )
    end
  elseif selectedTab == 2 then
    local nameList = {}
    for name,_ in pairs(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages) do
      table.insert(nameList, name)
    end
    table.sort(nameList)
    Script.notifyEvent('MultiIOLinkSMI_OnNewListIoddWriteMessages', json.encode(nameList))
    Script.notifyEvent('MultiIOLinkSMI_isIoddWriteMessageSelected', selectedIoddWriteMessage ~= '')
    Script.notifyEvent('MultiIOLinkSMI_OnNewSelectedIoddWriteMessage', selectedIoddWriteMessage)
    if selectedIoddWriteMessage ~= '' then
      CSK_IODDInterpreter.pageCalledWriteData()
      Script.notifyEvent('MultiIOLinkSMI_OnNewWriteMessageFunctionName', "CSK_MultiIOLinkSMI.writeMessage" .. multiIOLinkSMI_Instances[selectedInstance].parameters.port .. selectedIoddWriteMessage)
      Script.notifyEvent('MultiIOLinkSMI_OnNewWriteJSONTemplate', jsonTableViewer.jsonLine2Table(
        multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIoddWriteMessage].jsonTemplate)
      )
      Script.notifyEvent('MultiIOLinkSMI_OnNewTestWriteIoddMessage', testIoddMessageToWrite)
    end
  end
end
Timer.register(tmrMultiIOLinkSMI, "OnExpired", handleOnExpiredTmrMultiIOLinkSMI)


-- ********************* UI Setting / Submit Functions Start ********************

-- Function to register "On Resume" of the multiIOLinkSMI_Instances UI
--@pageCalled():string
local function pageCalled()
  if _G.availableAPIs.ioLinkSmi then
    updateUserLevel() -- try to hide user specific content asap
  end
  bugFixCntr = 1
  tmrMultiIOLinkSMI:start()
  return ''
end
Script.serveFunction("CSK_MultiIOLinkSMI.pageCalled", pageCalled)

-- Selecting instance
--@setSelectedInstance(instance:int):
local function setSelectedInstance(instance)
  selectedInstance = instance
  _G.logger:info(nameOfModule .. ": New selected instance = " .. tostring(selectedInstance))
  multiIOLinkSMI_Instances[selectedInstance].activeInUi = true
  selectedIoddReadMessage = ''
  selectedIoddWriteMessage = ''
  selectedTab = 0
  testWriteProcessData = ''
  testReadParameterIndex = 0
  testReadParameterSubindex = 0
  testWriteParameterData = ''
  testWriteParameterIndex = 0
  testWriteParameterSubindex = 0
  testIoddMessageToWrite = ''
  if multiIOLinkSMI_Instances[selectedInstance].ioddInfo then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].ioddInfo.ioddInstanceId)
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'activeInUi', true)
  tmrMultiIOLinkSMI:start()
end
Script.serveFunction("CSK_MultiIOLinkSMI.setSelectedInstance", setSelectedInstance)

---@param tabNumber int ID of the tab.
local function setSelectedTab(tabNumber)
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    selectedTab = 0
    bugFixCntr = 1
    handleOnExpiredTmrMultiIOLinkSMI()
    return
  end
  if tabNumber == 1 and selectedIoddReadMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].ioddInstanceId)
  elseif tabNumber == 2 and selectedIoddWriteMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIoddWriteMessage].ioddInstanceId)
  end
  selectedTab = tabNumber
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.setSelectedTab', setSelectedTab)

---@param port string IOLink sensor port.
local function setPort(port)
  multiIOLinkSMI_Instances[selectedInstance].parameters.port = port
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'port', port)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setPort', setPort)


-- Activation/deactivationg the instance
---@param status bool True = active
local function activateInstance(status)
  multiIOLinkSMI_Instances[selectedInstance].parameters.active = status
  if status == false then
    multiIOLinkSMI_Instances[selectedInstance].status = 'PORT_NOT_ACTIVE'
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'active', status)
end
Script.serveFunction('CSK_MultiIOLinkSMI.activateInstance', activateInstance)

local function applyNewDeviceIdentificationUI()
  multiIOLinkSMI_Instances[selectedInstance].parameters.deviceIdentification = helperFuncs.copy(multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification)
  multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification = nil
  multiIOLinkSMI_Instances[selectedInstance]:applyNewDeviceIdentification()
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.applyNewDeviceIdentificationUI', applyNewDeviceIdentificationUI)

---@param jsonNewDeviceIdentification string 
local function applyNewDeviceIdentification(jsonNewDeviceIdentification)
  multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification = json.decode(jsonNewDeviceIdentification)
  applyNewDeviceIdentificationUI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.applyNewDeviceIdentification', applyNewDeviceIdentification)

---@param newCondition string New condition string parced based on IODD file content.
local function setProcessDataCondition(newCondition)
  multiIOLinkSMI_Instances[selectedInstance]:setProcessDataConditionName(newCondition)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setProcessDataCondition', setProcessDataCondition)

local function handleOnIoddListChanged()
  for instance, instanceInfo in ipairs(multiIOLinkSMI_Instances) do
    local foundMatchingIodd, _ = CSK_IODDInterpreter.findIoddMatchingVendorIdDeviceIdVersion(
      instanceInfo.parameters.deviceIdentification.vendorId,
      instanceInfo.parameters.deviceIdentification.deviceId
    )
    if foundMatchingIodd and not instanceInfo.parameters.ioddInfo or not foundMatchingIodd and instanceInfo.parameters.ioddInfo then
      multiIOLinkSMI_Instances[instance]:applyNewDeviceIdentification()
      Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', instance, 'readMessages', json.encode(multiIOLinkSMI_Instances[instance].parameters.ioddReadMessages))
      Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', instance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[instance].parameters.ioddWriteMessages))
    end
  end
  handleOnExpiredTmrMultiIOLinkSMI()
end
if CSK_IODDInterpreter then
  Script.register('CSK_IODDInterpreter.OnIoddListChanged', handleOnIoddListChanged)
end

---@param port string 
---@return string jsonDeviceIdentification 
---@return string jsonPort2instanceIdMap 
local function getDeviceIdentification(port)
  local deviceIdentification = multiIOLinkSMI_Model.getDeviceIdentification(port)
  local jsonDeviceIdentification = json.encode(deviceIdentification)
  return jsonDeviceIdentification
end
Script.serveFunction('CSK_MultiIOLinkSMI.getDeviceIdentification', getDeviceIdentification)

---@param port IOLinkMasterPorts Port where the event occured.
---@param eventType IOLink.SMI.EventTypes Type of the event.
---@param eventCode int Event code as described within IO-Link Interface specification annex C.
local function handleOnNewPortEvent(port, eventType, eventCode)
  if PORT_EVENT_CODES[eventCode] then
    Script.notifyEvent('MultiIOLinkSMI_OnNewPortEvent', port, eventType, PORT_EVENT_CODES[eventCode].name)
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewPortEvent', port, eventType,'Unknown port event')
  end
  local updatedInstanceNumber
  for instanceNumber, instanceInfo in ipairs(multiIOLinkSMI_Instances) do
    if instanceInfo.parameters.port == port  then
      updatedInstanceNumber = instanceNumber
      local portStatus = multiIOLinkSMI_Model.IOLinkSMIhandle:getPortStatus(port)
      multiIOLinkSMI_Instances[instanceNumber].status = portStatus:getPortStatusInfo()
      Script.notifyEvent('MultiIOLinkSMI_OnNewIOLinkPortStatus', instanceNumber, multiIOLinkSMI_Instances[instanceNumber].status)
    end
  end
  if eventCode == 0xFF26 and updatedInstanceNumber ~= nil then
    setSelectedInstance(updatedInstanceNumber)
    local deviceInfo = multiIOLinkSMI_Model.getDeviceIdentification(port)
    if deviceInfo.deviceId == '' then
      handleOnExpiredTmrMultiIOLinkSMI()
      return
    end
    if not multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.deviceIdentification then
      multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.newDeviceIdentification = deviceInfo
      applyNewDeviceIdentificationUI()
      return
    elseif multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.deviceIdentification.vendorId == deviceInfo.vendorId and
    multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.deviceIdentification.deviceId == deviceInfo.deviceId then
      multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.deviceIdentification = deviceInfo
      handleOnExpiredTmrMultiIOLinkSMI()
      return
    else
      multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.newDeviceIdentification = deviceInfo
      handleOnExpiredTmrMultiIOLinkSMI()
      return
    end
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.handleOnNewPortEvent', handleOnNewPortEvent)

--**************************************************************************
--*************Read / Write Functions to be used externally ****************
--**************************************************************************

---@return bool readSuccess 
---@return string? readResult 
local function readProcessData()
  local jsonDataPointInfo = CSK_IODDInterpreter.getProcessDataInInfo()
  if not jsonDataPointInfo then
    return false, nil
  end
  local processDataInfo = json.decode(jsonDataPointInfo)
  local readSuccess, readData = Script.callFunction(
    'CSK_MultiIOLinkSMI.ReadProcessDataIODD' .. tostring(selectedInstance),
    json.encode(processDataInfo.ProcessDataIn.Datatype)
  )
  return readSuccess, readData
end
Script.serveFunction('CSK_MultiIOLinkSMI.readProcessData', readProcessData)

---@param jsonDataToWrite string JSON object with data to write to the IOLink device.
---@return bool writeSuccess Success of writing.
local function writeProcessData(jsonDataToWrite)
  local jsonDataPointInfo = CSK_IODDInterpreter.getProcessDataOutInfo()
  if not jsonDataPointInfo then
    return false
  end
  local processDataInfo = json.decode(jsonDataPointInfo)
  local writeSuccess = Script.callFunction(
    'CSK_MultiIOLinkSMI.WriteProcessDataIODD' .. tostring(selectedInstance),
    json.encode(processDataInfo.ProcessDataOut),
    jsonDataToWrite
  )
  return writeSuccess
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeProcessData', writeProcessData)

---@param index int Index of the parameter.
---@param subindex int Subindex of the parameter.
---@return bool readSuccess Success of reading.
---@return string? readResult Received data converted using IODD interpretation.
local function readParameter(index, subindex)
  local jsonDataPointInfo = CSK_IODDInterpreter.getParameterDataPointInfo(
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.ioddInstanceId,
    index,
    subindex
  )
  if not jsonDataPointInfo then
    return false, nil
  end
  local readSuccess, readData = Script.callFunction(
    'CSK_MultiIOLinkSMI.ReadParameterIODD' .. tostring(selectedInstance),
    index,
    subindex,
    jsonDataPointInfo
  )
  return readSuccess, readData
end
Script.serveFunction('CSK_MultiIOLinkSMI.readParameter', readParameter)

---@param index int Index of the parameter.
---@param subindex int Subindex of the parameter.
---@param jsonDataToWrite string JSON object with data to write to the IOLink device.
---@return bool writeSuccess Success of writing.
local function writeParameter(index, subindex, jsonDataToWrite)
  local jsonDataPointInfo = CSK_IODDInterpreter.getParameterDataPointInfo(
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.ioddInstanceId,
    index,
    subindex
  )
  if not jsonDataPointInfo then
    return false
  end
  local callSuccess, writeSuccess = Script.callFunction(
    'CSK_MultiIOLinkSMI.WriteParameterIODD' .. tostring(selectedInstance),
    index,
    subindex,
    jsonDataPointInfo,
    jsonDataToWrite
  )
  return writeSuccess
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeParameter', writeParameter)


--**************************************************************************
--***Read / Write Functions byte array functions  to be used for testing ***
--**************************************************************************

---@return table? resultByteArray Received byte array in dec format.
local function readProcessDataByteArray()
  local _, jsonByteArray = Script.callFunction("CSK_MultiIOLinkSMI.ReadProcessDataByteArray" .. tostring(selectedInstance))
  if not jsonByteArray then
    return nil
  end
  local byteArray = json.decode(jsonByteArray)
  return byteArray
end
Script.serveFunction('CSK_MultiIOLinkSMI.readProcessDataByteArray', readProcessDataByteArray)

local function readProcessDataByteArrayUI()
  local byteArray = readProcessDataByteArray()
  if not byteArray then
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Reading process data failed')
    return
  end
  local stringByteArray = table.concat(byteArray.value, ',')
  Script.notifyEvent('MultiIOLinkSMI_OnNewReadProcessDataByteArray', stringByteArray)
  Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Reading process data successful')
end
Script.serveFunction('CSK_MultiIOLinkSMI.readProcessDataByteArrayUI', readProcessDataByteArrayUI)

---@param processDataByteArray string Byte array in dec format where bytes are separated by comma. E.g. 1,12,123
local function setProcessDataByteArrayToWrite(processDataByteArray)
  testWriteProcessData = processDataByteArray
end
Script.serveFunction('CSK_MultiIOLinkSMI.setProcessDataByteArrayToWrite', setProcessDataByteArrayToWrite)

---@param byteArrayToWrite table? Byte array in dec format.
---@return bool success Success of writing.
---@return string? errorDescription Optional error description if writing failed.
local function writeProcessDataByteArray(byteArrayToWrite)
  local processDataToWrite = {
    value = byteArrayToWrite
  }
  local _, success, errorDescription = Script.callFunction("CSK_MultiIOLinkSMI.WriteProcessDataByteArray" .. tostring(selectedInstance), json.encode(processDataToWrite))
  return success, errorDescription
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeProcessDataByteArray', writeProcessDataByteArray)

local function writeProcessDataByteArrayUI()
  local jsonProcessDataByteArray = "[" .. testWriteProcessData .. "]"
  local convertSuccess, tableProcessDataByteArray = pcall(json.decode, jsonProcessDataByteArray)
  if not convertSuccess then
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Wrong byte array format')
    return
  end
  local success, errorDescription = writeProcessDataByteArray(selectedInstance, tableProcessDataByteArray)
  if success then
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Writing process data successful')
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', tostring(errorDescription))
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeProcessDataByteArrayUI', writeProcessDataByteArrayUI)

---@param index int Index of the parameter.
---@param subindex int Subindex of the parameter.
---@return table? resultByteArray Received byte array in dec format.
local function readParameterByteArray(index, subindex)
  local _, jsonByteArray = Script.callFunction("CSK_MultiIOLinkSMI.ReadParameterByteArray" .. tostring(selectedInstance), index, subindex)
  if not jsonByteArray then
    return nil
  end
  local byteArray = json.decode(jsonByteArray)
  return byteArray
end
Script.serveFunction('CSK_MultiIOLinkSMI.readParameterByteArray', readParameterByteArray)

---@param index int Index of the parameter.
local function setTestReadParameterIndex(index)
  testReadParameterIndex = index
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestReadParameterIndex', setTestReadParameterIndex)

---@param subindex int Subindex of the parameter.
local function setTestReadParameterSubindex(subindex)
  testReadParameterSubindex = subindex
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestReadParameterSubindex', setTestReadParameterSubindex)

local function readParameterByteArrayUI()
  local byteArray = readParameterByteArray(testReadParameterIndex, testReadParameterSubindex)
  if not byteArray then
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Reading parameter failed')
    return
  end
  local stringByteArray = table.concat(byteArray.value, ',')
  Script.notifyEvent('MultiIOLinkSMI_OnNewReadParameterByteArray', stringByteArray)
  Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Reading parameter successful')
end
Script.serveFunction('CSK_MultiIOLinkSMI.readParameterByteArrayUI', readParameterByteArrayUI)



---@param index int Index of the parameter.
local function setTestWriteParameterIndex(index)
  testWriteParameterIndex = index
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestWriteParameterIndex', setTestWriteParameterIndex)

---@param subindex int 
local function setTestWriteParameterSubindex(subindex)
  testWriteParameterSubindex = subindex
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestWriteParameterSubindex', setTestWriteParameterSubindex)

---@param byteArrayToWrite string Byte array in dec format where bytes are separated by comma. E.g. 1,12,123
local function setParameterByteArrayToWrite(byteArrayToWrite)
  testWriteParameterData = byteArrayToWrite
end
Script.serveFunction('CSK_MultiIOLinkSMI.setParameterByteArrayToWrite', setParameterByteArrayToWrite)

---@param index int Index of the parameter.
---@param subindex int Subndex of the parameter.
---@param byteArrayToWrite table? Byte array in dec format.
---@return bool success Success of writing.
---@return string? errorDescription Optional error description if writing failed.
local function writeParameterByteArray(index, subindex, byteArrayToWrite)
  local parameterToWrite = {
    value = byteArrayToWrite
  }
  local _, success, errorDescription = Script.callFunction("CSK_MultiIOLinkSMI.WriteParameterByteArray" .. tostring(selectedInstance), index, subindex, json.encode(parameterToWrite))
  return success, errorDescription
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeParameterByteArray', writeParameterByteArray)

local function writeParameterByteArrayUI()
  local jsonParameterByteArray = "[" .. testWriteParameterData .. "]"
  local convertSuccess, tableParameterByteArray = pcall(json.decode, jsonParameterByteArray)
  if not convertSuccess then
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Wrong byte array format')
    return
  end
  local success, result = writeParameterByteArray(testWriteParameterIndex, testWriteParameterSubindex, tableParameterByteArray)
  if success then
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Writing parameter successful')
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', tostring(result))
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeParameterByteArrayUI', writeParameterByteArrayUI)


--**************************************************************************
--***************************Read messages scope****************************
--**************************************************************************


---@param newSelectedMessage string Name of the message.
local function setSelectedIoddReadMessage(newSelectedMessage)
  selectedIoddReadMessage = newSelectedMessage
  if selectedIoddReadMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].ioddInstanceId)
  end
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.setSelectedIoddReadMessage', setSelectedIoddReadMessage)

local function createIoddReadMessage()
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    return
  end
  local newMessageName = multiIOLinkSMI_Instances[selectedInstance]:createIoddReadMessage()
  setSelectedIoddReadMessage(newMessageName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.createIoddReadMessage', createIoddReadMessage)

---@param newName string New name.
local function setIoddReadMessageName(newName)
  if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[newName] then
    handleOnExpiredTmrMultiIOLinkSMI()
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:renameIoddReadMessage(selectedIoddReadMessage, newName)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
  setSelectedIoddReadMessage(newName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setIoddReadMessageName', setIoddReadMessageName)


local function deleteIoddReadMessage()
  if selectedIoddReadMessage == '' then
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:deleteIoddReadMessage(selectedIoddReadMessage)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
  setSelectedIoddReadMessage('')
end
Script.serveFunction('CSK_MultiIOLinkSMI.deleteIoddReadMessage', deleteIoddReadMessage)

---@param newTriggerType string 'Periodic' or 'On event'
local function setTriggerType(newTriggerType)
  multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerType = newTriggerType
  if newTriggerType == 'Periodic' then
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerValue = 1000
  elseif newTriggerType == 'On event' then
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerValue = ''
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerValue', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerValue)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTriggerType', setTriggerType)

---@param newTriggerValue string Period in [ms] or name of served CROWN event.
local function setTriggerValue(newTriggerValue)
  if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerType == 'Periodic' then
    if not tonumber(newTriggerValue) then
      Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerValue', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerValue)
      return
    end
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerValue = tonumber(newTriggerValue)
  else
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].triggerValue = newTriggerValue
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTriggerValue', setTriggerValue)

local function handleOnNewReadDataJsonTemplateAndInfo(ioddInstanceId, jsonTemplate, jsonDataInfo)
  for instance, instanceInfo in ipairs(multiIOLinkSMI_Instances) do
    for messageName, messageInfo in pairs(instanceInfo.parameters.ioddReadMessages) do
      if ioddInstanceId == messageInfo.ioddInstanceId then
        multiIOLinkSMI_Instances[instance].parameters.ioddReadMessages[messageName].jsonTemplate = jsonTemplate
        multiIOLinkSMI_Instances[instance].parameters.ioddReadMessages[messageName].dataInfo = json.decode(jsonDataInfo)
        Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', instance, 'readMessages', json.encode(multiIOLinkSMI_Instances[instance].parameters.ioddReadMessages))
        break
      end
    end
  end
  if selectedInstance and selectedIoddReadMessage ~= '' then
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadJSONTemplate', jsonTableViewer.jsonLine2Table(
      multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIoddReadMessage].jsonTemplate)
    )
  end
end
if CSK_IODDInterpreter then
  Script.register('CSK_IODDInterpreter.OnNewReadDataJsonTemplateAndInfo', handleOnNewReadDataJsonTemplateAndInfo)
end

local function refreshReadDataResult()
  if selectedIoddReadMessage == '' then
    return
  end
  local _, readSuccess, readMessage = Script.callFunction("CSK_MultiIOLinkSMI.getReadDataResult" .. tostring(selectedInstance), selectedIoddReadMessage)
  if readSuccess ~= nil then
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataMessage', jsonTableViewer.jsonLine2Table(readMessage))
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataSuccess', readSuccess)
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataMessage', 'No read message')
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataSuccess', false)
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.refreshReadDataResult', refreshReadDataResult)

---@param messageName string Name of the configured message.
---@return bool success Success of reading the message.
---@return string? jsonReceivedData Received message in JSON format.
local function readIoddMessage(messageName)
  local _, readSuccess, jsonReadMessage = Script.callFunction('CSK_MultiIOLinkSMI.readIoddMessage' .. tostring(selectedInstance), messageName)
  return readSuccess, jsonReadMessage
end
Script.serveFunction('CSK_MultiIOLinkSMI.readIoddMessage', readIoddMessage)

local function readIoddMessageUI()
  local readSuccess, jsonReadMessage = readIoddMessage(selectedIoddReadMessage)
  Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataMessage', jsonTableViewer.jsonLine2Table(jsonReadMessage))
  Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataSuccess', readSuccess)
end
Script.serveFunction('CSK_MultiIOLinkSMI.readIoddMessageUI', readIoddMessageUI)


--**************************************************************************
--**************************Write messages scope****************************
--**************************************************************************

---@param newSelectedMessage string Name of the message.
local function setSelectedIoddWriteMessage(newSelectedMessage)
  selectedIoddWriteMessage = newSelectedMessage
  if selectedIoddWriteMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIoddWriteMessage].ioddInstanceId)
  end
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.setSelectedIoddWriteMessage', setSelectedIoddWriteMessage)


local function createIoddWriteMessage()
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    return
  end
  local newMessageName = multiIOLinkSMI_Instances[selectedInstance]:createIoddWriteMessage()
  setSelectedIoddWriteMessage(newMessageName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.createIoddWriteMessage', createIoddWriteMessage)


---@param newName string New name.
local function setIoddWriteMessageName(newName)
  if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[newName] then
    handleOnExpiredTmrMultiIOLinkSMI()
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:renameIoddWriteMessage(selectedIoddWriteMessage, newName)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages))
  setSelectedIoddWriteMessage(newName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setIoddWriteMessageName', setIoddWriteMessageName)


local function deleteIoddWriteMessage()
  if selectedIoddWriteMessage == '' then
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:deleteIoddWriteMessage(selectedIoddWriteMessage)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages))
  setSelectedIoddWriteMessage('')
end
Script.serveFunction('CSK_MultiIOLinkSMI.deleteIoddWriteMessage', deleteIoddWriteMessage)

local function handleOnNewWriteDataJsonTemplateAndInfo(ioddInstanceId, jsonTemplate, jsonDataInfo)
  for instance, instanceInfo in ipairs(multiIOLinkSMI_Instances) do
    for messageName, messageInfo in pairs(instanceInfo.parameters.ioddWriteMessages) do
      if ioddInstanceId == messageInfo.ioddInstanceId then
        multiIOLinkSMI_Instances[instance].parameters.ioddWriteMessages[messageName].jsonTemplate = jsonTemplate
        multiIOLinkSMI_Instances[instance].parameters.ioddWriteMessages[messageName].dataInfo = json.decode(jsonDataInfo)
        Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', instance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[instance].parameters.ioddWriteMessages))
        break
      end
    end
  end
  if selectedInstance and selectedIoddWriteMessage ~= '' then
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteJSONTemplate', jsonTableViewer.jsonLine2Table(
      multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIoddWriteMessage].jsonTemplate)
    )
  end
end
if CSK_IODDInterpreter then
  Script.register('CSK_IODDInterpreter.OnNewWriteDataJsonTemplateAndInfo', handleOnNewWriteDataJsonTemplateAndInfo)
end


local function refreshWriteDataResult()
  if selectedIoddWriteMessage == '' then
    return
  end
  local _, writeSuccess, writeMessage = Script.callFunction("CSK_MultiIOLinkSMI.getWriteDataResult" .. tostring(selectedInstance), selectedIoddWriteMessage)
  if writeSuccess ~= nil then
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataMessage', jsonTableViewer.jsonLine2Table(writeMessage))
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataSuccess', writeSuccess)
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataMessage', 'No write message')
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataSuccess', false)
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.refreshWriteDataResult', refreshWriteDataResult)

---@param newTestWriteIoddMessage string JSON data to write to the device.
local function setTestWriteIoddMessage(newTestWriteIoddMessage)
  testIoddMessageToWrite = newTestWriteIoddMessage
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestWriteIoddMessage', setTestWriteIoddMessage)

---@param messageName string Name of the configured message.
---@param jsonDataToWrite string Data to write to the IOLink device in JSON format.
---@return bool success Success of writing the message.
local function writeIoddMessage(messageName, jsonDataToWrite)
  local _, success = Script.callFunction('CSK_MultiIOLinkSMI.writeIoddMessage' .. tostring(selectedInstance), messageName, jsonDataToWrite)
  return success
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeIoddMessage', writeIoddMessage)

local function writeIoddMessageFromUI()
  local writeSuccess = writeIoddMessage(selectedIoddWriteMessage, testIoddMessageToWrite)
  Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataMessage', testIoddMessageToWrite)
  Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataSuccess', writeSuccess)
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeIoddMessageFromUI', writeIoddMessageFromUI)


--**************************************************************************
--***************Instance handling scope************************************
--**************************************************************************

-- Can use this function to get amount of instances from external app
--@getInstancesAmount():int
local function getInstancesAmount ()
  return #multiIOLinkSMI_Instances
end
Script.serveFunction("CSK_MultiIOLinkSMI.getInstancesAmount", getInstancesAmount)

-- Add new instance to project
local function addInstance()
  _G.logger:info(nameOfModule .. ": Add instance")
  table.insert(multiIOLinkSMI_Instances, multiIOLinkSMI_Model.create(#multiIOLinkSMI_Instances+1))
  Script.deregister("CSK_MultiIOLinkSMI.OnNewValueToForward" .. tostring(#multiIOLinkSMI_Instances) , handleOnNewValueToForward)
  Script.register("CSK_MultiIOLinkSMI.OnNewValueToForward" .. tostring(#multiIOLinkSMI_Instances) , handleOnNewValueToForward)
  setSelectedInstance(#multiIOLinkSMI_Instances)
end
Script.serveFunction('CSK_MultiIOLinkSMI.addInstance', addInstance)

---@param instanceNo int Number ID of instance
---@return auto jsonParameters Parameters in JSON format
local function getInstanceParameters(instanceNo)
  local jsonParameters = json.encode(multiIOLinkSMI_Instances[instanceNo].parameters)
  return jsonParameters
end
Script.serveFunction('CSK_MultiIOLinkSMI.getInstanceParameters', getInstanceParameters)

-- Send parameters to PersistentData CSK module if possible
--@sendParameters():
local function sendParameters()
  if multiIOLinkSMI_Instances[selectedInstance].persistentModuleAvailable then
    if CSK_IODDInterpreter and multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
      CSK_IODDInterpreter.setParameterName(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.ioddInstanceId)
      CSK_IODDInterpreter.sendParameters()
    end

    CSK_PersistentData.addParameter(helperFuncs.convertTable2Container(multiIOLinkSMI_Instances[selectedInstance].parameters), multiIOLinkSMI_Instances[selectedInstance].parametersName)

    -- Check if CSK_PersistentData version is >= 3.0.0
    if tonumber(string.sub(CSK_PersistentData.getVersion(), 1, 1)) >= 3 then
      CSK_PersistentData.setModuleParameterName(nameOfModule, multiIOLinkSMI_Instances[selectedInstance].parametersName, multiIOLinkSMI_Instances[selectedInstance].parameterLoadOnReboot, tostring(selectedInstance), #multiIOLinkSMI_Instances)
    else
      CSK_PersistentData.setModuleParameterName(nameOfModule, multiIOLinkSMI_Instances[selectedInstance].parametersName, multiIOLinkSMI_Instances[selectedInstance].parameterLoadOnReboot, tostring(selectedInstance))
    end
    _G.logger:info(nameOfModule .. ": Send MultiIOLinkSMI parameters with name '" .. multiIOLinkSMI_Instances[selectedInstance].parametersName .. "' to PersistentData module.")
    CSK_PersistentData.saveData()
  else
    _G.logger:warning(nameOfModule .. ": PersistentData Module not available.")
  end
end
Script.serveFunction("CSK_MultiIOLinkSMI.sendParameters", sendParameters)

local function makeDefaultInstance()
  selectedIoddReadMessage = ''
  selectedIoddWriteMessage = ''
  multiIOLinkSMI_Instances[selectedInstance].status = 'PORT_NOT_ACTIVE'
  multiIOLinkSMI_Instances[selectedInstance].useIodd = true
  multiIOLinkSMI_Instances[selectedInstance].parameters.port = ''
  multiIOLinkSMI_Instances[selectedInstance].parameters.active = false
  multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo = nil
  multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages = {}
  multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages = {}
  multiIOLinkSMI_Instances[selectedInstance].parameters.ReadJSONTemplate = '[]'
  multiIOLinkSMI_Instances[selectedInstance].parameters.WriteJSONTemplate = '[]'
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'active', multiIOLinkSMI_Instances[selectedInstance].parameters.active)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'port', multiIOLinkSMI_Instances[selectedInstance].parameters.port)
end
Script.serveFunction('CSK_MultiIOLinkSMI.makeDefaultInstance', makeDefaultInstance)

-- Reset all instances leaving only one
local function resetInstances()
  _G.logger:info(nameOfModule .. ": Reset instances.")
  setSelectedInstance(1)
  local totalAmount = #multiIOLinkSMI_Instances
  while totalAmount > 1 do
    Script.releaseObject(multiIOLinkSMI_Instances[totalAmount])
    multiIOLinkSMI_Instances[totalAmount] =  nil
    totalAmount = totalAmount - 1
  end
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.resetInstances', resetInstances)

-- Updating processing parameters of current instance when loading
local function updateProcessingParameters()
  selectedIoddReadMessage = ''
  selectedIoddWriteMessage = ''
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'port', multiIOLinkSMI_Instances[selectedInstance].parameters.port)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages))
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'active', multiIOLinkSMI_Instances[selectedInstance].parameters.active)
end


-- *****************************************************************
-- Following function can be adapted for PersistentData module usage
-- *****************************************************************

-- Function to set the name of the parameters if saved/loaded via the "PersistentData" CSK-module
--@setParameterName(name:string):
local function setParameterName(name)
  _G.logger:info(nameOfModule .. ": Set parameter name: " .. tostring(name))
  multiIOLinkSMI_Instances[selectedInstance].parametersName = name
end
Script.serveFunction("CSK_MultiIOLinkSMI.setParameterName", setParameterName)



-- Load parameters for this module from the PersistentData CSK-module if possible and use them
--@loadParameters():
local function loadParameters()
  if multiIOLinkSMI_Instances[selectedInstance].persistentModuleAvailable then
    local data = CSK_PersistentData.getParameter(multiIOLinkSMI_Instances[selectedInstance].parametersName)
    if data then
      _G.logger:info(nameOfModule .. ": Loaded parameters for multiIOLinkSMIObject " .. tostring(selectedInstance) .. " from PersistentData module.")
      multiIOLinkSMI_Instances[selectedInstance].parameters = helperFuncs.convertContainer2Table(data)
      updateProcessingParameters()
      if CSK_IODDInterpreter and multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
        CSK_IODDInterpreter.setParameterName(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.ioddInstanceId)
        CSK_IODDInterpreter.loadParameters()
      end
      CSK_MultiIOLinkSMI.pageCalled()
    else
      _G.logger:warning(nameOfModule .. ": Loading parameters from PersistentData module did not work.")
    end
  else
    _G.logger:warning(nameOfModule .. ": PersistentData Module not available.")
  end
  tmrMultiIOLinkSMI:start()
end
Script.serveFunction("CSK_MultiIOLinkSMI.loadParameters", loadParameters)


--@setLoadOnReboot(status:bool):
local function setLoadOnReboot(status)
  multiIOLinkSMI_Instances[selectedInstance].parameterLoadOnReboot = status
  _G.logger:info(nameOfModule .. ": Set new status to load setting on reboot: " .. tostring(status))
end
Script.serveFunction("CSK_MultiIOLinkSMI.setLoadOnReboot", setLoadOnReboot)

--@handleOnInitialDataLoaded()
local function handleOnInitialDataLoaded()

  _G.logger:info(nameOfModule .. ': Try to initially load parameter from CSK_PersistentData module.')
  if string.sub(CSK_PersistentData.getVersion(), 1, 1) == '1' then

    _G.logger:warning(nameOfModule .. ': CSK_PersistentData module is too old and will not work. Please update CSK_PersistentData module.')

    for j = 1, #multiIOLinkSMI_Instances do
      multiIOLinkSMI_Instances[j].persistentModuleAvailable = false
    end
  else
    -- Check if CSK_PersistentData version is >= 3.0.0
    if tonumber(string.sub(CSK_PersistentData.getVersion(), 1, 1)) >= 3 then
      local parameterName, loadOnReboot, totalInstances = CSK_PersistentData.getModuleParameterName(nameOfModule, '1')
      -- Check for amount if instances to create
      if totalInstances then
        local c = 2
        while c <= totalInstances do
          addInstance()
          c = c+1
        end
      end
    end
    if not multiIOLinkSMI_Instances then
      return
    end
    for i = 1, #multiIOLinkSMI_Instances do
      local parameterName, loadOnReboot = CSK_PersistentData.getModuleParameterName(nameOfModule, tostring(i))

      if parameterName then
        multiIOLinkSMI_Instances[i].parametersName = parameterName
        multiIOLinkSMI_Instances[i].parameterLoadOnReboot = loadOnReboot
      end

      if multiIOLinkSMI_Instances[i].parameterLoadOnReboot then
        setSelectedInstance(i)
        loadParameters()
      end
    end
    Script.notifyEvent('MultiIOLinkSMI_OnDataLoadedOnReboot')
  end
end
Script.register("CSK_PersistentData.OnInitialDataLoaded", handleOnInitialDataLoaded)

return funcs

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************

