---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter

--***************************************************************
-- Inside of this script, you will find the necessary functions,
-- variables and events to communicate with the MultiIOLinkSMI_Model and _Instances
--***************************************************************

--**************************************************************************
--************************ Start Global Scope ******************************
--**************************************************************************
local nameOfModule = 'CSK_MultiIOLinkSMI'

local funcs = {}

-- Timer to update UI via events after page was loaded
local tmrMultiIOLinkSMI = Timer.create()
tmrMultiIOLinkSMI:setExpirationTime(300)
tmrMultiIOLinkSMI:setPeriodic(false)

local multiIOLinkSMI_Model -- Reference to model handle
local multiIOLinkSMI_Instances -- Reference to instances handle
local selectedInstance = 1 -- Which instance is currently selected
local helperFuncs = require('Communication/MultiIOLinkSMI/helper/funcs')

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
--------------------------------------------------
-- Script.serveEvent("CSK_MultiIOLinkSMI.OnNewEvent", "MultiIOLinkSMI_OnNewEvent")
Script.serveEvent('CSK_MultiIOLinkSMI.OnNewResult', 'MultiIOLinkSMI_OnNewResult')

Script.serveEvent('CSK_MultiIOLinkSMI.OnNewStatusRegisteredEvent', 'MultiIOLinkSMI_OnNewStatusRegisteredEvent')

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

-- ...

-- ************************ UI Events End **********************************

--[[
--- Some internal code docu for local used function
local function functionName()
  -- Do something

end
]]

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

--- Function to forward data updates from instance threads to Controller part of module
---@param eventname string Eventname to use to forward value
---@param value auto Value to forward
local function handleOnNewValueToForward(eventname, value)
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

--- Function to get access to the multiIOLinkSMI_Model object
---@param handle handle Handle of multiIOLinkSMI_Model object
local function setMultiIOLinkSMI_Model_Handle(handle)
  multiIOLinkSMI_Model = handle
  Script.releaseObject(handle)
end
funcs.setMultiIOLinkSMI_Model_Handle = setMultiIOLinkSMI_Model_Handle

--- Function to get access to the multiIOLinkSMI_Instances object
---@param handle handle Handle of multiIOLinkSMI_Instances object
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
  end

  for i = 1, #multiIOLinkSMI_Instances do
    Script.register("CSK_MultiIOLinkSMI.OnNewValueUpdate" .. tostring(i) , handleOnNewValueUpdate)
  end

end
funcs.setMultiIOLinkSMI_Instances_Handle = setMultiIOLinkSMI_Instances_Handle

--- Function to update user levels
local function updateUserLevel()
  if multiIOLinkSMI_Instances[selectedInstance].userManagementModuleAvailable then
    -- Trigger CSK_UserManagement module to provide events regarding user role
    CSK_UserManagement.pageCalled()
  else
    -- If CSK_UserManagement is not active, show everything
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelAdminActive", true)
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelMaintenanceActive", true)
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelServiceActive", true)
    Script.notifyEvent("MultiIOLinkSMI_OnUserLevelOperatorActive", true)
  end
end

--- Function to send all relevant values to UI on resume
local function handleOnExpiredTmrMultiIOLinkSMI()
  -- Script.notifyEvent("MultiIOLinkSMI_OnNewEvent", false)

  updateUserLevel()

  Script.notifyEvent('MultiIOLinkSMI_OnNewSelectedInstance', selectedInstance)
  Script.notifyEvent("MultiIOLinkSMI_OnNewInstanceList", helperFuncs.createStringListBySize(#multiIOLinkSMI_Instances))

  Script.notifyEvent("MultiIOLinkSMI_OnNewStatusRegisteredEvent", multiIOLinkSMI_Instances[selectedInstance].parameters.registeredEvent)

  Script.notifyEvent("MultiIOLinkSMI_OnNewStatusLoadParameterOnReboot", multiIOLinkSMI_Instances[selectedInstance].parameterLoadOnReboot)
  Script.notifyEvent("MultiIOLinkSMI_OnPersistentDataModuleAvailable", multiIOLinkSMI_Instances[selectedInstance].persistentModuleAvailable)
  Script.notifyEvent("MultiIOLinkSMI_OnNewParameterName", multiIOLinkSMI_Instances[selectedInstance].parametersName)

  -- ...
end
Timer.register(tmrMultiIOLinkSMI, "OnExpired", handleOnExpiredTmrMultiIOLinkSMI)

-- ********************* UI Setting / Submit Functions Start ********************

local function pageCalled()
  updateUserLevel() -- try to hide user specific content asap
  tmrMultiIOLinkSMI:start()
  return ''
end
Script.serveFunction("CSK_MultiIOLinkSMI.pageCalled", pageCalled)

local function setSelectedInstance(instance)
  selectedInstance = instance
  _G.logger:info(nameOfModule .. ": New selected instance = " .. tostring(selectedInstance))
  multiIOLinkSMI_Instances[selectedInstance].activeInUI = true
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'activeInUI', true)
  tmrMultiIOLinkSMI:start()
end
Script.serveFunction("CSK_MultiIOLinkSMI.setSelectedInstance", setSelectedInstance)

local function getInstancesAmount ()
  return #multiIOLinkSMI_Instances
end
Script.serveFunction("CSK_MultiIOLinkSMI.getInstancesAmount", getInstancesAmount)

local function addInstance()
  _G.logger:info(nameOfModule .. ": Add instance")
  table.insert(multiIOLinkSMI_Instances, multiIOLinkSMI_Model.create(#multiIOLinkSMI_Instances+1))
  Script.deregister("CSK_MultiIOLinkSMI.OnNewValueToForward" .. tostring(#multiIOLinkSMI_Instances) , handleOnNewValueToForward)
  Script.register("CSK_MultiIOLinkSMI.OnNewValueToForward" .. tostring(#multiIOLinkSMI_Instances) , handleOnNewValueToForward)
  handleOnExpiredTmrMultiIOLinkSMI()
end
Script.serveFunction('CSK_MultiIOLinkSMI.addInstance', addInstance)

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

local function setRegisterEvent(event)
  multiIOLinkSMI_Instances[selectedInstance].parameters.registeredEvent = event
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'registeredEvent', event)
end
Script.serveFunction("CSK_MultiIOLinkSMI.setRegisterEvent", setRegisterEvent)

--- Function to share process relevant configuration with processing threads
local function updateProcessingParameters()
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'activeInUI', true)

  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'registeredEvent', multiIOLinkSMI_Instances[selectedInstance].parameters.registeredEvent)

  --Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'value', multiIOLinkSMI_Instances[selectedInstance].parameters.value)

  -- optionally for internal objects...
  --[[
  -- Send config to instances
  local params = helperFuncs.convertTable2Container(multiIOLinkSMI_Instances[selectedInstance].parameters.internalObject)
  Container.add(data, 'internalObject', params, 'OBJECT')
  Script.notifyEvent('MultiIOLinkSMI_OnNewProcessingParameter', selectedInstance, 'FullSetup', data)
  ]]

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
      _G.logger:info(nameOfModule .. ": Loaded parameters for multiIOLinkSMIObject " .. tostring(selectedInstance) .. " from CSK_PersistentData module.")
      multiIOLinkSMI_Instances[selectedInstance].parameters = helperFuncs.convertContainer2Table(data)

      -- If something needs to be configured/activated with new loaded data
      updateProcessingParameters()
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

