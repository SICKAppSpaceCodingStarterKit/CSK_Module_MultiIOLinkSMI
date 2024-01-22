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

-- luacheck: no max line length

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************
-- If App property "LuaLoadAllEngineAPI" is FALSE, use this to load and check for required APIs
-- This can improve performance of garbage collection
_G.availableAPIs = require('Communication/MultiIOLinkSMI/helper/checkAPIs') -- can be used to adjust function scope of the module related on available APIs of the device

-----------------------------------------------------------
-- Logger
_G.logger = Log.SharedLogger.create('ModuleLogger')
_G.logHandle = Log.Handler.create()
_G.logHandle:attachToSharedLogger('ModuleLogger')
_G.logHandle:setConsoleSinkEnabled(false) --> Set to TRUE if LoggingModule is not used
_G.logHandle:setLevel("ALL")
_G.logHandle:applyConfig()
-----------------------------------------------------------

-- Loading script regarding MultiIOLinkSMI_Model
-- Check this script regarding MultiIOLinkSMI_Model parameters and functions
local multiIOLinkSMI_Model = require('Communication/MultiIOLinkSMI/MultiIOLinkSMI_Model')

local multiIOLinkSMI_Instances = {} -- Handle all instances

-- Load script to communicate with the MultiIOLinkSMI_Model UI
-- Check / edit this script to see/edit functions which communicate with the UI
local multiIOLinkSMIController = require('Communication/MultiIOLinkSMI/MultiIOLinkSMI_Controller')

if _G.availableAPIs.ioLinkSmi and Engine.getEnumValues('IOLinkMasterPorts') ~= nil then
  _G.logger:info("IOLinkSMI API Support = true")
  table.insert(multiIOLinkSMI_Instances, multiIOLinkSMI_Model.create(1))
  multiIOLinkSMIController.setMultiIOLinkSMI_Instances_Handle(multiIOLinkSMI_Instances) -- share handle of instances
else
  _G.logger:warning("CSK_MultiIOLinkSMI: Features of this module are not supported on this device. Missing APIs.")
end

--**************************************************************************
--**********************End Global Scope ***********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************


local function main()

  if _G.availableAPIs.ioLinkSmi then
    multiIOLinkSMIController.setMultiIOLinkSMI_Model_Handle(multiIOLinkSMI_Model) -- share handle of model
    CSK_MultiIOLinkSMI.setSelectedInstance(1)
    CSK_MultiIOLinkSMI.pageCalled()
  end
    ----------------------------------------------------------------------------------------
  -- INFO: Please check if module will eventually load inital configuration triggered via
  --       event CSK_PersistentData.OnInitialDataLoaded
  --       (see internal variable _G.deepLearningObjects.parameterLoadOnReboot)
  --       If so, the app will trigger the "OnDataLoadedOnReboot" event if ready after loading parameters
  --
  ----------------------------------------------------------------------------------------


end
Script.register("Engine.OnStarted", main)

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************
