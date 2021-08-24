ResponderHandler = require './responder_handler'
MessageHandler   = require './message_handler'
q = require 'q'

class Consumer

  QUEUE_OPTIONS =
    autoDelete: true

  TOPIC_OPTIONS =
    durable: false
    autoDelete: false

  constructor: (@connection, @logger) ->
    @errorListeners = []
    @consumers = {}

  addErrorListener: (listener) ->
    @errorListeners.push listener

  prepare: (@topicName) ->
    channel = @connection.createChannel({
      name: 'consumerChannel',
      setup: (@channel) =>
        @logger.debug("Channel created for consumer")
        return q(@channel.assertExchange(@topicName, 'topic', TOPIC_OPTIONS)).then(() =>
          @logger.debug("Topic exchange created for producer")
        )
    })

    return q(new Promise((resolve, _reject) =>
      channel.on('connect', () => resolve(this))
    ))

  _ensureQueue: (queue) ->
    if !queue? or !(typeof queue is 'string')
      throw "Destination must be provided as a string"

  consume: (queue, callback) ->
    @consumers[queue] = {
      queueOpts: QUEUE_OPTIONS,
      callback: callback
    }
    @consumeWithOptions(queue, QUEUE_OPTIONS, callback)

  resumeConsumers: () =>
    for queue, consumer of @consumers
      @consumeWithOptions(queue, consumer['queueOpts'], consumer['callback'])

  consumeWithOptions: (queue, queueOpts, callback) ->
    @_ensureQueue(queue)
    responderHandler = new ResponderHandler(@channel)
    q(@channel.assertQueue(queue, queueOpts)).then (queueObject) =>
      responderHandler.queue = queueObject.queue
      return @_consumeWithQueueReady queueObject.queue, (message, messageObject) =>
        callback(message, new MessageHandler(@logger, messageObject.properties))
    .then (subscription) =>
      responderHandler.ready(subscription.consumerTag)
      q(responderHandler)
    , (err) =>
      @logger.error "Consumer with destination #{queue} exited: #{err}"
      q.reject(err)

  notifyErrorListeners: (error) ->
    for listener in @errorListeners
      try
        listener?(error) if typeof listener is 'function'
      catch err
        @logger.error "Error listener throw error #{err}"


  _consumeWithQueueReady: (queue, callback) ->
    @logger.debug "Consuming messages on #{queue}"
    @channel.consume queue, (messageObject) =>
      return unless messageObject
      @logger.debug "Received message on #{queue}"
      properties = messageObject.properties
      @_parseMessage(messageObject).done (message) =>
        @logger.debug "The message is", message unless properties.headers?.suppressLog
        try
          callback(message, messageObject)
        catch err
          @notifyErrorListeners(err)
          @logger.error "Consuming from #{queue} callback #{callback} threw an error, continuing to listen. #{err}"
        @channel.ack messageObject

  _parseMessage: (messageObject) ->
    try
      q(JSON.parse(messageObject.content.toString()))
    catch err
      @logger.error "Couldn't parse message #{messageObject.content.toString()}, err: #{err}"
      q.reject(err)

  tapInto: (pattern, callback) =>
    responderHandler = new ResponderHandler @channel
    q(@channel.assertQueue('', exclusive: true, autoDelete: true)).then (queueObject) =>
      queueName = queueObject.queue
      responderHandler.queue = queueName
      @channel.bindQueue(queueName, @topicName, pattern).then =>
        q(@_consumeWithQueueReady(queueName, (message, messageObject) =>
          callback(message, messageObject.fields.routingKey)
        ))
    .then (subscription) =>
      responderHandler.ready(subscription.consumerTag)
      q(responderHandler)

module.exports = Consumer
