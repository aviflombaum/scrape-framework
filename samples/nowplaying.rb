# Load the Scrapist Framework
require '../lib/base'

# Initialize the Scraper instance
scraper = Scraper.new(
  :domain => 'http://www.imdb.com/', # The root of the site
  :item_address_selector => "a.title"   # The selector for Item links for the Scraper
)

# A Static Attribute, to be applied to all Items on all Indexes (unless it's overridden)
project = scraper.add_attribute(:name => "project", :value => "Scrapist Example")

# A Dynamic Attribute
year = scraper.add_attribute(:name => "year", :selector => "div#tn15title h1 span a")

# A Dynamic Attribute Parsed through a Block
name = scraper.add_attribute(:name => "name", :selector => "div#tn15title h1") do |h_element|
  # This will yield the matching hpricot element which we will then crudly parse with the full power
  # of Ruby and Hpricot to remove the year from this data, leaving the attribute equal to the name.
  h_element.inner_html.to_s.split("<span>")[0]
end

# Now we add the index to the scraper.  The index is defined as any page that contains unique item urls
# i.e The index is the page with the links to the pages you want to scrape.
nowplaying = scraper.add_index(:path => "/nowplaying/")

# Let's add some index specific attributes, again, using the full power of hPricot.
director = nowplaying.add_attribute(:name => "director", :selector => "h5[text()*=Director:]") do |h_elem|
  h_elem.next_sibling.inner_text
end

# Let's use an array of selectors to collect both the movie image and scene images
images = nowplaying.add_attribute(:name => "images", :selector => ["div.photo img", "div.tn15media img"]) do |h_elem|
  h_elem.get_attribute("src")
end

# Now we call our magic collect_items method to extract the items out of that index.
nowplaying.collect_items

# Just for fun, let's add another index, newly released DVDs
newondvd = scraper.add_index(:path => "/sections/dvd/")

# If you run the scrape without this next line, you'll notice that the Grindhouse Unrated DVD link isn't good
# so for dead, broken, or just unwanted item links from an index you can always...
newondvd.remove_item_url("http://www.imdb.com/rg/REC_COMING_SOON//ra/us/a/B000UAE7O0")

# And obviously,
newondvd.add_item_url("http://www.imdb.com/rg/REC_POPULAR_TITLES//title/tt0413099/")

# Test the override attribute
newondvd.add_attribute(:name => "project", :value => "Scrapist to the Rescue")

# You can always call collect_items on the scraper instance intself to collect from all its indexes.
scraper.collect_items