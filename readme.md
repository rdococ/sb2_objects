Scriptblocks 2 Objects
======================

Adds an object model to [Scriptblocks 2](https://github.com/rdococ/scriptblocks2). An object can be thought of as a sort of 'mini-computer program'. You can send a message consisting of a message title and some data to an object and it will respond in a certain way, performing actions and reporting a value like a procedure does. Unlike a procedure, objects can be switched out with other objects that respond differently to the same messages. This is a very powerful mechanism for creating modular programs.

Objects are also similar to closures, unnamed procedures that can be passed around as values. You can consider a closure to be an object with only one message; alternatively, you can consider an object to be a closure that takes two arguments, the message title and accompanying data. In fact, this extension implements objects using builtin closures.

## Features

* Creating objects with arbitrary responses to a set of messages.
* Forwarding messages to objects, conditionally; i.e. only if the forwardee understands the message.
* Accessing data from where the object was created; i.e. lexical scope.