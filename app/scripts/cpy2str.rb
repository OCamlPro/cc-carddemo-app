# ========================================================================
# COPY to ISAM structure
# ========================================================================
# Generate and print the corresponding structure file with a sequence of fields
# together with their position and size in memory.
# ------------------------------------------------------------------------
require_relative 'cobstruct.rb'

if ARGV.length == 0
  puts "usage: ruby #{File.basename(__FILE__)} path_to_copy.cpy"
  exit
end

fields = extract_fields(ARGV[0] + ".cpy")
structure = generate_struct(fields)
structure.each do |s|
  if s.type == "DATA"
    puts "#{s.type} #{s.name} #{s.content} #{s.pos}:#{s.size}"
  else
    puts "#{s.type} #{s.name} #{s.pos}:#{s.size}"
  end
end
