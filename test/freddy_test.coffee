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

    it 'can handle success messages', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.success(pay: 'load')
      .done =>
        @freddy.deliver @randomDest, msg, (response) ->
          expect(response).to.eql(pay: 'load')
          done()
        , (error) ->
          done(Error('should have got success response'))

    it 'can handle error messages', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.error(error: 'not today')
      .done =>
        @freddy.deliver @randomDest, msg, (response) ->
          done(Error('should have got a error response'))
        , (error) ->
          expect(error).to.eql(error: 'not today')
          done()

    it 'requires a error callback when success is specified', (done) ->
      try
        @freddy.deliver @randomDest, msg, (response) ->
          done(Error('should not happen'))
      catch e
        expect(e.message).to.eql('error callback is required')
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

    context 'with send-and-forget message', ->
      it 'removes the message from the queue when timeout specified', (done) ->
        @freddy.consumer.channel.assertQueue(@randomDest, autoDelete: true).then =>
          @freddy.deliver @randomDest, msg, timeout: 0.01

          setTimeout =>
            @freddy.respondTo @randomDest, (payload, handler) ->
              done(Error('message was still in the queue'))
            .done =>
              setTimeout (-> done()), 20
          , 60

      it 'keeps the message in the queue when timeout is not specified', (done) ->
        @freddy.consumer.channel.assertQueue(@randomDest, autoDelete: true).then =>
          @freddy.deliver @randomDest, msg

          setTimeout =>
            @freddy.respondTo @randomDest, (payload, handler) -> done()
          , 60

    context 'with request message', ->
      it 'removes the message from the queue when timeout occurs', (done) ->
        @freddy.consumer.channel.assertQueue(@randomDest, autoDelete: true).then =>
          @freddy.deliver @randomDest, msg, timeout: 0.01, (->), (->)

          setTimeout =>
            @freddy.respondTo @randomDest, (payload, handler) ->
              done(Error('message was still in the queue'))
            .done =>
              setTimeout (-> done()), 20
          , 60

      it 'keeps the message in the queue when deleteOnTimeout is disabled', (done) ->
        @freddy.consumer.channel.assertQueue(@randomDest, autoDelete: true).then =>
          @freddy.deliver @randomDest, msg, timeout: 0.01, deleteOnTimeout: false, (->), (->)

          setTimeout =>
            @freddy.respondTo @randomDest, (payload, handler) -> done()
          , 60
