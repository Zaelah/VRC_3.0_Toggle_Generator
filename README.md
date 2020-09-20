
VRC 3.0 Toggle Generator
========================

Instructions
------------

  1. Extract the contents of this repo into a folder in your Unity project
  2. Drag and drop Unity .anim files containing behavior for your Avatar you want to mix-and-match (Mesh enables/disables, Blendshape values, and/or Mesh material swaps) onto MAKE_TEMPLATE_FROM_ANIM.bat to create templates
  3. Create text files (and optionally folders) under template/combos/ and template/emotes/ to represent the Toggles you want to have, each one listing all of the templates you want to combine in that Toggle
  4. Double-click RUN_STEP_1.bat and wait for it to finish
  5. Open and/or give focus to your Unity project and wait for it to finish automatically "Importing small assets"
  6. Double-click RUN_STEP_2.bat
  7. In your avatar's VRC Avatar Descriptor:
  * Set Playable Layers > Base > FX to generated/FXLayer.controller
  * Set Expressions > Menu to generated/Menu.asset
  * Set Expressions > Parameters to generated/Parameters.asset
