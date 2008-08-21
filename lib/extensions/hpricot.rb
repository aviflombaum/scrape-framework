#TODO fix crappy naming
require 'hpricot'
module Hpricot
  module Traverse
    TWO_LINEBREAK_CAUSING_ELEMENTS = [
      "p",
      "h1",
      "h2",
      "h3",
      "h4",
      "h5",
      "h6",
      "ol",
      "ul",
      "pre",
      "address",
      "blockquote",
      "dl",
      "dt",
      "dd",
      "div",
      "fieldset",
      "form",
      "hr",
      "table"
    ]  
   
    HTML_CHARACTER_MAP = {
      "&otilde;"=>"&#245;",
      "&sup1;"=>"&#185;",
      "&Iacute;"=>"&#205;",
      "&cedil;"=>"&#184;",
      "&ograve;"=>"&#242;",
      "&aelig;"=>"&#230;",
      "&ecirc;"=>"&#234;",
      "&plusmn;"=>"&#177;",
      "&eth;"=>"&#240;",
      "&Yacute;"=>"&#221;",
      "&Agrave;"=>"&#192;",
      "&Euml;"=>"&#203;",
      "&ouml;"=>"&#246;",
      "&Acirc;"=>"&#194;",
      "&ordf;"=>"&#170;",
      "&hibar;"=>"&#175;",
      "&Ugrave;"=>"&#217;",
      "&uuml;"=>"&#252;",
      "&THORN;"=>"&#222;",
      "&curren;"=>"&#164;",
      "&yen;"=>"&#165;",
      "&igrave;"=>"&#236;",
      "&para;"=>"&#182;",
      "&egrave;"=>"&#232;",
      "&Aelig;"=>"&#198;",
      "&auml;"=>"&#228;",
      "&Ograve;"=>"&#210;",
      "&nbsp;"=>"&#160;",
      "&reg;"=>"&#174;",
      "&deg;"=>"&#176;",
      "&micro;"=>"&#181;",
      "&aring;"=>"&#229;",
      "&Ccedil;"=>"&#199;",
      "&copy;"=>"&#169;",
      "&laquo;"=>"&#171;",
      "&Igrave;"=>"&#204;",
      "&Icirc;"=>"&#206;",
      "&pound;"=>"&#163;",
      "&divide;"=>"&#247;",
      "&atilde;"=>"&#227;",
      "&Egrave;"=>"&#200;",
      "&iuml;"=>"&#239;",
      "&Uuml;"=>"&#220;",
      "&amp;"=>"&#38;", 
      "&ordm;"=>"&#186;",
      "&sup2;"=>"&#178;",
      "&ccedil;"=>"&#231;",
      "&quot;"=>"&#34;", 
      "&Ucirc;"=>"&#219;",
      "&aacute;"=>"&#225;",
      "&ocirc;"=>"&#244;",
      "&uacute;"=>"&#250;",
      "&Auml;"=>"&#196;",
      "&acirc;"=>"&#226;",
      "&brkbar;"=>"&#166;",
      "&gt;"=>"&#62;", 
      "&iexcl;"=>"&#161;",
      "&Atilde;"=>"&#195;",
      "&thorn;"=>"&#254;",
      "&Ntilde;"=>"&#209;",
      "&die;"=>"&#168;",
      "&oacute;"=>"&#243;",
      "&Aacute;"=>"&#193;",
      "&Iuml;"=>"&#207;",
      "&sect;"=>"&#167;",
      "&not;"=>"&#172;",
      "&szlig;"=>"&#223;",
      "&Eacute;"=>"&#201;",
      "&Ouml;"=>"&#214;",
      "&Uacute;"=>"&#218;",
      "&ETH;"=>"&#208;",
      "&ntilde;"=>"&#241;",
      "&yuml;"=>"&#255;",
      "&Ocirc;"=>"&#212;",
      "&raquo;"=>"&#187;",
      "&oslash;"=>"&#248;",
      "&frac14;"=>"&#188;",
      "&eacute;"=>"&#233;",
      "&iacute;"=>"&#237;",
      "&Ecicr;"=>"&#202;",
      "&icirc;"=>"&#238;",
      "&euml;"=>"&#235;",
      "&times;"=>"&#215;",
      "&agrave;"=>"&#224;",
      "&frac12;"=>"&#189;",
      "&acute;"=>"&#180;",
      "&ucirc;"=>"&#251;",
      "&lt;"=>"&#60;",
      "&yacute;"=>"&#253;",
      "&Aring;"=>"&#197;",
      "&middot;"=>"&#183;",
      "&frac34;"=>"&#190;",
      "&Otilde;"=>"&#213;",
      "&Oacute;"=>"&#211;",
      "&cent;"=>"&#162;",
      "&Oslash;"=>"&#216;",
      "&iquest;"=>"&#191;",
      "&shy;"=>"&#173;",
      "&sup3;"=>"&#179;",
      "&ugrave;"=>"&#249;",
      "&rsaquo;"=>"&#8250;",
      "&lsaquo;"=>"&#8249;",
      "&sbquo;"=>"&#8218;",
      "&rsquo;"=>"&#8217;",
      "&lsquo;"=>"&#8216;",
      "&bdquo;"=>"&#8222;",
      "&rdquo;"=>"&#8221;",
      "&ldquo;"=>"&#8220;",
      "&raquo;"=>"&#187;",
      "&laquo;"=>"&#171;"
    }
    
    def sanitize_html_entities      
      Hpricot(self.to_html.gsub(/(#{HTML_CHARACTER_MAP.keys.join("|")})/) {|x| HTML_CHARACTER_MAP[x] }) if self
    end
    
    def clean_text
      self.html_breaks_only.sanitize_html_entities.inner_text.strip if self
    end
    
    def just_text
      self.sanitize_html_entities.inner_text.remove_linebreaks_and_spacing.strip if self
    end
      
    def html_breaks_only
      Hpricot(self.to_html.gsub(/(<br[ \/]*>|<p[^>]*>|<tr[^>]*>)/i, "\n")) if self
    end
    
    def two_linebreaks_regex
      "(#{TWO_LINEBREAK_CAUSING_ELEMENTS.join("|")})"
    end
    
    def one_linebreak_empty_regex
      "br|tr"
    end
    
    def one_linebreak_regex
      "li"
    end
    
    def causes_two_linebreaks?
      return false unless self.elem?
      File.basename(self.xpath) =~ /^#{two_linebreaks_regex}[^\/a-zA-Z]*$/
    end
    
    def causes_one_linebreak_and_empty?
      return false unless self.elem?
      File.basename(self.xpath) =~ /^#{one_linebreak_empty_regex}[^\/a-zA-Z]*$/
    end
    
    def causes_one_linebreak?
      return false unless self.elem?
      File.basename(self.xpath) =~ /^#{one_linebreak_regex}[^\/a-zA-Z]*$/
    end
    
    def build_nested_array(elem = nil)
      elem ||= self
      nested_array = []
      elem.children.each do |c|
        if !c.elem? # is plain text
          nested_array << c
        elsif c.causes_two_linebreaks?
          nested_array << [build_nested_array(c)]
        elsif c.causes_one_linebreak_and_empty?
          nested_array << []
        elsif c.causes_one_linebreak?
          nested_array << build_nested_array(c)
        else
          nested_array = nested_array + build_nested_array(c)
        end
      end
      
      nested_array
    end
    
    def nested_array_to_line_breaked(data = nil)
      data ||= build_nested_array(self)
      text = ''
      data.each do |d|
        unless d.is_a? Array
          text << "#{d.to_s.gsub(/\s+/, ' ')}"
        else
          text <<  nested_array_to_line_breaked(d) + "\n"
        end
      end
      text
    end
    
    def inner_text_with_html_breaks
      nested_array_to_line_breaked.strip
    end
    
    
  end
end