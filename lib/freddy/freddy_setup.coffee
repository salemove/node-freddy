Producer = require './producer'
Consumer = require './consumer'
Request  = require './request'
amqp     = require('amqp-connection-manager')

q        = require 'q'
_ = require 'underscore'
FreddyFacade = require './freddy_facade'

class FreddySetup

  FREDDY_TOPIC_NAME = 'freddy-topic'

  constructor: (@logger) ->
    @errorListeners = []
    @connectListeners = []

  connect: (amqpUrl, amqpOptions) ->
    q(amqp.connect(amqpUrl, {connectionOptions: amqpOptions})).then (@connection) =>
      @logger.info "Connection established to amqp"

      process.once 'SIGINT', @shutdown
      @_registerConnectionListeners()

      @_createWorkers().then =>
        facade = new FreddyFacade @consumer, @producer, @request, @shutdown
        @logger.info "Freddy connection successfully established"
        q(facade)
    , (err) =>
      @logger.error "An error occured while establishing connection: #{err}"
      process.removeListener 'SIGINT', @shutdown
      q.reject(err)

  shutdown: =>
    process.removeListener 'SIGINT', @shutdown
    if @connection
      @connection.close()
    else
      q.resolve()

  addErrorListener: (listener) ->
    @errorListeners.push listener
    @consumer.addErrorListener listener if @consumer?

  addConnectListener: (listener) ->
    @connectListeners.push listener

  _registerConnectionListeners: ->
    @connection.on 'connect', (params) =>
      @logger.info "amqp connected #{params?.url}"
      @_triggerConnectionListeners()

    @connection.on 'disconnect', (params) =>
      @logger.info "amqp disconnected #{params?.err}"

    @connection.on 'close', (maybeErr) =>
      if maybeErr
        @_triggerErrorListeners(maybeErr)
        @logger.error "Closed amqp connection due to error #{maybeErr}"
      else
        @logger.info "Closed amqp connection"
    @connection.on 'error', (err) =>
      @_triggerErrorListeners(err)
      @logger.error "Amqp connection terminated due to error #{err}"
    @connection.on 'blocked', (reason) =>
      @logger.warn "Connection blocked to amqp, reason: #{reason}"

  _createWorkers: ->
    @producer = new Producer @connection, @logger
    @consumer = new Consumer @connection, @logger
    q.all([@producer.prepare(FREDDY_TOPIC_NAME),
          @consumer.prepare(FREDDY_TOPIC_NAME)]).spread (@producer, @consumer) =>
      for listener in @errorListeners
        @consumer.addErrorListener(listener)
      @request = new Request @connection, @logger
      @request.prepare(@consumer, @producer).then =>
        q(this)

  _triggerErrorListeners: (error) ->
    for listener in @errorListeners
      listener(error) if typeof listener is 'function'

  _triggerConnectionListeners: (error) ->
    for listener in @connectListeners
      listener(error) if typeof listener is 'function'

module.exports = FreddySetup
