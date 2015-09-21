#!/usr/bin/env ruby

require 'Date'

@ts=Regexp.new('^(\p{Digit}{4}-\p{Digit}{2}-\p{Digit}{2}[[:blank:]]\p{Digit}{2}:\p{Digit}{2}:\p{Digit}{2},\p{Digit}{3})', Regexp::EXTENDED)
@labels = {}

def legend_out(log_entries)
    puts "Combined log file. Legend:"
    l2f = @labels.invert
    l2f.keys.sort.each { |label|
        if log_entries.include?(l2f[label])
            printf "%20s : %s\n", label, l2f[label]
        end
    }
    puts "========================================================="
end

def get_line(fd)
    l = fd.gets
    return l if l.nil?
    l.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    return l
end

def get_log_entry(fd)
   le = {}
   # read first line
   l = nil
   begin
       l = get_line(fd)
       return l if l.nil? # EOF reached
   end while l !~ @ts
   le['ts'] = DateTime.parse($1)
   le['data'] = $'
   # Checking for multiline log entry
   p = nil
   b = []
   begin
       p = fd.pos
       l = get_line(fd)
       break if l.nil? # this is last multiline entry in file
       b << l
   end while l !~ @ts
   fd.pos = p unless l.nil? # restoring file position unless we already reached EOF
   b.pop # pop is removing last line from current entry - it's first line of next entry
   le['data'] += b.join('')
   return le
end

def format_datetime(entry)
    entry['ts'].strftime('%Y-%m-%d %H:%M:%S.%3N')
end

def guess_label_for_path(path)
    case path
    when /([^\/]+)\/\p{Digit}{4}-\p{Digit}{2}-\p{Digit}{2}~\p{Digit}{2}.\p{Digit}{2}-([[:alpha:]]+)(?:_(\d+))?.*.log/
        "#{$1}/#{$2}#{$3}".upcase
    else
        path
    end
end

def log_entry_out(filename, entry)
    puts "#{ format_datetime(entry) } #{ @labels[filename] }#{entry['data']}"
end

filenames = ARGV.map { |s| Dir[ File.join(s, '**', '*') ].reject { |p| File.directory? p } }
filenames.flatten!

sources = Hash[ filenames.map { |f| [ f, File.open(f) ] } ]

# Initial seed of log entries
current_le_s = {}
sources.each_pair { |k,v| le = get_log_entry(v); current_le_s[k] = le unless le.nil? }

current_le_s.keys.each { |log|
    l = guess_label_for_path(log)
    if @labels.values.include?(l)
        l += '2' if l !~ /\d$/
        while @labels.values.include?(l)
            l.succ!
        end
    end
    @labels[log] = l
}

legend_out(current_le_s.keys)
#puts current_le_s.inspect
while current_le_s.keys.size > 0 do
    # output log entry with minimum timestamp
    ts = nil
    fn = nil
    current_le_s.each_pair { |k,v|
        if (ts.nil? or v['ts'] < ts)
            ts = v['ts']
            fn = k
        end
    }
    log_entry_out(fn, current_le_s[fn])
    current_le_s[fn] = get_log_entry(sources[fn])
    current_le_s.delete(fn) if current_le_s[fn].nil?
end
