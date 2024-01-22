--MIT License
--
--Copyright (c) 2023 SICK AG
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter

-- 
-- CreationTemplateVersion: 3.6.0
--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************

-- If app property "LuaLoadAllEngineAPI" is FALSE, use this to load and check for required APIs
-- This can improve performance of garbage collection

-- _G.availableAPIs = require('Communication/MultiIOLinkSMI/helper/checkAPIs') -- can be used to adjust function scope of the module related on available APIs of the device
-----------------------------------------------------------
-- Logger
_G.logger = Log.SharedLogger.create('ModuleLogger')
_G.logHandle = Log.Handler.create()
_G.logHandle:attachToSharedLogger('ModuleLogger')
_G.logHandle:setConsoleSinkEnabled(false) --> Set to TRUE if CSK_Logger is not used
_G.logHandle:setLevel("ALL")
_G.logHandle:applyConfig()
-----------------------------------------------------------

-- Loading script regarding MultiIOLinkSMI_Model
-- Check this script regarding MultiIOLinkSMI_Model parameters and functions
local multiIOLinkSMI_Model = require('Communication/MultiIOLinkSMI/MultiIOLinkSMI_Model')

local multiIOLinkSMI_Instances = {} -- Handle all instances
table.insert(multiIOLinkSMI_Instances, multiIOLinkSMI_Model.create(1)) -- Create at least 1 instance

-- Load script to communicate with the MultiIOLinkSMI_Model UI
-- Check / edit this script to see/edit functions which communicate with the UI
local multiIOLinkSMIController = require('Communication/MultiIOLinkSMI/MultiIOLinkSMI_Controller')
multiIOLinkSMIController.setMultiIOLinkSMI_Instances_Handle(multiIOLinkSMI_Instances) -- share handle of instances

--**************************************************************************
--**********************End Global Scope ***********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

--[[
--- Function to show how this module could be used
local function startProcessing()

  CSK_MultiIOLinkSMI.setSelectedInstance(1) --> select instance of module
  CSK_MultiIOLinkSMI.doSomething() --> preparation

  -- Option A --> prepare an event to trigger processing via this one
  --Script.serveEvent("CSK_MultiIOLinkSMI.OnNewTestEvent", "MultiIOLinkSMI_OnNewTestEvent") --> Create event to listen to and process forwarded object
  --CSK_MultiIOLinkSMI.setRegisterEvent('CSK_MultiIOLinkSMI.OnNewTestEvent') --> Register processing to the event

  --Script.notifyEvent('OnNewTestEvent', data)

    -- Option B --> trigger processing via function call
    local result = CSK_MultiIOLinkSMI.processSomething(data)

  end
end

-- Call processing function after persistent data was loaded
--Script.register("CSK_MultiIOLinkSMI.OnDataLoadedOnReboot", startProcessing)
]]

--OR

--- Function to react on startup event of the app
local function main()

  multiIOLinkSMIController.setMultiIOLinkSMI_Model_Handle(multiIOLinkSMI_Model) -- share handle of Model

  ----------------------------------------------------------------------------------------
  -- INFO: Please check if module will eventually load inital configuration triggered via
  --       event CSK_PersistentData.OnInitialDataLoaded
  --       (see internal variable _G.multiIOLinkSMI_Model.parameterLoadOnReboot)
  --       If so, the app will trigger the "OnDataLoadedOnReboot" event if ready after loading parameters
  --
  -- Can be used e.g. like this
  ----------------------------------------------------------------------------------------

  --startProcessing() --> see above
  CSK_MultiIOLinkSMI.pageCalled() -- Update UI

end
Script.register("Engine.OnStarted", main)

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************