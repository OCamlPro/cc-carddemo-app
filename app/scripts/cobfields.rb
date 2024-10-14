# ========================================================================
# COBOL fields extractor
# ========================================================================
# Takes a .cpy file containing COBOL data definitions and extract each
# field in a list of Ruby structures defined below.
# ------------------------------------------------------------------------

Struct.new("Group", :level, :name)
Struct.new("Data", :level, :name, :pic, :usage)
Struct.new("Redef", :level, :name, :redefined)

def is_group(field)
  field[2] == nil
end

def is_data(field)
  field[2] == "PIC"
end

def is_redef(field)
  field[2] == "REDEFINES"
end

def is_comment(line)
  return line[6] == '*'
end

def extract_fields(copy)
  res = []
  File.readlines(copy, chomp: true).each do |line|
    if is_comment(line) || line=="" then next end
    field = line.strip[0..-2].split
    if is_group(field)
      level = field[0]
      name  = field[1]
      res.push Struct::Group::new(level, name)
    elsif is_data(field)
      level = field[0]
      name  = field[1]
      pic   = field[3]
      usage = field[4]==nil ? "DISPLAY" : field[4]
      res.push Struct::Data::new(level, name, pic, usage)
    elsif is_redef(field)
      level     = field[0]
      redefiner = field[1]
      redefined = field[3]
      res.push Struct::Redef::new(level, redefiner, redefined)
    else
      puts "Error: unknown field #{field}."
      exit
    end
  end
  return res
end

def get_toplevel(fields)
  return fields[0].level
end
