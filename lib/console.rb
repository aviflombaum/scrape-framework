mod = File.join(File.dirname(__FILE__), 'page-console')
ENV["PAGE_NUMBER"] = ARGV[0]
exec "irb -r #{mod} --simple-prompt"