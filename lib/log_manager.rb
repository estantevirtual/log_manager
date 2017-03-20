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

  def info(text = nil, notify_agent: false, &block)
    text = yield if block
    @agent_notifier.notice_error(text, trace_only: true, custom_params: @data) if notify_agent
    @logger.info(log(text))
  end

  def debug(text = nil, notify_agent: false, &block)
    return unless debug?

    text = yield if block

    @agent_notifier.notice_error(text, trace_only: true, custom_params: @data) if notify_agent
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

    message = extract_message_from_args(progname, exception: exception, message: message, &block)

    @logger.error(format_message_for(exception, message))

    return if supress_notification

    # notice error
    notify_agent(progname,
                 exception: exception,
                 custom_params: custom_params,
                 message: message,
                 &block)
  end

  def notify_agent(progname = nil,
                   exception: nil, message: nil, custom_params: nil, trace_only: nil, &block)
    params = { custom_params: custom_params || @data }
    params[:trace_only] = true if trace_only
    if exception
      @agent_notifier.notice_error(exception, params)
    else
      message = extract_message_from_args(progname, exception: exception, message: message, &block)
      @agent_notifier.notice_error(message, params)
    end
  end

  def error_on_agent(progname,
                     exception: nil, message: nil, custom_params: nil, &block)

    notify_agent(progname, exception: exception, message: message, custom_params: custom_params, trace_only: true, &block)
  end

  def trace_on_agent(progname,
                     exception: nil, message: nil, custom_params: nil, &block)
    notify_agent(progname, exception: exception, message: message, custom_params: custom_params, trace_only: true, &block)
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

  def extract_message_from_args(progname = nil, exception: nil, message: nil, &block)
    block_msg = yield if block_given?
    exception_msg = extract_message_from_exception(exception)
    block_msg || message || exception_msg || progname
  end

  def extract_message_from_exception(exception)
    return exception if exception.nil?

    if exception.respond_to?(:message) && exception.message
      exception.message
    else
      exception.inspect
    end
  end

  def format_message_for(exception, message = nil)
    message = extract_message_from_exception(exception) if message.nil?
    log_exception = "Exception: #{exception.class}. " if exception
    log_message = "Message: #{log(message)}. "
    log_backtrace = "Backtrace: #{exception.backtrace.join(' | ')}" if exception

    "#{log_exception}#{log_message}#{log_backtrace}"
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
