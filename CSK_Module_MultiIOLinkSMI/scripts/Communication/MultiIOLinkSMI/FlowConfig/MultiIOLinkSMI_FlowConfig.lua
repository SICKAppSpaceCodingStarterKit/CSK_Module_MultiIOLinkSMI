--*****************************************************************
-- Here you will find all the required content to provide specific
-- features of this module via the 'CSK FlowConfig'.
--*****************************************************************

require('Communication.MultiIOLinkSMI.FlowConfig.MultiIOLinkSMI_OnNewData')
require('Communication.MultiIOLinkSMI.FlowConfig.MultiIOLinkSMI_OnNewDataAuto')
require('Communication.MultiIOLinkSMI.FlowConfig.MultiIOLinkSMI_WriteProcessData')

--- Function to react if FlowConfig was updated
local function handleOnClearOldFlow()
  if _G.availableAPIs.default and _G.availableAPIs.specificSMI then
    CSK_MultiIOLinkSMI.clearFlowConfigRelevantConfiguration()
  end
end
Script.register('CSK_FlowConfig.OnClearOldFlow', handleOnClearOldFlow)

--- Function to react if FlowConfig was updated
local function handleOnStopProvider()
  if _G.availableAPIs.default and _G.availableAPIs.specificSMI then
    CSK_MultiIOLinkSMI.stopFlowConfigRelevantProvider()
  end
end
Script.register('CSK_FlowConfig.OnStopFlowConfigProviders', handleOnStopProvider)
