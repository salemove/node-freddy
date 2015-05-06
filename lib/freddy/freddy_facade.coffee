q = require 'q'

class FreddyFacade

  DEFAULT_TIMEOUT = 3

  constructor: (@consumer, @producer, @request, @onShutdown) ->
    @deliver = @request.deliver
    @respondTo = @request.respondTo
    @tapInto = @consumer.tapInto

  shutdown: ->
    q(@onShutdown())

module.exports = FreddyFacade
