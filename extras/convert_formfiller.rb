#!/usr/bin/ruby
# This script converts files from the old formfiller syntax to the new
# Lua DSL.
#
# To use it, run the following in your favorite shell:
#
#   for f in ~/.local/share/luakit/forms/*; do ./convert.rb $f >> ~/.local/share/luakit/forms.lua; done
#
# BEWARE: this script is not fool-proof. Errors may occur during conversion,
# so do a manual check after the conversion!

def die(msg)
  puts msg
  exit 1
end

file = ARGV[0] or die("ruby convert.rb <FILE>")

f = File.new(file, "r")

forms = []

while (line = f.gets)
  form = forms.last
  if line =~ /^!profile/
    form = {
      :inputs => [],
    }
    forms << form
  end
  next if line =~ /^> vim/
  form[:profile] = $1 if line =~ /^!profile=(.*)/
  if line =~ /^!form\[(.*?)\|(.*?)\|(.*?)\|(.*?)\]:autosubmit=(.)/
    form[:name] = $1 unless $1 == ""
    form[:id] = $2 unless $2 == ""
    form[:method] = $3 unless $3 == ""
    form[:action] = $4 if %w{get post}.include?($4)
    form[:submit] = ($5 == "1")
  elsif line =~ /^(.*?)(\{.*?\})?\((.*?)\):(.*)/
    input = {}
    input[:name] = $1
    input[:type] = $3 if %w{text password checkbox radio submit reset file
                            hidden image buttontext password checkbox radio
                            submit reset file hidden image button}.include?($3)
    input[:fill] = case fill = $4
      when /^on$/i then true
      when /^off$/i then false
      else fill
    end
    form[:inputs] << input
  end
end

exit unless forms.size > 0

puts <<EOL
on "#{file.gsub(/\./) { '\\\\.' }}" {
EOL

forms.each do |form|
  if form[:profile] and forms.size > 1
    puts <<EOL
  form "#{form[:profile]}" {
EOL
  else
    puts "  form {"
  end
  %w{name id method action}.map(&:to_sym).each do |att|
    if form[att]
      puts <<EOL
    #{att} = "#{form[att]}",
EOL
    end
  end
  form[:inputs].each do |input|
    puts "    input {"
    %w{name type}.map(&:to_sym).each do |att|
      if input[att]
        puts <<EOL
      #{att} = "#{input[att]}",
EOL
      end
    end
    if input[:fill].is_a?(String)
      puts <<EOL
      value = "#{input[:fill]}",
EOL
    else
      puts <<EOL
      checked = #{input[:fill]},
EOL
    end
    puts "    },"
  end
  puts "    submit = true," if form[:submit]
  puts "  },"
end

puts "}"
puts
