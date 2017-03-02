require_relative './agent_notifier_factory'

class LogManager
  attr_accessor :data

  def initialize(data: {}, logger: nil, config: nil)
    @data = data
    @logger = logger || Rails.logger
    @config = { message_size_limit: 2000 }
    @config = @config.merge(config) if config
    @agent_notifier = AgentNotifierFactory.build(@config)
  end

  def self.merge(data:, other:)
    instance = new(data: data)
    instance.merge(other)
  end

  def merge(other)
    return self if other.nil?
    @data = @data.merge(other.data)
    self
  end

  def info(text = nil, &block)
    text = yield if block
    @logger.info(log(text))
  end

  def debug(text = nil, &block)
    return unless debug?

    text = yield if block

    @logger.debug(log(text))
  end

  def debug?
    @logger.debug?
  end

  def error(progname = nil,
            exception: nil,
            message: nil,
            supress_notification: false,
            custom_params: nil,
            &block)
    return unless @logger.error?

    block_message = yield if block

    exception_msg =
      if exception
        if exception.respond_to?(:message) && exception.message
          exception.message
        else
          exception.inspect
        end
      end

    final_message = block_message || message || exception_msg || progname

    log_exception = "Exception: #{exception.class}. " if exception
    log_message = "Message: #{log(final_message)}. "
    log_backtrace = "Backtrace: #{exception.backtrace.join(' | ')}" if exception
    @logger.error("#{log_exception}#{log_message}#{log_backtrace}")

    return if supress_notification

    # notice error
    if exception
      @agent_notifier.notice_error(exception, custom_params: custom_params || @data)
    else
      @agent_notifier.notice_error(final_message, custom_params: custom_params || @data)
    end
  end

  def string
    @data.map { |key, value| "#{key}: #{value.inspect}" }.join(', ')
  end

  def method_missing(m, *args, &block)
    match = m.to_s.match(/(.*)_(start|iteration|finish)/)
    super if match.nil?

    total = args.last[:total] if args.last.is_a?(Hash)

    log_progress(name: match[1], type: match[2], total: total)
  end

  def respond_to_missing?(m, include_private = false)
    m.to_s.match(/(.*)_(start|iteration|finish)/) || super
  end

  protected

  def log(text)
    "#{compact_long_message(text)}. Data: #{compact_long_message(string)}"
  end

  def compact_long_message(msg)
    msg_limit = @config[:message_size_limit]
    msg_size = msg.size
    return msg if msg_size <= msg_limit

    second_limit = msg_size - msg_limit
    second_limit = msg_size if second_limit <= msg_limit
    "#{msg[0..msg_limit - 1]}...#{msg[second_limit..msg_size]}"
  end

  def log_progress(name:, type:, total:)
    case type
    when 'start'.freeze
      @data[name] = 0
      @data["#{name}_timer"] = Time.now.utc
      @data["#{name}_total"] = total if total
      info("#{name}_#{type}")
    when 'iteration'.freeze
      @data[name] += 1

      if @data["#{name}_total"]
        percent = (@data[name].to_f * 100) / @data["#{name}_total"].to_f

        info("#{name}_percent: #{percent}%") if (@data[name] % 1000).zero?
        debug("#{name}_percent: #{percent}%")
      end

      info("#{name}_#{type}") if (@data[name] % 1000).zero?
      debug("#{name}_#{type}")
    when 'finish'.freeze
      @data["#{name}_timer"] = "#{Time.now.utc - @data["#{name}_timer"]} secs"
      info("#{name}_#{type}")
    end
  end
end
