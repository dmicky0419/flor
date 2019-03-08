
module Flor

  class Waiter

    def initialize(exid, opts)

      serie, timeout, on_timeout, repeat =
        expand_args(opts)

      # TODO fail if the serie mixes msg_waiting with row_waiting...

      @exid = exid
      @original_serie = repeat ? Flor.dup(serie) : nil
      @serie = serie
      @timeout = timeout
      @on_timeout = on_timeout

      @queue = []
      @mutex = Mutex.new
      @var = ConditionVariable.new

      @executor = nil
    end

    ROW_PSEUDO_POINTS = %w[ status tag ]

    def row_waiter?

      @serie.find { |_, points|
        points.find { |po|
          pos = po.split(':')
          pos.length > 1 && ROW_PSEUDO_POINTS.include?(pos[0]) } }
    end

    def msg_waiter?

      @serie.find { |_, points|
        points.find { |po|
          ! ROW_PSEUDO_POINTS.include?(po.split(':').first) } }
    end

    def to_s

      "#{super[0..-2]}#{
        { exid: @exid,
          original_serie: @original_serie,
          timeout: @timeout }.inspect
      }>"
    end

    def notify(executor, message)

      @executor = executor
        # could be handy

      @mutex.synchronize do

        return false unless match?(message)

        @serie.shift
        return false if @serie.any?

        @queue << [ executor, message ]
        @var.signal
      end

      # then...
      # returning false: do not remove me, I want to listen/wait further
      # returning true: remove me

      return true unless @original_serie
        # @original_serie is set if this is a repeat Waiter

      @serie = Flor.dup(@original_serie) # reset serie

      false # do not remove me
    end

    def check(unit)

      @mutex.synchronize do

        row = row_match?(unit)
        return false unless row

        @serie.shift
        return false if @serie.any?

        @queue << [ unit, row ]
        @var.signal
      end

      # then...
      # returning false: do not remove me, I want to listen/wait further
      # returning true: remove me

      return true unless @original_serie
        # @original_serie is set if this is a repeat Waiter

      @serie = Flor.dup(@original_serie) # reset serie

      false # do not remove me

    rescue => err

#puts "!" * 80; p err
      @executor.unit.logger.warn(
        "#{self.class}#check()", err, '(returning true, aka remove me)'
      ) if @executor

      true # remove me
    end

    def wait

      @mutex.synchronize do

        if @queue.empty?

          @var.wait(@mutex, @timeout)
            # will wait "in aeternum" if @timeout is nil

          if @queue.empty?
            fail RuntimeError.new(
              "timeout for #{self.to_s}, " +
              "msg_waiter? #{ !! msg_waiter?}, row_waiter? #{ !! row_waiter?}"
            ) if @on_timeout == 'fail'
            return { 'exid' => @exid, 'timed_out' => @on_timeout }
          end
        end

        @queue.shift[1]
      end
    end

    protected

    def match?(message)

      mpoint = message['point']

      return false if @exid && @exid != message['exid'] && mpoint != 'idle'

      nid, points = @serie.first
      mnid = message['nid']

      return false if nid && mnid && nid != mnid

      return false unless points.find { |point|
        ps = point.split(':')
        next false if ps[0] != mpoint
        next false if ps[1] && ! message['tags'].include?(ps[1])
        true }

      true
    end

    def row_match?(unit)

      nid, points = @serie.first

      row = nil

      points.find { |point|
        ps = point.split(':')
        row = send("row_match_#{ps[0]}?", unit, nid, ps[1..-1]) }

      row
    end

    def row_match_status?(unit, _, cdr)

      unit.storage.executions
        .where(exid: @exid, status: cdr.first)
        .first
    end

    def row_match_tag?(unit, nid, cdr)

      name = cdr.first

      q = unit.storage.pointers
        .where(exid: @exid, type: 'tag')
      q = q.where(nid: nid) if nid
      q = q.where(name: name) if name

      q.first
    end

    def expand_args(opts)

      owait = opts[:wait]
      orepeat = opts[:repeat] || false
      otimeout = opts[:timeout]
      oontimeout = opts[:on_timeout] || opts[:ontimeout] || 'fail'

      case owait
      when nil, true
        [ [ [ nil, %w[ failed terminated ] ] ], # serie
          otimeout,
          oontimeout,
          orepeat ]
      when Numeric
        [ [ [ nil, %w[ failed terminated ] ] ], # serie
          owait, # timeout
          oontimeout,
          orepeat ]
      when String, Array
        [ parse_serie(owait), # serie
          otimeout,
          oontimeout,
          orepeat ]
      else
        fail ArgumentError.new(
          "don't know how to deal with #{owait.inspect} (#{owait.class})")
      end
    end

    WAIT_REX =
      %r{
        \A
        ([0-9_\-]+)?[ ]*
        (
          [a-z]+(?::[-a-zA-Z_]+)?
          (?:[|, ][a-z]+(:[-a-zA-Z_]+)?)*
        )\z
      }x

    def parse_serie(s)

      return s if s.is_a?(Array) && s.collect(&:class).uniq == [ Array ]

      (s.is_a?(String) ? s.split(';') : s)
        .collect { |ss|
          ni, pt = ss.strip.match(WAIT_REX)[1, 2]
          [ ni, pt.split(/[|,]/).collect(&:strip) ]
        }
    end
  end
end

