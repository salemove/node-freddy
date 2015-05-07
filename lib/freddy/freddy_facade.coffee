q = require 'q'
_ = require 'underscore'

class FreddyFacade

  DEFAULT_TIMEOUT = 3

  constructor: (@consumer, @producer, @request, @onShutdown) ->
    @respondTo = @request.respondTo
    @tapInto = @consumer.tapInto

  deliver: (destination, message, options, successCallback, errorCallback) ->
    if typeof options is 'function'
      errorCallback = successCallback
      successCallback = options
      options = {}

    if successCallback && typeof successCallback != 'function'
      throw Error('success callback is required')

    if successCallback && typeof errorCallback != 'function'
      throw Error('error callback is required')

    options ||= {}
    options = _.pick(options, 'timeout', 'suppressLog', 'deleteOnTimeout')

    if successCallback
      options['timeout'] ||= 3

    if options['timeout'] && options['deleteOnTimeout'] == undefined
      options['deleteOnTimeout'] = true

    @request.deliver(destination, message, options, successCallback, errorCallback)

  shutdown: ->
    q(@onShutdown())

module.exports = FreddyFacade
