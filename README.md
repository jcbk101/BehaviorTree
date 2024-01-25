# Defold Behavior Tree with Example

In this project you will find an example of a simple Behavior Tree implemented in Defold, using Lua, without any plugins.

You can find the basic tree and node module under `/modules/tree.lua` and `/modules/node.lua`. Example code is in `/main/main_bird.script`.

A video showing this example can be found at: https://www.youtube.com/watch?v=42PGvmFFeWI


## What can the Behavior Tree do?

### Example: Script file
`./main/main_bird.script`
- A five (5) second count down begins.
- At zero (0) seconds, the bird begins to fly to each static bird (waypoints).
- After reaching a static bird, the main bird will simulate eating.
- After a second of eating, the bird flies to the next waypoint.

## Notes

### Delta time

In Defold, each script that wishes to utilize the BT should contain an `function update(self, dt)` or `function fixed_update(self, dt)` function. This is where the tree 'Ticks' and test the tree nodes.

In this implementation, manual positioning of any moving objects that are altered by a Node / Task should be handled in the node / task itself. The main lua module is assigned a variable called `node.dt`
which is used as a global-to-the-behavior-tree variable.

There is also a single data context table (array) called `node.sharedData`, for every task to access. Naming variables should be cared for in order to maintain correct functioning. 


### Can this be production ready?

I've have used this implementation in my current game, and I haven't run into any issues thus far. I believe it to be flexible, and if you know what you are doing, 
you can make it work to your liking. Feel free to use / modify it as you see fit.

