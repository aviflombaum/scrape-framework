class UntouchedHtmlParser < WWW::Mechanize::Page
  attr_reader :to_html
  def initialize(uri = nil, response = nil, body = nil, code = nil)
    @parser = UntouchedHtml.new(body)
    super(uri, response, body, code)
  end
  
  def to_html
    @untouched_html
  end
  
  def parse_html
  end
end

class UntouchedHtml
  def initialize(html)
    @html = html
  end
  
  def to_html
    @html
  end
end