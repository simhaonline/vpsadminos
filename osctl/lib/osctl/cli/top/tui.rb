require 'curses'

module OsCtl::Cli
  class Top::Tui < Top::Renderer
    include OsCtl::Utils::Humanize

    def initialize(*_)
      super
      @sort_index = 0
      @sort_desc = true
    end

    def start
      Curses.init_screen
      Curses.start_color
      Curses.crmode
      Curses.stdscr.keypad = true
      Curses.curs_set(0)  # hide cursor
      Curses.use_default_colors
      Curses.init_pair(1, Curses::COLOR_BLACK, Curses::COLOR_WHITE)

      last_measurement = nil
      last_count = nil

      render(Time.now, {containers: []})
      sleep(0.5)

      loop do
        now = Time.now

        if last_measurement.nil? || (now - last_measurement) >= rate
          model.measure
          last_measurement = now
        end

        data = get_data

        Curses.clear if last_count != data[:containers].count
        last_count = data[:containers].count

        render(now, data)
        Curses.timeout = rate * 1000

        case Curses.getch
        when 'q'
          break

        when Curses::Key::LEFT, '<'
          Curses.clear
          sort_next(-1)

        when Curses::Key::RIGHT, '>'
          Curses.clear
          sort_next(+1)

        when 'r', 'R'
          Curses.clear
          sort_inverse

        when 'm'
          modes = model.class::MODES
          i = modes.index(mode)

          if i+1 >= modes.count
            model.mode = modes[0]

          else
            model.mode = modes[i+1]
          end

          @header = nil
          Curses.clear

        when Curses::Key::RESIZE
          Curses.clear
        end
      end

    rescue Interrupt
    ensure
      Curses.close_screen
    end

    def render(t, data)
      Curses.setpos(0, 0)
      Curses.addstr("#{File.basename($0)} ct top - #{t.strftime('%H:%M:%S')}")
      Curses.addstr(" #{model.mode} mode, load average #{loadavg}")

      i = status_bar(1, data)

      Curses.attron(Curses.color_pair(1))
      i = header(i+1)
      Curses.attroff(Curses.color_pair(1))

      data[:containers].each do |ct|
        Curses.setpos(i, 0)
        print_row(ct)

        i += 1

        break if i >= (Curses.lines - 3)
      end

      stats(data[:containers])

      Curses.refresh
    end

    def status_bar(pos, data)
      cpu = data[:cpu]

      Curses.setpos(pos, 0)
      Curses.addstr('%CPU: ')

      if cpu
        bold { Curses.addstr(sprintf('%5.1f', format_percent(cpu[:user]))) }
        Curses.addstr(' us, ')
        bold { Curses.addstr(sprintf('%5.1f', format_percent(cpu[:system]))) }
        Curses.addstr(' sy, ')
        bold { Curses.addstr(sprintf('%5.1f', format_percent(cpu[:nice]))) }
        Curses.addstr(' ni, ')
        bold { Curses.addstr(sprintf('%5.1f', format_percent(cpu[:idle]))) }
        Curses.addstr(' id, ')
        bold { Curses.addstr(sprintf('%5.1f', format_percent(cpu[:iowait]))) }
        Curses.addstr(' wa, ')
        bold { Curses.addstr(sprintf('%5.1f', format_percent(cpu[:irq]))) }
        Curses.addstr(' hi, ')
        bold { Curses.addstr(sprintf('%5.1f', format_percent(cpu[:softirq]))) }
        Curses.addstr(' si')

      else
        Curses.addstr('calculating')
      end

      Curses.setpos(pos+1, 0)
      Curses.addstr('Containers: ')
      bold { Curses.addstr(sprintf('%3d', model.containers.count)) }
      Curses.addstr(' total, ')
      bold { Curses.addstr(sprintf('%3d', data[:containers].count-1)) } # -1 for [host]
      Curses.addstr(' running, ')
      bold { Curses.addstr(sprintf('%3d', model.containers.count{ |ct| ct.state == :stopped })) }
      Curses.addstr(' stopped')

      pos+2
    end

    def header(pos)
      unless @header
        ret = []

        ret << sprintf(
          '%-14s %7s %7s %6s %27s %27s',
          'Container',
          'CPU',
          'Memory',
          'Proc',
          'BlkIO          ',
          'Network        '
        )

        ret << sprintf(
          '%-14s %7s %7s %6s %13s %13s %13s %13s',
          '',
          '',
          '',
          '',
          'Read   ',
          'Write   ',
          'TX    ',
          'RX    '
        )

        ret << sprintf(
          '%-14s %7s %7s %6s %6s %6s %6s %6s %6s %6s %6s %6s',
          'ID',
          '',
          '',
          '',
          'Bytes',
          rt? ? 'IOPS' : 'IO',
          'Bytes',
          rt? ? 'IOPS' : 'IO',
          rt? ? 'bps' : 'Bytes',
          rt? ? 'pps' : 'Packet',
          rt? ? 'bps' : 'Bytes',
          rt? ? 'pps' : 'Packet'
        )

        # Fill to the edge of the screen
        @header = ret.map do |line|
          line << (' ' * (Curses.cols - line.size)) << "\n"
        end
      end

      @header.each do |line|
        Curses.setpos(pos, 0)
        Curses.addstr(line)
        pos += 1
      end

      pos
    end

    def print_row(ct)
      Curses.addstr(sprintf('%-14s ', ct[:id]))

      print_row_data([
        rt? ? format_percent(ct[:cpu_usage]) : humanize_time_ns(ct[:cpu_time]),
        humanize_data(ct[:memory]),
        ct[:nproc],
        humanize_data(ct[:blkio][:bytes][:r]),
        ct[:blkio][:iops][:r],
        humanize_data(ct[:blkio][:bytes][:w]),
        ct[:blkio][:iops][:w],
        humanize_data(ct[:tx][:bytes]),
        humanize_data(ct[:tx][:packets]),
        humanize_data(ct[:rx][:bytes]),
        humanize_data(ct[:rx][:packets])
      ])
    end

    def print_row_data(values)
      fmts = %w(%7s %7s %6s %6s %6s %6s %6s %6s %6s %6s %6s)

      fmts.zip(values).each_with_index do |pair, i|
        f, v = pair

        Curses.attron(Curses::A_BOLD) if i == @sort_index
        Curses.addstr(sprintf("#{f} ", v))
        Curses.attroff(Curses::A_BOLD) if i == @sort_index
      end
    end

    def stats(cts)
      Curses.setpos(Curses.lines - 3, 0)
      Curses.addstr('─' * Curses.cols)
      #Curses.addstr('-' * Curses.cols)

      Curses.setpos(Curses.lines - 2, 0)
      Curses.addstr(sprintf('%-14s ', 'Containers:'))
      print_row_data([
        rt? ? format_percent(sum(cts, :cpu_usage, false)) \
            : humanize_time_ns(sum(cts, :cpu_time, false)),
        humanize_data(sum(cts, :memory, false)),
        sum(cts, :nproc, false),
        humanize_data(sum(cts, [:blkio, :bytes, :r], false)),
        sum(cts, [:blkio, :iops, :r], false),
        humanize_data(sum(cts, [:blkio, :bytes, :w], false)),
        sum(cts, [:blkio, :iops, :w], false),
        humanize_data(sum(cts, [:tx, :bytes], false)),
        humanize_data(sum(cts, [:tx, :packets], false)),
        humanize_data(sum(cts, [:rx, :bytes], false)),
        humanize_data(sum(cts, [:rx, :packets], false))
      ])

      Curses.setpos(Curses.lines - 1, 0)
      Curses.addstr(sprintf('%-14s ', 'All:'))
      print_row_data([
        rt? ? format_percent(sum(cts, :cpu_usage, true)) \
            : humanize_time_ns(sum(cts, :cpu_time, true)),
        humanize_data(sum(cts, :memory, true)),
        sum(cts, :nproc, true),
        humanize_data(sum(cts, [:blkio, :bytes, :r], true)),
        sum(cts, [:blkio, :iops, :r], true),
        humanize_data(sum(cts, [:blkio, :bytes, :w], true)),
        sum(cts, [:blkio, :iops, :w], true),
        humanize_data(sum(cts, [:tx, :bytes], true)),
        humanize_data(sum(cts, [:tx, :packets], true)),
        humanize_data(sum(cts, [:rx, :bytes], true)),
        humanize_data(sum(cts, [:rx, :packets], true))
      ])
    end

    def get_data
      ret = model.data

      ret[:containers].sort! do |a, b|
        sortable_value(a) <=> sortable_value(b)
      end

      ret[:containers].reverse! if @sort_desc
      ret
    end

    def sortable_value(ct)
      lookup_field(ct, sortable_fields[@sort_index])
    end

    def sort_next(n)
      next_i = @sort_index + n
      fields = sortable_fields

      if next_i < 0
        next_i = fields.count - 1

      elsif next_i >= fields.count
        next_i = 0
      end

      @sort_index = next_i
    end

    def sort_inverse
      @sort_desc = !@sort_desc
    end

    def sortable_fields
      ret = []
      ret << (rt? ? :cpu_usage : :cpu_time)
      ret.concat([
        :memory,
        :nproc,
        [:blkio, :bytes, :r],
        [:blkio, :iops, :r],
        [:blkio, :bytes, :w],
        [:blkio, :iops, :w],
        [:tx, :bytes],
        [:tx, :packets],
        [:rx, :bytes],
        [:rx, :packets],
      ])
    end

    def sum(cts, field, host)
      cts.inject(0) do |acc, ct|
        if ct[:id] == '[host]' && !host
          acc

        else
          acc + lookup_field(ct, field)
        end
      end
    end

    def lookup_field(ct, field)
      if field.is_a?(Array)
        field.reduce(ct) { |acc, v| acc[v] }

      else
        ct[field]
      end
    end

    def loadavg
      File.read('/proc/loadavg').strip.split(' ')[0..2].join(', ')
    end

    def mode
      model.mode
    end

    def rt?
      model.mode == :realtime
    end

    def bold
      Curses.attron(Curses::A_BOLD)
      yield
      Curses.attroff(Curses::A_BOLD)
    end
  end
end