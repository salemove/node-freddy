q = require 'q'
_ = require 'underscore'

class FreddyFacade

  DEFAULT_TIMEOUT = 3

  constructor: (@consumer, @producer, @request, @onShutdown) ->
    @respondTo = @request.respondTo
    @tapInto = @consumer.tapInto

  deliver: (destination, message, options, positiveCallback, negativeCallback) ->
    if typeof options is 'function'
      negativeCallback = positiveCallback
      positiveCallback = options
      options = {}

    options ||= {}
    options = _.pick(options, 'timeout', 'suppressLog', 'deleteOnTimeout')
    options['timeout'] ||= 3

    if options['deleteOnTimeout'] == undefined
      options['deleteOnTimeout'] = true

    @request.deliver(destination, message, options, positiveCallback, negativeCallback)

  shutdown: ->
    q(@onShutdown())

module.exports = FreddyFacade
