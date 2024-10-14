# ========================================================================
# COBOL structure extractor
# ========================================================================
# Takes a .cpy file containing COBOL data definitions and extract the
# underlying structure with the offset/position and size of each field.
# ------------------------------------------------------------------------
# The program expects PICs to be normalized. It supports the following PICs
# where n is numeric:
# - X(n)
# - 9(n)
# - S9(n)V9..9
# and the following USAGEs:
# - DISPLAY (default)
# - BINARY/COMP/COMP-4
# - COMP-3 (packed decimal)
# - COMP-5
require_relative 'cobfields.rb'

Struct.new("Str", :type, :name, :content, :pos, :size)

def get_pic_size(stream, usage)
  case stream[0]
  when 'X'
    return stream[2..-1].to_i
  when '9'
    n = stream[2..-1].to_i
    case usage
    when "BINARY","COMP","COMP-4","COMP-5"
      if n<=4 then return 2
      elsif n<=9 then return 4
      elsif n<=18 then return 8
      else
        puts "Error: unsupported numeric size."
        exit 1
      end
    when "COMP-3"
      return ((stream[2..-1].to_i+1).to_f / 2.0).ceil
    else # DISPLAY
      return n
    end
  when 'S'
    paren_pos = stream[0..-1].index(')')
    n = stream[3..paren_pos-1].to_i
    v = stream[paren_pos+1] == 'V'? stream[paren_pos+2..-1].length.to_i : 0
    return get_pic_size("9(#{n+v})", usage)
  end
end

def is_comment(line)
  return line[6] == '*'
end

def generate_struct(fields)
  res = []
  last_pos = 0
  last_size = 0
  i = 0
  while i<fields.length do
    field = fields[i]

    # ---------- Case of Data ----------
    if field.instance_of? Struct::Data
      size = get_pic_size(field.pic, field.usage)
      pos = last_pos + last_size
      res.push Struct::Str::new(
        "DATA", field.name, "#{field.pic} #{field.usage}", pos, size
      )
      last_size = size
      last_pos = pos

    # ---------- Case of Group ----------
    elsif field.instance_of? Struct::Group
      sub = []
      j = i+1
      while j < fields.length && (fields[j].level.to_i > field.level.to_i) do
        subfield = fields[j]
        size = get_pic_size(subfield.pic, subfield.usage)
        pos = last_pos + last_size
        sub.push Struct::Str::new(
          "DATA", subfield.name, "#{subfield.pic} #{subfield.usage}", pos, size
        )
        last_size = size
        last_pos = pos
        j+=1
      end
      grp_size = sub.sum(0) {|subf| subf.size}
      res.push Struct::Str::new(
        "GRP", field.name, "", sub[0].pos, grp_size
      )
      res += sub
      i += sub.length

    # ---------- Case of Redef ----------
    elsif field.instance_of? Struct::Redef
      redefined_idx = res.find_index {|str| str.name==field.redefined}
      pos = res[redefined_idx].pos
      size = res[redefined_idx].size
      if field.name != "FILLER"
        res.push Struct::Str::new("RDEF", field.name, "", pos, size)
      end
      last_size = 0
      last_pos = pos
    else
      puts "Error: unknown field type #{field}"
      exit
    end

    i+=1
  end
  return res
end
