Scriptblocks 2 Objects
======================

Adds an object model to [Scriptblocks 2](https://github.com/rdococ/scriptblocks2). Objects can respond to a fixed set of messages, forward messages to other objects and recurse by sending messages to themselves.

## Blocks

* Create Object - Creates and returns a new object with the responses defined by its body.
* Define Response - Defines a response to a message.
* Forward Message - Forwards a message to another object if the object understands it.
* Send Message - Sends a message to an object.
* Get Myself - Returns the current object.

## Implementation details

Objects are represented internally as closures.