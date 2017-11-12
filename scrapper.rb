require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'open_uri_redirections'
require 'byebug'
require 'net/http'
require 'json'

@results = { success: 0, failed: 0, error: [], repeated:0 }

def trimUrl(url)
	url = url.to_s.strip

	if url.include? "/ref="
		url = url.gsub(/\/ref=.*/, '')
	end

	if url.include? "?"
		url = url.split('?')[0]
	end

	url
end

def getImgUrlIfBase24(imgElement)
	el = imgElement.css('img').attr('src')

	if el.to_s.include? "data:image"
		el = JSON.parse(imgElement.css("img").attr("data-a-dynamic-image").value).keys[0]
	end

	el.to_s
end

def removeCurrencyFromPrice(price)
	price = price.gsub(/[$£EUR ]/, '')
end

def changeImgUrlToFormat(imgUrl, size)
	format = "._SL#{size}_"
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
	
	case res.code.to_i
	when 201
		@results[:success] = @results[:success] + 1 	
	when 409
		@results[:repeated] = @results[:repeated] + 1 	
	else 
		@results[:failed] = @results[:failed] + 1 	
		@results[:error] << {code: res.code, url: params['url'] }
	end
	
	puts res.inspect
end

def createProductFromUrl(url,apiHost,secret)
	url = trimUrl(url)

	puts ""
	puts "Fetching '#{url}'..."

	begin
		page = Nokogiri::HTML(open(url, allow_redirections: :safe, "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36", "From" => "foo@bar.invalid", "Referer" => "http://www.ruby-lang.org/"))
	rescue OpenURI::HTTPError => e
		@results[:failed] = @results[:failed] + 1 	
		@results[:error] << {code: e.io.status[0].to_i, url: url }
		return puts "Page not found" if res.code == '404'
	end

	if name = page.at_css('[id="productTitle"]')
		name = name.text.strip
	elsif name = page.at_css('#title span')
		name = name.text.strip
	end

	@results[:failed] = @results[:failed] + 1 	
	@results[:error] << {code: 'no-name', url: url }
	return puts "No product name..." unless name
	

	price = page.at_css('[id="priceblock_ourprice"]')

	if price 
		price = price.text.strip.split('-')[0]
	elsif price = page.at_css('span.offer-price')
		price = price.text
	elsif price = page.at_css('#priceblock_saleprice')
		price = price.text
	elsif price = page.at_css('.a-color-price')
		price = price.text
	end

	@results[:failed] = @results[:failed] + 1 	
	@results[:error] << {code: 'no-name', url: url }
	return puts "No product price..." unless price

	rating = page.at_css('[id="averageCustomerReviews"]').css('i.a-icon-star').css("span.a-icon-alt").text

	@results[:failed] = @results[:failed] + 1 	
	@results[:error] << {code: 'no-rating', url: url }
	return puts "No product rating..." unless rating

	if imgPageElement = page.at_css('[id="imgTagWrapperId"]')
	elsif imgPageElement = page.at_css('#img-canvas')
	elsif imgPageElement = page.at_css('#ebooks-img-canvas')
	end


	@results[:failed] = @results[:failed] + 1 	
	@results[:error] << {code: 'no-image', url: url }
	return puts "No product image..." unless imgPageElement

	imgUrl = getImgUrlIfBase24(imgPageElement)

	currency = getCurrencyFromPrice(price)
	price = removeCurrencyFromPrice(price)

	imgUrl = changeImgUrlToFormat(imgUrl, 400)

	params = {
		'name' => name,
		'photo' => imgUrl,
		'price' => price,
		'currency' => currency,
		'rating' => rating,
		'url' => url
	}
	puts params;

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
		next if url[0] == "#" 
		next if url.strip == ""
		createProductFromUrl(url,apiHost,secret)	
	end

	puts ""
	puts "Successes: #{@results[:success]}, Failed: #{@results[:failed]}, repeated #{@results[:repeated]}"

	if @results[:error].length > 0 
		puts ""

		@results[:error].each do |e|
			puts "#{e[:code]} >> #{e[:url]} "
		end
	end
end


