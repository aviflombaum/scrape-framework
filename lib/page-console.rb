require 'hpricot'
if number = ENV["PAGE_NUMBER"]
  number = number.rjust(8, '0')
  filename = Dir["pages/#{number}*"].first
  path = File.join(ENV['PWD'], filename)
  puts "Hpricoting #{path}"
  @h = Hpricot(File.read(path))
end