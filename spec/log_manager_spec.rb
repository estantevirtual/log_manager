require 'spec_helper'

describe LogManager do
  let('logger') { double('logger') }
  let('agent_notifier') { double('agent_notifier') }

  context 'info' do
    before :each do
      @log_manager = LogManager.new(logger: logger, data: { any: 1, ble: 'ble' })
    end

    it 'logs the text' do
      expect(logger).to receive(:info).with('bla. Data: any: 1, ble: "ble"')
      @log_manager.info('bla')
    end

    it 'logs the block result' do
      expect(logger).to receive(:info).with('bla. Data: any: 1, ble: "ble"')
      @log_manager.info { 'bla' }
    end

    it 'cuts long messages' do
      log_manager = LogManager.new(
        config: { message_size_limit: 10 },
        logger: logger,
        data: { any: 'b' * 30 }
      )

      expect(logger).to receive(:info).with(
        'a' * 10 +
        '...' +
        'a' * 10 +
        '. Data: any: "bbbb...bbbbbbbbb"'
      )

      log_manager.info('a' * 10_000)
    end
  end

  context 'debug' do
    context 'when not in debug mode' do
      before :each do
        expect(logger).to receive(:debug?).and_return(false)
        @log_manager = LogManager.new(logger: logger, data: { any: 1 })
      end

      it 'doesnt log the text' do
        @log_manager.debug('bla')
      end

      it 'doesnt log the block result' do
        @log_manager.debug { 'bla' }
      end
    end

    context 'when in debug mode' do
      before :each do
        expect(logger).to receive(:debug?).and_return(true)
        @log_manager = LogManager.new(logger: logger, data: { any: 1 })
      end

      it 'logs the received text and the contained data' do
        expect(logger).to receive(:debug).with('bla. Data: any: 1')
        @log_manager.debug('bla')
      end

      it 'logs the return of the block and the contained data' do
        expect(logger).to receive(:debug).with('bla. Data: any: 1')
        @log_manager.debug { 'bla' }
      end
    end
  end

  context 'error' do
    before :each do
      expect(logger).to receive(:error?).and_return(true)
      @log_manager = LogManager.new(
        config: { agent_notifier: agent_notifier },
        logger: logger,
        data: { any: 1 }
      )
    end

    it 'notifies error message to agent (aka. New Relic)' do
      msg = 'Error'
      expect(agent_notifier).to receive(:notice_error).with(msg, custom_params: { any: 1 })
      expect(logger).to receive(:error).with('Message: Error. Data: any: 1. ')
      @log_manager.error(msg)
    end

    it 'notifies exception and log it\'s class, message and backtrace' do
      expect(logger).to receive(:error).with(%r{^Exception: ZeroDivisionError. Message: divided by 0. Data: any: 1. Backtrace: \/\w+\/\w+\/\w+\/\w+\/spec\/log_manager_spec.rb:\d+:in `\/' \| .*})

      begin
        1 / 0
      rescue => e
        expect(agent_notifier).to receive(:notice_error).with(e, custom_params: { any: 1 })
        @log_manager.error(exception: e)
      end
    end

    context 'when a message is passed along with the exception' do
      it 'logs the message, the exception\'s class and backtrace and also notifies it' do
        expect(agent_notifier).to receive(:notice_error)
        expect(logger).to receive(:error).with(%r{^Exception: ZeroDivisionError. Message: Custom message. Data: any: 1. Backtrace: \/\w+\/\w+\/\w+\/\w+\/spec\/log_manager_spec.rb:\d+:in `\/' \| .*})

        begin
          1 / 0
        rescue => e
          @log_manager.error(exception: e, message: 'Custom message')
        end
      end
    end
  end

  context 'when logging a progress of a loop' do
    before :each do
      @log_manager = LogManager.new(logger: logger)
    end

    it 'logs the iterations correctly' do
      expect(logger).to receive(:info)
        .with('any_message_start. Data: any_message: 0,' \
              ' any_message_timer: 2000-01-01 00:00:00 UTC')

      Timecop.freeze(Time.utc(2000, 1, 1, 0, 0, 0)) do
        @log_manager.any_message_start
      end

      n = 2
      n.times do |i|
        expect(logger).to receive(:debug?).and_return(true)
        expect(logger).to receive(:debug)
          .with("any_message_iteration. Data: any_message: #{i + 1}," \
                ' any_message_timer: 2000-01-01 00:00:00 UTC')

        @log_manager.any_message_iteration
      end

      expect(logger).to receive(:info)
        .with("any_message_finish. Data: any_message: #{n}," \
              ' any_message_timer: "2.0 secs"')

      Timecop.freeze(Time.utc(2000, 1, 1, 0, 0, 2)) do
        @log_manager.any_message_finish
      end
    end
  end
end
