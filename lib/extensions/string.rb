class String
  def tidy_whitespace
    self.gsub(/&nbsp;/, ' ').gsub(/\s+/, ' ')
  end
  
  def remove_linebreaks_and_spacing
    self.gsub(/\r|\n|\t/, "")
  end
  
  def clean_url
    self.gsub(" ", "%20").gsub(/[^\.]\.\//, '').gsub(/&amp;/,'&')
  end
  
  def blank?
    return true if self == "" || self == " "
  end
end