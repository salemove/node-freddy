MessageHandler = require '../lib/freddy/message_handler'
should = require 'should'
TestHelper = (require './test_helper')

describe 'MessageHandler', ->

  before -> @properties = prop: 'value'

  beforeEach ->
    @messageHandler = new MessageHandler TestHelper.logger('warn'), @properties

  it 'keeps properties', ->
    @messageHandler.properties.should.eql(@properties)

  it 'has promise for checking for reponse', ->
    @messageHandler.whenResponded.should.be.ok

  context 'when success', ->
    before -> @response = my: 'resp'
    beforeEach -> @messageHandler.success(@response)

    it 'resolves response promise with the response', (done) ->
      @messageHandler.whenResponded.done (response) =>
        response.should.eql(@response)
        done()

  context 'when nacked', ->

    context 'with error message', ->
      before -> @error = 'bad'
      beforeEach -> @messageHandler.error(@error)

      it 'resolves response promise with error', (done) ->
        @messageHandler.whenResponded.done (->), (error) =>
          error.should.eql(@error)
          done()

    context 'without error message', ->
      before -> @error = "Couldn't process message"
      beforeEach -> @messageHandler.error()
      it "resolves response with error #{@error}", (done) ->
        @messageHandler.whenResponded.done (->), (error) =>
          error.should.eql(@error)
          done()
