# Changelog
All notable changes to this project will be documented in this file.

## Release 3.1.0

### New features
- OnNewRawReadMessage_INSTANCE_PORT_MESSAGENAME provides timestamp as 2nd event parameter (used for FlowConfig)

### Improvements
- Minor docu improvements
- Minor update of readMessageName check

### Bugfix
- 'OnNewDataAuto' FlowConfig block did not work with initial load of persistent data
- Legacy bindings of ValueDisplay elements and FileUpload feature within UI did not work if deployed with VS Code AppSpace SDK
- UI differs if deployed via Appstudio or VS Code AppSpace SDK
- Fullscreen icon of iFrame was visible

## Release 3.0.1

### Bugfix
- Issue to create new instances (introduced with v3.0.0)

## Release 3.0.0

### New features
- Provide features even without CSK_Module_IODDInterpreter
- Create readMessages without IODD information, by setting start-/endByte (or bit position within byte) and unpack format
- Optionally search and cut relevant part out of created JSON within readMessage
- Register to event to forward content as writeMessage
- New FlowConfig block 'OnNewDataAuto' which automatically creates readMessages and optionally checks to power selected port (WARNING: Do NOT mix with manual readMessage setup)
- New FlowConfig block 'WriteProcessData'
- React on "OnStopFlowConfigProviders" event of FlowConfig modul to stop pulling IO-Link data
- Check and handle different kind of IOLink.SMI APIs
- Function to delete all existing readMessages
- Check if persistent data to load provides all relevant parameters. Otherwise add default values
- Selectable if timers for readMessages should start automatically after parameters were loaded

### Improvements
- Changed event name "OnNewReadMessage_PORT_MESSAGENAME" to "OnNewReadMessage_INSTANCE_PORT_MESSAGENAME" to make it possible to switch between ports during runtime
- Do not start readMessage timers automatically with creation of readMessage
- Use new event 'OnNewRawReadMessage_INSTANCE_PORT_MESSAGENAME" within FlowConfig (only providing data content as first parameter)
- If using FlowConfig, start readMessage timers after 5 seconds
- Add info about port within "OnNewIOLinkPortStatus" event
- Add list of ports related to instances within "getInstancePortMap" function
- Better handling if CSK_IODDInterpreter is not available

### Bugfix
- Issue with CSK_UserManagement support
- Error if sending process data without any selection
- Error in handling IODD data

## Release 2.1.1

### Bugfixes
- writing of process data and parameters is available again

## Release 2.1.0

### New features
- Now it is possible to read subindexes (even if the subindex access is not supported). Requires IODD interpreter v2.1.0 or more

### Improvements
- Speeding up of data parsing when reading from IO-Link device

## Release 2.0.0

### New features
- Supports FlowConfig feature to provide data of IO-Link ReadMessage
- Changed event name of readMessages from 'readMessage[PORT][MESSAGENAME] to 'OnNewReadMessage_[PORT]_[MESSAGENAME]
- Possible to pause timers for readMessages
- Function 'getPort' for currently selected instance
- Provide version of module via 'OnNewStatusModuleVersion'
- Function 'getParameters' to provide PersistentData parameters
- Check if features of module can be used on device and provide this via 'OnNewStatusModuleIsActive' event / 'getStatusModuleActive' function
- Function to 'resetModule' to default setup

### Improvements
- Better interaction with CSK_IODDInterpreter (version 2.0.0 needed)
- Check status of port within instance thread (prevent to get data if sensor is not in operating mode)
- Port only changeable if currently inactive
- New UI design available (e.g. selectable via CSK_Module_PersistentData v4.1.0 or higher), see 'OnNewStatusCSKStyle'
- Preset names for ReadMessages / WriteMessages instead of renaming them after creation
- check if instance exists if selected
- 'loadParameters' returns its success
- 'sendParameters' can control if sent data should be saved directly by CSK_Module_PersistentData
- Added UI icon and browser tab information

### Bugfix
- IODD parsing
- Check if readMessage exists before trying to delete it

## Release 1.0.0
- Initial commit
