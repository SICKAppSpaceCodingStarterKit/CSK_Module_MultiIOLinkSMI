---@diagnostic disable: need-check-nil, missing-parameter, redundant-parameterm, ignore Script _APPNAME

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

-- Timer to update UI via events after page was loaded
local tmrMultiIOLinkSMI = Timer.create()
tmrMultiIOLinkSMI:setExpirationTime(500)
tmrMultiIOLinkSMI:setPeriodic(false)

-- IOLink event codes that can be received by driver and their desciption to be logged.
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

local availableIOLinkPorts = {} -- Sensor ports that can be used as IO-Link ports and that are not used yet by other instances.

local multiIOLinkSMI_Model -- Reference to global handle
local multiIOLinkSMI_Instances
local selectedInstance = 1
local selectedIODDReadMessage = ''
local selectedIODDWriteMessage = ''
local selectedTab = 0
local testWriteProcessData = ''
local testReadParameterIndex = 0
local testReadParameterSubindex = 0
local testWriteParameterData = ''
local testWriteParameterIndex = 0
local testWriteParameterSubindex = 0
local testIODDMessageToWrite = ''

-- ************************ UI Events Start ********************************
-- Only to prevent WARNING messages, but these are only examples/placeholders for dynamically created events/functions
----------------------------------------------------------------
local function emptyFunction()
end
Script.serveFunction("CSK_MultiIOLinkSMI.processInstanceNUM", emptyFunction)
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewResultNUM", "MultiIOLinkSMI_OnNewResultNUM")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueToForwardNUM", "MultiIOLinkSMI_OnNewValueToForwardNUM")
Script.serveEvent("CSK_MultiIOLinkSMI.OnNewValueUpdateNUM", "MultiIOLinkSMI_OnNewValueUpdateNUM")
----------------------------------------------------------------
-- Real events
----------------------------------------------------------------
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewSelectedTab',                      'MultiIOLinkSMI_OnNewSelectedTab')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewDeviceIdentificationApplied',      'MultiIOLinkSMI_OnNewDeviceIdentificationApplied')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewIOLinkPortStatus',                 'MultiIOLinkSMI_OnNewIOLinkPortStatus')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPortStatus',                       'MultiIOLinkSMI_OnNewPortStatus')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusNewDeviceFound',             'MultiIOLinkSMI_OnNewStatusNewDeviceFound')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPortEvent',                        'MultiIOLinkSMI_OnNewPortEvent')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPortDropdown',                     'MultiIOLinkSMI_OnNewPortDropdown')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewPort',                             'MultiIOLinkSMI_OnNewPort')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusInstanceActive',             'MultiIOLinkSMI_OnNewStatusInstanceActive')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusCSKIODDInterpreterAvailable','MultiIOLinkSMI_OnNewStatusCSKIODDInterpreterAvailable')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusIODDMatchFound',             'MultiIOLinkSMI_OnNewStatusIODDMatchFound')

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

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusProcessDataVariable',        'MultiIOLinkSMI_OnNewStatusProcessDataVariable')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewProcessDataCondition',             'MultiIOLinkSMI_OnNewProcessDataCondition')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewListProcessDataCondition',         'MultiIOLinkSMI_OnNewListProcessDataCondition')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewListIODDReadMessages',             'MultiIOLinkSMI_OnNewListIODDReadMessages')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusIODDReadMessageSelected',    'MultiIOLinkSMI_OnNewStatusIODDReadMessageSelected')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewSelectedIODDReadMessage',          'MultiIOLinkSMI_OnNewSelectedIODDReadMessage')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewTriggerType',                      'MultiIOLinkSMI_OnNewTriggerType')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewTriggerValue',                     'MultiIOLinkSMI_OnNewTriggerValue')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewListIODDWriteMessages',            'MultiIOLinkSMI_OnNewListIODDWriteMessages')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusIODDWriteMessageSelected',   'MultiIOLinkSMI_OnNewStatusIODDWriteMessageSelected')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewSelectedIODDWriteMessage',         'MultiIOLinkSMI_OnNewSelectedIODDWriteMessage')
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewTestWriteIODDMessage',             'MultiIOLinkSMI_OnNewTestWriteIODDMessage')

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
--- Function to react on status change of Operator user level
---@param status boolean Status if Operator level is active
local function handleOnUserLevelOperatorActive(status)
  Script.notifyEvent("MultiIOLinkSMI_OnUserLevelOperatorActive", status)
end

--- Function to react on status change of Maintenance user level
---@param status boolean Status if Maintenance level is active
local function handleOnUserLevelMaintenanceActive(status)
  Script.notifyEvent("MultiIOLinkSMI_OnUserLevelMaintenanceActive", status)
end

--- Function to react on status change of Service user level
---@param status boolean Status if Service level is active
local function handleOnUserLevelServiceActive(status)
  Script.notifyEvent("MultiIOLinkSMI_OnUserLevelServiceActive", status)
end

--- Function to react on status change of Admin user level
---@param status boolean Status if Admin level is active
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

--- Optionally: Only use if needed for extra internal objects -  see also Model
--- Function to sync paramters between instance threads and Controller part of module
---@param instance int Instance new value is coming from
---@param parameter string Name of the paramter to update/sync
---@param value auto Value to update
---@param selectedObject int? Optionally if internal parameter should be used for internal objects
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


-- Function to send all relevant values to UI on resume
--@handleOnExpiredTmrMultiIOLinkSMI()
local function handleOnExpiredTmrMultiIOLinkSMI()
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
  Script.notifyEvent('MultiIOLinkSMI_OnNewStatusInstanceActive', multiIOLinkSMI_Instances[selectedInstance].parameters.active)
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
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewFirmwareVersion', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewHardwareVersion', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewSerialNumber', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewVendorId', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewVendorName', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewVendorText', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewProductId', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewProductName', "")
    Script.notifyEvent('MultiIOLinkSMI_OnNewProductText', "")
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewStatusNewDeviceFound', (multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification ~= nil))
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
  Script.notifyEvent('MultiIOLinkSMI_OnNewStatusCSKIODDInterpreterAvailable', (CSK_IODDInterpreter ~= nil))
  Script.notifyEvent('MultiIOLinkSMI_OnNewStatusIODDMatchFound', (multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo ~= nil))
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    Script.notifyEvent('MultiIOLinkSMI_OnNewStatusProcessDataVariable', false)
    return
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewStatusProcessDataVariable', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo.isProcessDataVariable)
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
    Script.notifyEvent('MultiIOLinkSMI_OnNewListIODDReadMessages', json.encode(nameList))
    Script.notifyEvent('MultiIOLinkSMI_OnNewStatusIODDReadMessageSelected', selectedIODDReadMessage ~= '')
    Script.notifyEvent('MultiIOLinkSMI_OnNewSelectedIODDReadMessage', selectedIODDReadMessage)
    if selectedIODDReadMessage ~= '' then
      Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerType', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerType)
      Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerValue', tostring(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerValue))
      Script.notifyEvent('MultiIOLinkSMI_OnNewReadMessageEventName', "CSK_MultiIOLinkSMI.readMessage" .. multiIOLinkSMI_Instances[selectedInstance].parameters.port .. selectedIODDReadMessage)
      CSK_IODDInterpreter.pageCalledReadData()
      Script.notifyEvent('MultiIOLinkSMI_OnNewReadJSONTemplate', jsonTableViewer.jsonLine2Table(
        multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].jsonTemplate)
      )
    end
  elseif selectedTab == 2 then
    local nameList = {}
    for name,_ in pairs(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages) do
      table.insert(nameList, name)
    end
    table.sort(nameList)
    Script.notifyEvent('MultiIOLinkSMI_OnNewListIODDWriteMessages', json.encode(nameList))
    Script.notifyEvent('MultiIOLinkSMI_OnNewStatusIODDWriteMessageSelected', selectedIODDWriteMessage ~= '')
    Script.notifyEvent('MultiIOLinkSMI_OnNewSelectedIODDWriteMessage', selectedIODDWriteMessage)
    if selectedIODDWriteMessage ~= '' then
      CSK_IODDInterpreter.pageCalledWriteData()
      Script.notifyEvent('MultiIOLinkSMI_OnNewWriteMessageFunctionName', "CSK_MultiIOLinkSMI.writeMessage" .. multiIOLinkSMI_Instances[selectedInstance].parameters.port .. selectedIODDWriteMessage)
      Script.notifyEvent('MultiIOLinkSMI_OnNewWriteJSONTemplate', jsonTableViewer.jsonLine2Table(
        multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIODDWriteMessage].jsonTemplate)
      )
      Script.notifyEvent('MultiIOLinkSMI_OnNewTestWriteIODDMessage', testIODDMessageToWrite)
    end
  end
end
Timer.register(tmrMultiIOLinkSMI, "OnExpired", handleOnExpiredTmrMultiIOLinkSMI)

-- ********************* UI Setting / Submit Functions Start ********************

local function pageCalled()
  if _G.availableAPIs.ioLinkSmi then
    updateUserLevel() -- try to hide user specific content asap
  end
  tmrMultiIOLinkSMI:start()
  return ''
end
Script.serveFunction("CSK_MultiIOLinkSMI.pageCalled", pageCalled)

local function setSelectedInstance(instance)
  selectedInstance = instance
  _G.logger:info(nameOfModule .. ": New selected instance = " .. tostring(selectedInstance))
  multiIOLinkSMI_Instances[selectedInstance].activeInUi = true
  selectedIODDReadMessage = ''
  selectedIODDWriteMessage = ''
  selectedTab = 0
  testWriteProcessData = ''
  testReadParameterIndex = 0
  testReadParameterSubindex = 0
  testWriteParameterData = ''
  testWriteParameterIndex = 0
  testWriteParameterSubindex = 0
  testIODDMessageToWrite = ''
  if multiIOLinkSMI_Instances[selectedInstance].ioddInfo then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].ioddInfo.ioddInstanceId)
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'activeInUi', true)
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction("CSK_MultiIOLinkSMI.setSelectedInstance", setSelectedInstance)

local function setSelectedTab(tabNumber)
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    selectedTab = 0
    handleOnExpiredTmrMultiIOLinkSMI()
    return
  end
  if tabNumber == 1 and selectedIODDReadMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].ioddInstanceId)
  elseif tabNumber == 2 and selectedIODDWriteMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIODDWriteMessage].ioddInstanceId)
  end
  selectedTab = tabNumber
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.setSelectedTab', setSelectedTab)

local function setPort(port)
  multiIOLinkSMI_Instances[selectedInstance].parameters.port = port
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'port', port)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setPort', setPort)

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

local function applyNewDeviceIdentification(jsonNewDeviceIdentification)
  multiIOLinkSMI_Instances[selectedInstance].parameters.newDeviceIdentification = json.decode(jsonNewDeviceIdentification)
  applyNewDeviceIdentificationUI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.applyNewDeviceIdentification', applyNewDeviceIdentification)

local function setProcessDataCondition(newCondition)
  multiIOLinkSMI_Instances[selectedInstance]:setProcessDataConditionName(newCondition)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setProcessDataCondition', setProcessDataCondition)

--- Function called when there is a new IODD file loaded or deleted in CSK_Module_IODDInterpreter to check if there are any updates for existing instances.
local function handleOnIODDListChanged()
  for instance, instanceInfo in ipairs(multiIOLinkSMI_Instances) do
    local foundMatchingIODD, _ = CSK_IODDInterpreter.findIODDMatchingVendorIdDeviceIdVersion(
      instanceInfo.parameters.deviceIdentification.vendorId,
      instanceInfo.parameters.deviceIdentification.deviceId
    )
    if foundMatchingIODD and not instanceInfo.parameters.ioddInfo or not foundMatchingIODD and instanceInfo.parameters.ioddInfo then
      selectedIODDReadMessage = ''
      selectedIODDWriteMessage = ''
      multiIOLinkSMI_Instances[instance]:applyNewDeviceIdentification()
      Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', instance, 'readMessages', json.encode(multiIOLinkSMI_Instances[instance].parameters.ioddReadMessages))
      Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', instance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[instance].parameters.ioddWriteMessages))
    end
  end
  tmrMultiIOLinkSMI:start()
end
if CSK_IODDInterpreter then
  Script.register('CSK_IODDInterpreter.OnIODDListChanged', handleOnIODDListChanged)
end

local function getDeviceIdentification(port)
  local deviceIdentification = multiIOLinkSMI_Model.getDeviceIdentification(port)
  local jsonDeviceIdentification = json.encode(deviceIdentification)
  return jsonDeviceIdentification
end
Script.serveFunction('CSK_MultiIOLinkSMI.getDeviceIdentification', getDeviceIdentification)

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
    if not CSK_IODDInterpreter then
      multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.deviceIdentification = deviceInfo
      handleOnExpiredTmrMultiIOLinkSMI()
      return
    elseif not multiIOLinkSMI_Instances[updatedInstanceNumber].parameters.deviceIdentification then
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

local function readProcessData()
  local jsonDataPointInfo = CSK_IODDInterpreter.getProcessDataInInfo()
  if not jsonDataPointInfo then
    return false, nil
  end
  local processDataInfo = json.decode(jsonDataPointInfo)
  local readSuccess, readData = Script.callFunction(
    'CSK_MultiIOLinkSMI.readProcessDataIODD_' .. tostring(selectedInstance),
    json.encode(processDataInfo.ProcessDataIn.Datatype)
  )
  return readSuccess, readData
end
Script.serveFunction('CSK_MultiIOLinkSMI.readProcessData', readProcessData)

local function writeProcessData(jsonDataToWrite)
  local jsonDataPointInfo = CSK_IODDInterpreter.getProcessDataOutInfo()
  if not jsonDataPointInfo then
    return false
  end
  local processDataInfo = json.decode(jsonDataPointInfo)
  local writeSuccess = Script.callFunction(
    'CSK_MultiIOLinkSMI.writeProcessDataIODD_' .. tostring(selectedInstance),
    json.encode(processDataInfo.ProcessDataOut),
    jsonDataToWrite
  )
  return writeSuccess
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeProcessData', writeProcessData)

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
    'CSK_MultiIOLinkSMI.readParameterIODD_' .. tostring(selectedInstance),
    index,
    subindex,
    jsonDataPointInfo
  )
  return readSuccess, readData
end
Script.serveFunction('CSK_MultiIOLinkSMI.readParameter', readParameter)

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
    'CSK_MultiIOLinkSMI.writeParameterIODD_' .. tostring(selectedInstance),
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

local function readProcessDataByteArray()
  local _, jsonByteArray = Script.callFunction("CSK_MultiIOLinkSMI.readProcessDataByteArray_" .. tostring(selectedInstance))
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

local function setProcessDataByteArrayToWrite(processDataByteArray)
  testWriteProcessData = processDataByteArray
end
Script.serveFunction('CSK_MultiIOLinkSMI.setProcessDataByteArrayToWrite', setProcessDataByteArrayToWrite)

local function writeProcessDataByteArray(byteArrayToWrite)
  local processDataToWrite = {
    value = byteArrayToWrite
  }
  local _, success, errorDescription = Script.callFunction("CSK_MultiIOLinkSMI.writeProcessDataByteArray_" .. tostring(selectedInstance), json.encode(processDataToWrite))
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
  local success, errorDescription = writeProcessDataByteArray(tableProcessDataByteArray)
  if success then
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', 'Writing process data successful')
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewTestCommandState', tostring(errorDescription))
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeProcessDataByteArrayUI', writeProcessDataByteArrayUI)

local function readParameterByteArray(index, subindex)
  local _, jsonByteArray = Script.callFunction("CSK_MultiIOLinkSMI.readParameterByteArray_" .. tostring(selectedInstance), index, subindex)
  if not jsonByteArray then
    return nil
  end
  local byteArray = json.decode(jsonByteArray)
  return byteArray
end
Script.serveFunction('CSK_MultiIOLinkSMI.readParameterByteArray', readParameterByteArray)

local function setTestReadParameterIndex(index)
  testReadParameterIndex = index
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestReadParameterIndex', setTestReadParameterIndex)

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

local function setTestWriteParameterIndex(index)
  testWriteParameterIndex = index
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestWriteParameterIndex', setTestWriteParameterIndex)

local function setTestWriteParameterSubindex(subindex)
  testWriteParameterSubindex = subindex
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestWriteParameterSubindex', setTestWriteParameterSubindex)

local function setParameterByteArrayToWrite(byteArrayToWrite)
  testWriteParameterData = byteArrayToWrite
end
Script.serveFunction('CSK_MultiIOLinkSMI.setParameterByteArrayToWrite', setParameterByteArrayToWrite)

local function writeParameterByteArray(index, subindex, byteArrayToWrite)
  local parameterToWrite = {
    value = byteArrayToWrite
  }
  local _, success, errorDescription = Script.callFunction("CSK_MultiIOLinkSMI.writeParameterByteArray_" .. tostring(selectedInstance), index, subindex, json.encode(parameterToWrite))
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

local function setSelectedIODDReadMessage(newSelectedMessage)
  selectedIODDReadMessage = newSelectedMessage
  if selectedIODDReadMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].ioddInstanceId)
  end
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.setSelectedIODDReadMessage', setSelectedIODDReadMessage)

local function createIODDReadMessage()
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    return
  end
  local newMessageName = multiIOLinkSMI_Instances[selectedInstance]:createIODDReadMessage()
  setSelectedIODDReadMessage(newMessageName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.createIODDReadMessage', createIODDReadMessage)

local function setIODDReadMessageName(newName)
  if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[newName] then
    handleOnExpiredTmrMultiIOLinkSMI()
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:renameIODDReadMessage(selectedIODDReadMessage, newName)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
  setSelectedIODDReadMessage(newName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setIODDReadMessageName', setIODDReadMessageName)

local function deleteIODDReadMessage()
  if selectedIODDReadMessage == '' then
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:deleteIODDReadMessage(selectedIODDReadMessage)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
  setSelectedIODDReadMessage('')
end
Script.serveFunction('CSK_MultiIOLinkSMI.deleteIODDReadMessage', deleteIODDReadMessage)

local function setTriggerType(newTriggerType)
  multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerType = newTriggerType
  if newTriggerType == 'Periodic' then
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerValue = 1000
  elseif newTriggerType == 'On event' then
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerValue = ''
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerValue', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerValue)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTriggerType', setTriggerType)

local function setTriggerValue(newTriggerValue)
  if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerType == 'Periodic' then
    if not tonumber(newTriggerValue) then
      Script.notifyEvent('MultiIOLinkSMI_OnNewTriggerValue', multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerValue)
      return
    end
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerValue = tonumber(newTriggerValue)
  else
    multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].triggerValue = newTriggerValue
  end
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTriggerValue', setTriggerValue)


--- Function called when new data set selected in read data tables of CSK_Module_IODDInterpreter to update the existing IODD read messages accordingly.
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
  if selectedInstance and selectedIODDReadMessage ~= '' then
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadJSONTemplate', jsonTableViewer.jsonLine2Table(
      multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[selectedIODDReadMessage].jsonTemplate)
    )
  end
end
if CSK_IODDInterpreter then
  Script.register('CSK_IODDInterpreter.OnNewReadDataJsonTemplateAndInfo', handleOnNewReadDataJsonTemplateAndInfo)
end

local function refreshReadDataResult()
  if selectedIODDReadMessage == '' then
    return
  end
  local _, readSuccess, readMessage = Script.callFunction("CSK_MultiIOLinkSMI.getReadDataResult" .. tostring(selectedInstance), selectedIODDReadMessage)
  if readSuccess ~= nil then
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataMessage', jsonTableViewer.jsonLine2Table(readMessage))
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataSuccess', readSuccess)
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataMessage', 'No read message')
    Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataSuccess', false)
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.refreshReadDataResult', refreshReadDataResult)

local function readIODDMessage(messageName)
  local _, readSuccess, jsonReadMessage = Script.callFunction('CSK_MultiIOLinkSMI.readIODDMessage' .. tostring(selectedInstance), messageName)
  return readSuccess, jsonReadMessage
end
Script.serveFunction('CSK_MultiIOLinkSMI.readIODDMessage', readIODDMessage)

local function readIODDMessageUI()
  local readSuccess, jsonReadMessage = readIODDMessage(selectedIODDReadMessage)
  Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataMessage', jsonTableViewer.jsonLine2Table(jsonReadMessage))
  Script.notifyEvent('MultiIOLinkSMI_OnNewReadDataSuccess', readSuccess)
end
Script.serveFunction('CSK_MultiIOLinkSMI.readIODDMessageUI', readIODDMessageUI)

local function getIODDReadMessageJSONTemplate(messageName)
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[messageName] then
    return nil
  end
  return multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages[messageName].jsonTemplate
end
Script.serveFunction('CSK_MultiIOLinkSMI.getIODDReadMessageJSONTemplate', getIODDReadMessageJSONTemplate)


--**************************************************************************
--**************************Write messages scope****************************
--**************************************************************************

local function setSelectedIODDWriteMessage(newSelectedMessage)
  selectedIODDWriteMessage = newSelectedMessage
  if selectedIODDWriteMessage ~= '' then
    CSK_IODDInterpreter.setSelectedInstance(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIODDWriteMessage].ioddInstanceId)
  end
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.setSelectedIODDWriteMessage', setSelectedIODDWriteMessage)

local function createIODDWriteMessage()
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddInfo then
    return
  end
  local newMessageName = multiIOLinkSMI_Instances[selectedInstance]:createIODDWriteMessage()
  setSelectedIODDWriteMessage(newMessageName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.createIODDWriteMessage', createIODDWriteMessage)

local function setIODDWriteMessageName(newName)
  if multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[newName] then
    handleOnExpiredTmrMultiIOLinkSMI()
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:renameIODDWriteMessage(selectedIODDWriteMessage, newName)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages))
  setSelectedIODDWriteMessage(newName)
end
Script.serveFunction('CSK_MultiIOLinkSMI.setIODDWriteMessageName', setIODDWriteMessageName)

local function deleteIODDWriteMessage()
  if selectedIODDWriteMessage == '' then
    return
  end
  multiIOLinkSMI_Instances[selectedInstance]:deleteIODDWriteMessage(selectedIODDWriteMessage)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages))
  setSelectedIODDWriteMessage('')
end
Script.serveFunction('CSK_MultiIOLinkSMI.deleteIODDWriteMessage', deleteIODDWriteMessage)

--- Function called when new data set selected in write data tables of CSK_Module_IODDInterpreter to update the existing IODD write messages accordingly.
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
  if selectedInstance and selectedIODDWriteMessage ~= '' then
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteJSONTemplate', jsonTableViewer.jsonLine2Table(
      multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[selectedIODDWriteMessage].jsonTemplate)
    )
  end
end
if CSK_IODDInterpreter then
  Script.register('CSK_IODDInterpreter.OnNewWriteDataJsonTemplateAndInfo', handleOnNewWriteDataJsonTemplateAndInfo)
end

local function refreshWriteDataResult()
  if selectedIODDWriteMessage == '' then
    return
  end
  local _, writeSuccess, writeMessage = Script.callFunction("CSK_MultiIOLinkSMI.getWriteDataResult" .. tostring(selectedInstance), selectedIODDWriteMessage)
  if writeSuccess ~= nil then
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataMessage', writeMessage)
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataSuccess', writeSuccess)
  else
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataMessage', 'No write message')
    Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataSuccess', false)
  end
end
Script.serveFunction('CSK_MultiIOLinkSMI.refreshWriteDataResult', refreshWriteDataResult)

local function setTestWriteIODDMessage(newTestWriteIODDMessage)
  testIODDMessageToWrite = newTestWriteIODDMessage
end
Script.serveFunction('CSK_MultiIOLinkSMI.setTestWriteIODDMessage', setTestWriteIODDMessage)

local function writeIODDMessage(messageName, jsonDataToWrite)
  local _, success = Script.callFunction('CSK_MultiIOLinkSMI.writeIODDMessage' .. tostring(selectedInstance), messageName, jsonDataToWrite)
  return success
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeIODDMessage', writeIODDMessage)

local function writeIODDMessageFromUI()
  local writeSuccess = writeIODDMessage(selectedIODDWriteMessage, testIODDMessageToWrite)
  Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataMessage', testIODDMessageToWrite)
  Script.notifyEvent('MultiIOLinkSMI_OnNewWriteDataSuccess', writeSuccess)
end
Script.serveFunction('CSK_MultiIOLinkSMI.writeIODDMessageFromUI', writeIODDMessageFromUI)

local function getIODDWriteMessageJSONTemplate(messageName)
  if not multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[messageName] then
    return nil
  end
  return multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages[messageName].jsonTemplate
end
Script.serveFunction('CSK_MultiIOLinkSMI.getIODDWriteMessageJSONTemplate', getIODDWriteMessageJSONTemplate)


--**************************************************************************
--***************Instance handling scope************************************
--**************************************************************************

local function getInstancesAmount ()
  return #multiIOLinkSMI_Instances
end
Script.serveFunction("CSK_MultiIOLinkSMI.getInstancesAmount", getInstancesAmount)

local function addInstance()
  _G.logger:info(nameOfModule .. ": Add instance")
  table.insert(multiIOLinkSMI_Instances, multiIOLinkSMI_Model.create(#multiIOLinkSMI_Instances+1))
  Script.deregister("CSK_MultiIOLinkSMI.OnNewValueToForward" .. tostring(#multiIOLinkSMI_Instances) , handleOnNewValueToForward)
  Script.register("CSK_MultiIOLinkSMI.OnNewValueToForward" .. tostring(#multiIOLinkSMI_Instances) , handleOnNewValueToForward)
  setSelectedInstance(#multiIOLinkSMI_Instances)
end
Script.serveFunction('CSK_MultiIOLinkSMI.addInstance', addInstance)

local function getInstanceParameters(instanceNo)
  local jsonParameters = json.encode(multiIOLinkSMI_Instances[instanceNo].parameters)
  return jsonParameters
end
Script.serveFunction('CSK_MultiIOLinkSMI.getInstanceParameters', getInstanceParameters)

local function makeDefaultInstance()
  selectedIODDReadMessage = ''
  selectedIODDWriteMessage = ''
  multiIOLinkSMI_Instances[selectedInstance].status = 'PORT_NOT_ACTIVE'
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

--- Function to share process relevant configuration with processing threads
local function updateProcessingParameters()
  selectedIODDReadMessage = ''
  selectedIODDWriteMessage = ''
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'port', multiIOLinkSMI_Instances[selectedInstance].parameters.port)
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'readMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddReadMessages))
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'writeMessages', json.encode(multiIOLinkSMI_Instances[selectedInstance].parameters.ioddWriteMessages))
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'active', multiIOLinkSMI_Instances[selectedInstance].parameters.active)
end

-- *****************************************************************
-- Following function can be adapted for CSK_PersistentData module usage
-- *****************************************************************

local function setParameterName(name)
  _G.logger:info(nameOfModule .. ": Set parameter name = " .. tostring(name))
  multiIOLinkSMI_Instances[selectedInstance].parametersName = name
end
Script.serveFunction("CSK_MultiIOLinkSMI.setParameterName", setParameterName)

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
    _G.logger:info(nameOfModule .. ": Send MultiIOLinkSMI parameters with name '" .. multiIOLinkSMI_Instances[selectedInstance].parametersName .. "' to CSK_PersistentData module.")
    CSK_PersistentData.saveData()
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_MultiIOLinkSMI.sendParameters", sendParameters)

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
      _G.logger:warning(nameOfModule .. ": Loading parameters from CSK_PersistentData module did not work.")
    end
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
  tmrMultiIOLinkSMI:start()
end
Script.serveFunction("CSK_MultiIOLinkSMI.loadParameters", loadParameters)

local function setLoadOnReboot(status)
  multiIOLinkSMI_Instances[selectedInstance].parameterLoadOnReboot = status
  _G.logger:info(nameOfModule .. ": Set new status to load setting on reboot: " .. tostring(status))
end
Script.serveFunction("CSK_MultiIOLinkSMI.setLoadOnReboot", setLoadOnReboot)

--- Function to react on initial load of persistent parameters
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

