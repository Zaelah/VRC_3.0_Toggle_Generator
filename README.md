
VRC 3.0 Toggle Generator
========================

Preparation
-----------

    1. Extract the contents of this repo into a folder in your Unity project
    2. Manually extract snippets of toggleable behavior you want to mix-and-match from Unity .anim files (open them up in a text editor) and put them into specially-formatted files under template/states and template/emotes.
    3. Manually create files for each Toggle you want, listing each file under template/states that should be combined to create the toggleable behavior you want (e.g. combination of Mesh enables/disables, Blendshape values, and/or Mesh material swaps).

Usage
-----

    1. Double-click RUN_STEP_1.bat - this will create animation files and other files that need to be referenced in step 3.
    2. Open or give focus to your Unity project and wait for it to finish automatically "Importing small assets". This creates files needed for step 3.
    3. Double-click RUN_STEP_2.bat - this will create all menu, parameter and animation controller files.
    4. In your avatar's VRC Avatar Descriptor:
        * Set Playable Layers > Base > FX to generated/FXLayer.controller
        * Set Expressions > Menu to generated/Menu.asset
        * Set Expressions > Parameters to generated/Parameters.asset
