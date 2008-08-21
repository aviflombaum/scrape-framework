module HdocHandler
  # maybe I should make these class methods so that specific scrapes can call them as well
  # saving docs locally to speed things up
  def get_hdoc(url, agent)
    if !File.exists? 'pages'
      File.makedirs 'pages'
    end
    filename = 'pages/' + url_to_file_name(url)
    if !File.exists? filename
      puts "Downloading #{url}"
      hdoc = download_hdoc(url, agent)
      write_hdoc(filename, hdoc)
    end
    File.open(filename) do |f|
      Hpricot(f.read)
    end
  end
  
  def download_hdoc(url, agent)
    begin
      hdoc = agent.get(url)
    rescue OpenURI::HTTPError => m
      puts "Could not download: #{m}"
      sleep 10
      return Hpricot("<html></html>")   
    rescue WWW::Mechanize::ResponseCodeError => m
      puts "Could not download: #{m}"
      sleep 10
      return Hpricot("<html></html>")        
    end
    hdoc
  end

  def write_hdoc(filename, hdoc)
    File.open(filename, 'w+') do |f|
      f.puts hdoc.parser.to_html
    end
  end
  
  def url_to_file_name(url)
    url.strip.gsub(/[^-a-zA-Z0-9_]/, '_')
  end
end

module UrlHandler
  def full_url_from_current_path(path, current_path = nil)
    p = if path =~ /http:\/\//
      path
    elsif path =~ /^\// #absolute path, only need to join path to domain
      File.join(self.domain, path)
    elsif path =~ /^\.\//
      # path = path[2..-1]
      File.join(current_path.to_s, path)
    else #a relative url
      if current_path #have to check for this because index pages won't specify a current path
        File.join(File.dirname(current_path), path.to_s)
      else
        File.join(self.domain, path)
      end
    end
    p.clean_url
  end
  
  #validation
  def check_url(url)
    http_getter = Net::HTTP                    
    uri = URI.parse(url.gsub(/\s/, "%20"))
    response = http_getter.start(uri.host, uri.port) {|http|
      path = [uri.path, uri.query].compact.join("?")
      puts "---#{path}"
      begin
        http.get(path)
      rescue Timeout::Error
        return false
      end
    }
  end
end