# Configure chai
chai = require 'chai'
sinonChai = require 'sinon-chai'
chai.use(sinonChai)
global.expect = chai.expect

winston   = require 'winston'
amqp      = require('amqp-connection-manager')
amqpUrl   = "amqp://guest:guest@localhost:5672"
q         = require 'q'

uniqueId = -> id = ""; id += Math.random().toString(36).substr(2) while id.length < 32; id.substr 0, 32

logger = (level = 'debug') ->
  winston.createLogger({
    transports: [ new winston.transports.Console level: level, colorize: true, timestamp: true ]
  })

deleteExchange = (connection, exchangeName) ->
  q(new Promise((resolve, reject) ->
    connection.createChannel({
      setup: (amqpChannel) ->
        amqpChannel.deleteExchange(exchangeName)
        resolve()
    })
  ))

connect = ->
  q(amqp.connect(amqpUrl))

deliver = (connection, queue, topicName, message) ->
  q(connection.createChannel()).then (channel) ->
    messageToSend = new Buffer(JSON.stringify(message))
    channel.publish(topicName, queue, messageToSend)
    channel.sendToQueue(queue, messageToSend)
    channel

exports.logger = logger
exports.deleteExchange = deleteExchange
exports.connect = connect
exports.deliver = deliver
exports.amqpUrl = amqpUrl
exports.uniqueId = uniqueId
