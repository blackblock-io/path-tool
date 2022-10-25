Download the ZIP and extract it.
Copy the `addons` directory to your godot 4.0 project root.
Then in godot go to `project settings` -> `plugins` and enable the path-tool plugin.

Demo video: [https://youtu.be/45_5DmTPMP0](https://youtu.be/45_5DmTPMP0)

How to use:

First before anything add a PathPointManager node to the 3D scene's root from "Add Child Node" button in the "Scene" dock.
Add PathPoint3D (PP) nodes under the PathPointManager node from "Add Child Node" button in the "Scene" dock.
Select PP you want to connect from and press "Assign source PathPoint3D (b)" from the PathToolDock.
Then select PPs you want to connect to from the source PP and press "Assign next neighbours (n)" from the PathToolDock.
Assigning a PP as a source node is only needed when assigning next neighbours directly as instructed above.

OR the faster way:

Click on a PP you want to connect from, then press "Create next neighbour (d)".
It creates a new PP and automatically connects the old PP to the new one.
Then just move the new new PP to a wanted position and repeat.

OR the super fast way:

Click on a PP you want to connect from, then press "Enable super mode (s)".
Then move you mouse anywhere in the scene and press space bar to create a PP into the location of your mouse.
It creates a new PP and connects the previously selected PP to the new one.
You can keep placing new PPs like that as long as there's collision shapes where the mouse is.
Alternatively, you don't need to have any PPs selected when starting to use super mode,
using it this way just creates a new PP without any connections.
When you're done, click "Disable super mode (s)".

PP colors:

Red = Not connected into or from anything

Blue = Currently selected source PP

Yellow = Connected from a PP but doesn't connect into any PPs

Purple = Connects into PPs but is not connected from any PPs

Green = Connected both ways


You can manipulate path settings (curve value, auto curvature, weights for the csv export) by clicking on a path between two PPs.

You can manipulate PP settings (tags) by clicking on a PP.
