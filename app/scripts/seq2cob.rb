# ========================================================================
# Sequential file to COBOL indexed file generator
# ========================================================================
# Takes a .cpy file containing COBOL data definitions as argument and
# takes data described in a line sequential file and print a COBOL program
# which uses the data to generate an indexed file
# ------------------------------------------------------------------------
require_relative 'cobfields.rb'
require_relative 'cobstruct.rb'

$input_name = ARGV[0]
$output_name = ARGV[1]
$cob_progname = ARGV[2]
$copybook_path = ARGV[3]
$cob_copy_name = ARGV[4]
$cob_key = ARGV[5]
$cob_altkeys = ARGV[6].dup[1..-2].split(',')

if ARGV.length == 0
  print "usage: ruby #{File.basename(__FILE__)} "
  print "input_name output_name program_name copybook_path copy_name"
  puts "record_key [altkey1,...,alkeyN]"
  exit
end

INITIAL_INDENT = 7
INDENT = 4

# ===============================================
# COBOL program generators
# ===============================================

def stmt(n, x)
  print " " * (INITIAL_INDENT+n*INDENT)
  puts x
end

def cont(n, x)
  print " " * (INITIAL_INDENT-1)
  print '-'
  print " " * (n*INDENT)
  puts x
end

def comment(x)
  print " " * (INITIAL_INDENT-1)
  print '* '
  puts x
end

def gen_id_div
  stmt 0, "IDENTIFICATION DIVISION."
  stmt 0, "PROGRAM-ID. #{$cob_progname}."
  puts ""
end

def gen_env_div
  stmt 0, "ENVIRONMENT DIVISION."
  stmt 0, "INPUT-OUTPUT SECTION."
  stmt 0, "FILE-CONTROL."
  stmt 1, "SELECT OPTIONAL #{$cob_progname}-FILE"
  stmt 1, "ASSIGN TO '#{$output_name}'"
  stmt 1, "ORGANIZATION IS INDEXED"
  stmt 1, "ACCESS MODE IS SEQUENTIAL"
  stmt 1, "RECORD KEY IS #{$cob_key}"
  $cob_altkeys.each do |altkey|
    stmt 1, "ALTERNATE KEY IS #{altkey} WITH DUPLICATES"
  end
  stmt 1, "FILE STATUS IS WS-#{$cob_progname}-STATUS."
  puts ""
end

def gen_data_div
  stmt 0, "DATA DIVISION."
  stmt 0, "FILE SECTION."
  stmt 0, "FD #{$cob_progname}-FILE."
  stmt 0, "COPY #{$cob_copy_name}."
  stmt 0, "WORKING-STORAGE SECTION."
  stmt 0, "01 WS-#{$cob_progname}-STATUS PIC XX VALUE SPACES."
  puts ""
end

def gen_proc_div
  stmt 0, "PROCEDURE DIVISION."
  stmt 1, "OPEN OUTPUT #{$cob_progname}-FILE"
end

def gen_header
  gen_id_div()
  gen_env_div()
  gen_data_div()
  gen_proc_div()
end

# slice string literal to fit fixed format
def stmt_sliced_data(data)
  if data[0] == "'" && INITIAL_INDENT+INDENT+data.length > 71
    grp_size = 71-INITIAL_INDENT-INDENT-2
    blocks = data.scan(/.{#{grp_size}}/)
    blocks.each_with_index do |block, k|
      if k == 0
        stmt 1, block
      else
        cont 1, ("'" + block)
      end
    end
    cont 1, ("'" + data[blocks.size*grp_size..-1])
  else
    stmt 1, data
  end
end

# ===============================================
# Formatting
# ===============================================

def decode_sign_value(x)
  case x
  when '{','}'
    return 0
  when 'A'..'I'
    return x.ord-'A'.ord+1
  when 'J'..'R'
    return -(x.ord-'J'.ord+1)
  when '0'..'9'
    return x.to_i
  else
    puts "Error: last sign value is wrong: got #{x}."
    exit 1
  end
end

def format_display_signed_num(rawinput, pic)
  n = get_pic_size(pic, "DISPLAY")
  paren_pos = pic[0..-1].index(')')
  v = pic[paren_pos+1] == 'V'? pic[paren_pos+2..-1].length.to_i : 0
  left_size = n-v
  right_size = v-1
  last = decode_sign_value(rawinput[-2])
  sign = (last<0)? "-" : "+"
  return sign + rawinput[0..left_size-1] + "." + rawinput[left_size..left_size+right_size-1] + last.abs.to_s
end

def format(stream, pic, usage)
  if usage=="DISPLAY" && pic[0]=='S' then
    return format_display_signed_num(stream, pic)
  else
    return "'" + stream + "'"
  end
end

# ===============================================
# Utility functions
# ===============================================

def extract_raw_data(fields)
  all_data = []
  structure = generate_struct(fields)
  File.readlines($input_name, chomp: true).each do |line|
    data = []
    structure.each do |field|
      if field.type=="DATA" then
        data.push(
          line[field.pos..field.pos+field.size-1]
            .gsub("'", "\'\'")
        )
      end
    end
    all_data.push(data)
  end
  return all_data
end

# ===============================================
# Main function
# ===============================================

gen_header()

all_fields = extract_fields($copybook_path + $cob_copy_name + ".cpy")
record_name = all_fields[0].name
toplevel = get_toplevel(all_fields)
all_fields = all_fields.select { |f| f.level != toplevel }
relevant_fields = all_fields.select { |f| f.instance_of? Struct::Data }
all_data = extract_raw_data(all_fields)

# ----- Sort data by record key -----
key_field_idx = all_fields.find_index { |f| f.name == $cob_key }
if all_fields[key_field_idx].instance_of? Struct::Group
  sub = []
  i = key_field_idx+1
  while all_fields[i].level.to_i > all_fields[key_field_idx].level.to_i
    subfield_idx = relevant_fields.find_index {
      |f| f.name == all_fields[i].name
    }
    sub.push subfield_idx
    i+=1
  end
  sorted_data = all_data.sort { |d1,d2|
    sub.map {|i| d1[i]} <=> sub.map {|i| d2[i]}
  }
else
  sorted_data = all_data.sort { |d1,d2|
    d1[key_field_idx] <=> d2[key_field_idx]
  }
end

# ----- Transform sorted data to COBOL WRITEs -----
sorted_data.each do |data|
  relevant_fields.each_with_index do |line, i|
    if relevant_fields[i].name=="FILLER" then next end
    formatted_data = format(
        data[i],
        relevant_fields[i].pic,
        relevant_fields[i].usage
      )
    # check if some lines are too long
    if formatted_data.length + relevant_fields[i].name.length >=
       71-INITIAL_INDENT-INDENT-9 then
      stmt 1, "MOVE"
      stmt_sliced_data formatted_data
      stmt 1, "TO #{relevant_fields[i].name}"
    else
      stmt 1, "MOVE #{formatted_data} TO #{relevant_fields[i].name}"
    end
  end
  stmt 1, "WRITE #{record_name}"
  stmt 1, "IF WS-#{$cob_progname}-STATUS NOT= '00' THEN"
  stmt 2, "DISPLAY 'IO Error with status: ' WITH NO ADVANCING"
  stmt 2, "DISPLAY WS-#{$cob_progname}-STATUS"
  stmt 1, "END-IF"
end
stmt 1, "CLOSE #{$cob_progname}-FILE"
stmt 1, "STOP RUN."
