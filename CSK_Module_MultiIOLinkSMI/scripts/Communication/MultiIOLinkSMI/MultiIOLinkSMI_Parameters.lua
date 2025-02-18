---@diagnostic disable: redundant-parameter, undefined-global

--***************************************************************
-- Inside of this script, you will find the relevant parameters
-- for this module and its default values
--***************************************************************

local multiIOLinkSMIParameters = {}

multiIOLinkSMIParameters.flowConfigPriority = CSK_FlowConfig ~= nil or false -- Status if FlowConfig should have priority for FlowConfig relevant configurations
--multiIOLinkSMIParameters.name = 'Sensor'.. self.multiIOLinkSMIInstanceNoString -- for future use
multiIOLinkSMIParameters.processingFile = 'CSK_MultiIOLinkSMI_Processing'
multiIOLinkSMIParameters.port = '' -- IOLink port used
multiIOLinkSMIParameters.active = false -- Parameter showing if instance is activated or not
multiIOLinkSMIParameters.ioddInfo = nil -- Table containing IODD information
multiIOLinkSMIParameters.deviceIdentification = nil -- Table containing IODD information
multiIOLinkSMIParameters.ioddReadMessages = {} -- Table contatining information about read messages. Each read message has its own IODD Interpreter instance
multiIOLinkSMIParameters.ioddWriteMessages = {} -- Table contatining information about write messages. Each write message has its own IODD Interpreter instance
multiIOLinkSMIParameters.autoStartTimer = false -- Status if read message timers should be started automatically after parameters were loaded

return multiIOLinkSMIParameters