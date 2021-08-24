q = require 'q'
_ = require 'underscore'

#Encapsulate the request-response types of messaging
class Request

  RESPONSE_QUEUE_OPTIONS =
    exclusive: true

  MESSAGE_TYPES =
    REQUEST: 'request'
    SUCCESS: 'success'
    ERROR: 'error'

  constructor: (@connection, @logger) ->
    @requests = {}
    @responseQueue = null
    @isReconnecting = false

  setIsReconnecting: (value) ->
    @isReconnecting = value

  prepare: (@consumer, @producer) ->
    return q.reject('Need consumer and producer') unless @consumer and @producer
    channel = @connection.createChannel({
      setup: @_setupResponseQueue
    })

    return q(new Promise((resolve, reject) =>
      channel.on('connect', resolve)
    ))

  deliver: (destination, message, options, successCallback, errorCallback) =>
    if successCallback
      options.type = MESSAGE_TYPES.REQUEST
      @_request destination, message, options, (message, msgHandler) =>
        if !msgHandler || msgHandler.properties.type == MESSAGE_TYPES.ERROR
          errorCallback message
        else
          successCallback message
    else
      @producer.produce destination, message, options

  _request: (destination, message, options, callback) ->
    correlationId = @_uuid()
    _.extend options, {correlationId: correlationId, replyTo: @responseQueue}
    @requests[correlationId] = {
      timeout: @_timeout(destination, message, options.timeout, correlationId, callback)
      callback: callback
    }
    @producer.produce destination, message, options

  respondTo: (destination, callback) =>
    @consumer.consume destination, (message, msgHandler) =>
      properties = msgHandler.properties
      @_responder(properties) message, msgHandler, callback, (type, response) =>
        correlationId = properties.correlationId
        @producer.produce properties.replyTo, response, {correlationId, type} if response?

  _responder: (properties) ->
    if properties.type == MESSAGE_TYPES.REQUEST
      @_respondToRequest
    else
      @_respondToSimpleDeliver

  _respondToRequest: (message, msgHandler, callback, done) ->
    msgHandler.whenResponded.done (response) ->
      done(MESSAGE_TYPES.SUCCESS, response)
    , (error) ->
      done(MESSAGE_TYPES.ERROR, error)
    callback(message, msgHandler)

  _respondToSimpleDeliver: (message, msgHandler, callback) ->
    callback(message, msgHandler)
    return null # avoid returning anything

  _uuid: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c is 'x' then r else (r & 0x3|0x8)
      v.toString(16)
    )

  _timeout: (destination, message, timeoutSeconds, correlationId, callback) ->
    setTimeout =>
      errorText = "Timeout waiting for response from #{destination} with #{timeoutSeconds}s"
      @logger.error "#{errorText}, payload:", message
      @consumer.notifyErrorListeners(new Error(errorText))
      delete @requests[correlationId]
      callback {error: "Timeout waiting for response"} if (typeof callback is 'function')
    , timeoutSeconds * 1000

  _setupResponseQueue: (channel) =>
    @logger.debug "Created response queue for requests"
    if @isReconnecting
      @logger.debug "Resuming consumers after reconnect"
      @consumer.resumeConsumers()
      @setIsReconnecting(false)
    @consumer.consumeWithOptions '', RESPONSE_QUEUE_OPTIONS, (message, msgHandler) =>
      correlationId = msgHandler.properties.correlationId
      if @requests[correlationId]?
        entry = @requests[correlationId]
        clearTimeout entry.timeout
        delete @requests[correlationId]
        @logger.debug "Received request response on #{@responseQueue}"
        entry.callback message, msgHandler
    .then (subscription) =>
      @responseQueue = subscription.queue
      q(subscription)

module.exports = Request
