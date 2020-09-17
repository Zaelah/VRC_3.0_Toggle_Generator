
VRC 3.0 Toggle Generator
========================

Preparation
-----------

  1. Extract the contents of this repo into a folder in your Unity project
  2. Create animations containing individual behaviors or sets of behaviors you want to be able to mix-and-match (Mesh enables/disables, Blendshape values, and/or Mesh material swaps). Drag and drop these reference animations onto MAKE_TEMPLATE_FROM_ANIM.bat to generate a template file. Move this file to template/emotes (if it's a facial expression) or template/states (if it's some other kind of state or outfit change).
  3. Manually create files for each Toggle you want, listing each file under template/states that should be combined to create the toggleable behavior you want. Put these 'combo' files under template/combos. The folder structure of template/combos will be translated directly into the sub-menu structure in VRChat's Avatar 3.0 rotary expression menu.

Usage
-----

  1. Double-click RUN_STEP_1.bat - this will create animation files and other files that need to be referenced in step 3.
  2. Open or give focus to your Unity project and wait for it to finish automatically "Importing small assets". This creates files needed for step 3.
  3. Double-click RUN_STEP_2.bat - this will create all menu, parameter and animation controller files.
  4. In your avatar's VRC Avatar Descriptor:
  * Set Playable Layers > Base > FX to generated/FXLayer.controller
  * Set Expressions > Menu to generated/Menu.asset
  * Set Expressions > Parameters to generated/Parameters.asset
