# Encapsulate delivering.
# Send every message to the direct queue and the topic exchange.
_ = require 'underscore'
q = require 'q'

class Producer

  TOPIC_EXCHANGE_OPTIONS =
    durable: false
    autoDelete: false

  constructor: (@connection, @logger) ->

  prepare: (@topicName) ->
    q(@connection.createChannel()).then (@channel) =>
      @logger.debug("Channel created for producer")
      q(@channel.assertExchange(@topicName, 'topic', TOPIC_EXCHANGE_OPTIONS))
    .then =>
      @logger.debug("Topic exchange created for producer")
      q(this)
    , (err) =>
      @logger.error("Failed to prepare Producer: #{err}")
      q.reject(err)

  produce: (destination, message = {}, options = {}) ->
    @_ensureDestination(destination)
    @logger.debug("Publishing to #{destination}:", message) unless options.suppressLog

    rabbitOptions = _.pick(options, 'type', 'replyTo', 'correlationId')
    rabbitOptions['contentType'] = 'application/json'
    rabbitOptions['headers'] = {suppressLog: (options.suppressLog || false)}
    if options['deleteOnTimeout']
      rabbitOptions['expiration'] = Math.floor(options['timeout'] * 1000)

    messageToSend = @_prepareMessage(message)

    @channel.publish(@topicName, destination, messageToSend, rabbitOptions)
    @channel.sendToQueue(destination, messageToSend, rabbitOptions)

  _ensureDestination: (destination) ->
    if (!destination? or !(typeof destination is 'string'))
      throw "Destination must be provided as a string"

  _prepareMessage: (message) ->
    new Buffer(JSON.stringify(message))

module.exports = Producer
