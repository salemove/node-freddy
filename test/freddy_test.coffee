Freddy      = require '../lib/freddy'
TestHelper  = require './test_helper'
q           = require 'q'

describe 'Freddy', ->
  logger = TestHelper.logger('warn')
  msg = {test: 'data'}

  describe '.connect', ->
    context 'with correct amqp url', ->
      it 'can connect to amqp', (done) ->
        Freddy.connect(TestHelper.amqpUrl, logger).done ->
          done()
        , =>
          done Error("Connection should have succeeded, but failed")

    context 'with incorrect amqp url', ->
      it 'cannot connect', (done) ->
        Freddy.connect('amqp://wrong:wrong@localhost:9000', logger).done ->
          done(Error("Connection should have failed, but succeeded"))
        , =>
          done()

  context 'when connected', ->
    beforeEach (done) ->
      @randomDest = TestHelper.uniqueId()
      Freddy.connect(TestHelper.amqpUrl, logger).done (@freddy) =>
        done()
      , (err) ->
        done(err)

    afterEach (done) ->
      @freddy.shutdown().done ->
        done()

    it 'can send and receive messages', (done) ->
      @freddy.respondTo @randomDest, (receivedMsg, handler) ->
        expect(receivedMsg).to.eql(msg)
        done()
      .done =>
        @freddy.deliver @randomDest, msg

    it 'can catch errors', (done) ->
      myError = new Error('catch me')
      Freddy.addErrorListener (err) ->
        err.should.eql(myError)
        done()

      @freddy.respondTo @randomDest, (message, msgHandler) ->
        throw myError
      .done =>
        @freddy.deliver @randomDest, {}

    it 'can handle positive messages', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.ack(pay: 'load')
      .done =>
        @freddy.deliver @randomDest, msg, (response) ->
          expect(response).to.eql(pay: 'load')
          done()
        , (error) ->
          done(Error('should have got positive response'))

    it 'can handle negative messages', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.nack(error: 'not today')
      .done =>
        @freddy.deliver @randomDest, msg, (response) ->
          done(Error('should have got a negative response'))
        , (error) ->
          expect(error).to.eql(error: 'not today')
          done()

    it 'requires a negative callback when positive is specified', (done) ->
      try
        @freddy.deliver @randomDest, msg, (response) ->
          done(Error('should not happen'))
      catch e
        expect(e.message).to.eql('negative callback is required')
        done()

    describe 'when tapping', ->
      it "doesn't consume message", (done) ->
        tapPromise = q.defer()
        respondPromise = q.defer()
        @freddy.tapInto @randomDest, =>
          tapPromise.resolve()
        .then =>
          @freddy.respondTo @randomDest, =>
            respondPromise.resolve()
        .done =>
          q.all([tapPromise, respondPromise]).then ->
            done()
          @freddy.deliver @randomDest, msg

    context 'on timeout', ->
      context 'with delete_on_timeout enabled', ->
        it 'removes the message from the queue', (done) ->
          @freddy.consumer.channel.assertQueue(@randomDest, autoDelete: true).then =>
            @freddy.deliver @randomDest, msg, timeout: 0.01

            setTimeout =>
              @freddy.respondTo @randomDest, (payload, handler) ->
                done(Error('message was still in the queue'))
              .done =>
                setTimeout (-> done()), 20
            , 60

      context 'with delete_on_timeout disabled', ->
        it 'keeps the message in the queue', (done) ->
          @freddy.consumer.channel.assertQueue(@randomDest, autoDelete: true).then =>
            @freddy.deliver @randomDest, msg, timeout: 0.01, deleteOnTimeout: false

            setTimeout =>
              @freddy.respondTo @randomDest, (payload, handler) -> done()
            , 20
