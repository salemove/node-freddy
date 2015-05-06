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
      @freddy.respondTo @randomDest, (receivedMsg) ->
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

    it 'can handle positive acknowledgements', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.ack(res: 'yey')
      .done =>
        @freddy.deliver @randomDest, msg, ->
          done()
        , (error) ->
          done(Error('should have got positive ack'))

    it 'can handle negative acknowledgements', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.nack('not today')
      .done =>
        @freddy.deliver @randomDest, msg, ->
          done(Error('should have got negative ack'))
        , (error) ->
          expect(error).to.eql(error: 'not today')
          done()

    it 'can handle messages that require a response', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.ack(pay: 'load')
      .done =>
        @freddy.deliver @randomDest, msg, (response) ->
          expect(response).to.eql(pay: 'load')
          done()
        , (error) ->
          done(Error('should have got positive response'))

    it 'can handle messages that require a negative response', (done) ->
      @freddy.respondTo @randomDest, (payload, handler) ->
        handler.nack('not today')
      .done =>
        @freddy.deliver @randomDest, msg, (response) ->
          done(Error('should have got a negative response'))
        , (error) ->
          expect(error).to.eql(error: 'not today')
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
