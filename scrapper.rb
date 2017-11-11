require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
require 'byebug'
require 'net/http'
require 'json'

def trimUrl(url)
	url = url.to_s.strip

	if url.include? "/ref="
		url = url.gsub(/\/ref=.*/, '')
	end

	url
end

def getImgUrlIfBase24(imgUrl, page)
	if imgUrl.include? "data:image/jpeg;base64"
		imgUrl = page.at_css('[id="imgTagWrapperId"]').css('img').attr('data-old-hires').to_s
	end
	imgUrl
end

def removeCurrencyFromPrice(price)
	price = price.gsub(/[$£EUR ]/, '')
end

def changeImgUrlToFormat(imgUrl, format)
	imgUrl = imgUrl.gsub(/\.\_S\w[0-9]+\_/, format)
end

def getCurrencyFromPrice(price)
	if price.include? "EUR "
		currency = '€'
	elsif price.include? "$"
		currency = '$'
	else price.include? "£"
		currency = '£'
	end
end

def sendProductToApi(apiHost, params, authorization)
	apiUrl = URI.parse(apiHost + '/api/products')

	req = Net::HTTP::Post.new(apiUrl, {
		'Content-Type' => 'application/json',
		'Authorization' => authorization
		})
	req.body = params.to_json
	res = Net::HTTP.start(apiUrl.hostname, apiUrl.port).request(req)
	puts res.inspect
end

def createProductFromUrl(url,apiHost,secret)
	url = trimUrl(url)

	page = Nokogiri::HTML(open(url, allow_redirections: :safe, "User-Agent" => "", "From" => "foo@bar.invalid", "Referer" => "http://www.ruby-lang.org/"))
	# todo add 503 response handler

	name = page.at_css('[id="productTitle"]').text.strip
	price = page.at_css('[id="priceblock_ourprice"]').text.strip.split('-')[0]
	rating = page.at_css('[id="averageCustomerReviews"]').css('i.a-icon-star').css("span.a-icon-alt").text

	imgPageElement = page.at_css('[id="imgTagWrapperId"]').css('img').attr('src')
	imgUrl = getImgUrlIfBase24(imgPageElement.to_s, page)

	currency = getCurrencyFromPrice(price)
	price = removeCurrencyFromPrice(price)

	imgUrl = changeImgUrlToFormat(imgUrl, '_SL400_')

	params = {
		'name' => name,
		'photo' => imgUrl,
		'price' => price,
		'currency' => currency,
		'rating' => rating,
		'url' => url
	}

	sendProductToApi(apiHost, params, secret)

end


arguments = ARGV.to_a

if arguments.length != 3 
	puts 'Not suficient arguments provided'
else 
	#todo validate arguments
	file = arguments[0]
	apiHost = arguments[1].to_s
	secret = arguments[2].to_s	

	File.open(file).readlines.each do |url|
		createProductFromUrl(url,apiHost,secret)	
	end
end


