#! /usr/bin/python

import os
import re
import mmap

from datetime import date
import sys, getopt

po_table = {}
po_string_table = {}
plur_po_string_table = {}

#Find msgid in po files
normal_po_regex = re.compile(r"(?<=msgid\s)\".*?(?<!\\)\"(?=\s+msgstr)")
plural_po_regex = re.compile(r"(?<=msgid\s)\".*?(?<!\\)\"(?=\s+msgid_plural)")

#Detect language in lp and lua files
po_find_regex = re.compile(
    r'(?<=gettext\.textdomain\(\'|gettext\.textdomain\(\")[a-z]+-[a-z]*-*[a-z]+(?=\'\)|\"\))')

#Detect T"" in source files
normal_trans_regex = re.compile(
    r"(?<=\.T|\(T|\{T|\sT|\[T|,T)\".*?(?<!\\)\"(?=,|\s|\s\.\.|\.\.|\)|\}|\")")
#Detect T'' in source files
accent_trans_regex = re.compile(
    r"(?<=\.T|\(T|\{T|\sT|\[T|,T)\'.*?(?<!\\)\'(?=,|\s|\s\.\.|\.\.|\)|\}|\")")
#Detect N"","" plurar strings
normal_plural_trans_regex = re.compile(
    r"(?<=\(N\(|\[N\(|\{N\(|\sN\()\".*?\\*?\",\W*\".*?(?<!\\)\"(?=,|\s|\s\.\.|\.\.|\))")
normal_first_plur_regex = re.compile(r'(?<=\").*?(?<!\\)(?=\",|\"\s+,)')
normal_second_plur_regex = re.compile(r'(?<=\s\"|,\").*?(?<!\\)(?=\")')
#Detect N'','' plurar strings
accent_plural_trans_regex = re.compile(
    r"(?<=\(N\(|\[N\(|\{N\(|\sN\()'.*?\\*?',\W*'.*?(?<!\\)'(?=,|\s|\s\.\.|\.\.|\))")
accent_first_plur_regex = re.compile(r"(?<=').*?(?<!\\)(?=',|'\s+,)")
accent_second_plur_regex = re.compile(r"(?<=\s'|,').*?(?<!\\)(?=')")

msgid_po_regex = re.compile(r"(?<=msgid\s\").*(?=\")")

translate_table = {}
plur_table = {}
plurs_table = {}

po_files = {}


def gen_tbl_from_po(lang_path):
    if not os.path.exists(lang_path):
        return
    for d in os.listdir(lang_path):
        d_path = os.path.join(lang_path, d)
        if os.path.isdir(d_path):
            po_table[d] = []
            po_string_table[d] = {}
            plur_po_string_table[d] = {}
            for sub_root, sub_dirs, sub_files in os.walk(d_path):
                for file in sub_files:
                    if file.endswith(".po"):
                        base_name = file.replace(".po", "")
                        translate_table[base_name] = ()
                        plur_table[base_name] = ()
                        plurs_table[base_name] = {}
                        po_table[d].append(os.path.join(sub_root, file))
                        with open(os.path.join(sub_root, file), 'r', encoding='UTF8') as po_file:
                            string_file = po_file.read()
                        po_string_table[d][base_name] = tuple(
                            [s[1:-1] for s in normal_po_regex.findall(string_file)])
                        plur_po_string_table[d][base_name] = tuple(
                            [s[1:-1] for s in plural_po_regex.findall(string_file)])


def check_files(scanOnly):
    for root, dirs, files in os.walk("decompressed"):
        for file in files:
            if file.endswith(".lp") or file.endswith(".lua"):
              with open(os.path.join(root, file), 'r', encoding='UTF8') as search_file:
                  string_file = search_file.read()
              po_file = po_find_regex.findall(string_file)
              if len(po_file) != 0:
                domain = po_file[0]
                if domain not in translate_table:
                  translate_table[domain] = ()
                  plur_table[domain] = ()
                  plurs_table[domain] = {}
                if scanOnly == "ScanOnly":
                  po_files[domain] = {}
                  continue
                translate_table[domain] += tuple(
                    [s[1:-1] for s in normal_trans_regex.findall(string_file)])
                translate_table[domain] += tuple(
                    [s[1:-1].replace('"', '\\\"') for s in accent_trans_regex.findall(string_file)])
                plural_string = normal_plural_trans_regex.findall(string_file)
                for string in plural_string:
                  first_matches = normal_first_plur_regex.findall(string)
                  second_matches = normal_second_plur_regex.findall(string)
                  if first_matches and second_matches:
                    plur_table[domain] += tuple(first_matches)
                    plurs_table[domain][first_matches[0]] = second_matches[0]
                plural_string = accent_plural_trans_regex.findall(string_file)
                for string in plural_string:
                  first_matches = accent_first_plur_regex.findall(string)
                  second_matches = accent_second_plur_regex.findall(string)
                  if first_matches and second_matches:
                    plur_table[domain] += tuple(s.replace('"', '\\\"') for s in first_matches)
                    plurs_table[domain][first_matches[0].replace('"', '\\\"')] = second_matches[0].replace('"', '\\\"')


def gen_po(lang_path):
    for lang in po_string_table:
      for file in po_string_table[lang]:
        if file in translate_table and file in po_string_table[lang]:

          #Normal strings msgid
          diff_table = set(translate_table[file]) - \
              set(po_string_table[lang][file])
          po_file = open(lang_path+"/"+lang+"/"+file +
                         ".po", 'a', encoding='UTF8')
          for string in diff_table:
            print("Found missing "+string+" in "+file+" for "+lang)
            po_file.write("\nmsgid "+"\""+string+"\""+"\nmsgstr \"\"\n")
          po_file.close()

          #Plural strings
          diff_table = set(plur_table[file]) - \
              set(plur_po_string_table[lang][file])
          po_file = open(lang_path+"/"+lang+"/"+file +
                         ".po", 'a', encoding='UTF8')
          for string in diff_table:
            print("Found missing "+string+" in "+file+" for "+lang)
            po_file.write("\nmsgid \""+string+"\"\nmsgid_plural \"" +
                          plurs_table[file][string]+"\"\nmsgstr[0] \"\"\nmsgstr[1] \"\"\n")
          po_file.close()

def main(argv):
  lang_path = "decompressed/gui_file/www/lang"
  operation = ''
  template = ''
  try:
    opts, args = getopt.getopt(argv, "hd:o:t:", ["dir=", "operation=", "template="])
  except getopt.GetoptError:
    print('update_po.py -d <lang directory> -o <operation>')
    sys.exit(2)
  for opt, arg in opts:
    if opt == '-h':
        print('update_po.py -d <lang directory> -o <clean | template | update> -t')
        sys.exit()
    elif opt in ("-d", "--dir"):
        lang_path = arg
    elif opt in ("-o", "--operation"):
        operation = arg
    elif opt in ("-t", "--template"):
        template = arg


  if operation == "clean":
    gen_tbl_from_po(lang_path)
    check_files("Complete")

    for lang in po_string_table:
      for file in po_string_table[lang]:
        skip_line = 2
        skip_section = 0
        po = open(lang_path+"/"+lang+"/"+file+".po", 'r', encoding='UTF8')
        po_line = po.readlines()
        po.close()
        po = open(lang_path+"/"+lang+"/"+file+".po", 'w', encoding='UTF8')
        for line in po_line:
          #Skip first 2 lines
          if skip_line != 0:
            skip_line = skip_line-1
            po.write(line)
            continue
          cleared_line = msgid_po_regex.search(line)
          if skip_section != 0:
            #Skip line until white line, this way we actually remove missing translation by not writing them
            if not line.strip():
                skip_section = 0
          elif cleared_line:
            if not cleared_line.group(0) in translate_table[file] and not cleared_line.group(0) in plur_table[file]:
                print("Removing '"+cleared_line.group(0) +
                      "' from "+file+" in "+lang)
                skip_section = 1
            else:
                #Write if present
                po.write(line)
          else:
            #Write everything else
            po.write(line)
        po.close()
  elif operation == "template":
    if template == '':
        print("Provide name for lang template")
    else:
        if os.path.exists(lang_path+"/"+template):
            print("directory already exists")
            sys.exit(1)
        os.mkdir(lang_path+"/"+template)
        check_files("ScanOnly")

        for file in po_files:
            po = open(lang_path+"/"+template +
                      "/"+file+".po", 'w', encoding='UTF8')
            po.write('msgid ""\n')
            po.write('msgstr ""\n')
            po.write('"Project-Id-Version: '+file+'\\n"\n')
            po.write('"Report-Msgid-Bugs-To: \\n"\n')
            po.write('"POT-Creation-Date: ' +
                    date.today().strftime("%Y-%m-%d %X")+'\\n"\n')
            po.write('"PO-Revision-Date: \\n"\n')
            po.write('"Last-Translator: \\n"\n')
            po.write('"Language-Team: none\\n"\n')
            po.write('"Language: '+template+'\\n"\n')
            po.write('"MIME-Version: 1.0\\n"\n')
            po.write('"Content-Type: text/plain; charset=UTF-8\\n"\n')
            po.write('"Content-Transfer-Encoding: 8bit\\n"\n')
            po.write('"Language-Name: \\n"\n')
            po.write('"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n')
            po.write('"X-Generator: \\n"\n')
            po.write('"X-Poedit-SourceCharset: UTF-8\\n"\n')
            po.close()

        gen_tbl_from_po(lang_path)
        check_files("Complete")
        gen_po(lang_path)
  else:
      gen_tbl_from_po(lang_path)
      check_files("Complete")
      gen_po(lang_path)


if __name__ == "__main__":
   main(sys.argv[1:])
