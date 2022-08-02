Scriptblocks 2 Objects
======================

Adds an object model to [Scriptblocks 2](https://github.com/rdococ/scriptblocks2). Objects can respond to a fixed set of messages, forward messages to other objects and recurse by sending messages to themselves.

## Features

* Creating anonymous objects that respond to a set of messages in arbitrary ways.
* Forwarding messages to other objects.

## Blocks

* Create Object - Creates and returns a new object with the responses defined by its body.
* Define Response - Defines a response to a message.
* Forward Message - Forwards a message to another object if the object understands it.
* Tell Object - Sends a message to an object.
* Ask Object - Sends a message to an object and reports the result.
* Get Myself - Returns the current object.

## Implementation details

The 'Create Object' block creates a closure and wraps it up into an Object instance. When a message is sent to a typical object, its closure is called with a plain table of the form `{name = ..., arg = ...}`, with the message name and argument. The 'Create Object' block uses the context attribute "objects:message" to hold the current message table. The 'Define Response' and 'Forward Message' blocks access this context attribute. If the message name matches a response definition, it is evaluated, otherwise the object closure continues execution.

MessageResult instances are used to hold the result of a message response. Because objects are implemented as closures, they can technically report any value. The 'Define Response' and 'Forward Message' blocks report MessageResults if they are successful to distinguish valid message responses. 'Forward Message' specifically uses this to determine if the recipient understood the message, and continue searching if it didn't.