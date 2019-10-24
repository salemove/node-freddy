# Messaging API supporting acknowledgements and request-response

[![Build Status](https://travis-ci.org/salemove/node-freddy.svg?branch=master)](https://travis-ci.org/salemove/node-freddy)

## Setup

Inject the appropriate logger and set up connection parameters:

```coffee
Freddy = require 'freddy'
Freddy.addErrorListener(listener)
Freddy.connect('amqp://guest:guest@localhost:5672', {logger}).done (freddy) ->
  continueWith(freddy)
, (error) ->
  doSthWithError(error)
```

### TLS connection

See http://www.squaremobius.net/amqp.node/ssl.html for available options.

```coffee
sslOptions = {
  cert: fs.readFileSync('clientcert.pem'),
  key: fs.readFileSync('clientkey.pem'),
  ca: [fs.readFileSync('cacert.pem')]
}

Freddy.connect('amqps://localhost:5671', {logger, ...sslOptions}).done (freddy) ->
  continueWith(freddy)
, (error) ->
  doSthWithError(error)
```

## Supported message queues

These message queues have been tested and are working with Freddy. Other queues can be added easily:

 * [RabbitMQ](https://www.rabbitmq.com/)

## Delivering messages

### Simple delivery

#### Send and forget
Sends a `message` to the given `destination`. If there is no consumer then the
message stays in the queue until somebody consumes it.
```coffee
  freddy.deliver destination, message
```

#### Expiring messages
Sends a `message` to the given `destination`. If nobody consumes the message in
`timeout` seconds then the message is discarded. This is useful for showing
notifications that must happen in a certain timeframe but where we don't really
care if it reached the destination or not.
```coffee
freddy.deliver destination, message, timeout: 5
```

### Request delivery

#### Expiring messages
Sends a `message` to the given `destination`. Has a default timeout of 3 and
discards the message from the queue if a response hasn't been returned in that
time.
```coffee
freddy.deliver destination, message, (response) ->
  # ...
, (error) ->
  # ...
```

#### Persistant messages
Sends a `message` to the given `destination`. Keeps the message in the queue if
a timeout occurs.
```coffee
freddy.deliver destination, message, timeout: 4, deleteOnTimeout: false, (response) ->
  # ...
, (error) ->
  # ...
```

## Responding to messages
```coffee
freddy.respondTo destination, (message, handler) ->
  if true
    handler.success(id: 5)
  else
    handler.error(error: 'something went wrong')
.done (responderHandler) ->
  doSthWith(responderHandler)
```

## Tapping into messages
When it's necessary to receive messages but not consume them, consider tapping.

```coffee
responderHandler = freddy.tapInto(pattern, callback)
```

* `destination` refers to the destination that the message was sent to
* Note that it is not possible to respond to the message while tapping.
* When tapping the following wildcards are supported in the `pattern` :
  * `#` matching 0 or more words
  * `*` matching exactly one word

Examples:

```coffee
freddy.tapInto "i.#.free", (message, handler) ->
  # ...
```
receives messages that are delivered to `"i.want.to.break.free"`

```coffee
freddy.tapInto "somebody.*.love", (message, handler) ->
  # ...
```
receives messages that are delivered to `somebody.to.love` but doesn't receive messages delivered to `someboy.not.to.love`

## Credits

**freddy** was originally written by [Urmas Talimaa] as part of SaleMove development team.

![SaleMove Inc. 2012][SaleMove Logo]

**freddy** is maintained and funded by [SaleMove, Inc].

The names and logos for **SaleMove** are trademarks of SaleMove, Inc.

[Urmas Talimaa]: https://github.com/urmastalimaa?source=c "Urmas"
[SaleMove, Inc]: http://salemove.com/ "SaleMove Website"
[SaleMove Logo]: http://app.salemove.com/assets/logo.png "SaleMove Inc. 2012"
