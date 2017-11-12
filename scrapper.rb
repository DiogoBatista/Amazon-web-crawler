require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'open_uri_redirections'
require 'byebug'
require 'net/http'
require 'json'

@@results = { success: 0, failed: 0, error: [], repeated: 0 }
@robot_found = false

USAGE = <<ENDUSAGE
Usage:
ruby scrapper.rb [--file PATH] [--api API] [--secret SECRET]
ENDUSAGE

HELP = <<ENDHELP
-h, --help       Show this help.
-f, --file       The input file with Amazon links, one per line
-a, --api        The API endpoing where you want to do the POST request.
-s, --secret     Send this value as an Authorization Header. This is not a mandatory field.
ENDHELP

 ARGS = {}
 next_arg = ""

 ARGV.each do |arg|
  case arg
  when '-h','--help'      then ARGS[:help] = true
  when '-f','--file'     then next_arg = :file
  when '-a','--api'    then next_arg = :api
  when '-s','--secret'    then next_arg = :secret
  else
    if next_arg
      ARGS[next_arg] = arg
    end
  end
end

if ARGS[:help]
  puts USAGE
  puts HELP
  exit
end

if (!ARGS[:file] or !ARGS[:api])
  puts USAGE
  puts HELP
  exit
end

class Product
  def initialize(url)
    @url = clean_url(url)
    @name = ""
    @rating = ""
    @image = ""
    @price = 0.0
    @currency = ""
    @page = ""
    @broken = false
  end

  def broken?
    @broken
  end

  def valid?
    not broken?
  end

  def params
    {
      name: @name,
      photo: @image,
      price: @price,
      currency: @currency,
      rating: @rating,
      url: @url
    }
  end

  def self.fetch(url)
    new(url).fetch
  end

  def fetch
    return if @url.to_s.empty?
    puts ""
    puts "Fetching #{@url}..."

    @page = create_page
    return false if broken? or robot_check?
    
    @name = scrape_name
    return false if broken?

    @price = scrape_price
    return false if broken?

    @rating = scrape_rating
    return false if broken?

    @image = scrape_image
    return false if broken?

    self
  end

  def post(api, secret = nil)
    url = URI.parse(api)

    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = secret if secret

    req = Net::HTTP::Post.new(url, headers)
    req.body = params.to_json

    res = Net::HTTP.start(url.hostname, url.port).request(req)

    case res.code.to_i
    when 201
      puts "[201] Product #{@name} created."
      @@results[:success] = @@results[:success] + 1 
    when 409
      puts "[409] Product #{@name} already existed."
      @@results[:repeated] = @@results[:repeated] + 1
    when 500
      puts "[500] Some weird error on the backend"
      puts "params: #{params}"
      @@results[:failed] = @@results[:failed] + 1 
      @@results[:error] << { code: res.code, url: @url }
    else 
      puts res.inspect
      @@results[:failed] = @@results[:failed] + 1 
      @@results[:error] << { code: res.code, url: @url }
    end
  end

private

  def clean_url(url)
    url = url.to_s.strip

    if url.include? "/ref="
      url = url.gsub(/\/ref=.*/, '')
    end

    if url.include? "?"
      url = url.split('?')[0]
    end

    url
  end

  def create_page
    begin
      @page = Nokogiri::HTML(open(@url, allow_redirections: :safe, "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36"))
    rescue OpenURI::HTTPError => e
      code = e.io.status[0].to_i
      @@results[:failed] = @@results[:failed] + 1 
      @@results[:error] << { code: code, url: @url }

      @broken = true
      return puts "Page not found"
    end
  end

  def scrape_name
    name = ""

    if name = @page.css('#productTitle, #title span')
      name = name.text.strip
    end

    name = name.to_s

    if name.empty?
      @@results[:failed] = @@results[:failed] + 1 
      @@results[:error] << { code: 'no-name', url: @url }

      @broken = true
      puts "No product name..."
    end

    name
  end

  def scrape_price
    price = @page.at_css('#priceblock_ourprice, span.offer-price, #priceblock_saleprice, .a-color-price')

    if price
      price = price.text.strip.split('-')[0]

      # Add currency before removing it from price
      @currency = get_currency(price)
      price = remove_currency_from_price(price)
    end

    price = price.to_f

    unless price > 0.0
      @@results[:failed] = @@results[:failed] + 1 
      @@results[:error] << {code: 'no-name', url: @url }

      @broken = true
      puts "No product price..."
    end

    price
  end

  def remove_currency_from_price(price)
    price.gsub(/[$£EUR ]/, '')
  end

  def get_currency(price)
    if price.include? "EUR"
      "€"
    elsif price.include? "$"
      "$"
    elsif price.include? "£"
      "£"
    end
  end

  def scrape_rating
    rating = @page.at_css('[id="averageCustomerReviews"]').css('i.a-icon-star').css("span.a-icon-alt").text

    unless rating
      @@results[:failed] = @@results[:failed] + 1 
      @@results[:error] << {code: 'no-rating', url: @url }

      @broken = true
      puts "No product rating..." 
    end

    rating
  end

  def scrape_image
    image = @page.at_css('#imgTagWrapperId img, #img-canvas img, #ebooks-img-canvas img')

    unless image
      @@results[:failed] = @@results[:failed] + 1 
      @@results[:error] << { code: 'unavailable', url: @url }
      
      @broken = true
      puts "No product image..." 
    end

    source = get_image_url(image)

    convert_image_url_to_size(source, 400)
  end

  def get_image_url(image)
    source = image.attr('src')

    if source.include? "data:image"
      source = JSON.parse(image.attr("data-a-dynamic-image")).keys[0]
    end

    source
  end

  def convert_image_url_to_size(source, size)
    format = "._SL#{size}_"

    source.gsub(/\.\_\w\w[0-9]+\_/, format)
  end

  def robot_check?
    check = @page.to_s.include? "Sorry, we just need to make sure you're not a robot."
    puts "Amazon is checking for robots... (ooops)" if check

    check
  end
end

class Results
  def self.all
    @@results ||= { success: 0, failed: 0, error: [], repeated: 0 }
  end
end

File.open(ARGS[:file]).readlines.each do |url|
  next if @robot_found
  next if url[0] == "#" 
  next if url.strip == ""

  product = Product.fetch(url)

  product.post(ARGS[:api], ARGS[:secret])

  # wait 5 seconds to avoid Amazon bot detection
  sleep(5)
end

results = @@results

puts ""
puts "Successes: #{results[:success]}, Failed: #{results[:failed]}, repeated #{results[:repeated]}"

if results[:error].length > 0 
  puts ""

  results[:error].each do |e|
    puts "#{e[:code]} >> #{e[:url]} "
  end
end
