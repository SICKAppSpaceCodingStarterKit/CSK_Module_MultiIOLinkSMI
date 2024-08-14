# Changelog
All notable changes to this project will be documented in this file.

## Release 2.0.0

### New features
- Supports FlowConfig feature to provide data of IO-Link ReadMessage
- Function 'getPort' for currently selected instance
- Provide version of module via 'OnNewStatusModuleVersion'
- Function 'getParameters' to provide PersistentData parameters
- Check if features of module can be used on device and provide this via 'OnNewStatusModuleIsActive' event / 'getStatusModuleActive' function
- Function to 'resetModule' to default setup

### Improvements
- New UI design available (e.g. selectable via CSK_Module_PersistentData v4.1.0 or higher), see 'OnNewStatusCSKStyle'
- Preset names for ReadMessages / WriteMessages instead of renaming them after creation
- check if instance exists if selected
- 'loadParameters' returns its success
- 'sendParameters' can control if sent data should be saved directly by CSK_Module_PersistentData
- Added UI icon and browser tab information

## Release 1.0.0
- Initial commit
