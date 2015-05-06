# Messaging API supporting acknowledgements and request-response

[![Build Status](https://travis-ci.org/salemove/node-freddy.svg?branch=master)](https://travis-ci.org/salemove/node-freddy)

## Usage

Since 0.2.1 freddy for node.js uses promises, more info at

https://github.com/kriskowal/q (Pay close attention the the section *The End*)

### Setup
```coffee
Freddy = require 'freddy'
Freddy.addErrorListener(listener)
Freddy.connect('amqp://guest:guest@localhost:5672', logger).done (freddy) ->
  continueWith(freddy)
, (error) ->
  doSthWithError(error)
```

### Delivering messages
```coffee
freddy.deliver(destination, message, options = {}, positiveCallback = null, negativeCallback = null)
```

  The options include:

  * `timeout`: In seconds, defaults to 3.
  * `suppressLog`: Avoid logging the message contents


### Responding to messages
```coffee
freddy.respondTo(destination, callback)
```

* `respondTo` returns a promise which resolved with the ResponderHandler

```coffee
freddy.respondTo destination, (message, handler) ->
  handler.ack(x: 'y')
.done (responderHandler) ->
  doSthWith(responderHandler.cancel())
```

### The MessageHandler

### Tapping into messages

```coffee
responderHandler = freddy.tapInto(pattern, callback)
```

No other differences to ruby spec, blocking variant is not provided for obvious reasons.

### The ResponderHandler

* When cancelling the responder returns a promise, no messages will be received after the promise resolves.

```coffee
freddy.respondTo(destination, (->))
.then (responderHandler) ->
  responderHandler.cancel()
.done ->
  freddy.deliver(destination, easy: 'go') #will not be received
```

## Credits

**freddy** was originally written by [Urmas Talimaa] as part of SaleMove development team.

![SaleMove Inc. 2012][SaleMove Logo]

**freddy** is maintained and funded by [SaleMove, Inc].

The names and logos for **SaleMove** are trademarks of SaleMove, Inc.

[Urmas Talimaa]: https://github.com/urmastalimaa?source=c "Urmas"
[SaleMove, Inc]: http://salemove.com/ "SaleMove Website"
[SaleMove Logo]: http://app.salemove.com/assets/logo.png "SaleMove Inc. 2012"
