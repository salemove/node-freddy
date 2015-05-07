q = require 'q'

class MessageHandler

  constructor: (@logger, @properties) ->
    @_responded = q.defer()
    @whenResponded = @_responded.promise

  success: (response) ->
    @logger.debug("Responder responded with a success message", response)
    @_responded.resolve(response || {})

  error: (errorMessage) ->
    @logger.debug("Responder responded with an error", errorMessage)
    @_responded.reject(errorMessage || "Couldn't process message")

module.exports = MessageHandler
