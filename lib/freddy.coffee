winston = require 'winston'
FreddySetup = require './freddy/freddy_setup'

defaultLogger = winston.createLogger({
  transports: [
    new winston.transports.Console(level: 'info', colorize: true, timestamp: true)
  ]
})

setup = null

connect = (amqpUrl, {logger = defaultLogger, ...amqpOptions}) ->
  setup = new FreddySetup(logger)
  setup.connect(amqpUrl, amqpOptions)

addErrorListener = (listener) ->
  setup.addErrorListener listener if setup

exports.connect = connect
exports.addErrorListener = addErrorListener
