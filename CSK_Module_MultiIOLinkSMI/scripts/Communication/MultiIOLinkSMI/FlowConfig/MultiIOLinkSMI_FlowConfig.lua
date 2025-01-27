--*****************************************************************
-- Here you will find all the required content to provide specific
-- features of this module via the 'CSK FlowConfig'.
--*****************************************************************

require('Communication.MultiIOLinkSMI.FlowConfig.MultiIOLinkSMI_OnNewData')
require('Communication.MultiIOLinkSMI.FlowConfig.MultiIOLinkSMI_OnNewDataAuto')
--require('Communication.MultiIOLinkSMI.FlowConfig.MultiIOLinkSMI_SendRequest')

-- Reference to the multiIOLinkSMI_Instances handle
local multiIOLinkSMI_Instances

--- Function to react if FlowConfig was updated
local function handleOnClearOldFlow()
  if _G.availableAPIs.default and _G.availableAPIs.specificSMI then
    for i = 1, # multiIOLinkSMI_Instances do
      if multiIOLinkSMI_Instances[i].parameters.flowConfigPriority then
        CSK_MultiIOLinkSMI.clearFlowConfigRelevantConfiguration()
        break
      end
    end
  end
end
Script.register('CSK_FlowConfig.OnClearOldFlow', handleOnClearOldFlow)

--- Function to react if FlowConfig was updated
local function handleOnStopProvider()
  if _G.availableAPIs.default and _G.availableAPIs.specificSMI then
    for i = 1, # multiIOLinkSMI_Instances do
      if multiIOLinkSMI_Instances[i].parameters.flowConfigPriority then
        CSK_MultiIOLinkSMI.stopFlowConfigRelevantProvider()
        break
      end
    end
  end
end
Script.register('CSK_FlowConfig.OnStopFlowConfigProviders', handleOnStopProvider)

--- Function to get access to the multiIOLinkSMI_Instances
---@param handle handle Handle of multiIOLinkSMI_Instances object
local function setMultiIOLinkSMI_Instances_Handle(handle)
  multiIOLinkSMI_Instances = handle
end

return setMultiIOLinkSMI_Instances_Handle